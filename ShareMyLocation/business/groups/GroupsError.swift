/// Типизированные ошибки фичи «Группы»; замаплены из Firebase в data-слое.
/// Read-срез этапа 4: только ошибки realtime-чтения; EmptyName/NameTooLong/GroupNotFound
/// появятся вместе с редактором групп (этап 5).
/// Порт частичный из Android GroupsError.kt.
enum GroupsError {
    /// Нет сети или таймаут (Firestore unavailable/deadlineExceeded, сеть).
    case networkUnavailable

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Доменная ошибка фичи «Группы»: несёт типизированный GroupsError для интерактора.
/// Порт Android GroupsException(error, cause): исходная ошибка не переносится —
/// её текст попадает в reason кейса .unexpected и в лог data-слоя.
struct GroupsException: Error {
    let error: GroupsError
}
