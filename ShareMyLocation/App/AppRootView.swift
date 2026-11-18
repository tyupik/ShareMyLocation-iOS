import Factory
import SwiftUI

/// Корень приложения, порт AppRoot.kt в заглушечном виде этапа 1: пока сессия
/// не проверена — индикатор загрузки; затем switch по AppUiState
/// (Auth / ProfileSetup / Main). Реальные экраны подключают этапы 2–3;
/// навигационные события (AppEffect) пойдут через них же.
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
                placeholder("Экран входа — этап 2")
            } else if viewModel.state.requiresOnboarding {
                placeholder("Онбординг — этап 3")
            } else {
                placeholder("Main — этапы 4–8")
            }
        }
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
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
