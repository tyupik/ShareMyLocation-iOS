import Observation

/// Корневая ViewModel приложения: подписывается на observeAuthState и обновляет
/// AppUiState, чтобы корневая навигация выбрала стартовый экран
/// (Auth / ProfileSetup / Main). Порт resolveSession из Android AppViewModel.kt;
/// в этапе 1 сессия резолвится потоком observeAuthState (указание docs/port-plan.md),
/// чтение профиля users/{uid} для requiresOnboarding подключит этап 3,
/// отправку AppEffect (после входа через AuthScreen) — этап 2.
/// Оркестрация шаринга геолокации (LocationSharingEngine) — этап 8, здесь не трогаем.
@MainActor
@Observable
final class AppViewModel {
    private(set) var state: AppUiState = .initial

    /// One-off события корневой навигации; отправка включается в этапе 2 вместе с AuthScreen.
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
            // No-op этапа 1: состояние обновляет подписка на observeAuthState
            // (сама эмиссия приходит после sign-in), повторный resolve не нужен.
            break
        }
    }

    /// Подписка на состояние аутентификации: первая эмиссия резолвит сессию,
    /// дальнейшие — реакция на sign-in/sign-out. Профиль для requiresOnboarding
    /// (users/{uid}) добавит этап 3: сейчас конвертер вызывается с profile == nil.
    private func observeSession() {
        Task {
            for await user in authInteractor.observeAuthState() {
                let uiModel = appUiConverter.convert(user, nil)
                state = AppUiState(
                    isSessionResolved: true,
                    isAuthenticated: uiModel.isAuthenticated,
                    requiresOnboarding: uiModel.requiresOnboarding,
                )
            }
        }
    }
}
