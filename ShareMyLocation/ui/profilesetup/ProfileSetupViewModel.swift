import Foundation
import Observation
import UIKit

/// ViewModel экрана настройки/редактирования профиля.
/// Через интерактор читает и сохраняет профиль, через ProfileSetupUiConverter переводит
/// бизнес-модели в Ui-модели. Сохранённый аватар резолвится асинхронно после предзаполнения:
/// ошибка аватара не ломает экран, остаётся плейсхолдер с инициалом.
/// Порт из Android ProfileSetupViewModel.kt; iOS-адаптации этапа 3: temp-Uri камеры и кропа
/// не портируются — снимок и результат кропа живут in-memory (pendingCropImage).
/// Единственная публичная точка входа для UI — onIntent.
@MainActor
@Observable
final class ProfileSetupViewModel {
    private(set) var state: ProfileSetupUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<ProfileSetupEffect>
    private let effectsContinuation: AsyncStream<ProfileSetupEffect>.Continuation

    /// Снимок, отправленный в кроп и ожидающий результата (замена тройки uri Android:
    /// pendingCaptureUri/pendingCropSourceUri/pendingCropOutputUri — temp-файлы не нужны).
    private var pendingCropImage: UIImage?

    private let profileInteractor: ProfileInteractor
    private let profileSetupUiConverter: ProfileSetupUiConverter

    init(profileInteractor: ProfileInteractor, profileSetupUiConverter: ProfileSetupUiConverter) {
        self.profileInteractor = profileInteractor
        self.profileSetupUiConverter = profileSetupUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: ProfileSetupEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
    }

    func onIntent(_ intent: ProfileSetupIntent) {
        switch intent {
        case .screenShown:
            loadProfile()
        case .displayNameChanged(let value):
            state.displayName = value
            state.error = nil
        case .phoneChanged(let value):
            state.phone = value
            state.error = nil
        case .avatarPickRequested:
            state.isAvatarSourceDialogVisible = true
        case .avatarSourceDialogDismissed:
            state.isAvatarSourceDialogVisible = false
        case .avatarSourceGallerySelected:
            state.isAvatarSourceDialogVisible = false
            state.isGalleryPickerPresented = true
        case .avatarSourceCameraSelected:
            onCameraSelected()
        case .avatarGalleryDismissed:
            state.isGalleryPickerPresented = false
        case .avatarPicked(let data):
            onAvatarPicked(data)
        case .avatarCaptureCompleted(let image):
            onCaptureCompleted(image)
        case .avatarCaptureCancelled:
            // Поздний сигнал от binding sheet (VM уже закрыл камеру после снимка) — no-op.
            guard state.isCameraPresented else { return }
            state.isCameraPresented = false
        case .avatarCropConfirmed(let image):
            onCropConfirmed(image)
        case .avatarCropCancelled:
            // Кроп отменён (или завершился ошибкой): выбор фото отменяется целиком.
            pendingCropImage = nil
        case .saveClicked:
            saveProfile()
        case .errorDismissed:
            state.error = nil
        }
    }

    private func loadProfile() {
        guard !state.isLoading else { return }
        state.isLoading = true
        state.error = nil
        Task {
            switch await profileInteractor.getProfile() {
            case .success(let user):
                let uiModel = profileSetupUiConverter.convert(user: user)
                state.displayName = uiModel.displayName
                state.phone = uiModel.phone
                state.savedAvatarPath = uiModel.savedAvatarPath
                state.isLoading = false
                loadSavedAvatar(user)
            case .failure(let error):
                print("ProfileSetupViewModel: Не удалось загрузить профиль — \(error)")
                state.isLoading = false
                state.error = toUiError(error)
            }
        }
    }

    /// Неуспех загрузки сохранённого аватара не показываем: остаёмся на плейсхолдере с инициалом.
    private func loadSavedAvatar(_ user: User) {
        guard user.avatarVersion > 0 else { return }
        Task {
            switch await profileInteractor.getAvatar(uid: user.uid, version: user.avatarVersion) {
            case .success(let avatar):
                state.savedAvatarPath = avatar.cachedPath
            case .failure(let error):
                print("ProfileSetupViewModel: Не удалось загрузить сохранённый аватар — \(error)")
            }
        }
    }

    /// Камера выбрана: проверяем доступность и просим экран открыть sheet камеры.
    private func onCameraSelected() {
        state.isAvatarSourceDialogVisible = false
        state.error = nil
        guard profileInteractor.isCameraAvailable() else {
            print("ProfileSetupViewModel: Камера на устройстве недоступна")
            state.error = .cameraUnavailable
            return
        }
        state.isCameraPresented = true
    }

    /// Выбрано фото из галереи: декодируем данные и отправляем снимок в кроп.
    /// nil — пользователь отменил выбор (no-op). Неудача декода — unexpected
    /// (баннер), прежний аватар остаётся.
    private func onAvatarPicked(_ data: Data?) {
        guard let data else { return }
        guard !state.isSaving else { return }
        guard let image = UIImage(data: data) else {
            print("ProfileSetupViewModel: Не удалось декодировать выбранное изображение")
            state.error = .unexpected(nil)
            return
        }
        pendingCropImage = image
        effectsContinuation.yield(.launchAvatarCrop(image))
    }

    /// Съёмка завершена: снимок идёт в кроп, sheet камеры закрывается.
    private func onCaptureCompleted(_ image: UIImage) {
        state.isCameraPresented = false
        pendingCropImage = image
        effectsContinuation.yield(.launchAvatarCrop(image))
    }

    /// Кроп завершён успешно: сжимаем результат и делаем его отложенным аватаром.
    /// Неуспех — ошибка показывается существующим баннером, прежний аватар остаётся.
    private func onCropConfirmed(_ image: UIImage) {
        guard pendingCropImage != nil else { return }
        guard !state.isSaving else { return }
        state.isSaving = true
        state.error = nil
        Task {
            switch await profileInteractor.prepareAvatar(image) {
            case .success(let path):
                pendingCropImage = nil
                state.isSaving = false
                state.pendingAvatarPath = path
            case .failure(let error):
                print("ProfileSetupViewModel: Не удалось подготовить аватар — \(error)")
                pendingCropImage = nil
                state.isSaving = false
                state.error = toUiError(error)
            }
        }
    }

    private func saveProfile() {
        guard !state.isSaving, !state.isLoading else { return }
        let displayName = state.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = state.phone
        let pendingAvatarPath = state.pendingAvatarPath
        state.isSaving = true
        state.error = nil
        Task {
            switch await profileInteractor.saveProfile(
                displayName: displayName,
                phone: phone,
                pendingAvatarPath: pendingAvatarPath,
            ) {
            case .success:
                state.isSaving = false
                effectsContinuation.yield(.completed)
            case .failure(let error):
                print("ProfileSetupViewModel: Не удалось сохранить профиль — \(error)")
                state.isSaving = false
                state.error = toUiError(error)
            }
        }
    }

    private func toUiError(_ error: ProfileError) -> ProfileSetupUiError {
        profileSetupUiConverter.convertError(error)
    }
}
