import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

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

    /// Имена коллекции/полей users/{uid} — те же, что в Android FirebaseBackend:
    /// кроссплатформенная дружба требует точного совпадения схемы Firestore.
    private static let USERS_COLLECTION = "users"
    private static let FIELD_EMAIL = "email"
    private static let FIELD_DISPLAY_NAME = "displayName"
    private static let FIELD_CREATED_AT = "createdAt"
    private static let FIELD_UPDATED_AT = "updatedAt"
    private static let FIELD_HAS_COMPLETED_ONBOARDING = "hasCompletedOnboarding"

    /// Идентификатор провайдера Apple в Firebase Auth.
    private static let APPLE_PROVIDER_ID = "apple.com"

    func signInWithEmail(email: String, password: String) async throws {
        guard Self.isFirebaseConfigured else {
            throw AuthException(error: .unexpected("Firebase не сконфигурирован — вход по email невозможен"))
        }
        print("AuthRepositoryImpl.signInWithEmail: start")
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            try await ensureUserDocument()
            print("AuthRepositoryImpl.signInWithEmail: done")
        } catch {
            throw toAuthException(error)
        }
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        guard Self.isFirebaseConfigured else {
            throw AuthException(error: .unexpected("Firebase не сконфигурирован — регистрация невозможна"))
        }
        print("AuthRepositoryImpl.signUpWithEmail: start")
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // В iOS AuthDataResult.user не optional (в Android getUser() nullable
            // и проверяется): после createUser пользователь гарантированно есть.
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            try await ensureUserDocument()
            print("AuthRepositoryImpl.signUpWithEmail: done")
        } catch {
            throw toAuthException(error)
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String?) async throws {
        guard Self.isFirebaseConfigured else {
            throw AuthException(error: .unexpected("Firebase не сконфигурирован — вход через Google невозможен"))
        }
        print("AuthRepositoryImpl.signInWithGoogle: start")
        do {
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            _ = try await Auth.auth().signIn(with: credential)
            try await ensureUserDocument()
            print("AuthRepositoryImpl.signInWithGoogle: done")
        } catch {
            throw toAuthException(error)
        }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: String?) async throws {
        guard Self.isFirebaseConfigured else {
            throw AuthException(error: .unexpected("Firebase не сконфигурирован — вход через Apple невозможен"))
        }
        print("AuthRepositoryImpl.signInWithApple: start")
        do {
            let credential = OAuthProvider.credential(
                withProviderID: Self.APPLE_PROVIDER_ID,
                idToken: idToken,
                rawNonce: rawNonce,
            )
            let result = try await Auth.auth().signIn(with: credential)
            // Apple отдаёт имя только при первой авторизации — пишем в displayName сессии,
            // чтобы ensureUserDocument подхватил его в users/{uid}.
            if let fullName, !fullName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = fullName
                try await changeRequest.commitChanges()
            }
            try await ensureUserDocument()
            print("AuthRepositoryImpl.signInWithApple: done")
        } catch {
            throw toAuthException(error)
        }
    }

    /// Создаёт users/{uid} с createdAt и hasCompletedOnboarding = false, если документа
    /// ещё нет, иначе обновляет поля (merge). Порт 1:1 из FirebaseBackend.ensureUserDocument.
    private func ensureUserDocument() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthException(
                error: .unexpected("Нет текущего пользователя Firebase после успешной аутентификации"),
            )
        }
        let document = Firestore.firestore()
            .collection(Self.USERS_COLLECTION)
            .document(firebaseUser.uid)
        do {
            print("AuthRepositoryImpl.ensureUserDocument: start")
            let snapshot = try await document.getDocument()
            var data: [String: Any] = [:]
            // Android кладёт email как есть (может быть null) — NSNull даёт тот же null в Firestore.
            data[Self.FIELD_EMAIL] = firebaseUser.email ?? NSNull()
            data[Self.FIELD_DISPLAY_NAME] = firebaseUser.displayName ?? ""
            data[Self.FIELD_UPDATED_AT] = FieldValue.serverTimestamp()
            if !snapshot.exists {
                data[Self.FIELD_CREATED_AT] = FieldValue.serverTimestamp()
                data[Self.FIELD_HAS_COMPLETED_ONBOARDING] = false
            }
            try await document.setData(data, merge: true)
            print("AuthRepositoryImpl.ensureUserDocument: done")
        } catch {
            throw toAuthException(error)
        }
    }

    /// Маппинг ошибки Firebase в AuthException: коды Auth → invalidCredentials/emailAlreadyInUse,
    /// коды Firestore unavailable/deadlineExceeded → networkUnavailable, остальное —
    /// unexpected с «код: сообщение» (порт FirebaseBackend.toAuthException + describeCause).
    private func toAuthException(_ error: Error) -> AuthException {
        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail, .wrongPassword, .userNotFound, .userDisabled, .invalidCredential:
                return AuthException(error: .invalidCredentials)
            case .emailAlreadyInUse:
                return AuthException(error: .emailAlreadyInUse)
            case .networkError:
                return AuthException(error: .networkUnavailable)
            default:
                return AuthException(error: .unexpected("\(code): \(nsError.localizedDescription)"))
            }
        }

        // Классификацию сети Firestore ставим после веток Firebase Auth,
        // чтобы не изменить их приоритет (как в Android toAuthException).
        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded:
                return AuthException(error: .networkUnavailable)
            default:
                return AuthException(error: .unexpected("\(code): \(nsError.localizedDescription)"))
            }
        }

        return AuthException(error: .unexpected(nsError.localizedDescription))
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
