import Observation

/// Корневая ViewModel приложения: при старте и после входа через AuthScreen проверяет
/// сессию, чтобы корневая навигация выбрала стартовый экран (Auth / ProfileSetup / Main).
/// Порт resolveSession из Android AppViewModel.kt: чтение профиля users/{uid}
/// для requiresOnboarding подключит этап 3 (конвертер вызывается с profile == nil),
/// оркестрация шаринга геолокации (LocationSharingEngine) — этап 8, здесь не трогаем.
@MainActor
@Observable
final class AppViewModel {
    private(set) var state: AppUiState = .initial

    /// One-off события корневой навигации: отправляются после входа через AuthScreen
    /// (порт resolveSession(sendEffect: true) из Android).
    let effects: AsyncStream<AppEffect>
    private let effectsContinuation: AsyncStream<AppEffect>.Continuation

    private let authInteractor: AuthInteractor
    private let appUiConverter: AppUiConverter

    init(authInteractor: AuthInteractor, appUiConverter: AppUiConverter) {
        self.authInteractor = authInteractor
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

    /// Читает сессию, обновляет AppUiState; после входа (sendEffect = true) дополнительно
    /// отправляет Effect с целевым экраном. Профиль users/{uid} добавит этап 3:
    /// сейчас конвертер вызывается с profile == nil, поэтому requiresOnboarding всегда false
    /// и Effect после входа — всегда navigateToMain.
    private func resolveSession(sendEffect: Bool) async {
        let user = await authInteractor.getCurrentUser()
        let uiModel = appUiConverter.convert(user, nil)
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
