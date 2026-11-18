import Factory
import SwiftUI

/// Вкладка «Профиль»: показывает аватар, имя, email и телефон, кнопки «Редактировать»,
/// «Делиться геопозицией» и «Выход». Навигацию выполняет вызывающая сторона: onEditProfile
/// и onOpenSharingSettings вызываются только из коллекции Effect, onSignOut передаёт
/// действие наружу (в Android — контракт MainScreen). Порт 1:1 из Android ProfileScreen.kt.
struct ProfileScreen: View {
    let onEditProfile: () -> Void
    let onOpenSharingSettings: () -> Void
    let onSignOut: () -> Void

    @State private var viewModel: ProfileViewModel

    init(
        onEditProfile: @escaping () -> Void,
        onOpenSharingSettings: @escaping () -> Void,
        onSignOut: @escaping () -> Void,
    ) {
        self.onEditProfile = onEditProfile
        self.onOpenSharingSettings = onOpenSharingSettings
        self.onSignOut = onSignOut
        _viewModel = State(initialValue: Container.shared.profileViewModel())
    }

    var body: some View {
        AuroraBackdrop {
            switch viewModel.state.phase {
            case .loading:
                ProgressView()
                    .tint(AuroraColors.auroraIndigoLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .content(let profile):
                ProfileContent(
                    profile: profile,
                    onIntent: { viewModel.onIntent($0) },
                    onSignOut: onSignOut,
                )
            case .error(let error):
                LoadError(
                    text: errorText(error),
                    retryText: "Повторить",
                    onRetry: { viewModel.onIntent(.screenShown) },
                    isCentered: true,
                )
            }
        }
        .task {
            // На каждый показ — перечитка профиля (порт LaunchedEffect(Unit) Android).
            viewModel.onIntent(.screenShown)
        }
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case .navigateToEditProfile:
                    onEditProfile()
                case .navigateToSharingSettings:
                    onOpenSharingSettings()
                }
            }
        }
    }

    /// Тексты ошибок — дословно Android strings.xml.
    private func errorText(_ error: ProfileUiError) -> String {
        switch error {
        case .network:
            return "Не удалось загрузить профиль. Проверьте интернет и попробуйте снова"
        case .unexpected:
            return "Не удалось загрузить профиль. Попробуйте ещё раз"
        }
    }
}

/// Контент вкладки: шапка, контактные данные и кнопки действий.
private struct ProfileContent: View {
    let profile: ProfileUiModel
    let onIntent: (ProfileIntent) -> Void
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeader(
                    displayName: profile.displayName,
                    avatarPath: profile.avatarPath,
                )

                if let email = profile.email {
                    ProfileInfoRow(symbolName: "envelope", text: email)
                }

                if let phone = profile.phone {
                    ProfileInfoRow(symbolName: "phone", text: phone)
                }

                ProfileEditButton {
                    onIntent(.editClicked)
                }

                ProfileSharingButton {
                    onIntent(.sharingClicked)
                }

                ProfileSignOutButton(action: onSignOut)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview {
    ProfileContent(
        profile: ProfileUiModel(
            displayName: "Иван",
            email: "ivan@example.com",
            phone: "+79991234567",
            avatarPath: nil,
        ),
        onIntent: { _ in },
        onSignOut: {},
    )
    .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
