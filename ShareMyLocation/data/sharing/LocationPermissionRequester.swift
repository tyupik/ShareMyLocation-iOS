import CoreLocation

/**
 Реализация LocationPermissionRequesting поверх CLLocationManager: проверка статуса и запрос
 when-in-use через системный диалог. Живёт в data/sharing: UI и ViewModel знают только
 протокол из business/sharing. iOS-замена связки Android LocationSharingController
 (hasLocationPermission) + rememberLauncherForActivityResult (SharingSettingsScreen).

 Класс @MainActor: CLLocationManager в свежих SDK MainActor-аннотирован, а делегатские
 колбэки приходят в main-поток — изоляция совпадает с реальным потоком исполнения.
 */
// TODO: проверить на CI — изоляция @MainActor против CLLocationManagerDelegate
// (instance authorizationStatus, двойной вызов locationManagerDidChangeAuthorization,
// delegate живёт синглтоном через Factory).
@MainActor
final class LocationPermissionRequester: NSObject, LocationPermissionRequesting, CLLocationManagerDelegate {
    /// Менеджер живёт с синглтоном: пересоздание сбрасывало бы делегата и активный диалог прав.
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    /// One-shot continuation ожидания решения пользователя; nil — запрос не в полёте.
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    /// Resume-guard: делегат может вызваться дважды за один запрос (см. делегат-метод).
    private var isAuthorizationRequestActive = false

    func hasLocationPermission() -> Bool {
        // Только instance-свойство authorizationStatus: class-метод authorizationStatus()
        // deprecated с iOS 14, instance-вариант — штатный путь для текущего статуса.
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func requestWhenInUse() async -> Bool {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Право уже выдано (в том числе «сильное» always — для шаринга достаточно).
            return true
        case .denied, .restricted:
            // Диалог не покажется: пользователь уже отказал или доступ ограничен системой.
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                isAuthorizationRequestActive = true
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return false
        }
    }

    /**
     Колбэк смены статуса прав. Вызывается ДВАЖДЫ за один запрос: сразу при
     requestWhenInUseAuthorization с текущим статусом notDetermined (игнорируем) и после
     решения пользователя — резюмим только фактический итог (one-shot continuation).
     */
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard isAuthorizationRequestActive, status != .notDetermined else { return }
        isAuthorizationRequestActive = false
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
    }
}
