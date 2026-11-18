/// Типизированные ошибки фичи «Шаринг»; замаплены из Firebase в data-слое.
/// Порт 1:1 из Android SharingError.kt.
enum SharingError {
    /// Нет сети или таймаут (Firestore unavailable/deadlineExceeded, сеть).
    case networkUnavailable

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)

    // «Not found» нет: отсутствие документа sharingSettings/{uid} — не ошибка,
    // а дефолтное состояние до первого сохранения (см. SharingSettings.defaultFor).
}

/// Доменная ошибка фичи «Шаринг»: несёт типизированный SharingError для интерактора.
/// Порт Android SharingException(error, cause): исходная ошибка не переносится —
/// её текст попадает в reason кейса .unexpected и в лог data-слоя (паттерн GroupsException).
struct SharingException: Error {
    let error: SharingError
}
