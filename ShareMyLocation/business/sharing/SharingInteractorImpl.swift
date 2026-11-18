/// Реализация интерактора настроек шаринга поверх репозитория (тонкий проброс).
/// Порт 1:1 из Android SharingInteractorImpl.kt.
final class SharingInteractorImpl: SharingInteractor {
    private let sharingRepository: SharingRepository

    init(sharingRepository: SharingRepository) {
        self.sharingRepository = sharingRepository
    }

    func getSettings() async -> Result<SharingSettings, SharingError> {
        await toSharingResult {
            try await sharingRepository.getSettings()
        }
    }

    func getSettingsByUid(uid: String) async -> Result<SharingSettings, SharingError> {
        await toSharingResult {
            try await sharingRepository.getSettingsByUid(uid: uid)
        }
    }

    func saveSettings(_ settings: SharingSettings) async -> Result<Void, SharingError> {
        await toSharingResult {
            try await sharingRepository.saveSettings(settings)
        }
    }

    func updateLocation(_ location: SharedLocation) async -> Result<Void, SharingError> {
        await toSharingResult {
            try await sharingRepository.updateLocation(location)
        }
    }

    func saveEnabled(_ isEnabled: Bool) async -> Result<Void, SharingError> {
        await toSharingResult {
            try await sharingRepository.saveEnabled(isEnabled)
        }
    }

    func observeIsEnabled() -> AsyncStream<Bool> {
        sharingRepository.observeIsEnabled()
    }

    /// Оборачивает вызов репозитория в бизнес-результат: SharingException отдаёт свою
    /// типизированную ошибку, остальное — unexpected с localizedDescription
    /// (паттерн toGroupsResult Android SharingInteractorImpl).
    private func toSharingResult<T>(_ operation: () async throws -> T) async -> Result<T, SharingError> {
        do {
            return .success(try await operation())
        } catch let exception as SharingException {
            return .failure(exception.error)
        } catch {
            return .failure(.unexpected(error.localizedDescription))
        }
    }
}
