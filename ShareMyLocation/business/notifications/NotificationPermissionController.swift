/**
 Проверка права на локальные уведомления и учёт факта его запроса. Системный компонент,
 поэтому реализация живёт в data-слое (см. NotificationPermissionControllerImpl).
 Порт Android NotificationPermissionController.kt; async-версии isGranted/requestAuthorization —
 замена синхронного checkSelfPermission: статус права UNUserNotificationCenter доступен
 только асинхронно.
 @MainActor: вызывающий (MainViewModel) и системный диалог — main-контекст.
 */
@MainActor
protocol NotificationPermissionController {
    /// Право на показ уведомлений выдано пользователем.
    func isGranted() async -> Bool

    /// Системный диалог права ещё не показывался — его стоит запросить.
    func shouldRequest() -> Bool

    /// Показывает системный диалог запроса права; true — пользователь разрешил.
    func requestAuthorization() async -> Bool

    /// Результат системного диалога; вызывается при любом исходе.
    func onRequestResult(granted: Bool)
}
