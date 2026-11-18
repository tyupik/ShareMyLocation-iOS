/// Типизированные ошибки фичи «Друзья»; замаплены из Firebase в data-слое.
/// Порт 1:1 из Android FriendsError.kt.
enum FriendsError {
    /// Нет сети или таймаут (Firestore unavailable/deadlineExceeded, сеть).
    case networkUnavailable

    /// Телефон не соответствует правилу 10–15 цифр после нормализации.
    case invalidPhone

    /// Пользователь с таким телефоном не найден.
    case userNotFound

    /// Попытка добавить в друзья самого себя.
    case requestToSelf

    /// Пользователь уже в списке друзей.
    case alreadyFriends

    /// Заявка этому пользователю уже отправлена и ещё в статусе PENDING.
    case requestAlreadySent

    /// От этого пользователя уже есть встречная заявка.
    case requestAlreadyIncoming

    /// Всё, что не удалось сопоставить с конкретной ошибкой; reason — код/сообщение источника.
    case unexpected(String?)
}

/// Доменная ошибка фичи «Друзья»: несёт типизированный FriendsError для интерактора.
/// Порт Android FriendsException(error, cause): исходная ошибка не переносится —
/// её текст попадает в reason кейса .unexpected и в лог data-слоя.
struct FriendsException: Error {
    let error: FriendsError
}
