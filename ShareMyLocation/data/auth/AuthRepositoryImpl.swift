import FirebaseAuth
import FirebaseCore

/// Реализация аутентификации поверх FirebaseAuth напрямую: Android-обёртка FirebaseBackend
/// не портируется (специфика билда Android). Порт логики AuthRepositoryImpl.kt +
/// маппинга FirebaseBackend.toUser (uid/email/displayName, остальное — дефолты).
/// Приложение переживает отсутствие GoogleService-Info.plist: все методы проверяют
/// isFirebaseConfigured и не крашатся без сконфигурированного Firebase.
final class AuthRepositoryImpl: AuthRepository {
    /// Firebase сконфигурирован (GoogleService-Info.plist в бандле и configure() вызван).
    static var isFirebaseConfigured: Bool {
        FirebaseApp.app() != nil
    }

    func getCurrentUser() async -> User? {
        guard Self.isFirebaseConfigured else {
            return nil
        }
        return Self.toUser(Auth.auth().currentUser)
    }

    func signOut() async {
        guard Self.isFirebaseConfigured else {
            return
        }
        do {
            try Auth.auth().signOut()
        } catch {
            print("AuthRepositoryImpl.signOut: \(error)")
        }
    }

    /// Колбэк слушателя состояния аутентификации обёрнут в AsyncStream на границе data-слоя:
    /// слушатель эмитит сразу при регистрации (сессия или nil) и далее при каждом
    /// sign-in/sign-out. Если Firebase не сконфигурирован — единственная эмиссия nil
    /// и завершение потока (сессии нет, приложение работает без Firebase).
    func observeAuthState() -> AsyncStream<User?> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            guard Self.isFirebaseConfigured else {
                continuation.yield(nil)
                continuation.finish()
                return
            }
            let listener = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(Self.toUser(user))
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// FirebaseUser сессии → User (без данных документа users — их здесь нет;
    /// маппинг портирован из FirebaseBackend.toUser).
    private static func toUser(_ firebaseUser: FirebaseAuth.User?) -> User? {
        guard let firebaseUser else {
            return nil
        }
        return User(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
        )
    }
}
