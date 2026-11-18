import Contacts

/// Реализация интерактора телефонной книги поверх репозитория.
/// Порт 1:1 из Android ContactsInteractorImpl.kt: делегирование + nil → .noPhone.
final class ContactsInteractorImpl: ContactsInteractor {
    private let contactsRepository: ContactsRepository

    init(contactsRepository: ContactsRepository) {
        self.contactsRepository = contactsRepository
    }

    func getPhone(from contact: CNContact) async -> Result<String, ContactsError> {
        let phone = contactsRepository.readFirstPhone(from: contact)
        guard let phone else {
            return .failure(.noPhone)
        }
        return .success(phone)
    }
}
