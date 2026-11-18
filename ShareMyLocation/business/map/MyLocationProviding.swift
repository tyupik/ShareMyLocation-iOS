import CoreLocation

/**
 Источник собственной локации (CoreLocation): последний известный фикс и one-shot запрос.
 Порт 1:1 из Android MyLocationProvider.kt (FusedLocationProviderClient → CLLocationManager).
 Реализация живёт в data/map: ViewModel не знает про CoreLocation.
 @MainActor: CLLocationManager и его делегатские колбэки — main-контекст
 (паттерн LocationPermissionRequesting).
 */
@MainActor
protocol MyLocationProviding {
    /**
     Есть ли разрешение на геолокацию: when-in-use или always. Синхронная проверка
     фактических грантов — флаг прав экрана только из них, никогда не «оптимистично».
     */
    func hasLocationPermission() -> Bool

    /**
     Последний известный фикс из кэша CoreLocation (мгновенно); nil — фикса нет
     (нет прав, кэш пуст). Все отказы преобразуются в nil — «фикса нет», вызывающий
     не трогает камеру.
     */
    func lastKnownLocation() async -> SharedLocation?

    /**
     One-shot фикс (requestLocation); nil — фикса нет (отказ, ошибка провайдера,
     таймаут ~10 с). Вызывающий не ждёт индикатора — задержка до секунд, компромисс плана.
     */
    func currentLocation() async -> SharedLocation?
}
