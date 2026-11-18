import Factory

/// Binding data-слоя карты (аналог Android MapModule.kt).
extension Container {
    /// Репозиторий точек геолокаций. Синглтон: слушатели чанков переживают вкладку.
    var mapRepository: Factory<MapRepository> {
        self {
            MapRepositoryImpl()
        }.singleton
    }

    /// Провайдер собственной локации. Синглтон: CLLocationManager + delegate живут с ним
    /// (аналог @Singleton Android MyLocationProviderImpl).
    var myLocationProvider: Factory<MyLocationProviding> {
        self {
            MyLocationProviderImpl()
        }.singleton
    }
}
