/// Типизированные ошибки аутентификации; маппятся из Firebase в data-слое.
/// Порт 1:1 из Android business/auth/AuthError.kt.
enum AuthError {
    /// Неверный email или пароль при входе либо некорректные данные при регистрации.
    case invalidCredentials

    /// Email уже занят.
    case emailAlreadyInUse

    /// Нет сети или таймаут.
    case networkUnavailable

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Доменная ошибка аутентификации: несёт типизированный AuthError для интерактора.
/// Порт Android AuthException(error, cause): исходный Throwable не переносится —
/// его текст попадает в reason кейса .unexpected и в лог data-слоя.
struct AuthException: Error {
    let error: AuthError
}
