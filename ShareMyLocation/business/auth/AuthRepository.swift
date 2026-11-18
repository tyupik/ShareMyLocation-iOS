/// Контракт аутентификации: Firebase Auth + документ users/{uid} в Firestore.
/// Порт 1:1 из Android AuthRepository.kt. Успешным считается только результат,
/// после которого документ пользователя создан или обновлён (merge по uid) —
/// метод считается выполненным, если не выбросил исключение.
protocol AuthRepository {
    /// Вход по email/password; после входа — ensureUserDocument.
    func signInWithEmail(email: String, password: String) async throws

    /// Регистрация email/password c displayName (попадает и в сессию, и в users/{uid});
    /// после регистрации — ensureUserDocument.
    func signUpWithEmail(email: String, password: String, displayName: String) async throws

    /// Обмен Google idToken/accessToken на Firebase-сессию; после входа — ensureUserDocument.
    func signInWithGoogle(idToken: String, accessToken: String?) async throws

    /// Обмен Apple idToken (с rawNonce от анти-replay) на Firebase-сессию; fullName
    /// (приходит только при первой авторизации) пишется в displayName сессии;
    /// после входа — ensureUserDocument.
    func signInWithApple(idToken: String, rawNonce: String, fullName: String?) async throws

    /// Текущий пользователь сохранённой сессии либо nil.
    func getCurrentUser() async -> User?

    func signOut() async

    /// Realtime-поток состояния аутентификации: первая эмиссия — сохранённая сессия
    /// (или nil), далее — при каждом sign-in/sign-out. Аналог callbackFlow
    /// из Android AuthRepositoryImpl.kt.
    func observeAuthState() -> AsyncStream<User?>
}
