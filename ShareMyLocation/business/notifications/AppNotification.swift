/**
 Уведомления приложения, публикуемые локально из realtime-потоков Firestore.
 Порт 1:1 из Android AppNotification.kt.
 */
enum AppNotification {
    /// Входящая заявка в друзья от пользователя `fromUid` (снапшот имени — `fromName`).
    case friendRequestReceived(fromUid: String, fromName: String)

    /// Друг `uid` начал делиться геопозицией (появился в наборе видимых друзей).
    case friendStartedSharing(uid: String, displayName: String)
}
