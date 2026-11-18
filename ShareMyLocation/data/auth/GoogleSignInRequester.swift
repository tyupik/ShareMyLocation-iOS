import GoogleSignIn
import UIKit

/// Реализация GoogleSignInRequesting поверх GIDSignIn SDK. Аналог Android
/// GoogleCredentialRequest.kt (Credential Manager), вынесен в data-слой: UI знает
/// только протокол из business/auth. Колбэк async signIn(withPresenting:) —
/// штатное API GoogleSignIn-iOS 7+.
final class GoogleSignInRequester: GoogleSignInRequesting {
    func requestIdToken() async -> GoogleSignInOutcome {
        // Без конфигурации GIDSignIn (нет клиента) и без Firebase запуск диалога
        // бессмысленен: обмен токена всё равно упадёт. Результат — notConfigured.
        guard GIDSignIn.sharedInstance.configuration != nil else {
            print("GoogleSignInRequester: GIDSignIn не сконфигурирован (нет GIDConfiguration)")
            return .notConfigured
        }
        guard AuthRepositoryImpl.isFirebaseConfigured else {
            print("GoogleSignInRequester: Firebase не сконфигурирован — обмен токена невозможен")
            return .notConfigured
        }
        guard let presenting = Self.presentingViewController() else {
            return .failed(reason: "Не найден view controller для показа диалога Google Sign-In")
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = result.user.idToken?.tokenString else {
                return .failed(reason: "Google Sign-In вернул результат без idToken")
            }
            return .success(idToken: idToken, accessToken: result.user.accessToken.tokenString)
        } catch {
            // Отмена системного диалога — не ошибка: тихо возвращаем управление (как в Android).
            let nsError = error as NSError
            if nsError.domain == GIDSignInErrorDomain, nsError.code == GIDSignInError.canceled.rawValue {
                print("GoogleSignInRequester: диалог Google Sign-In отменён пользователем")
                return .cancelled
            }
            print("GoogleSignInRequester: ошибка Google Sign-In — \(nsError)")
            return .failed(reason: nsError.localizedDescription)
        }
    }

    /// Верхний вью-контроллер активной сцены: root keyWindow с раскруткой цепочки presented.
    private static func presentingViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard
            let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
            let root = scene.keyWindow?.rootViewController
        else {
            return nil
        }
        var topController: UIViewController? = root
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}
