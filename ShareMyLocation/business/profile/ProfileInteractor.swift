import UIKit

/// Интерактор профиля: оркестрирует ProfileRepository и возвращает бизнес-модели.
/// Валидирует телефон до записи и решает, нужен ли upload аватара.
/// Порт 1:1 из Android ProfileInteractor.kt.
protocol ProfileInteractor {
    /// Профиль текущего пользователя.
    func getProfile() async -> Result<User, ProfileError>

    /// Сжимает изображение и возвращает путь к копии в кэше приложения.
    func prepareAvatar(_ image: UIImage) async -> Result<String, ProfileError>

    /// true, если на устройстве есть камера (iOS-адаптация: проверка до презентации sheet'а).
    func isCameraAvailable() -> Bool

    /// Резолвит аватар пользователя как AvatarImage; версия 0 и меньше означает,
    /// что аватара нет — вернётся модель с cachedPath = nil без похода в репозиторий.
    func getAvatar(uid: String, version: Int) async -> Result<AvatarImage, ProfileError>

    /// Сохраняет профиль: нормализует и валидирует телефон, при необходимости загружает
    /// аватар из `pendingAvatarPath`; завершает онбординг (hasCompletedOnboarding = true).
    func saveProfile(
        displayName: String,
        phone: String,
        pendingAvatarPath: String?,
    ) async -> Result<Void, ProfileError>
}
