import CoreLocation
import FirebaseAuth

/**
 Фоновый движок отправки геолокации поверх CLLocationManager: пока документ
 sharingSettings/{uid} хранит isEnabled = true, пишет последнюю координату в locations/{uid}
 (merge-set) не чаще раза в SHARING_INTERVAL_MS. Получателей не вычисляет — только пишет
 свою точку; выбор адресатов и свежесть (updatedAt) определяет читатель (этап 7).
 Порт Android LocationSharingService.kt + LocationSharingControllerImpl.kt
 (foreground-сервис → непрерывная подписка CoreLocation; FusedLocationProvider →
 CLLocationManager; PRIORITY_HIGH_ACCURACY 5 c → throttle 5 c по elapsed записи).

 Жизненный цикл: старт/стоп — только через LocationSharingEngine (корневой оркестратор
 AppViewModel по realtime-флагу isEnabled, явный стоп при выходе из аккаунта MainViewModel).
 Кнопка «Остановить» Android-уведомления сервиса не портируется: системный индикатор
 showsBackgroundLocationIndicator — честный признак фоновой работы, isEnabled остаётся
 включённым до действия пользователя. START_STICKY-аналог — восстановление оркестратором
 при запуске процесса (первая эмиссия isEnabled = true поднимает движок заново).

 Класс @MainActor: CLLocationManager в свежих SDK MainActor-аннотирован, а делегатские
 колбэки приходят в main-поток — изоляция совпадает с реальным потоком исполнения
 (паттерн MyLocationProviderImpl/LocationPermissionRequester).
 */
// TODO: проверить на CI — изоляция @MainActor против CLLocationManagerDelegate
// (паттерн MyLocationProviderImpl), передача CLLocation в Task (Sendability, Swift 5 mode)
// и матчинг CLError.Code.denied вместо явной проверки домена kCLErrorDomain.
@MainActor
final class LocationSharingEngineImpl: NSObject, LocationSharingEngine, CLLocationManagerDelegate {
    private let sharingRepository: SharingRepository
    private let locationPermissionRequester: LocationPermissionRequesting

    init(
        sharingRepository: SharingRepository,
        locationPermissionRequester: LocationPermissionRequesting,
    ) {
        self.sharingRepository = sharingRepository
        self.locationPermissionRequester = locationPermissionRequester
        super.init()
    }

    /// Отдельный лёгкий CLLocationManager: не переиспользует LocationPermissionRequester
    /// (тот живёт своим диалогом прав; здесь — непрерывная подписка обновлений).
    /// Менеджер живёт с синглтоном: пересоздание сбрасывало бы делегата.
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    private(set) var isRunning = false

    /// Подряд идущие несетевые ошибки записи; серия — признак отзыва прав (см. onPersistFailed).
    private var consecutiveUnexpectedFailures = 0

    /// Последняя точка провайдера, ожидающая своего тика записи (throttle).
    private var pendingLocation: CLLocation?

    /// Момент последней успешной постановки в очередь записи (throttle по elapsed).
    private var lastPersistAt: Date?

    func setSharingEnabled(_ enabled: Bool) {
        if enabled {
            // Гейт прав и сессии ДО старта (порт LocationSharingControllerImpl):
            // «включено без прав» — ложное обещание, движок молча не работает,
            // isEnabled в Firestore не трогается.
            guard locationPermissionRequester.hasLocationPermission(), Auth.auth().currentUser != nil else {
                print("LocationSharingEngineImpl: нет прав геолокации или пользователя — не стартую")
                stopInternal()
                return
            }
            // Повторный старт при работающем движке подавляется (порт isSubscribed).
            guard !isRunning else { return }
            isRunning = true
            Task { await validateAndSubscribe() }
        } else {
            // Стоп по не запущенному движку — no-op (порт stopService).
            stopInternal()
        }
    }

    // MARK: - Приватное

    /**
     Ревалидация настройки по свежим данным (порт validateAndSubscribe): ошибка чтения
     или isEnabled = false — стоп. Движок доверяет только isEnabled: получателей
     (allowedUids/группы) вычисляет читатель.
     */
    private func validateAndSubscribe() async {
        // Порт getOrNull() Android: ошибка чтения трактуется как «настройка недоступна».
        let settings = try? await sharingRepository.getSettings()
        guard let settings, settings.isEnabled else {
            print("LocationSharingEngineImpl: Ревалидация не пройдена: настройка выключена или недоступна — стоп")
            stopInternal()
            return
        }
        // За время сетевой ревалидации движок могли остановить — гонка с setSharingEnabled(false).
        guard isRunning else { return }
        startLocationUpdates()
    }

    /// Подписка на обновления локации: высокая точность, без пауз и без фоновых индикаторов-лжи
    /// (порт startLocationUpdates + requestLocationUpdates).
    private func startLocationUpdates() {
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        if locationPermissionRequester.hasLocationPermission() {
            // Ставится только при выданном праве: на notDetermined роняет приложение.
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
        print("LocationSharingEngineImpl: Обновления локации оформлены: интервал=\(Self.SHARING_INTERVAL_MS) мс")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Запоминаем последнюю точку; запись — не чаще раза в SHARING_INTERVAL_MS
        // (throttle по elapsed от последней записи).
        pendingLocation = location
        let now = Date()
        if let lastPersistAt, now.timeIntervalSince(lastPersistAt) * 1000 < Double(Self.SHARING_INTERVAL_MS) {
            return
        }
        lastPersistAt = now
        guard let pending = pendingLocation else { return }
        Task { await persistLocation(pending) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied {
            // Права отозваны: продолжать бессмысленно (порт SecurityException → stopSelf).
            print("LocationSharingEngineImpl: Права геолокации отозваны — останавливаю движок: \(error)")
            stopInternal()
            return
        }
        print("LocationSharingEngineImpl: Ошибка провайдера локации: \(error)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRunning else { return }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            print("LocationSharingEngineImpl: Права геолокации отозваны/ограничены — останавливаю движок")
            stopInternal()
        default:
            break
        }
    }

    // MARK: - Запись точки

    private func persistLocation(_ location: CLLocation) async {
        let sharedLocation = SharedLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMeters: location.horizontalAccuracy,
        )
        do {
            try await sharingRepository.updateLocation(sharedLocation)
            consecutiveUnexpectedFailures = 0
        } catch {
            onPersistFailed(error)
        }
    }

    /**
     Ошибка записи (порт onPersistFailed): сеть недоступна — ждём следующей точки;
     повторная несанкционированная (PERMISSION_DENIED в Unexpected — отозвали права или
     разлогинили) — стоп, иначе движок писал бы в никуда каждые 5 секунд.
     */
    private func onPersistFailed(_ error: Error) {
        let sharingError = (error as? SharingException)?.error
        if case .networkUnavailable? = sharingError {
            print("LocationSharingEngineImpl: Не удалось записать локацию: сеть недоступна — ждём следующей точки")
            return
        }
        consecutiveUnexpectedFailures += 1
        let failures = consecutiveUnexpectedFailures
        print("LocationSharingEngineImpl: Не удалось записать локацию (подряд: \(failures)) — \(error)")
        if case .unexpected(let reason)? = sharingError,
            reason?.uppercased().contains(Self.PERMISSION_DENIED_MARKER) == true,
            consecutiveUnexpectedFailures >= Self.MAX_CONSECUTIVE_UNEXPECTED_FAILURES {
            print("LocationSharingEngineImpl: Повторная несанкционированная ошибка записи — останавливаю движок")
            stopInternal()
        }
    }

    /**
     Внутренний стоп (порт stopSelf): подписка снимается, точка в locations/{uid} остаётся;
     isEnabled в Firestore не перезаписывается — восстановление решает оркестратор.
     */
    private func stopInternal() {
        manager.stopUpdatingLocation()
        isRunning = false
        pendingLocation = nil
        lastPersistAt = nil
        consecutiveUnexpectedFailures = 0
    }

    // ------------------------------------------------------------------
    // Константы (порт companion object Android LocationSharingService).
    // ------------------------------------------------------------------

    /// Интервал записей: 5 c ≈ 17 200 записей/день — безопасно для квот Spark.
    private static let SHARING_INTERVAL_MS = 5_000

    /// Сколько подряд несанкционированных ошибок пережидаем, прежде чем остановить движок.
    private static let MAX_CONSECUTIVE_UNEXPECTED_FAILURES = 2

    /// Признак несанкционированности в reason у SharingError.unexpected (описание кода Firestore).
    private static let PERMISSION_DENIED_MARKER = "PERMISSION_DENIED"
}
