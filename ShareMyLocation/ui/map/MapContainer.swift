import Factory

/// Binding ui-классов вкладки «Карта». ViewModel не singleton: время жизни — экран
/// (паттерн создания из AGENTS.md: State(initialValue: Container.shared.mapViewModel())).
extension Container {
    var mapViewModel: Factory<MapViewModel> {
        self {
            MapViewModel(
                mapInteractor: self.mapInteractor(),
                friendsInteractor: self.friendsInteractor(),
                profileInteractor: self.profileInteractor(),
                myLocationProvider: self.myLocationProvider(),
                mapUiConverter: self.mapUiConverter(),
            )
        }
    }

    var mapUiConverter: Factory<MapUiConverter> {
        self {
            MapUiConverter()
        }
    }
}
