import Factory

/// Binding репозитория аутентификации (аналог Android AuthModule.kt).
extension Container {
    var authRepository: Factory<AuthRepository> {
        self {
            AuthRepositoryImpl()
        }.singleton
    }

    /// Источник Google-токена: обычный (не singleton) — SDK хранит своё состояние глобально,
    /// обёртке state не нужен.
    var googleSignInRequester: Factory<GoogleSignInRequesting> {
        self {
            GoogleSignInRequester()
        }
    }
}
