import SwiftUI

/// Точка входа приложения. Тема всегда тёмная AURORA.
@main
struct ShareMyLocationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}
