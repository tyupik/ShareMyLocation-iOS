/// Бизнес-модель группы друзей из коллекции groups Firestore.
/// Группа — личная «папка» владельца: `memberUids` ⊆ friendUids владельца,
/// участники групп о членстве не знают (шеринг — отдельная фаза).
/// `createdAt` — millis времени создания; 0 — поле отсутствует/рассинхрон.
/// Порт 1:1 из Android Group.kt.
struct Group {
    let groupId: String
    let name: String
    let memberUids: [String]

    /// millis времени создания; 0 — поле отсутствует/рассинхрон.
    var createdAt: Int64 = 0
}
