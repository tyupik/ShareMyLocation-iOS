/// Ui-модель профиля, в которую конвертер переводит бизнес-модель User.
/// Порт 1:1 из Android ProfileUiModel.
struct ProfileUiModel {
    let displayName: String
    let email: String?
    let phone: String?

    /// Путь к файлу аватара в кэше приложения; nil — плейсхолдер с инициалом.
    /// Догружается асинхронно во ViewModel после основного контента.
    var avatarPath: String?
}

/// Ошибки загрузки профиля в терминах Ui-слоя. Порт 1:1 из Android ProfileUiError.
enum ProfileUiError {
    /// Нет сети или таймаут.
    case network

    /// Всё остальное; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Конвертер бизнес-модели пользователя в Ui-модель вкладки «Профиль». Порт 1:1.
struct ProfileUiConverter {
    func convert(user: User, avatarPath: String?) -> ProfileUiModel {
        ProfileUiModel(
            displayName: user.displayName ?? "",
            email: user.email,
            phone: user.phone,
            avatarPath: avatarPath,
        )
    }

    func convertError(_ error: ProfileError) -> ProfileUiError {
        switch error {
        case .invalidPhone:
            return .unexpected("ProfileError.invalidPhone")
        case .networkUnavailable:
            return .network
        case .avatarTooLarge:
            return .unexpected("ProfileError.avatarTooLarge")
        case .unexpected(let reason):
            return .unexpected(reason)
        }
    }
}
