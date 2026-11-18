import Factory

/// Binding ui-классов главного экрана. ViewModel не singleton: время жизни — экран
/// (паттерн создания из AGENTS.md: State(initialValue: Container.shared.mainViewModel())).
extension Container {
    var mainViewModel: Factory<MainViewModel> {
        self {
            MainViewModel(
                authInteractor: self.authInteractor(),
                friendsInteractor: self.friendsInteractor(),
            )
        }
    }
}
