/// Типизированные ошибки работы с профилем; маппятся из Firebase в data-слое.
/// Порт 1:1 из Android business/profile/ProfileError.kt.
enum ProfileError {
    /// Телефон не соответствует правилу 10–15 цифр после нормализации.
    case invalidPhone

    /// Нет сети или таймаут.
    case networkUnavailable

    /// JPEG аватара превышает лимит документа Firestore даже после сжатия.
    case avatarTooLarge

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Доменная ошибка профиля: несёт типизированный ProfileError для интерактора.
/// Порт Android ProfileException(error, cause): исходная ошибка не переносится —
/// её текст попадает в reason кейса .unexpected и в лог data-слоя.
struct ProfileException: Error {
    let error: ProfileError
}
