import Factory

/// Binding репозитория телефонной книги (аналог Android ContactsModule.kt).
/// Синглтон: state не держит, но Android-репозиторий — @Singleton (паритет DI-графа).
extension Container {
    var contactsRepository: Factory<ContactsRepository> {
        self {
            ContactsRepositoryImpl()
        }.singleton
    }
}
