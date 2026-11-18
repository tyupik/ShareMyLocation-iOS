import Foundation

/// Ui-модель профиля, в которую конвертер переводит бизнес-модель User.
/// Порт 1:1 из Android ProfileSetupUiModel.
struct ProfileSetupUiModel {
    let displayName: String
    let phone: String

    /// Путь к кэш-файлу уже сохранённого аватара; конвертер всегда возвращает nil —
    /// путь резолвится асинхронно в ProfileSetupViewModel через интерактор.
    let savedAvatarPath: String?
}

/// Конвертер бизнес-моделей профиля в Ui-модели экрана настройки. Порт 1:1.
struct ProfileSetupUiConverter {
    func convert(user: User) -> ProfileSetupUiModel {
        ProfileSetupUiModel(
            displayName: user.displayName ?? "",
            phone: user.phone ?? "",
            savedAvatarPath: nil,
        )
    }

    func convertError(_ error: ProfileError) -> ProfileSetupUiError {
        switch error {
        case .invalidPhone:
            return .invalidPhone
        case .networkUnavailable:
            return .network
        case .avatarTooLarge:
            return .avatarTooLarge
        case .unexpected(let reason):
            return .unexpected(reason)
        }
    }
}
