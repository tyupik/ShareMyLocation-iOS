/**
 Точка геолокации пользователя: документ locations/{uid} в Firestore.
 Наполняется из Firestore в data-слое, поэтому не тянет за собой Firebase-типы.
 Порт 1:1 из Android FriendLocation.kt.
 */
struct FriendLocation {
    let uid: String
    let latitude: Double
    let longitude: Double

    /// Точность точки в метрах; 0.0 — поле отсутствует в документе.
    var accuracyMeters: Double = 0.0

    /// millis последней отправки точки (updatedAt); 0 — поле отсутствует.
    var updatedAtMillis: Int64 = 0

    init(
        uid: String,
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double = 0.0,
        updatedAtMillis: Int64 = 0,
    ) {
        self.uid = uid
        self.latitude = latitude
        self.longitude = longitude
        self.accuracyMeters = accuracyMeters
        self.updatedAtMillis = updatedAtMillis
    }
}
