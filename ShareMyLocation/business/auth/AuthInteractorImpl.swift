/// Реализация интерактора аутентификации поверх репозитория.
/// Порт 1:1 из Android AuthInteractorImpl.kt: чистое делегирование +
/// превращение ошибок репозитория в бизнес-результат.
final class AuthInteractorImpl: AuthInteractor {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func signInWithEmail(email: String, password: String) async -> AuthResult {
        await toAuthResult {
            try await authRepository.signInWithEmail(email: email, password: password)
        }
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async -> AuthResult {
        await toAuthResult {
            try await authRepository.signUpWithEmail(email: email, password: password, displayName: displayName)
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String?) async -> AuthResult {
        await toAuthResult {
            try await authRepository.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: String?) async -> AuthResult {
        await toAuthResult {
            try await authRepository.signInWithApple(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
        }
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

    /// Оборачивает вызов репозитория в бизнес-результат: AuthException отдаёт свою
    /// типизированную ошибку, остальное — Unexpected с localizedDescription
    /// (порт Result.toAuthResult из Android).
    private func toAuthResult(_ operation: () async throws -> Void) async -> AuthResult {
        do {
            try await operation()
            return .success
        } catch let exception as AuthException {
            return .error(exception.error)
        } catch {
            return .error(.unexpected(error.localizedDescription))
        }
    }
}
