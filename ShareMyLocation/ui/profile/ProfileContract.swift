/// Фазы вкладки «Профиль»: взаимоисключающие — загрузка, данные или ошибка.
/// Порт 1:1 из Android ProfileUiState (sealed interface) в виде struct с вложенным enum.
struct ProfileUiState {
    enum Phase {
        /// Вкладка загружает профиль.
        case loading

        /// Данные профиля загружены.
        case content(ProfileUiModel)

        /// Загрузка профиля не удалась.
        case error(ProfileUiError)
    }

    var phase: Phase = .loading

    static let initial = ProfileUiState()
}

/// Действия пользователя на вкладке «Профиль». Порт 1:1 из Android ProfileIntent.
enum ProfileIntent {
    /// Вкладка показана: перечитываем профиль при каждом входе на вкладку.
    case screenShown

    /// Пользователь нажал «Редактировать».
    case editClicked

    /// Пользователь нажал «Делиться геопозицией».
    case sharingClicked
}

/// One-off события экрана. Порт 1:1 из Android ProfileEffect.
enum ProfileEffect {
    /// Открыть ProfileSetup в режиме редактирования; навигацию выполняет вызывающая сторона.
    case navigateToEditProfile

    /// Открыть настройки шаринга; навигацию выполняет вызывающая сторона
    /// (этап 6; временно обрабатывается баннером-заглушкой).
    case navigateToSharingSettings
}
