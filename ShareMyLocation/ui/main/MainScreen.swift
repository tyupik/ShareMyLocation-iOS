import Factory
import SwiftUI

/// Главный экран-контейнер: вкладки Карта (заглушка этапа 7), Друзья, Профиль и кастомный
/// навбар-пилюля (MainBottomBar через safeAreaInset). Навигацию выполняет вызывающая сторона:
/// экран сам не знает про корневой switch — выход из аккаунта уходит в MainViewModel
/// (signOut → observeAuthState переразрешает сессию, корень показывает AuthScreen),
/// а редактор групп на этапе 4 — временный баннер (этап 5 подключит реальный editor).
/// Правка профиля — sheet внутри экрана. Порт 1:1 из Android MainScreen.kt;
/// iOS-адаптации этапа 4: карта — заглушка, лямбды сокращены против Android
/// (onSignedOut не нужен, edit — sheet, шаринг/группы — баннеры).
struct MainScreen: View {
    @State private var viewModel: MainViewModel

    /// Правка профиля — sheet поверх вкладки (эфемерное UI-состояние, не бизнес-состояние).
    @State private var isEditPresented = false

    /// Временный баннер «Редактор групп появится на этапе 5» (до подключения GroupEditor).
    @State private var isGroupsNoticeShown = false

    /// Таймер автоскрытия баннера групп: отменяется при повторном показе,
    /// чтобы ранний таймер не скрыл новый баннер раньше срока.
    @State private var groupsNoticeHideTask: Task<Void, Never>?

    /// Временный баннер «Настройки шаринга появятся на этапе 6» (до SharingSettingsScreen).
    @State private var isSharingNoticeShown = false

    /// Таймер автоскрытия баннера шаринга: аналогично отменяется при повторном показе.
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
                // Редактор групп появится на этапе 5: пока запрос редактора показывает баннер.
                FriendsScreen(onOpenGroupEditor: { _ in showGroupsNotice() })
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
        .overlay(alignment: .top) {
            if isGroupsNoticeShown {
                // Временный авто-скрывающийся баннер до этапа 5.
                ErrorBanner(text: "Редактор групп появится на этапе 5")
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            if isSharingNoticeShown {
                // Настройки шаринга появятся на этапе 6: временный авто-скрывающийся баннер.
                ErrorBanner(text: "Настройки шаринга появятся на этапе 6")
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isGroupsNoticeShown)
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
    private func showGroupsNotice() {
        groupsNoticeHideTask?.cancel()
        groupsNoticeHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            isGroupsNoticeShown = false
        }
    }

    /// Аналог showGroupsNotice для баннера настроек шаринга.
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
