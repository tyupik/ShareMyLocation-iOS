import UserNotifications

/**
 Реализация NotificationPermissionController поверх UNUserNotificationCenter: статус права,
 разовый системный диалог и флаг «право уже запрашивали» (UserDefaults; ключ перенесён
 дословно из Android SharedPreferences). Живёт в data-слое: знает про системный центр
 уведомлений. Статус права меняется только системным диалогом/Настройками — читается
 асинхронно (замена синхронного checkSelfPermission Android).
 */
// TODO: проверить на CI — notificationSettings() async и requestAuthorization(options:)
// (iOS 15+ async-варианты UNUserNotificationCenter).
@MainActor
final class NotificationPermissionControllerImpl: NotificationPermissionController {
    /// Ключ флага «право уже запрашивали» — дословно из Android NotificationPermissionControllerImpl.
    private static let KEY_ASKED = "notifications_permission_asked"

    func isGranted() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func shouldRequest() -> Bool {
        !UserDefaults.standard.bool(forKey: Self.KEY_ASKED)
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            print("NotificationPermissionControllerImpl.requestAuthorization: \(error)")
            return false
        }
    }

    func onRequestResult(granted: Bool) {
        print("NotificationPermissionControllerImpl.onRequestResult: granted=\(granted)")
        // Флаг ставится при любом результате: после первого показа системного диалога
        // запрос больше не навязывается (отказ — пользователь включит в настройках).
        UserDefaults.standard.set(true, forKey: Self.KEY_ASKED)
    }
}
