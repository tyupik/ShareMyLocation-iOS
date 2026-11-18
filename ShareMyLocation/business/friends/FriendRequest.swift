/// Статусы заявки в друзья.
/// DECLINED не используется: отклонение заявки — удаление её документа в Firestore.
/// Порт 1:1 из Android FriendRequestStatus.kt.
enum FriendRequestStatus {
    case pending
    case accepted
}

/// Бизнес-модель заявки в друзья из коллекции friendRequests Firestore.
/// `fromName` и `fromAvatarVersion` — снапшот профиля отправителя на момент отправки.
/// `createdAt` — millis времени создания; 0 — поле отсутствует/рассинхрон,
/// такие заявки при клиентской сортировке оказываются внизу.
/// Порт 1:1 из Android FriendRequest.kt.
struct FriendRequest {
    let fromUid: String
    let toUid: String
    let fromName: String
    let fromAvatarVersion: Int
    let status: FriendRequestStatus

    /// millis времени создания; 0 — поле отсутствует/рассинхрон.
    var createdAt: Int64 = 0
}
