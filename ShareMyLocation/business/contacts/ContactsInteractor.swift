import Contacts

/// Интерактор телефонной книги: оркестрирует ContactsRepository для сценария
/// «выбрать друга из контактов и найти его по телефону».
/// Порт 1:1 из Android ContactsInteractor.kt (getPhoneForSearch → getPhone(from:)).
protocol ContactsInteractor {
    /// Телефон выбранного контакта «как есть» (нормализацию выполняет поиск друзей).
    /// Телефона нет — .noPhone, сбой чтения — .readFailed.
    func getPhone(from contact: CNContact) async -> Result<String, ContactsError>
}
