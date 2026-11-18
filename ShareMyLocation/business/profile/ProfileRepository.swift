import UIKit

/// Контракт работы с профилем: документы users/{uid} и avatars/{uid} в Firestore.
/// Текущий пользователь подразумевается неявно — как в AuthRepository.
/// Порт 1:1 из Android ProfileRepository.kt; Android-методы temp-Uri камеры и кропа
/// (createCameraAvatarUri и др.) не портируются: на iOS снимок и результат кропа
/// живут in-memory как UIImage (см. план этапа 3).
protocol ProfileRepository {
    /// Профиль текущего пользователя: данные сессии, дополненные документом users/{uid}.
    func getProfile() async throws -> User

    /// Сжимает изображение (максимальная сторона ~1024px, JPEG ~80%) и кладёт копию
    /// в кэш приложения; возвращает путь к файлу.
    func prepareAvatar(_ image: UIImage) async throws -> String

    /// true, если на устройстве есть камера.
    func isCameraAvailable() -> Bool

    /// Загружает подготовленный JPEG в документ avatars/{uid}; возвращает новую версию аватара.
    func uploadAvatar(cachedPath: String) async throws -> Int

    /// Путь к кэшированному файлу аватара; при промахе кэша байты читаются из avatars/{uid}
    /// и складываются в кэш. nil — аватара нет (рассинхрон avatarVersion и avatars/{uid},
    /// не ошибка).
    func getAvatar(uid: String, version: Int) async throws -> String?

    /// Сохраняет поля профиля в users/{uid}: displayName, phone, hasCompletedOnboarding
    /// и updatedAt. Аватар загружается отдельно через uploadAvatar.
    func saveProfile(
        displayName: String,
        phone: String,
        hasCompletedOnboarding: Bool,
    ) async throws
}
