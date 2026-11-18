import Factory

/// Binding репозитория друзей (аналог Android FriendsModule.kt).
/// Синглтон: realtime-слушатели и состояние отправки живут между экранами.
extension Container {
    var friendsRepository: Factory<FriendsRepository> {
        self {
            FriendsRepositoryImpl()
        }.singleton
    }
}
