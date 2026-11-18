import Foundation

/**
 API-ключ Google Maps: читается из Info.plist (project.yml: GMSApiKeyKey). В git —
 плейсхолдер; реальный ключ пользователь вносит локально при сборке (Sideloadly),
 CI собирает с плейсхолдером → вкладка показывает заглушку (GMSMapView не создаётся
 вовсе — аналог проверки BuildConfig.MAPS_API_KEY.isBlank Android).
 */
// TODO: проверить на CI — подхватывает ли Maps SDK ключ из Info.plist GMSApiKeyKey;
// если нет — GMSServices.provideAPIKey в AppDelegate при isConfigured (допущение плана).
enum MapApiKey {
    /// Значение из Info.plist; nil — ключа нет.
    private static let rawValue: String? = Bundle.main.object(
        forInfoDictionaryKey: "GMSApiKeyKey",
    ) as? String

    /// Ключ настроен: непустой и не плейсхолдер из project.yml.
    static var isConfigured: Bool {
        guard let rawValue, !rawValue.isEmpty else {
            return false
        }
        return rawValue != "TODO_MAPS_API_KEY"
    }
}
