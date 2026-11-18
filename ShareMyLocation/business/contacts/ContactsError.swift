/// Типизированные ошибки чтения телефонной книги; замаплены из контактов в data-слое.
/// Порт 1:1 из Android ContactsError.kt.
enum ContactsError {
    /// У выбранного контакта нет ни одного непустого номера.
    case noPhone

    /// Чтение контакта не удалось; reason — код/сообщение источника.
    /// На iOS контакт приходит из CNContactPickerViewController целиком в памяти,
    /// поэтому readFailed не возбуждается — кейс оставлен для паритета с Android.
    case readFailed(String?)
}

/// Доменная ошибка чтения телефонной книги: несёт типизированный ContactsError
/// для интерактора. Порт Android ContactsException(error, cause): исходная ошибка
/// не переносится — её текст попадает в reason кейса .readFailed и в лог data-слоя.
struct ContactsException: Error {
    let error: ContactsError
}
