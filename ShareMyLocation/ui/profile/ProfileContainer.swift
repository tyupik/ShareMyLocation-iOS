import Factory

/// Binding ui-классов профиля. ViewModel не singleton: время жизни — экран
/// (паттерн создания из AGENTS.md: State(initialValue: Container.shared.profileViewModel())).
extension Container {
    var profileViewModel: Factory<ProfileViewModel> {
        self {
            ProfileViewModel(
                profileInteractor: self.profileInteractor(),
                profileUiConverter: self.profileUiConverter(),
            )
        }
    }

    var profileUiConverter: Factory<ProfileUiConverter> {
        self {
            ProfileUiConverter()
        }
    }
}
