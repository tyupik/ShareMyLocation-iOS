import FirebaseCore
import UIKit

/// AppDelegate: конфигурирует Firebase при запуске. Если GoogleService-Info.plist
/// отсутствует в бандле (файл не в git), приложение не крашится — работает без Firebase,
/// сессии нет (см. AuthRepositoryImpl.isFirebaseConfigured).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            print("GoogleService-Info.plist отсутствует — Firebase не сконфигурирован")
            return true
        }
        FirebaseApp.configure()
        return true
    }
}
