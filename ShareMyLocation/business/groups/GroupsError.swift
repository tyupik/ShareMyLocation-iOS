/// Типизированные ошибки фичи «Группы»; замаплены из Firebase в data-слое.
/// Порт 1:1 из Android GroupsError.kt.
enum GroupsError {
    /// Нет сети или таймаут (Firestore unavailable/deadlineExceeded, сеть).
    case networkUnavailable

    /// Имя группы после trim пустое.
    case emptyName

    /// Имя группы длиннее 50 символов.
    case nameTooLong

    /// Группа не найдена или не принадлежит текущему пользователю: правило groups читает
    /// resource.data, поэтому несуществующий документ и чужая группа дают PERMISSION_DENIED,
    /// NOT_FOUND мапится туда же — для клиента это одно состояние.
    case groupNotFound

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Доменная ошибка фичи «Группы»: несёт типизированный GroupsError для интерактора.
/// Порт Android GroupsException(error, cause): исходная ошибка не переносится —
/// её текст попадает в reason кейса .unexpected и в лог data-слоя.
struct GroupsException: Error {
    let error: GroupsError
}
