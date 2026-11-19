/// Вкладки главного экрана. Порт 1:1 из Android MainTab.kt.
enum MainTab: CaseIterable {
    case map
    case friends
    case profile
}

/// SSOT главного экрана-контейнера.
/// Содержимое вкладок сами управляют своим состоянием, поэтому здесь только выбранная вкладка
/// и badge-счётчик входящих заявок в друзья для нижней панели. Порт 1:1 из Android MainUiState.
struct MainUiState {
    var selectedTab: MainTab = .map

    /// Число входящих PENDING-заявок в друзья; badge на вкладке friends при значении > 0.
    var pendingRequestsCount: Int = 0

    static let initial = MainUiState()
}

/// Действия пользователя. Порт 1:1 из Android MainIntent без NotificationsPermissionResult:
/// запрос права на уведомления выполняется во ViewModel системным диалогом
/// (requestAuthorization) — UI не участвует, отдельный Intent/Effect не нужен.
enum MainIntent {
    /// Пользователь выбрал вкладку в нижней навигации.
    case tabSelected(MainTab)

    /// Пользователь нажал «Выход» на вкладке «Профиль».
    case signOutClicked
}

/// One-off события экрана. Порт 1:1 из Android MainEffect без RequestNotificationsPermission:
/// диалог запроса права системный и показывается напрямую из ViewModel, эффект не нужен.
enum MainEffect {
    /// Выход выполнен — возвращаемся на экран аутентификации.
    case navigateToAuth
}
