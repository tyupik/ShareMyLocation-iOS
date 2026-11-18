import Contacts

/// Контракт чтения телефонной книги. READ_CONTACTS не требуется: контакт целиком
/// приходит из системного CNContactPickerViewController (пикер без разрешений) —
/// iOS-адаптация Android-репозитория (там Uri с временным read-грантом).
/// Порт 1:1 из Android ContactsRepository.kt.
protocol ContactsRepository {
    /// Читает первый непустой телефон контакта «как есть», без нормализации.
    /// nil — телефонов нет или все пусты.
    func readFirstPhone(from contact: CNContact) -> String?
}
