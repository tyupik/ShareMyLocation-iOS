import Factory

/// Binding ui-классов экрана настройки профиля. ViewModel не singleton: время жизни — экран
/// (паттерн создания из AGENTS.md: State(initialValue: Container.shared.profileSetupViewModel())).
extension Container {
    var profileSetupViewModel: Factory<ProfileSetupViewModel> {
        self {
            ProfileSetupViewModel(
                profileInteractor: self.profileInteractor(),
                profileSetupUiConverter: self.profileSetupUiConverter(),
            )
        }
    }

    var profileSetupUiConverter: Factory<ProfileSetupUiConverter> {
        self {
            ProfileSetupUiConverter()
        }
    }
}
