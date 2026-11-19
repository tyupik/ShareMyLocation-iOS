/**
 Управление фоновым движком отправки геолокации (этап 8; Android foreground-сервис
 LocationSharingService → CoreLocation). Системный компонент, поэтому не MVI:
 единственный владелец старт/стопа — корневой оркестратор AppViewModel (реагирует на
 записанный документ isEnabled; latency compensation делает реакцию мгновенной), плюс
 явный стоп при выходе из аккаунта (MainViewModel). Порт 1:1 из Android
 LocationSharingController.kt: ViewModel контекст не держит — проверки прав и сессии
 инкапсулированы в реализации (data/sharing).
 */
protocol LocationSharingEngine {
    /**
     Идемпотентно приводит движок к состоянию `enabled`: true — стартует подписку на
     обновления локации, только если есть разрешение на геолокацию и текущий пользователь
     Firebase (иначе «включено без прав» — ложное обещание, движок молча не работает);
     false — останавливает подписку (no-op, если не запущена). isEnabled в Firestore
     при этом не трогается.
     */
    func setSharingEnabled(_ enabled: Bool)

    /// Подписка на обновления локации активна (наблюдение/отладка; оркестратор не использует).
    var isRunning: Bool { get }
}
