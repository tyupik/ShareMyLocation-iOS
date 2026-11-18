/// Контракт работы с друзьями и заявками: коллекции users и friendRequests в Firestore.
/// Текущий пользователь подразумевается неявно — как в AuthRepository.
/// Порт 1:1 из Android FriendsRepository.kt (Result-обёртки Android не переносятся:
/// iOS-методы бросают FriendsException, бизнес-результат собирает интерактор).
protocol FriendsRepository {
    /// Поиск по точному совпадению нормализованного телефона; пустой список — совпадений нет.
    func findUsersByPhone(phone: String) async throws -> [User]

    /// Отправляет PENDING-заявку пользователю `toUid`. Проверки AlreadyFriends,
    /// RequestAlreadySent и RequestAlreadyIncoming выполняются внутри по свежим данным Firestore.
    func sendFriendRequest(toUid: String) async throws

    /// Принимает заявку `request`: статус ACCEPTED + friendUids обоих участников (транзакция).
    func acceptFriendRequest(request: FriendRequest) async throws

    /// Отклоняет заявку `request`: удаление её документа (статус DECLINED не персистится).
    func declineFriendRequest(request: FriendRequest) async throws

    /// Удаляет друга: arrayRemove(friendUids) у обоих участников (транзакция).
    func removeFriend(friendUid: String) async throws

    /// Профили пользователей по uid; чанкование списками по 10 выполняется внутри.
    func getUsersByUids(uids: [String]) async throws -> [User]

    /// Realtime-поток входящих PENDING-заявок текущего пользователя.
    /// Без orderBy на сервере: сортировка «новые сверху» выполняется на клиенте (в интеракторе),
    /// композитные индексы для фичи не требуются. Конец потока — обрыв слушателя.
    func observeIncomingFriendRequests() -> AsyncStream<[FriendRequest]>

    /// Realtime-поток списка друзей текущего пользователя (поле friendUids документа users).
    func observeFriendUids() -> AsyncStream<[String]>
}
