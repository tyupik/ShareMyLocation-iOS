import Contacts

/// Реализация чтения телефонной книги поверх CNContact: контакт целиком приходит
/// из системного CNContactPickerViewController (пикер без разрешений), чтение —
/// синхронное из памяти. iOS-адаптация Android ContactsRepositoryImpl.kt (там запрос
/// к ContactsProvider по Uri с временным read-грантом).
final class ContactsRepositoryImpl: ContactsRepository {
    /// Первый непустой телефон контакта «как есть», без нормализации; nil — телефонов нет.
    func readFirstPhone(from contact: CNContact) -> String? {
        contact.phoneNumbers.first(where: { !$0.value.stringValue.isEmpty })?.value.stringValue
    }
}
