import Factory

/// Binding интерактора аутентификации (аналог Android AuthInteractorModule.kt).
extension Container {
    var authInteractor: Factory<AuthInteractor> {
        self {
            AuthInteractorImpl(authRepository: self.authRepository())
        }
    }
}
