import Observation

/// Корневая ViewModel приложения: при старте и после входа/онбординга проверяет сессию
/// и документ users/{uid}, чтобы корневая навигация выбрала стартовый экран
/// (Auth / ProfileSetup / Main). Порт resolveSession из Android AppViewModel.kt;
/// оркестрация шаринга геолокации (LocationSharingEngine) — этап 8, здесь не трогаем.
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
    private let appUiConverter: AppUiConverter

    init(authInteractor: AuthInteractor, profileInteractor: ProfileInteractor, appUiConverter: AppUiConverter) {
        self.authInteractor = authInteractor
        self.profileInteractor = profileInteractor
        self.appUiConverter = appUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: AppEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
        observeSession()
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
        if sendEffect {
            let effect: AppEffect = uiModel.requiresOnboarding ? .navigateToProfileSetup : .navigateToMain
            effectsContinuation.yield(effect)
        }
    }
}
