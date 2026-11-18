import Factory

/// Binding корневых ui-классов. ViewModel не singleton: время жизни — экран
/// (паттерн создания из AGENTS.md: State(initialValue: Container.shared.appViewModel())).
extension Container {
    var appViewModel: Factory<AppViewModel> {
        self {
            AppViewModel(
                authInteractor: self.authInteractor(),
                appUiConverter: self.appUiConverter(),
            )
        }
    }

    var appUiConverter: Factory<AppUiConverter> {
        self {
            AppUiConverter()
        }
    }
}
