/// Контракт чтения групп: коллекция groups в Firestore.
/// Текущий пользователь подразумевается неявно — он владелец читаемых групп.
/// Read-срез этапа 4: только realtime-список; запись (create/update/delete/getGroup)
/// появится в этапе 5 (порт частичный из Android GroupsRepository.kt).
protocol GroupsRepository {
    /// Realtime-поток групп текущего пользователя (поле ownerId == его uid).
    /// Без orderBy на сервере: сортировка по имени выполняется на клиенте (в интеракторе),
    /// композитные индексы для фичи не требуются.
    func observeMyGroups() -> AsyncStream<[Group]>
}
