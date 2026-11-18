import Contacts

/**
 SSOT вкладки «Друзья». Секции «Поиск», «Список» живут в одном состоянии, заявки — в
 sheet'е по колокольчику (`isRequestsSheetVisible`); списки приходят realtime-потоками,
 `searchState` и `busyUid` не зависят друг от друга. Аватары резолвятся асинхронно после
 основного контента: ошибка аватара не ломает экран, остаётся плейсхолдер с инициалом.
 Контакт из системного пикера (`FriendsIntent.contactPicked`) нового состояния не требует:
 его телефон подставляется в `searchQuery` и переиспользует обычный поиск (`searchState`).
 Порт 1:1 из Android FriendsContract.kt (ContactPickerUnavailable не портируется:
 CNContactPickerViewController недоступен только без приложения контактов — всегда есть).
 */
struct FriendsUiState {
    var friends: [FriendUiModel] = []
    var isFriendsLoading: Bool = true
    var incomingRequests: [FriendRequestUiModel] = []

    /// Текущий запрос поиска; вход на вкладку = чистый лист поиска (сбрасывается screenShown).
    var searchQuery: String = ""
    var searchState: FriendsSearchUiState = .idle

    /// uid, с которым сейчас выполняется действие (кнопки показывают прогресс).
    var busyUid: String? = nil

    /// Ошибка явного действия (поиск/добавить/принять/отклонить/удалить) для баннера;
    /// ошибки пассивной загрузки секций сюда не попадают. Сбрасывается по errorDismissed
    /// и при каждом screenShown.
    var actionError: FriendsUiError? = nil

    /// Пассивная недоступность секции «Друзья» (упал realtime-поток); восстанавливается
    /// screenShown/Повторить.
    var isFriendsLoadFailed: Bool = false

    /// Пассивная недоступность секции «Заявки» (упал realtime-поток); восстанавливается
    /// screenShown/Повторить.
    var isRequestsLoadFailed: Bool = false

    /// Секция «Группы»: realtime-список групп владельца (имя + число участников).
    var groups: [GroupUiModel] = []
    var isGroupsLoading: Bool = true

    /// Пассивная недоступность секции «Группы» (упал realtime-поток); восстанавливается
    /// screenShown/Повторить.
    var isGroupsLoadFailed: Bool = false

    /// Снимок друга, для которого открыт диалог подтверждения удаления; nil — диалог скрыт.
    /// Транзиентное: вход на вкладку = без диалога (сбрасывается screenShown).
    var removeDialogFriend: FriendUiModel? = nil

    /// Видимость sheet'а заявок. Транзиентное: вход на вкладку = лист закрыт
    /// (сбрасывается screenShown).
    var isRequestsSheetVisible: Bool = false

    static let initial = FriendsUiState()
}

/// Состояние секции поиска. Порт 1:1 из Android FriendsSearchUiState (sealed interface).
enum FriendsSearchUiState {
    case idle
    case loading
    case found(FriendUiModel)
    case notFound
    case error(FriendsUiError)
}

extension FriendsSearchUiState {
    /// Активен ли поиск (guard повторного запуска; аналог `is Loading` Android).
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}

/// Действия пользователя на вкладке «Друзья». Порт 1:1 из Android FriendsIntent
/// без ContactPickerUnavailable (iOS-пикер не требует приложения контактов).
enum FriendsIntent {
    /// Вкладка показана: перезапускаем realtime-потоки при каждом входе на вкладку.
    case screenShown

    /// Нажат колокольчик заявок — открыть sheet со списком заявок.
    case requestsBellClicked

    /// Sheet заявок закрыт (свайп, тап вне, назад).
    case requestsSheetDismissed

    case searchQueryChanged(String)
    case searchClicked
    case searchCleared

    /// Системный контакт-пикер вернул результат: `contact` — выбранный контакт целиком
    /// (читаем первый непустой телефон и запускаем поиск по нему), nil — пикер закрыт
    /// без выбора, реакция не нужна.
    case contactPicked(CNContact?)

    case addFriendClicked(uid: String)
    case acceptRequestClicked(fromUid: String)
    case declineRequestClicked(fromUid: String)

    /// Нажата кнопка «Удалить из друзей» у друга `uid` — открыть диалог подтверждения.
    case removeFriendClicked(uid: String)

    /// Подтверждение удаления в диалоге: удаляем друга из снимка FriendsUiState.removeDialogFriend.
    case removeFriendConfirmed

    /// Диалог подтверждения удаления закрыт без подтверждения.
    case removeFriendDialogDismissed

    /// Нажата кнопка «Создать» в секции групп — открыть редактор в режиме создания.
    case createGroupClicked

    /// Нажата карточка группы `groupId` — открыть редактор этой группы.
    case groupClicked(groupId: String)

    case errorDismissed
}

/// One-off события экрана. Порт 1:1 из Android FriendsEffect.
enum FriendsEffect {
    /// Заявка в друзья успешно отправлена — показываем оверлей-подтверждение (аналог Snackbar).
    case friendRequestSent

    /// Открыть редактор группы поверх Main; `groupId` == nil — режим создания.
    case openGroupEditor(groupId: String?)
}
