/// Доменная модель пользователя, общая для нескольких экранов.
/// Порт 1:1 из Android business/common/User.kt. Наполняется из Firebase Auth и Firestore
/// в data-слое, поэтому не тянет за собой Firebase-типы.
struct User {
    let uid: String
    let email: String?
    let displayName: String?

    /// Нормализованный телефон: только цифры с ведущим «+», если он был.
    var phone: String? = nil

    /// Версия аватара: инкрементируется при каждой загрузке нового JPEG в avatars/{uid}.
    /// 0 — аватара нет (legacy-документы с avatarUrl и без avatarVersion читаются как 0).
    var avatarVersion: Int = 0

    /// Прошёл ли пользователь онбординг ProfileSetup.
    var hasCompletedOnboarding: Bool = false
}
