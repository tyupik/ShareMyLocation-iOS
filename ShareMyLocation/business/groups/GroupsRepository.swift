/// Контракт работы с группами: коллекция groups в Firestore.
/// Текущий пользователь подразумевается неявно — он владелец всех операций.
/// Порт 1:1 из Android GroupsRepository.kt (Result-обёртки Android не переносятся:
/// iOS-методы бросают GroupsException, бизнес-результат собирает интерактор).
protocol GroupsRepository {
    /// Realtime-поток групп текущего пользователя (поле ownerId == его uid).
    /// Без orderBy на сервере: сортировка по имени выполняется на клиенте (в интеракторе),
    /// композитные индексы для фичи не требуются.
    func observeMyGroups() -> AsyncStream<[Group]>

    /// Одноразовое чтение группы `groupId`; несуществующая группа, а также группа, где текущий
    /// пользователь не владелец и не участник (memberUids), — .groupNotFound.
    /// С Фазы 7 участник группы может читать её документ (проверка видимости карты);
    /// пишут группу по-прежнему только владельцы.
    func getGroup(groupId: String) async throws -> Group

    /// Создаёт группу с именем `name` и составом `memberUids`; возвращает её groupId.
    func createGroup(name: String, memberUids: [String]) async throws -> String

    /// Обновляет группу `groupId`: имя и полный состав `memberUids`; ownerId/createdAt не меняются.
    func updateGroup(groupId: String, name: String, memberUids: [String]) async throws

    /// Удаляет группу `groupId`; id приходит только из realtime-списка — документ существует.
    func deleteGroup(groupId: String) async throws
}
