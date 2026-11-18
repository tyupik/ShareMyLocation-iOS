import CoreLocation

/**
 Реализация MyLocationProviding поверх CLLocationManager: последний известный фикс из кэша
 провайдера и one-shot requestLocation. Порт 1:1 из Android MyLocationProviderImpl.kt
 (FusedLocationProviderClient → CoreLocation).
 Все отказы (нет прав, ошибка/таймаут провайдера) преобразуются в nil — «фикса нет»,
 вызывающий не трогает камеру.

 ОТДЕЛЬНЫЙ лёгкий CLLocationManager: не переиспользует LocationPermissionRequester
 (тот живёт своим диалогом прав; здесь — только чтение фиксов).
 Класс @MainActor: CLLocationManager в свежих SDK MainActor-аннотирован, а делегатские
 колбэки приходят в main-поток — изоляция совпадает с реальным потоком исполнения.
 */
// TODO: проверить на CI — CLLocationManager.requestLocation() + delegate под @MainActor
// (паттерн LocationPermissionRequester: двойной вызов delegate, continuation one-shot).
@MainActor
final class MyLocationProviderImpl: NSObject, MyLocationProviding, CLLocationManagerDelegate {
    /// Менеджер живёт с синглтоном: пересоздание сбрасывало бы делегата.
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    /// One-shot continuation ожидания фикса; nil — запрос не в полёте.
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    /**
     Флаг one-shot запроса: continuation резюмится ровно один раз (делегат ИЛИ таймаут —
     кто первый) И гейтит параллельные запросы — новый вызов currentLocation при активном
     one-shot отказывается (nil), не перезаписывая continuation.
     */
    private var isLocationRequestActive = false

    /// Задача таймаута one-shot запроса: отменяется при получении фикса.
    private var timeoutTask: Task<Void, Never>?

    func hasLocationPermission() -> Bool {
        // Только instance-свойство authorizationStatus: class-метод authorizationStatus()
        // deprecated с iOS 14 (паттерн LocationPermissionRequester).
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func lastKnownLocation() async -> SharedLocation? {
        guard hasLocationPermission(), let location = manager.location else {
            return nil
        }
        return Self.toSharedLocation(location)
    }

    func currentLocation() async -> SharedLocation? {
        guard hasLocationPermission() else {
            return nil
        }
        // Параллельный вызов при активном one-shot (например, locateMeClicked, пока
        // fetchMyLocation с screenShown ещё ждёт фикс): отказ новому — nil. Перезапись
        // continuation потеряла бы первый resume (утечка). В полёте остаётся прежний
        // запрос — его результат обновит myLocation вызывающей стороне не хуже.
        guard !isLocationRequestActive else {
            print("MyLocationProviderImpl: запрос фикса уже в полёте — считаю фикса нет")
            return nil
        }
        let location = await withCheckedContinuation { continuation in
            locationContinuation = continuation
            isLocationRequestActive = true
            manager.requestLocation()
            // Таймаут ~10 c: requestLocation может не ответить (нет фикса/сигнала) — nil.
            // Strong self безопасен: провайдер — синглтон, живёт с процессом.
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.LOCATION_TIMEOUT_NANOS)
                guard !Task.isCancelled else { return }
                self.fulfillLocation(nil)
            }
        }
        return location.map(Self.toSharedLocation)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        fulfillLocation(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("MyLocationProviderImpl: requestLocation не удался — считаю фикса нет: \(error)")
        fulfillLocation(nil)
    }

    // MARK: - Приватное

    /** Одноразовый resume-guard: делегат или таймаут — кто первый. */
    private func fulfillLocation(_ location: CLLocation?) {
        guard isLocationRequestActive else { return }
        isLocationRequestActive = false
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: location)
    }

    private static func toSharedLocation(_ location: CLLocation) -> SharedLocation {
        SharedLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMeters: location.horizontalAccuracy,
        )
    }

    /// Таймаут one-shot запроса фикса.
    private static let LOCATION_TIMEOUT_NANOS: UInt64 = 10_000_000_000
}
