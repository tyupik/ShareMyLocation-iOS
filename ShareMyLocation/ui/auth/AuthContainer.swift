import Factory

/// Binding ui-классов аутентификации. ViewModel не singleton: время жизни — экран
/// (паттерн создания из AGENTS.md: State(initialValue: Container.shared.authViewModel())).
extension Container {
    var authViewModel: Factory<AuthViewModel> {
        self {
            AuthViewModel(
                authInteractor: self.authInteractor(),
                googleSignInRequester: self.googleSignInRequester(),
                authUiConverter: self.authUiConverter(),
            )
        }
    }

    var authUiConverter: Factory<AuthUiConverter> {
        self {
            AuthUiConverter()
        }
    }
}
