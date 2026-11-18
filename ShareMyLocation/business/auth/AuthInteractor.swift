/// Интерактор аутентификации: оркестрирует AuthRepository и возвращает бизнес-модели.
/// Успешным считается только результат, после которого документ users/{uid} создан
/// или обновлён. Порт 1:1 из Android AuthInteractor.kt (signInWithGoogle дополнен
/// accessToken из iOS-сигнатуры плана).
protocol AuthInteractor {
    /// Вход по email/password.
    func signInWithEmail(email: String, password: String) async -> AuthResult

    /// Регистрация email/password c displayName.
    func signUpWithEmail(email: String, password: String, displayName: String) async -> AuthResult

    /// Обмен Google-токенов на Firebase-сессию.
    func signInWithGoogle(idToken: String, accessToken: String?) async -> AuthResult

    /// Обмен Apple-токена на Firebase-сессию.
    func signInWithApple(idToken: String, rawNonce: String, fullName: String?) async -> AuthResult

    /// Текущий пользователь сохранённой сессии либо nil.
    func getCurrentUser() async -> User?

    func signOut() async

    /// Realtime-поток состояния аутентификации: первая эмиссия — сохранённая сессия
    /// (или nil), далее — при каждом sign-in/sign-out.
    func observeAuthState() -> AsyncStream<User?>
}
