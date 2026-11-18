/// Реализация интерактора аутентификации поверх репозитория.
/// Порт 1:1 из Android AuthInteractorImpl.kt (методы этапа 1: чистое делегирование).
final class AuthInteractorImpl: AuthInteractor {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func getCurrentUser() async -> User? {
        await authRepository.getCurrentUser()
    }

    func signOut() async {
        await authRepository.signOut()
    }

    func observeAuthState() -> AsyncStream<User?> {
        authRepository.observeAuthState()
    }
}
