/**
 Публикация системных уведомлений. Системный компонент, поэтому реализация живёт в data-слое
 (см. NotificationPublisherImpl): право на уведомления и категории — его забота.
 Порт 1:1 из Android NotificationPublisher.kt.
 */
protocol NotificationPublisher {
    /// Публикует уведомление; без выданного права реализация молча пропускает публикацию.
    func publish(_ notification: AppNotification)
}
