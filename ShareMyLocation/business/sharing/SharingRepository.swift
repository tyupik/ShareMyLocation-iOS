/**
 Контракт работы с настройками шаринга и точкой геолокации: коллекции sharingSettings
 и locations в Firestore. Текущий пользователь подразумевается неявно — документ ключуется
 его uid. Порт 1:1 из Android SharingRepository.kt (Result-обёртки Android не переносятся:
 iOS-методы бросают SharingException, бизнес-результат собирает интерактор).
 */
protocol SharingRepository {
    /**
     Одноразовое чтение настроек текущего пользователя. Отсутствующий документ — не ошибка:
     возвращается `SharingSettings.defaultFor` (до первого сохранения документа нет).
     */
    func getSettings() async throws -> SharingSettings

    /**
     Одноразовое чтение настроек произвольного пользователя (этап 7, карта видимости).
     Чужой или отсутствующий документ — не ошибка: возвращается `SharingSettings.defaultFor`
     («пользователь не делится локацией»); неуспех — только сеть/unexpected.
     */
    func getSettingsByUid(uid: String) async throws -> SharingSettings

    /**
     Записывает полный снимок настроек (merge всех пяти полей, updatedAt = serverTimestamp).
     Идемпотентна: повторная запись того же снимка не меняет смысл документа.
     */
    func saveSettings(_ settings: SharingSettings) async throws

    /**
     Записывает точку геолокации текущего пользователя merge-set'ом locations/{uid}
     (только {geo, accuracy, updatedAt}); настройки и получателей не трогает.
     */
    func updateLocation(_ location: SharedLocation) async throws

    /**
     Меняет только {isEnabled, updatedAt} в sharingSettings/{uid} (merge): частичная запись,
     чтобы движок и уведомление не перезаписали audience/allowedUids снимком автосейва.
     */
    func saveEnabled(_ isEnabled: Bool) async throws

    /**
     Realtime-поток флага isEnabled текущего пользователя; отсутствующий документ — false.
     Ошибка слушателя (сеть, PERMISSION_DENIED после logout, смерть слушателя) закрывает поток.
     */
    func observeIsEnabled() -> AsyncStream<Bool>
}
