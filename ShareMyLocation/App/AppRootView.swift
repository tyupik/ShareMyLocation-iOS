import Factory
import SwiftUI

/// Корень приложения, порт AppRoot.kt: пока сессия не проверена — индикатор загрузки,
/// затем switch по AppUiState (Auth / ProfileSetup / Main). Ветка Auth с этапа 2 —
/// реальный AuthScreen (связь 1:1 с Android: AuthScreen(onSuccess = { AuthCompleted })));
/// реальный ProfileSetup/Main подключают этапы 3–8.
struct AppRootView: View {
    @State private var viewModel: AppViewModel

    init() {
        _viewModel = State(initialValue: Container.shared.appViewModel())
    }

    var body: some View {
        AuroraBackdrop {
            if !viewModel.state.isSessionResolved {
                ProgressView()
                    .tint(AuroraColors.auroraIndigoLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.state.isAuthenticated {
                AuthScreen(onAuthenticated: { viewModel.onIntent(.authCompleted) })
            } else if viewModel.state.requiresOnboarding {
                placeholder("Онбординг — этап 3")
            } else {
                placeholder("Main — этапы 4–8")
            }
        }
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
        .task {
            // Подписка на AppEffect: переключение ветки уже выполнено switch'ем по state
            // (см. AppViewModel.resolveSession), поэтому обработчик — только лог,
            // контракт one-off событий при этом не нарушается (допущение 7 плана этапа 2).
            for await effect in viewModel.effects {
                switch effect {
                case .navigateToMain:
                    print("AppRootView: navigateToMain")
                case .navigateToProfileSetup:
                    print("AppRootView: navigateToProfileSetup")
                }
            }
        }
    }

    /// Текстовая заглушка ветки навигации до появления реального экрана.
    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.auroraHeadlineSmall)
            .foregroundStyle(AuroraColors.auroraTextMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppRootView()
}
