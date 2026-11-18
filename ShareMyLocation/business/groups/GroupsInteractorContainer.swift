import Factory

/// Binding интерактора групп (аналог Android GroupsInteractorModule.kt).
/// Синглтон: держит realtime-состояние чтения групп между экранами.
extension Container {
    var groupsInteractor: Factory<GroupsInteractor> {
        self {
            GroupsInteractorImpl(groupsRepository: self.groupsRepository())
        }.singleton
    }
}
