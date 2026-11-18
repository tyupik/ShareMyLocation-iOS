/// Аудитория шаринга: все друзья либо выбранные люди и группы.
/// Порт 1:1 из Android SharingAudience.kt (ALL_FRIENDS/CUSTOM → allFriends/custom).
enum SharingAudience {
    /// Все друзья владельца.
    case allFriends

    /// Выбранные люди и группы; пустой выбор = «не видно никому» (валидно, на экране есть подсказка).
    case custom
}

/**
 Бизнес-модель настроек шаринга геолокации: документ sharingSettings/{uid} в Firestore.
 Порт 1:1 из Android SharingSettings.kt.

 Семантика для сервиса отправки локации (этап 8):
 - `isEnabled == false` — «не отправлять никому», `audience` и списки игнорируются;
 - isEnabled == true и audience == `allFriends` — видят все friendUids владельца;
 - isEnabled == true и audience == `custom` — получатель видит локацию, если его uid ∈
   `allowedUids` ИЛИ он состоит в memberUids какой-либо группы из `allowedGroupIds`;
   пересечения/дубли допустимы — union, дедупликация на стороне читателя. Пустые списки
   при custom — «не видно никому» (валидно, на экране есть подсказка-Effect).

 Границы (осознанно НЕ делаем): фоновый движок отправки (этап 8), realtime-слушатель
 настроек, аватары в чекбоксах. Риск: движок не должен доверять `allowedUids`/`allowedGroupIds`
 без перевалидации — взаимную дружбу и актуальный состав групп проверять при отправке.

 `updatedAt` — millis последней записи; 0 — поле отсутствует.
 */
struct SharingSettings {
    let uid: String
    var isEnabled: Bool
    var audience: SharingAudience
    var allowedUids: [String]
    var allowedGroupIds: [String]

    /// millis последней записи; 0 — поле отсутствует.
    var updatedAt: Int64 = 0

    /**
     Дефолт отсутствующего документа: шаринг выключен, аудитория allFriends, выбор пуст.
     Android-фабрика default() переименована в defaultFor: «default» — ключевое слово Swift.
     */
    static func defaultFor(uid: String) -> SharingSettings {
        SharingSettings(
            uid: uid,
            isEnabled: false,
            audience: .allFriends,
            allowedUids: [],
            allowedGroupIds: [],
        )
    }
}
