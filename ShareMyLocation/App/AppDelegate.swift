import Factory
import FirebaseCore
import UIKit
import UserNotifications

/**
 AppDelegate: конфигурирует Firebase при запуске, стартует наблюдатель локальных
 уведомлений (порт ShareMyLocationApp.onCreate Android) и показывает их баннером
 при открытом приложении. Если GoogleService-Info.plist отсутствует в бандле
 (файл не в git), приложение не крашится — работает без Firebase, сессии нет
 (см. AuthRepositoryImpl.isFirebaseConfigured); наблюдатель в этом случае сам не
 активирует Firestore-слушателей.
 */
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            print("GoogleService-Info.plist отсутствует — Firebase не сконфигурирован")
            startAppServices()
            return true
        }
        FirebaseApp.configure()
        startAppServices()
        return true
    }

    /// Запуск process-scoped сервисов приложения (единый путь — с Firebase и без):
    /// наблюдатель уведомлений идемпотентен и сам следит за аутентификацией.
    private func startAppServices() {
        // Порт Android ShareMyLocationApp.onCreate: наблюдатель живёт весь срок процесса.
        Container.shared.notificationWatcher().start()
        // Foreground-показ локальных уведомлений: Android IMPORTANCE_DEFAULT показывает
        // баннер и при открытом приложении.
        // TODO: проверить на CI — delegate UNUserNotificationCenter из AppDelegate.
        UNUserNotificationCenter.current().delegate = self
    }

    /// Показ уведомления, пока приложение на переднем плане (порт IMPORTANCE_DEFAULT Android:
    /// баннер + звук, в центр уведомлений сообщение не кладётся).
    // TODO: проверить на CI — сигнатура willPresent и опция .banner (iOS 14+).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void,
    ) {
        completionHandler([.banner, .sound])
    }
}
