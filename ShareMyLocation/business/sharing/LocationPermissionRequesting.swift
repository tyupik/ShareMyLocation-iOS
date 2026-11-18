/**
 Источник прав геолокации (CoreLocation): проверка статуса и запрос when-in-use.
 Протокол живёт в business, реализация (CLLocationManager) — в data/sharing: ViewModel
 не знает про CoreLocation. iOS-замена Android LocationSharingController.hasLocationPermission()
 + rememberLauncherForActivityResult экрана (этап 6); Always-право — отдельный шаг этапа 8.
 @MainActor: CLLocationManager и его диалог — main-контекст, все вызывающие (ViewModel,
 экран) тоже MainActor.
 */
@MainActor
protocol LocationPermissionRequesting {
    /**
     Есть ли разрешение на геолокацию: when-in-use или always (always считается «сильнее»
     и тоже подходит для работы шаринга).
     */
    func hasLocationPermission() -> Bool

    /**
     Показывает системный диалог запроса when-in-use (только из состояния notDetermined) и
     возвращает итог: true — право выдано или уже было, false — отказ/ограничение.
     */
    func requestWhenInUse() async -> Bool
}
