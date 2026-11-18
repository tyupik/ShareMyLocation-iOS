/**
 Друг, чья локация сейчас видна текущему пользователю: точка FriendLocation,
 дополненная профилем (имя, версия аватара) из realtime-списка друзей.
 Видимость определяется семантикой этапа 5 (см. KDoc MapInteractor).
 Порт 1:1 из Android VisibleFriend.kt.
 */
struct VisibleFriend {
    let uid: String
    let displayName: String
    let avatarVersion: Int
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let updatedAtMillis: Int64
}
