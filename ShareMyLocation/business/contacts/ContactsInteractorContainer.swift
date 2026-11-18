import Factory

/// Binding интерактора телефонной книги (аналог Android ContactsInteractorModule.kt).
/// Интерактор не singleton: state не держит, репозиторий — синглтон (см. data/contacts).
extension Container {
    var contactsInteractor: Factory<ContactsInteractor> {
        self {
            ContactsInteractorImpl(contactsRepository: self.contactsRepository())
        }
    }
}
