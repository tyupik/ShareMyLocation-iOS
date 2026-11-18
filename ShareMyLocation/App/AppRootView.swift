import Factory
import SwiftUI

/// Корень приложения, порт AppRoot.kt: пока сессия не проверена — индикатор загрузки,
/// затем switch по AppUiState (Auth / ProfileSetup / Main). Ветка Auth — реальный AuthScreen,
/// ветка ProfileSetup — реальный ProfileSetupScreen (этап 3); вместо Main — временная
/// заглушка с sheet'ом вкладки «Профиль» (MainScreen подключит этап 4).
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
                // Временная интеграция этапа 3 — удалить на этапе 4 (заменится MainScreen).
                MainPlaceholder(onSignOut: { viewModel.onIntent(.signOutRequested) })
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

/// Временная интеграция этапа 3 — удалить на этапе 4: вместо реального MainScreen
/// заглушка с кнопкой, открывающей sheet вкладки «Профиль» (аналог Android: вкладка
/// открывает ProfileSetup поверх Main и по выходу возвращает в Auth).
private struct MainPlaceholder: View {
    let onSignOut: () -> Void

    @State private var isProfilePresented = false
    @State private var isEditPresented = false
    @State private var isSharingNoticeShown = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Main — этапы 4–8")
                .font(.auroraHeadlineSmall)
                .foregroundStyle(AuroraColors.auroraTextMuted)
            GradientPrimaryButton(title: "Профиль", isEnabled: true, isLoading: false) {
                isProfilePresented = true
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isProfilePresented) {
            ProfileScreen(
                onEditProfile: { isEditPresented = true },
                onOpenSharingSettings: { showSharingNotice() },
                onSignOut: onSignOut,
            )
            .sheet(isPresented: $isEditPresented) {
                ProfileSetupScreen(isEditMode: true, onCompleted: { isEditPresented = false })
            }
        }
        .overlay(alignment: .top) {
            if isSharingNoticeShown {
                // Настройки шаринга появятся на этапе 6: временный авто-скрывающийся баннер.
                ErrorBanner(text: "Настройки шаринга появятся на этапе 6")
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSharingNoticeShown)
    }

    /// Показ баннера на ~2 секунды; авто-скрытие без DispatchQueue (только Task).
    private func showSharingNotice() {
        isSharingNoticeShown = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isSharingNoticeShown = false
        }
    }
}

#Preview {
    AppRootView()
}
