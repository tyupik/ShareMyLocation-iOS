import Factory
import SwiftUI

/// Payload sheet'а редактора группы: обёртка groupId для sheet(item:) (эфемерное UI-состояние
/// экрана, приходит из Effect openGroupEditor FriendsScreen — в state его класть запрещено
/// правилами MVI). nil groupId — режим создания.
private struct GroupEditorPayload: Identifiable {
    let id = UUID()
    let groupId: String?
}

/// Главный экран-контейнер: вкладки Карта (заглушка этапа 7), Друзья, Профиль и кастомный
/// навбар-пилюля (MainBottomBar через safeAreaInset). Навигацию выполняет вызывающая сторона:
/// экран сам не знает про корневой switch — выход из аккаунта уходит в MainViewModel
/// (signOut → observeAuthState переразрешает сессию, корень показывает AuthScreen).
/// Правка профиля — sheet внутри экрана; редактор групп и настройки шаринга — sheet'ы
/// поверх вкладок (GroupEditorScreen сам закрывается Effect'ом closed → обнуление payload).
/// Порт 1:1 из Android MainScreen.kt; iOS-адаптации: карта — заглушка, лямбды сокращены
/// против Android (onSignedOut не нужен, edit/sharing — sheet'ы).
struct MainScreen: View {
    @State private var viewModel: MainViewModel

    /// Правка профиля — sheet поверх вкладки (эфемерное UI-состояние, не бизнес-состояние).
    @State private var isEditPresented = false

    /// Редактор групп: sheet поверх вкладок (эфемерное UI-состояние, не бизнес-состояние).
    @State private var groupEditorPayload: GroupEditorPayload?

    /// Настройки шаринга: sheet поверх вкладок (эфемерное UI-состояние, не бизнес-состояние).
    @State private var isSharingSettingsPresented = false

    init() {
        _viewModel = State(initialValue: Container.shared.mainViewModel())
    }

    var body: some View {
        ZStack {
            switch viewModel.state.selectedTab {
            case .map:
                MainMapStub()
            case .friends:
                // Редактор групп открывается sheet'ом поверх Main (Effect → payload → sheet).
                FriendsScreen(onOpenGroupEditor: { groupEditorPayload = GroupEditorPayload(groupId: $0) })
            case .profile:
                ProfileScreen(
                    onEditProfile: { isEditPresented = true },
                    onOpenSharingSettings: { isSharingSettingsPresented = true },
                    onSignOut: { viewModel.onIntent(.signOutClicked) },
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Нижняя навигация-пилюля: контент не заезжает под неё (карта — этап 7 добавит
        // свой contentPadding поверх safeAreaInset).
        .safeAreaInset(edge: .bottom) {
            MainBottomBar(
                selectedTab: viewModel.state.selectedTab,
                friendsBadgeCount: viewModel.state.pendingRequestsCount,
                onTabSelected: { viewModel.onIntent(.tabSelected($0)) },
            )
        }
        .sheet(isPresented: $isEditPresented) {
            ProfileSetupScreen(isEditMode: true, onCompleted: { isEditPresented = false })
        }
        .sheet(item: $groupEditorPayload) { payload in
            GroupEditorScreen(
                groupId: payload.groupId,
                // Закрытие по Effect closed; свайп-закрытие sheet'а обнуляет payload без .closed —
                // подписка эффектов умирает вместе с экраном, рассинхрона нет.
                onClosed: { groupEditorPayload = nil },
            )
        }
        .sheet(isPresented: $isSharingSettingsPresented) {
            // Своей кнопки закрытия у экрана нет: закрывается свайпом/тапом вне —
            // флаг сбрасывается binding'ом; Task'и умирающей ViewModel безвредны.
            SharingSettingsScreen()
        }
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case .navigateToAuth:
                    // no-op: signOut уже выполнен, observeAuthState переразрешит сессию
                    // и корень покажет AuthScreen (аналог onSignedOut Android не нужен —
                    // допущение 5 плана этапа 4).
                    print("MainScreen: navigateToAuth")
                }
            }
        }
    }
}

#Preview {
    MainScreen()
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
