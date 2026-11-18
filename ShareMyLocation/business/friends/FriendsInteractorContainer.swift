import Factory

/// Binding интерактора друзей (аналог Android FriendsInteractorModule.kt).
/// Синглтон: кэш профилей друзей (friendsCache) живёт между экранами.
extension Container {
    var friendsInteractor: Factory<FriendsInteractor> {
        self {
            FriendsInteractorImpl(
                friendsRepository: self.friendsRepository(),
                authInteractor: self.authInteractor(),
            )
        }.singleton
    }
}
