/// Модели Ui-слоя, в которые конвертер переводит бизнес-результат аутентификации.
/// Порт 1:1 из Android AuthUiConverter.kt.
enum AuthUiModel {
    case success

    case error(AuthUiError)
}

/// Ошибки аутентификации в терминах Ui-слоя. Порт 1:1 из Android AuthUiError
/// + iOS-расширение googleNotConfigured (GoogleSignIn-iOS без конфигурации).
enum AuthUiError {
    case invalidCredentials

    case emailAlreadyInUse

    case networkUnavailable

    case unexpected(String?)

    /// SDK Google не сконфигурирован (нет GoogleService-Info.plist) — баннер
    /// «Сервисы Google не настроены».
    case googleNotConfigured
}

/// Конвертер бизнес-результата аутентификации в Ui-модель. Порт 1:1 из Android.
struct AuthUiConverter {
    func convert(_ result: AuthResult) -> AuthUiModel {
        switch result {
        case .success:
            return .success
        case .error(let error):
            return .error(toUiError(error))
        }
    }

    private func toUiError(_ error: AuthError) -> AuthUiError {
        switch error {
        case .invalidCredentials:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .networkUnavailable:
            return .networkUnavailable
        case .unexpected(let reason):
            return .unexpected(reason)
        }
    }
}
