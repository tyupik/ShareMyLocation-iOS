/**
 Интерактор настроек шаринга: оркестрирует SharingRepository и возвращает бизнес-модели.
 Валидация на этом слое не нужна: аудитория — enum, а состав списков отсекает ViewModel
 (пересечение с актуальными друзьями/группами перед записью).
 Порт 1:1 из Android SharingInteractor.kt.
 */
protocol SharingInteractor {
    /// Одноразовое чтение настроек; отсутствующий документ — defaultFor, не ошибка.
    func getSettings() async -> Result<SharingSettings, SharingError>

    /**
     Одноразовое чтение настроек произвольного пользователя (этап 7, карта видимости);
     чужой или отсутствующий документ — defaultFor («не шарит»), не ошибка.
     */
    func getSettingsByUid(uid: String) async -> Result<SharingSettings, SharingError>

    /// Полная идемпотентная запись снимка настроек (автосохранение экрана).
    func saveSettings(_ settings: SharingSettings) async -> Result<Void, SharingError>

    /// Запись точки геолокации владельца (вызывается фоновым движком, этап 8).
    func updateLocation(_ location: SharedLocation) async -> Result<Void, SharingError>

    /// Частичная запись флага isEnabled (merge {isEnabled, updatedAt}); остальное — автосейв экрана.
    func saveEnabled(_ isEnabled: Bool) async -> Result<Void, SharingError>

    /// Realtime-поток флага isEnabled для корневого оркестратора движка; нет документа — false.
    func observeIsEnabled() -> AsyncStream<Bool>
}
