import Observation

/**
 Корневая ViewModel приложения: при старте и после входа/онбординга проверяет сессию
 и документ users/{uid}, чтобы корневая навигация выбрала стартовый экран
 (Auth / ProfileSetup / Main). Порт resolveSession из Android AppViewModel.kt.

 Дополнительно (этап 8) — корневой оркестратор фонового движка отправки геолокации
 (порт observeSharingEnabled Android 1:1): после каждого успешного resolveSession с
 isAuthenticated == true перезапускается realtime-подписка на флаг isEnabled и на каждую
 эмиссию стартует/останавливает движок через LocationSharingEngine. Закрывает оба
 сценария: при старте процесса движок поднимается, если isEnabled и права (проверка
 внутри движка); тумблер стартит/останавливает шаринг даже с закрытым экраном настроек
 (latency compensation Firestore делает реакцию мгновенной). Обрыв потока — fail-safe:
 лог + остановка движка.
 */
@MainActor
@Observable
final class AppViewModel {
    private(set) var state: AppUiState = .initial

    /// One-off события корневой навигации: отправляются после входа (AuthScreen)
    /// и после завершения онбординга (ProfileSetupScreen) — порт
    /// resolveSession(sendEffect: true) из Android.
    let effects: AsyncStream<AppEffect>
    private let effectsContinuation: AsyncStream<AppEffect>.Continuation

    private let authInteractor: AuthInteractor
    private let profileInteractor: ProfileInteractor
    private let sharingInteractor: SharingInteractor
    private let locationSharingEngine: LocationSharingEngine
    private let appUiConverter: AppUiConverter

    /**
     Триггер перезапуска слушателя isEnabled: счётчик инкрементируется после каждого
     успешного resolveSession вошедшего пользователя (init и authCompleted/onboardingCompleted)
     — порт sharingTrigger Android: ViewModel переживает logout→login, старый поток после
     смены аккаунта умирает, без перезапуска движок второго аккаунта остался бы мёртвым.
     */
    private var sharingTrigger = 0

    /// Активная подписка на флаг isEnabled: перезапускается инкрементом триггера
    /// (порт flatMapLatest Android).
    private var sharingTask: Task<Void, Never>?

    init(
        authInteractor: AuthInteractor,
        profileInteractor: ProfileInteractor,
        sharingInteractor: SharingInteractor,
        locationSharingEngine: LocationSharingEngine,
        appUiConverter: AppUiConverter,
    ) {
        self.authInteractor = authInteractor
        self.profileInteractor = profileInteractor
        self.sharingInteractor = sharingInteractor
        self.locationSharingEngine = locationSharingEngine
        self.appUiConverter = appUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: AppEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
        observeSession()
    }

    deinit {
        sharingTask?.cancel()
    }

    func onIntent(_ intent: AppIntent) {
        switch intent {
        case .authCompleted:
            // Порт Android AppViewModel: повторный resolve после входа, на этот раз
            // с отправкой AppEffect (целевой экран — онбординг или Main).
            Task {
                await resolveSession(sendEffect: true)
            }
        case .onboardingCompleted:
            // Порт Android: ProfileSetupScreen → onCompleted → resolveSession(sendEffect: true),
            // после сохранения hasCompletedOnboarding = true чтение даёт Main.
            Task {
                await resolveSession(sendEffect: true)
            }
        }
    }

    /// Подписка на состояние аутентификации: первая эмиссия резолвит сессию без эффекта,
    /// дальнейшие (sign-in/sign-out) — та же реакция (как init-вызов resolveSession в Android).
    private func observeSession() {
        Task {
            for await _ in authInteractor.observeAuthState() {
                await resolveSession(sendEffect: false)
            }
        }
    }

    /// Читает сессию и документ профиля, обновляет AppUiState; после входа или онбординга
    /// (sendEffect = true) дополнительно отправляет Effect с целевым экраном.
    /// Ошибка чтения профиля не блокирует вход: онбординг считается пройденным
    /// (порт Android resolveSession: profile = getOrNull()).
    private func resolveSession(sendEffect: Bool) async {
        let user = await authInteractor.getCurrentUser()
        var profile: User?
        if let user {
            switch await profileInteractor.getProfile() {
            case .success(let loadedProfile):
                profile = loadedProfile
            case .failure(let error):
                print("AppViewModel: Не удалось прочитать users/{uid}, пропускаем экран онбординга — \(error)")
            }
        }
        let uiModel = appUiConverter.convert(user, profile)
        state = AppUiState(
            isSessionResolved: true,
            isAuthenticated: uiModel.isAuthenticated,
            requiresOnboarding: uiModel.requiresOnboarding,
        )
        if uiModel.isAuthenticated {
            sharingTrigger += 1
            restartSharingTask()
        }
        if sendEffect {
            let effect: AppEffect = uiModel.requiresOnboarding ? .navigateToProfileSetup : .navigateToMain
            effectsContinuation.yield(effect)
        }
    }

    /**
     Realtime-флаг isEnabled → старт/стоп движка (порт observeSharingEnabled Android).
     Подписка перезапускается по триггеру; конец потока без отмены (ошибка Firestore-
     слушателя: сеть, PERMISSION_DENIED после logout, смерть слушателя) глотается
     НАМЕРЕННО: контракт AppUiState не содержит error-полей, а движок обязан
     останавливаться при обрыве (fail-safe) — job при этом жив и реагирует на триггер.
     */
    private func restartSharingTask() {
        sharingTask?.cancel()
        sharingTask = Task {
            for await isEnabled in sharingInteractor.observeIsEnabled() {
                guard !Task.isCancelled else { return }
                locationSharingEngine.setSharingEnabled(isEnabled)
            }
            guard !Task.isCancelled else { return }
            print("AppViewModel: Realtime-поток флага isEnabled прервался — стоп движка")
            locationSharingEngine.setSharingEnabled(false)
        }
    }
}
