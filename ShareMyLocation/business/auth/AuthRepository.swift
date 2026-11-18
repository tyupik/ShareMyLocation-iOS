/// Контракт аутентификации: Firebase Auth. Минимальный срез этапа 1 — resolve сессии;
/// методы signInWithEmail/signUpWithEmail/signInWithGoogle добавляются в этапе 2
/// (вместе с ensureUserDocument и AuthResult/AuthError).
protocol AuthRepository {
    /// Текущий пользователь сохранённой сессии либо nil.
    func getCurrentUser() async -> User?

    func signOut() async

    /// Realtime-поток состояния аутентификации: первая эмиссия — сохранённая сессия
    /// (или nil), далее — при каждом sign-in/sign-out. Аналог callbackFlow
    /// из Android AuthRepositoryImpl.kt.
    func observeAuthState() -> AsyncStream<User?>
}
