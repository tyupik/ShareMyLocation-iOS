/**
 SSOT экрана управления группой: один экран на создание (`groupId` == nil) и редактирование.
 Состав выбирается чекбоксами из друзей владельца; запись в Firestore — только по
 saveClicked/deleteConfirmed. Порт 1:1 из Android GroupEditorContract.kt.
 */
struct GroupEditorUiState {
    /// nil — создание группы, иначе — id редактируемой группы.
    var groupId: String? = nil

    /// Первичная загрузка (группа + друзья); при каждом screenShown снова true.
    var isLoading: Bool = true

    /**
     Экран-ошибка загрузки (группа не прочитана или упал realtime-поток друзей);
     «Повторить» — повторный screenShown. Причина уточняется `loadError`.
     */
    var isLoadFailed: Bool = false

    /// Конкретная причина экрана-ошибки; nil — generic-текст (падение потока друзей).
    var loadError: GroupsUiError? = nil

    var name: String = ""

    /// Все друзья владельца; `GroupMemberUiModel.isChecked` — вхождение в группу на экране.
    var friends: [GroupMemberUiModel] = []

    /// Сбрасывается при каждом screenShown — вход на экран не должен наследовать занятость
    /// пережившей ViewModel.
    var isSaving: Bool = false

    /// Сбрасывается при каждом screenShown — вход на экран не должен наследовать занятость
    /// пережившей ViewModel.
    var isDeleting: Bool = false

    /// Транзиентное UI-состояние, вход = без диалога.
    var isDeleteDialogVisible: Bool = false

    /**
     Ошибка явного действия (сохранить/удалить) для баннера; ошибки загрузки сюда
     не попадают (isLoadFailed). Сбрасывается по errorDismissed и при каждом screenShown.
     */
    var actionError: GroupsUiError? = nil

    static let initial = GroupEditorUiState()
}

/// Действия пользователя на экране управления группой. Порт 1:1 из Android GroupEditorIntent.
enum GroupEditorIntent {
    /**
     Экран показан: в режиме редактирования — одноразовая перечитка группы, в обоих режимах —
     перезапуск realtime-потока друзей. Повтор по «Повторить» — тот же intent с тем же groupId.
     */
    case screenShown(groupId: String?)

    case nameChanged(String)

    /// Локальное переключение чекбокса участника; запись в Firestore — только по saveClicked.
    case memberToggled(uid: String)

    /**
     Сохранение: создание — createGroup(имя + выбранный состав),
     редактирование — updateGroup(имя + весь memberUids).
     */
    case saveClicked

    /// Запрос удаления: показывает диалог подтверждения.
    case deleteClicked

    /// Подтверждение удаления в диалоге.
    case deleteConfirmed

    case deleteDialogDismissed

    case errorDismissed
}

/// One-off события экрана. Порт 1:1 из Android GroupEditorEffect.
enum GroupEditorEffect {
    /// Сохранение или удаление завершены — навигация назад (список обновится realtime-слушателем).
    case closed
}
