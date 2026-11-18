/// Ui-модели и конвертер редактора группы: порт 1:1 из Android GroupEditorUiConverter.kt.

/// Ui-модель друга в списке чекбоксов редактора группы.
struct GroupMemberUiModel {
    let uid: String
    let displayName: String

    /// Вхождение друга в группу на экране; запись в Firestore — по saveClicked.
    var isChecked: Bool
}

/// Ошибки фичи «Группы» в терминах Ui-слоя.
enum GroupsUiError {
    case network
    case emptyName
    case nameTooLong
    case groupNotFound

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Конвертер бизнес-моделей в Ui-модели редактора группы.
struct GroupEditorUiConverter {
    func convertFriend(_ user: User, isChecked: Bool) -> GroupMemberUiModel {
        GroupMemberUiModel(
            uid: user.uid,
            displayName: user.displayName ?? "",
            isChecked: isChecked,
        )
    }

    func convertError(_ error: GroupsError) -> GroupsUiError {
        switch error {
        case .networkUnavailable:
            return .network
        case .emptyName:
            return .emptyName
        case .nameTooLong:
            return .nameTooLong
        case .groupNotFound:
            return .groupNotFound
        case .unexpected(let reason):
            return .unexpected(reason)
        }
    }
}
