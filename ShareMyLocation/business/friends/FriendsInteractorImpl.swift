/// Реализация интерактора друзей поверх репозитория.
/// Порт 1:1 из Android FriendsInteractorImpl.kt. Кэш профилей друзей — состояние синглтона:
/// Android решает гонки ConcurrentHashMap, здесь все обращения к кэшу выполняются в
/// MainActor-задачах observeFriends (класс сознательно не @MainActor целиком — синхронные
/// методы протокола должны оставаться nonisolated).
final class FriendsInteractorImpl: FriendsInteractor {
    /// Кэш профилей друзей по uid: исключает повторные запросы для уже известных uid.
    /// Мутирует только внутри MainActor-задачи observeFriends (см. KDoc класса).
    private var friendsCache: [String: User] = [:]

    private let friendsRepository: FriendsRepository
    private let authInteractor: AuthInteractor

    init(friendsRepository: FriendsRepository, authInteractor: AuthInteractor) {
        self.friendsRepository = friendsRepository
        self.authInteractor = authInteractor
    }

    func searchByPhone(rawPhone: String) async -> Result<User, FriendsError> {
        let normalizedPhone = PhoneNormalizer.normalize(rawPhone)
        guard PhoneNormalizer.isValid(normalizedPhone) else {
            return .failure(.invalidPhone)
        }
        let candidates: [User]
        do {
            candidates = try await friendsRepository.findUsersByPhone(phone: normalizedPhone)
        } catch let exception as FriendsException {
            return .failure(exception.error)
        } catch {
            return .failure(.unexpected(error.localizedDescription))
        }
        // При коллизии телефонов берём первого из списка (допущение фичи).
        guard let user = candidates.first else {
            return .failure(.userNotFound)
        }
        if user.uid == await authInteractor.getCurrentUser()?.uid {
            return .failure(.requestToSelf)
        }
        return .success(user)
    }

    func sendFriendRequest(toUid: String) async -> Result<Void, FriendsError> {
        await toFriendsResult {
            try await friendsRepository.sendFriendRequest(toUid: toUid)
        }
    }

    func acceptFriendRequest(request: FriendRequest) async -> Result<Void, FriendsError> {
        await toFriendsResult {
            try await friendsRepository.acceptFriendRequest(request: request)
        }
    }

    func declineFriendRequest(request: FriendRequest) async -> Result<Void, FriendsError> {
        await toFriendsResult {
            try await friendsRepository.declineFriendRequest(request: request)
        }
    }

    func removeFriend(friendUid: String) async -> Result<Void, FriendsError> {
        await toFriendsResult {
            try await friendsRepository.removeFriend(friendUid: friendUid)
        }
    }

    func observeIncomingFriendRequests() -> AsyncStream<[FriendRequest]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let upstreamTask = Task {
                for await requests in friendsRepository.observeIncomingFriendRequests() {
                    // Сортировка «новые сверху» на клиенте (без серверного orderBy и индекса):
                    // 0 (нет поля/рассинхрон) — внизу, как в Android sortedByDescending.
                    continuation.yield(requests.sorted { $0.createdAt > $1.createdAt })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                upstreamTask.cancel()
            }
        }
    }

    func observeFriends() -> AsyncStream<[User]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            // Последний выданный набор uid — порт distinctUntilChanged Android: снапшот
            // users-документа приходит и при посторонних изменениях (updatedAt), а маппинг
            // по неизменному кэшу детерминирован, поэтому такой повтор не yields.
            var lastEmittedUids: [String]?
            // MainActor-задача: friendsCache мутирует только здесь (порт ConcurrentHashMap).
            let upstreamTask = Task { @MainActor in
                for await uids in friendsRepository.observeFriendUids() {
                    // Догрузка только новых uid: кэш живёт, пока жив синглтон-интерактор.
                    let missing = uids.filter { friendsCache[$0] == nil }
                    if !missing.isEmpty {
                        do {
                            let users = try await friendsRepository.getUsersByUids(uids: missing)
                            for user in users {
                                friendsCache[user.uid] = user
                            }
                        } catch {
                            // Догрузка не удалась — порт Android getOrThrow: поток обрывается,
                            // ViewModel показывает inline-ошибку секции (Повторить = ScreenShown).
                            print("FriendsInteractorImpl: Не удалось догрузить профили друзей — \(error)")
                            continuation.finish()
                            return
                        }
                    }
                    if uids != lastEmittedUids {
                        lastEmittedUids = uids
                        let friends = uids.compactMap { friendsCache[$0] }
                            .sorted { ($0.displayName ?? "") < ($1.displayName ?? "") }
                        continuation.yield(friends)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                upstreamTask.cancel()
            }
        }
    }

    /// Оборачивает вызов репозитория в бизнес-результат: FriendsException отдаёт свою
    /// типизированную ошибку, остальное — unexpected с localizedDescription
    /// (порт Result-делегирования Android FriendsInteractorImpl).
    private func toFriendsResult(_ operation: () async throws -> Void) async -> Result<Void, FriendsError> {
        do {
            try await operation()
            return .success(())
        } catch let exception as FriendsException {
            return .failure(exception.error)
        } catch {
            return .failure(.unexpected(error.localizedDescription))
        }
    }
}
