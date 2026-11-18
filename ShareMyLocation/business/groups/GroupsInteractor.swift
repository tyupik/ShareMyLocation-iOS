/// Интерактор групп: оркестрирует GroupsRepository и возвращает бизнес-модели.
/// Read-срез этапа 4: только realtime-список; валидация имени и запись появятся в этапе 5.
/// Порт частичный из Android GroupsInteractor.kt.
protocol GroupsInteractor {
    /// Realtime-поток групп текущего пользователя, отсортированный по имени (lowercase).
    func observeGroups() -> AsyncStream<[Group]>
}
