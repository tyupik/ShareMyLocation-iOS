import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import UIKit

/// Реализация профиля поверх Firestore, AvatarCompressor и AvatarCache.
/// Порт 1:1 из Android ProfileRepositoryImpl.kt + FirebaseBackend (getUserProfile/
/// uploadAvatar/getAvatarBytes/saveProfile): Android-обёртка FirebaseBackend не портируется
/// (Java-класс специфики билда Android). Приложение переживает отсутствие
/// GoogleService-Info.plist: все методы проверяют isFirebaseConfigured и не крашатся.
final class ProfileRepositoryImpl: ProfileRepository {
    /// Firebase сконфигурирован (GoogleService-Info.plist в бандле и configure() вызван).
    private var isFirebaseConfigured: Bool {
        AuthRepositoryImpl.isFirebaseConfigured
    }

    /// Имена коллекций/полей — те же, что в Android FirebaseBackend:
    /// кроссплатформенная дружба требует точного совпадения схемы Firestore.
    private static let USERS_COLLECTION = "users"
    private static let AVATARS_COLLECTION = "avatars"
    private static let FIELD_EMAIL = "email"
    private static let FIELD_DISPLAY_NAME = "displayName"
    private static let FIELD_PHONE = "phone"
    private static let FIELD_AVATAR_VERSION = "avatarVersion"
    private static let FIELD_AVATAR_BLOB = "jpeg"
    private static let FIELD_HAS_COMPLETED_ONBOARDING = "hasCompletedOnboarding"
    private static let FIELD_UPDATED_AT = "updatedAt"

    /// Максимальный размер JPEG аватара: лимит документа Firestore — 1 МБ, берём с запасом
    /// (порт Android MAX_AVATAR_BYTES).
    private static let MAX_AVATAR_BYTES = 900_000

    private let avatarCompressor: AvatarCompressor
    private let avatarCache: AvatarCache

    init(avatarCompressor: AvatarCompressor, avatarCache: AvatarCache) {
        self.avatarCompressor = avatarCompressor
        self.avatarCache = avatarCache
    }

    func getProfile() async throws -> User {
        guard isFirebaseConfigured else {
            throw ProfileException(error: .unexpected("Firebase не сконфигурирован — чтение профиля невозможно"))
        }
        guard let firebaseUser = Auth.auth().currentUser else {
            throw ProfileException(error: .unexpected("Нет текущего пользователя Firebase при чтении профиля"))
        }
        print("ProfileRepositoryImpl.getProfile: start")
        do {
            let snapshot = try await Firestore.firestore()
                .collection(Self.USERS_COLLECTION)
                .document(firebaseUser.uid)
                .getDocument()
            print("ProfileRepositoryImpl.getProfile: done, exists=\(snapshot.exists)")
            let data = snapshot.data()
            let avatarVersion = (data?[Self.FIELD_AVATAR_VERSION] as? NSNumber)
                .map { Int(truncatingIfNeeded: $0) } ?? 0
            return User(
                uid: firebaseUser.uid,
                email: firebaseUser.email,
                displayName: Self.firstNonEmpty(
                    data?[Self.FIELD_DISPLAY_NAME] as? String,
                    firebaseUser.displayName,
                ),
                phone: data?[Self.FIELD_PHONE] as? String,
                avatarVersion: avatarVersion,
                hasCompletedOnboarding: (data?[Self.FIELD_HAS_COMPLETED_ONBOARDING] as? NSNumber)?.boolValue == true,
            )
        } catch {
            throw toProfileException(error)
        }
    }

    func prepareAvatar(_ image: UIImage) async throws -> String {
        do {
            return try avatarCompressor.compressToCache(image)
        } catch {
            throw toProfileException(error)
        }
    }

    func isCameraAvailable() -> Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func uploadAvatar(cachedPath: String) async throws -> Int {
        guard isFirebaseConfigured else {
            throw ProfileException(error: .unexpected("Firebase не сконфигурирован — загрузка аватара невозможна"))
        }
        guard let firebaseUser = Auth.auth().currentUser else {
            throw ProfileException(error: .unexpected("Нет текущего пользователя Firebase при загрузке аватара"))
        }
        let jpegBytes = try avatarCompressor.readBytes(cachedPath: cachedPath)
        guard jpegBytes.count <= Self.MAX_AVATAR_BYTES else {
            throw ProfileException(error: .avatarTooLarge)
        }
        print("ProfileRepositoryImpl.uploadAvatar: start")
        let firestore = Firestore.firestore()
        let usersDocument = firestore.collection(Self.USERS_COLLECTION).document(firebaseUser.uid)
        let avatarsDocument = firestore.collection(Self.AVATARS_COLLECTION).document(firebaseUser.uid)
        do {
            // Транзакция: блоб в avatars/{uid} + инкремент avatarVersion в users/{uid}
            // одной операцией (порт FirebaseBackend.uploadAvatar).
            let transactionResult = try await firestore.runTransaction { (transaction, errorPointer) -> Any? in
                // TODO: проверить на CI — имена API Firestore-транзакции в firebase-ios-sdk 11.x
                // (runTransaction, transaction.getDocument, setData(_:forDocument:merge:)).
                let usersSnapshot = try transaction.getDocument(usersDocument)
                let storedVersion = (usersSnapshot.data()?[Self.FIELD_AVATAR_VERSION] as? NSNumber)
                    .map { Int(truncatingIfNeeded: $0) } ?? 0
                let newVersion = storedVersion + 1

                transaction.setData(
                    [
                        Self.FIELD_AVATAR_BLOB: jpegBytes,
                        Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                    ],
                    forDocument: avatarsDocument,
                    merge: true,
                )
                transaction.setData(
                    [
                        Self.FIELD_AVATAR_VERSION: newVersion,
                        Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                    ],
                    forDocument: usersDocument,
                    merge: true,
                )
                return newVersion
            }
            guard let newVersion = (transactionResult as? NSNumber).map({ Int(truncatingIfNeeded: $0) }) else {
                throw ProfileException(error: .unexpected("Транзакция загрузки аватара не вернула версию"))
            }
            // Удаляет временный файл из compressToCache после успешной загрузки; при неудачной
            // загрузке файл остаётся — нужен для повторного сохранения.
            deleteTempFile(cachedPath: cachedPath)
            print("ProfileRepositoryImpl.uploadAvatar: done, version=\(newVersion)")
            return newVersion
        } catch {
            throw toProfileException(error)
        }
    }

    func getAvatar(uid: String, version: Int) async throws -> String? {
        guard isFirebaseConfigured else {
            throw ProfileException(error: .unexpected("Firebase не сконфигурирован — чтение аватара невозможно"))
        }
        if let cached = avatarCache.cachedPath(uid: uid, version: version) {
            return cached
        }
        print("ProfileRepositoryImpl.getAvatarBytes: start")
        do {
            let snapshot = try await Firestore.firestore()
                .collection(Self.AVATARS_COLLECTION)
                .document(uid)
                .getDocument()
            print("ProfileRepositoryImpl.getAvatarBytes: done, exists=\(snapshot.exists)")
            guard let blob = snapshot.data()?[Self.FIELD_AVATAR_BLOB] as? NSData else {
                return nil
            }
            return try avatarCache.cacheBytes(uid: uid, version: version, bytes: blob as Data)
        } catch {
            throw toProfileException(error)
        }
    }

    func saveProfile(
        displayName: String,
        phone: String,
        hasCompletedOnboarding: Bool,
    ) async throws {
        guard isFirebaseConfigured else {
            throw ProfileException(error: .unexpected("Firebase не сконфигурирован — сохранение профиля невозможно"))
        }
        guard let firebaseUser = Auth.auth().currentUser else {
            throw ProfileException(error: .unexpected("Нет текущего пользователя Firebase при сохранении профиля"))
        }
        print("ProfileRepositoryImpl.saveProfile: start")
        do {
            try await Firestore.firestore()
                .collection(Self.USERS_COLLECTION)
                .document(firebaseUser.uid)
                .setData(
                    [
                        Self.FIELD_DISPLAY_NAME: displayName,
                        Self.FIELD_PHONE: phone,
                        Self.FIELD_HAS_COMPLETED_ONBOARDING: hasCompletedOnboarding,
                        Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                    ],
                    merge: true,
                )
            print("ProfileRepositoryImpl.saveProfile: done")
        } catch {
            throw toProfileException(error)
        }
    }

    /// Удаляет временный файл из compressToCache; ошибка удаления не влияет на результат
    /// загрузки (порт Android deleteTempFile).
    private func deleteTempFile(cachedPath: String) {
        do {
            try FileManager.default.removeItem(atPath: cachedPath)
        } catch {
            print("ProfileRepositoryImpl: Не удалось удалить временный файл аватара: \(cachedPath)")
        }
    }

    /// ProfileException проходит как есть, сеть Firestore — networkUnavailable,
    /// остальное — unexpected с «код: сообщение»
    /// (порт FirebaseBackend.toProfileException + isNetworkError).
    private func toProfileException(_ error: Error) -> ProfileException {
        if let exception = error as? ProfileException {
            return exception
        }
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded:
                return ProfileException(error: .networkUnavailable)
            default:
                return ProfileException(error: .unexpected("\(code): \(nsError.localizedDescription)"))
            }
        }
        return ProfileException(error: .unexpected(nsError.localizedDescription))
    }

    /// Первый непустой аргумент: значение документа приоритетнее значения из сессии
    /// (порт FirebaseBackend.firstNonEmpty).
    private static func firstNonEmpty(_ primary: String?, _ fallback: String?) -> String? {
        if let primary, !primary.isEmpty {
            return primary
        }
        return fallback
    }
}
