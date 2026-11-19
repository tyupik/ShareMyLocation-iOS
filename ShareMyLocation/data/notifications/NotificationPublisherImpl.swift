import UserNotifications

/**
 Публикация локальных уведомлений о заявках в друзья и шаринге геопозиции друзей.
 Живёт в data-слое: знает про UNUserNotificationCenter. Право на уведомления проверяется
 здесь: без него публикация молча пропускается (повторный запрос права — не здесь,
 см. NotificationPermissionControllerImpl).
 Порт 1:1 из Android NotificationPublisherImpl.kt: каналы → категории UNNotification
 (те же id "friend_requests"/"friend_sharing"), id уведомления = префикс + uid —
 повторное событие по uid заменяет карточку; тап открывает приложение системно
 (контент-интенция Android не портируется — системное поведение iOS).
 Тексты — дословный порт strings.xml.
 */
// TODO: проверить на CI — notificationSettings() async (iOS 15+), регистрация
// UNNotificationCategory и add(UNNotificationRequest) с trigger = nil.
@MainActor
final class NotificationPublisherImpl: NotificationPublisher {
    /// Категории — аналоги каналов Android (id и префиксы id уведомлений совпадают дословно).
    private static let FRIEND_REQUESTS_CATEGORY_ID = "friend_requests"
    private static let FRIEND_SHARING_CATEGORY_ID = "friend_sharing"
    private static let FRIEND_REQUEST_ID_PREFIX = "friend_request_"
    private static let FRIEND_SHARING_ID_PREFIX = "friend_sharing_"

    /// Категории регистрируются разово за жизнь синглтона (setNotificationCategories
    /// заменяет весь набор — как идемпотентный createNotificationChannel Android).
    private var areCategoriesRegistered = false

    func publish(_ notification: AppNotification) {
        // Асинхронно (порт fire-and-forget notify() Android): watcher не ждёт
        // системных вызовов центра уведомлений.
        Task {
            guard await Self.isPermissionGranted() else {
                print("NotificationPublisherImpl.publish: нет разрешения на уведомления — пропущено")
                return
            }
            ensureCategories()
            switch notification {
            case .friendRequestReceived(let fromUid, let fromName):
                await publishFriendRequest(fromUid: fromUid, fromName: fromName)
            case .friendStartedSharing(let uid, let displayName):
                await publishFriendSharing(uid: uid, displayName: displayName)
            }
        }
    }

    private func publishFriendRequest(fromUid: String, fromName: String) async {
        // Тексты — порт strings.xml (notification_friend_request_*).
        let body = fromName.isBlank
            ? "У вас новая заявка в друзья"
            : "\(fromName) хочет добавиться в друзья"
        await publishNotification(
            title: "Заявка в друзья",
            body: body,
            categoryId: Self.FRIEND_REQUESTS_CATEGORY_ID,
            identifier: Self.FRIEND_REQUEST_ID_PREFIX + fromUid,
        )
    }

    private func publishFriendSharing(uid: String, displayName: String) async {
        // Тексты — порт strings.xml (notification_friend_sharing_*).
        let body = displayName.isBlank
            ? "Ваш друг начал(а) делиться геопозицией"
            : "\(displayName) начал(а) делиться геопозицией"
        await publishNotification(
            title: "Геопозиция друга",
            body: body,
            categoryId: Self.FRIEND_SHARING_CATEGORY_ID,
            identifier: Self.FRIEND_SHARING_ID_PREFIX + uid,
        )
    }

    /// Публикует уведомление немедленно (trigger = nil); повторное событие по тому же
    /// identifier заменяет карточку (аналог notify(id) Android); свайп закрывает.
    private func publishNotification(title: String, body: String, categoryId: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // IMPORTANCE_DEFAULT Android звучит: явный .default, иначе карточка была бы тихой.
        content.sound = .default
        content.categoryIdentifier = categoryId
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("NotificationPublisherImpl.publish: id=\(identifier)")
        } catch {
            print("NotificationPublisherImpl.publish: не удалось добавить уведомление — \(error)")
        }
    }

    private func ensureCategories() {
        guard !areCategoriesRegistered else { return }
        areCategoriesRegistered = true
        let friendRequests = UNNotificationCategory(
            identifier: Self.FRIEND_REQUESTS_CATEGORY_ID,
            actions: [],
            intentIdentifiers: [],
            options: [],
        )
        let friendSharing = UNNotificationCategory(
            identifier: Self.FRIEND_SHARING_CATEGORY_ID,
            actions: [],
            intentIdentifiers: [],
            options: [],
        )
        UNUserNotificationCenter.current().setNotificationCategories([friendRequests, friendSharing])
    }

    /// Право выдано пользователем (порт isNotificationsPermissionGranted; статус читается
    /// асинхронно — замена синхронного checkSelfPermission Android).
    private static func isPermissionGranted() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}

/// Android String.isBlank: пусто или только пробельные символы.
private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
