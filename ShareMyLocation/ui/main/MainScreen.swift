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
/// Правка профиля — sheet внутри экрана; редактор групп — sheet поверх вкладок
/// (GroupEditorScreen сам закрывается Effect'ом closed → обнуление payload).
/// «Настройки шаринга появятся на этапе 6» — временный баннер до этапа 6.
/// Порт 1:1 из Android MainScreen.kt; iOS-адаптации: карта — заглушка, лямбды сокращены
/// против Android (onSignedOut не нужен, edit — sheet, шаринг — баннер).
struct MainScreen: View {
    @State private var viewModel: MainViewModel

    /// Правка профиля — sheet поверх вкладки (эфемерное UI-состояние, не бизнес-состояние).
    @State private var isEditPresented = false

    /// Редактор групп: sheet поверх вкладок (эфемерное UI-состояние, не бизнес-состояние).
    @State private var groupEditorPayload: GroupEditorPayload?

    /// Временный баннер «Настройки шаринга появятся на этапе 6» (до SharingSettingsScreen).
    @State private var isSharingNoticeShown = false

    /// Таймер автоскрытия баннера шаринга: отменяется при повторном показе,
    /// чтобы ранний таймер не скрыл новый баннер раньше срока.
    @State private var sharingNoticeHideTask: Task<Void, Never>?

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
                    onOpenSharingSettings: { showSharingNotice() },
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
        .overlay(alignment: .top) {
            if isSharingNoticeShown {
                // Настройки шаринга появятся на этапе 6: временный авто-скрывающийся баннер.
                ErrorBanner(text: "Настройки шаринга появятся на этапе 6")
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSharingNoticeShown)
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

    /// Показ баннера на ~2 секунды; авто-скрытие без DispatchQueue (только Task).
    /// Повторный показ отменяет предыдущий таймер скрытия: без отмены более ранний
    /// Task.sleep скрыл бы новый баннер раньше срока.
    private func showSharingNotice() {
        sharingNoticeHideTask?.cancel()
        sharingNoticeHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            isSharingNoticeShown = false
        }
    }
}

#Preview {
    MainScreen()
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
