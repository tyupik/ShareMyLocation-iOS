/// Интерактор друзей: оркестрирует FriendsRepository и возвращает бизнес-модели.
/// Валидирует телефон при поиске и решает, можно ли отправить заявку.
/// Порт 1:1 из Android FriendsInteractor.kt.
protocol FriendsInteractor {
    /// Поиск пользователя по введённому телефону: нормализация и валидация (.invalidPhone),
    /// пустой результат — .userNotFound, собственный uid — .requestToSelf.
    /// При коллизии телефонов возвращается первый из списка.
    func searchByPhone(rawPhone: String) async -> Result<User, FriendsError>

    /// Отправка PENDING-заявки; проверки дубликатов выполняются в репозитории по свежим данным.
    func sendFriendRequest(toUid: String) async -> Result<Void, FriendsError>

    /// Принятие входящей заявки.
    func acceptFriendRequest(request: FriendRequest) async -> Result<Void, FriendsError>

    /// Отклонение входящей заявки (удаление её документа).
    func declineFriendRequest(request: FriendRequest) async -> Result<Void, FriendsError>

    /// Удаление друга из своего списка (и себя из списка друга).
    func removeFriend(friendUid: String) async -> Result<Void, FriendsError>

    /// Realtime-поток входящих PENDING-заявок, новые сверху.
    func observeIncomingFriendRequests() -> AsyncStream<[FriendRequest]>

    /// Realtime-поток списка друзей (по uid из friendUids), отсортированный по displayName.
    /// Внутренний кэш профилей живёт, пока жив синглтон-интерактор: перезапрашиваются
    /// только новые uid, поэтому смена имени/аватара уже известного друга подтянется
    /// только после перезапуска процесса (компромисс плана фичи).
    func observeFriends() -> AsyncStream<[User]>
}
