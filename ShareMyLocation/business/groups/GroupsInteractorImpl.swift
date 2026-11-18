/// Реализация интерактора групп поверх репозитория.
/// Порт 1:1 из Android GroupsInteractorImpl.kt.
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

    func getGroup(groupId: String) async -> Result<Group, GroupsError> {
        await toGroupsResult {
            try await groupsRepository.getGroup(groupId: groupId)
        }
    }

    func createGroup(rawName: String, memberUids: [String]) async -> Result<String, GroupsError> {
        let name: String
        switch validatedName(rawName) {
        case .success(let validated):
            name = validated
        case .failure(let error):
            return .failure(error)
        }
        // Состав валидируется в ViewModel (⊆ актуальных друзей) и авторитетно — create-правилами.
        return await toGroupsResult {
            try await groupsRepository.createGroup(name: name, memberUids: memberUids)
        }
    }

    func updateGroup(groupId: String, rawName: String, memberUids: [String]) async -> Result<Void, GroupsError> {
        let name: String
        switch validatedName(rawName) {
        case .success(let validated):
            name = validated
        case .failure(let error):
            return .failure(error)
        }
        return await toGroupsResult {
            try await groupsRepository.updateGroup(groupId: groupId, name: name, memberUids: memberUids)
        }
    }

    func deleteGroup(groupId: String) async -> Result<Void, GroupsError> {
        await toGroupsResult {
            try await groupsRepository.deleteGroup(groupId: groupId)
        }
    }

    /// Trim + валидация имени; неуспех — .emptyName либо .nameTooLong.
    private func validatedName(_ rawName: String) -> Result<String, GroupsError> {
        // Kotlin trim() убирает любые ведущие/хвостовые пробельные символы — ближайший
        // iOS-эквивалент .whitespacesAndNewlines.
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return .failure(.emptyName)
        }
        if name.count > Self.MAX_GROUP_NAME_LENGTH {
            return .failure(.nameTooLong)
        }
        return .success(name)
    }

    /// Оборачивает вызов репозитория в бизнес-результат: GroupsException отдаёт свою
    /// типизированную ошибку, остальное — unexpected с localizedDescription
    /// (порт Result-делегирования Android GroupsInteractorImpl, паттерн toFriendsResult).
    private func toGroupsResult<T>(_ operation: () async throws -> T) async -> Result<T, GroupsError> {
        do {
            return .success(try await operation())
        } catch let exception as GroupsException {
            return .failure(exception.error)
        } catch {
            return .failure(.unexpected(error.localizedDescription))
        }
    }

    /// Лимит имени группы; продублирован литералом 50 в firestore.rules (isGroupName).
    private static let MAX_GROUP_NAME_LENGTH = 50
}
