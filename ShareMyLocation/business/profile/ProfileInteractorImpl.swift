import UIKit

/// Реализация интерактора профиля поверх репозитория.
/// Порт 1:1 из Android ProfileInteractorImpl.kt: делегирование + валидация телефона
/// и порядок «upload аватара → saveProfile».
final class ProfileInteractorImpl: ProfileInteractor {
    private let profileRepository: ProfileRepository

    init(profileRepository: ProfileRepository) {
        self.profileRepository = profileRepository
    }

    func getProfile() async -> Result<User, ProfileError> {
        await toProfileResult {
            try await profileRepository.getProfile()
        }
    }

    func prepareAvatar(_ image: UIImage) async -> Result<String, ProfileError> {
        await toProfileResult {
            try await profileRepository.prepareAvatar(image)
        }
    }

    func isCameraAvailable() -> Bool {
        profileRepository.isCameraAvailable()
    }

    func getAvatar(uid: String, version: Int) async -> Result<AvatarImage, ProfileError> {
        guard version > 0 else {
            return .success(AvatarImage(uid: uid, version: version, cachedPath: nil))
        }
        let result = await toProfileResult {
            try await profileRepository.getAvatar(uid: uid, version: version)
        }
        switch result {
        case .success(let cachedPath):
            return .success(AvatarImage(uid: uid, version: version, cachedPath: cachedPath))
        case .failure(let error):
            return .failure(error)
        }
    }

    func saveProfile(
        displayName: String,
        phone: String,
        pendingAvatarPath: String?,
    ) async -> Result<Void, ProfileError> {
        let normalizedPhone = PhoneNormalizer.normalize(phone)
        guard PhoneNormalizer.isValid(normalizedPhone) else {
            return .failure(.invalidPhone)
        }

        if let pendingAvatarPath {
            let uploadResult = await toProfileResult {
                try await profileRepository.uploadAvatar(cachedPath: pendingAvatarPath)
            }
            guard case .success = uploadResult else {
                return uploadResult.map { _ in () }
            }
        }
        return await toProfileResult {
            try await profileRepository.saveProfile(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: normalizedPhone,
                hasCompletedOnboarding: true,
            )
        }
    }

    /// Оборачивает вызов репозитория в бизнес-результат: ProfileException отдаёт свою
    /// типизированную ошибку, остальное — unexpected с localizedDescription
    /// (порт Result.toProfileResult из Android).
    private func toProfileResult<T>(_ operation: () async throws -> T) async -> Result<T, ProfileError> {
        do {
            return .success(try await operation())
        } catch let exception as ProfileException {
            return .failure(exception.error)
        } catch {
            return .failure(.unexpected(error.localizedDescription))
        }
    }
}
