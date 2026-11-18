import Factory

/// Binding data-слоя шаринга (аналог Android SharingModule.kt).
extension Container {
    /// Репозиторий настроек шаринга. Синглтон: realtime-слушатель isEnabled живёт
    /// между экранами (нужен движку, этап 8).
    var sharingRepository: Factory<SharingRepository> {
        self {
            SharingRepositoryImpl()
        }.singleton
    }

    /// Requester прав геолокации. Синглтон держит живой CLLocationManager + delegate:
    /// пересоздание сбрасывало бы активный системный диалог и статус.
    var locationPermissionRequester: Factory<LocationPermissionRequesting> {
        self {
            LocationPermissionRequester()
        }.singleton
    }
}
