import Factory

/// Binding репозитория аутентификации (аналог Android AuthModule.kt).
extension Container {
    var authRepository: Factory<AuthRepository> {
        self {
            AuthRepositoryImpl()
        }.singleton
    }
}
