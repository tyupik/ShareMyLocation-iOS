import Factory

/// Binding репозитория групп (аналог Android GroupsModule.kt).
/// Синглтон: realtime-слушатель чтения групп живёт между экранами.
extension Container {
    var groupsRepository: Factory<GroupsRepository> {
        self {
            GroupsRepositoryImpl()
        }.singleton
    }
}
