import Factory
import SwiftUI

/// Корень приложения, порт AppRoot.kt: пока сессия не проверена — индикатор загрузки,
/// затем switch по AppUiState (Auth / ProfileSetup / Main). Ветка Auth — реальный AuthScreen,
/// ветка ProfileSetup — реальный ProfileSetupScreen, ветка Main — реальный MainScreen (этап 4).
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
                ProfileSetupScreen(isEditMode: false, onCompleted: { viewModel.onIntent(.onboardingCompleted) })
            } else {
                MainScreen()
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
}

#Preview {
    AppRootView()
}
