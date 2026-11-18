import UIKit

/// SSOT экрана настройки/редактирования профиля. Порт из Android ProfileSetupUiState
/// с iOS-адаптациями этапа 3 (см. план): temp-Uri камеры/кропа заменены in-memory UIImage,
/// добавлены state-флаги isGalleryPickerPresented/isCameraPresented.
/// Режим (онбординг или редактирование) в состояние не входит: он влияет только на тексты
/// и приходит параметром ProfileSetupScreen(isEditMode:) от корневой навигации.
struct ProfileSetupUiState {
    var displayName: String = ""
    var phone: String = ""

    /// Путь к сжатой копии нового аватара в кэше приложения.
    var pendingAvatarPath: String? = nil

    /// Путь к кэш-файлу уже сохранённого аватара (показывается, пока новое фото не выбрано).
    var savedAvatarPath: String? = nil

    /// Показан диалог выбора источника аватара (галерея или камера).
    var isAvatarSourceDialogVisible: Bool = false

    /// Открыт системный photo picker (PhotosPicker).
    var isGalleryPickerPresented: Bool = false

    /// Открыт sheet камеры.
    var isCameraPresented: Bool = false

    /// Первичная загрузка профиля с сервера.
    var isLoading: Bool = false

    /// Подготовка аватара (сжатие) или сохранение профиля.
    var isSaving: Bool = false

    var error: ProfileSetupUiError? = nil

    static let initial = ProfileSetupUiState()
}

/// Ошибки экрана настройки/редактирования профиля в терминах Ui-слоя. Порт 1:1.
enum ProfileSetupUiError {
    /// Телефон не соответствует правилу 10–15 цифр.
    case invalidPhone

    /// Нет сети или таймаут.
    case network

    /// Фото слишком большое для документа Firestore даже после сжатия.
    case avatarTooLarge

    /// Камеру открыть не удалось: на устройстве нет камеры.
    case cameraUnavailable

    /// Всё остальное; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Действия пользователя экрана настройки/редактирования профиля.
/// Порт из Android ProfileSetupIntent с iOS-адаптациями этапа 3 (см. план).
enum ProfileSetupIntent {
    /// Экран показан: перечитываем профиль, чтобы предзаполнить поля.
    case screenShown

    case displayNameChanged(String)

    case phoneChanged(String)

    /// Пользователь нажал на бейдж камеры / кнопку выбора фото: показать диалог источника.
    case avatarPickRequested

    /// Пользователь закрыл диалог выбора источника, не выбрав вариант.
    case avatarSourceDialogDismissed

    /// В диалоге выбрана галерея: экран открывает photo picker.
    case avatarSourceGallerySelected

    /// В диалоге выбрана камера: VM проверяет доступность камеры и открывает sheet.
    case avatarSourceCameraSelected

    /// Пользователь закрыл photo picker (выбор отменён): сброс флага пикера.
    case avatarGalleryDismissed

    /// UI-слой получил данные выбранного фото; nil — пользователь отменил выбор (no-op).
    case avatarPicked(Data?)

    /// Съёмка завершена снимком: снимок отправляется в кроп.
    case avatarCaptureCompleted(UIImage)

    /// Пользователь отменил съёмку.
    case avatarCaptureCancelled

    /// Кроп завершён успешно: результат сжимается и становится отложенным аватаром.
    case avatarCropConfirmed(UIImage)

    /// Кроп отменён или завершился ошибкой: выбор фото отменяется целиком.
    case avatarCropCancelled

    case saveClicked

    /// Пользователь закрыл баннер с ошибкой.
    case errorDismissed
}

/// One-off события экрана. Порт из Android ProfileSetupEffect
/// (iOS-адаптация: вместо тройки uri — снимок UIImage для Mantis).
enum ProfileSetupEffect {
    /// Профиль сохранён — навигацию выполняет вызывающая сторона через onCompleted.
    case completed

    /// Открыть Mantis-кроп для снимка.
    case launchAvatarCrop(UIImage)
}
