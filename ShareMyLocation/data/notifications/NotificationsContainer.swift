import Factory

/// Binding data-слоя уведомлений (аналог Android NotificationsModule.kt).
extension Container {
    /// Публикатор локальных уведомлений. Синглтон: категории регистрируются разово.
    var notificationPublisher: Factory<NotificationPublisher> {
        self {
            NotificationPublisherImpl()
        }.singleton
    }

    /// Контроллер права на уведомления. Синглтон: флаг «право уже запрашивали» — процессный.
    var notificationPermissionController: Factory<NotificationPermissionController> {
        self {
            NotificationPermissionControllerImpl()
        }.singleton
    }
}
