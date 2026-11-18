import Factory

/// Binding интерактора карты (аналог Android @Singleton MapInteractorImpl).
/// Синглтон: конвейер карты переживает пересоздание вкладки.
extension Container {
    var mapInteractor: Factory<MapInteractor> {
        self {
            MapInteractorImpl(
                mapRepository: self.mapRepository(),
                sharingRepository: self.sharingRepository(),
                friendsInteractor: self.friendsInteractor(),
                groupsInteractor: self.groupsInteractor(),
                authInteractor: self.authInteractor(),
            )
        }.singleton
    }
}
