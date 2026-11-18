/// Ui-модели и конвертер экрана настроек шаринга: порт 1:1 из Android SharingSettingsUiConverter.kt.

/// Ui-модель строки чекбокса секций «Люди»/«Группы» настроек шаринга.
struct SharingCheckRowUiModel {
    /// uid друга либо groupId группы.
    let id: String
    let displayName: String

    /// Вхождение в выбор шаринга на экране; запись в Firestore — автосохранением.
    var isChecked: Bool
}

/// Ошибки фичи «Шаринг» в терминах Ui-слоя.
enum SharingUiError {
    case network

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Конвертер бизнес-моделей в Ui-модели экрана настроек шаринга.
struct SharingSettingsUiConverter {
    func convertFriend(_ user: User, isChecked: Bool) -> SharingCheckRowUiModel {
        SharingCheckRowUiModel(
            id: user.uid,
            displayName: user.displayName ?? "",
            isChecked: isChecked,
        )
    }

    func convertGroup(_ group: Group, isChecked: Bool) -> SharingCheckRowUiModel {
        SharingCheckRowUiModel(
            id: group.groupId,
            displayName: group.name,
            isChecked: isChecked,
        )
    }

    func convertAudience(_ audience: SharingAudience) -> SharingAudienceUi {
        switch audience {
        case .allFriends:
            return .allFriends
        case .custom:
            return .custom
        }
    }

    /// Обратное преобразование аудитории для снимка записи.
    func toBusiness(_ audience: SharingAudienceUi) -> SharingAudience {
        switch audience {
        case .allFriends:
            return .allFriends
        case .custom:
            return .custom
        }
    }

    func convertError(_ error: SharingError) -> SharingUiError {
        switch error {
        case .networkUnavailable:
            return .network
        case .unexpected(let reason):
            return .unexpected(reason)
        }
    }
}
