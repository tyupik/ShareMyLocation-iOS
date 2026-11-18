/// Бизнес-модель аватара пользователя.
/// `cachedPath` — путь к файлу JPEG в кэше приложения; nil — аватара нет
/// (документ avatars/{uid} отсутствует при avatarVersion > 0 — рассинхрон, не ошибка).
/// Порт 1:1 из Android AvatarImage.kt.
struct AvatarImage {
    let uid: String
    let version: Int
    let cachedPath: String?
}
