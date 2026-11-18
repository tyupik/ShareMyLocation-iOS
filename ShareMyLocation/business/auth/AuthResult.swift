/// Бизнес-модель результата аутентификации. Порт 1:1 из Android AuthResult.kt.
enum AuthResult {
    /// Аутентификация прошла, документ users/{uid} создан или обновлён.
    case success

    case error(AuthError)
}
