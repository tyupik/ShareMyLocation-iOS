import Factory

/// Binding наблюдателя уведомлений (аналог Android @Singleton-инъекции в Application).
/// Синглтон: watcher живёт весь срок процесса, дедуп-наборы и идемпотентный старт — только в нём.
extension Container {
    var notificationWatcher: Factory<NotificationWatcher> {
        self {
            NotificationWatcher(
                authInteractor: self.authInteractor(),
                friendsInteractor: self.friendsInteractor(),
                mapInteractor: self.mapInteractor(),
                notificationPublisher: self.notificationPublisher(),
            )
        }.singleton
    }
}
