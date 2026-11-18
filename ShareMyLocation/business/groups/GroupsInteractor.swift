/// Интерактор групп: оркестрирует GroupsRepository и возвращает бизнес-модели.
/// Валидирует имя группы при создании и переименовании: trim; пустое после trim —
/// .emptyName, длиннее 50 символов — .nameTooLong.
/// Порт 1:1 из Android GroupsInteractor.kt.
protocol GroupsInteractor {
    /// Realtime-поток групп текущего пользователя, отсортированный по имени (lowercase).
    func observeGroups() -> AsyncStream<[Group]>

    /// Одноразовое чтение группы; несуществующая, а также группа, где текущий пользователь
    /// не владелец и не участник (memberUids), — .groupNotFound. С Фазы 7 участник
    /// группы может читать её документ (проверка видимости карты).
    func getGroup(groupId: String) async -> Result<Group, GroupsError>

    /// Создание группы с именем `rawName` и составом `memberUids`; возвращает groupId созданной группы.
    func createGroup(rawName: String, memberUids: [String]) async -> Result<String, GroupsError>

    /// Обновление группы: имя `rawName` (trim, валидация) и полный состав `memberUids`.
    func updateGroup(groupId: String, rawName: String, memberUids: [String]) async -> Result<Void, GroupsError>

    /// Удаление группы.
    func deleteGroup(groupId: String) async -> Result<Void, GroupsError>
}
