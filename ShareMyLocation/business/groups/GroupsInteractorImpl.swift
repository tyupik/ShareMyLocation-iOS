/// Реализация интерактора групп поверх репозитория.
/// Read-срез этапа 4; порт частичный из Android GroupsInteractorImpl.kt.
final class GroupsInteractorImpl: GroupsInteractor {
    private let groupsRepository: GroupsRepository

    init(groupsRepository: GroupsRepository) {
        self.groupsRepository = groupsRepository
    }

    /// Сортировка групп по имени на клиенте — композитные индексы не требуются.
    func observeGroups() -> AsyncStream<[Group]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let upstreamTask = Task {
                for await groups in groupsRepository.observeMyGroups() {
                    continuation.yield(groups.sorted { $0.name.lowercased() < $1.name.lowercased() })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                upstreamTask.cancel()
            }
        }
    }
}
