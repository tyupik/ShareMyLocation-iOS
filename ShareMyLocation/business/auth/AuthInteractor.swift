/// Интерактор аутентификации: оркестрирует AuthRepository и возвращает бизнес-модели.
/// Минимальный срез этапа 1 (см. AuthRepository); методы входа добавляются в этапе 2.
protocol AuthInteractor {
    /// Текущий пользователь сохранённой сессии либо nil.
    func getCurrentUser() async -> User?

    func signOut() async

    /// Realtime-поток состояния аутентификации: первая эмиссия — сохранённая сессия
    /// (или nil), далее — при каждом sign-in/sign-out.
    func observeAuthState() -> AsyncStream<User?>
}
