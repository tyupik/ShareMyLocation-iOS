import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

/**
 Реализация настроек шаринга и отправки геолокации поверх Firestore напрямую:
 Android-обёртка FirebaseBackend не портируется, sharing-методы getSharingSettings/
 getSharingSettingsByUid/saveSharingSettings/saveMyLocation/setSharingEnabled/
 listenSharingSettings перенесены сюда (порт 1:1, включая toSharingAudience/
 toStringList/toSharingException/isSharingAccessDenied). Приложение переживает
 отсутствие GoogleService-Info.plist: все методы проверяют isFirebaseConfigured
 и не крашатся.

 Realtime-слушатель isEnabled обёрнут в AsyncStream на границе data-слоя: данные уходят
 в поток через yield, ошибка слушателя завершает поток — перезапуск возможен по повторной
 подписке (аналог callbackFlow + awaitClose Android SharingRepositoryImpl).
 */
final class SharingRepositoryImpl: SharingRepository {
    /// Firebase сконфигурирован (GoogleService-Info.plist в бандле и configure() вызван).
    private var isFirebaseConfigured: Bool {
        AuthRepositoryImpl.isFirebaseConfigured
    }

    /// Имена коллекций/полей — те же, что в Android FirebaseBackend:
    /// кроссплатформенная дружба требует точного совпадения схемы Firestore.
    private static let SHARING_SETTINGS_COLLECTION = "sharingSettings"
    private static let LOCATIONS_COLLECTION = "locations"
    private static let FIELD_IS_ENABLED = "isEnabled"
    private static let FIELD_AUDIENCE = "audience"
    private static let FIELD_ALLOWED_UIDS = "allowedUids"
    private static let FIELD_ALLOWED_GROUP_IDS = "allowedGroupIds"
    private static let FIELD_UPDATED_AT = "updatedAt"
    private static let FIELD_GEO = "geo"
    private static let FIELD_ACCURACY = "accuracy"
    private static let AUDIENCE_ALL_FRIENDS = "ALL_FRIENDS"
    private static let AUDIENCE_CUSTOM = "CUSTOM"

    /// Одноразовое чтение sharingSettings/{uid}: отсутствующий документ — дефолт, не ошибка
    /// (правило владельческое и resource не читает, поэтому deny отсутствующего невозможен).
    /// Порт 1:1 FirebaseBackend.getSharingSettings.
    func getSettings() async throws -> SharingSettings {
        guard isFirebaseConfigured else {
            throw SharingException(
                error: .unexpected("Firebase не сконфигурирован — чтение настроек шаринга невозможно"),
            )
        }
        let myUid = try requireMyUid()
        print("SharingRepositoryImpl.getSharingSettings: start")
        do {
            let snapshot = try await Firestore.firestore()
                .collection(Self.SHARING_SETTINGS_COLLECTION)
                .document(myUid)
                .getDocument()
            print("SharingRepositoryImpl.getSharingSettings: done, exists=\(snapshot.exists)")
            guard snapshot.exists else {
                return SharingSettings.defaultFor(uid: myUid)
            }
            return Self.toSettings(snapshot, uid: myUid)
        } catch {
            throw toSharingException(error)
        }
    }

    /// Одноразовое чтение sharingSettings/{uid} произвольного пользователя (этап 7):
    /// !exists ИЛИ PERMISSION_DENIED/NOT_FOUND — НЕ ошибка, возвращается дефолт «не шарит».
    /// Порт 1:1 FirebaseBackend.getSharingSettingsByUid + isSharingAccessDenied.
    func getSettingsByUid(uid: String) async throws -> SharingSettings {
        guard isFirebaseConfigured else {
            throw SharingException(
                error: .unexpected("Firebase не сконфигурирован — чтение настроек шаринга невозможно"),
            )
        }
        _ = try requireMyUid()
        print("SharingRepositoryImpl.getSharingSettingsByUid: start")
        do {
            let snapshot = try await Firestore.firestore()
                .collection(Self.SHARING_SETTINGS_COLLECTION)
                .document(uid)
                .getDocument()
            print("SharingRepositoryImpl.getSharingSettingsByUid: done, exists=\(snapshot.exists)")
            guard snapshot.exists else {
                return SharingSettings.defaultFor(uid: uid)
            }
            return Self.toSettings(snapshot, uid: uid)
        } catch {
            if Self.isSharingAccessDenied(error) {
                print("SharingRepositoryImpl.getSharingSettingsByUid: access denied — трактую как «не шарит»")
                return SharingSettings.defaultFor(uid: uid)
            }
            throw toSharingException(error)
        }
    }

    /// Полный снимок настроек: merge всех пяти полей
    /// {isEnabled, audience, allowedUids, allowedGroupIds, updatedAt = serverTimestamp}.
    /// Merge безопасен: правило владельческое и не использует resource/affectedKeys().
    /// Порт 1:1 FirebaseBackend.saveSharingSettings.
    func saveSettings(_ settings: SharingSettings) async throws {
        guard isFirebaseConfigured else {
            throw SharingException(
                error: .unexpected("Firebase не сконфигурирован — запись настроек шаринга невозможна"),
            )
        }
        let myUid = try requireMyUid()
        print("SharingRepositoryImpl.saveSharingSettings: start")
        do {
            try await Firestore.firestore()
                .collection(Self.SHARING_SETTINGS_COLLECTION)
                .document(myUid)
                .setData([
                    Self.FIELD_IS_ENABLED: settings.isEnabled,
                    Self.FIELD_AUDIENCE: Self.toAudienceString(settings.audience),
                    Self.FIELD_ALLOWED_UIDS: settings.allowedUids,
                    Self.FIELD_ALLOWED_GROUP_IDS: settings.allowedGroupIds,
                    Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                ], merge: true)
            print("SharingRepositoryImpl.saveSharingSettings: done")
        } catch {
            throw toSharingException(error)
        }
    }

    /// Точка геолокации владельца merge-set'ом locations/{uid}:
    /// {geo = GeoPoint(lat, lng), accuracy, updatedAt = serverTimestamp}. Состав полей
    /// не валидируем — консистентно с sharingSettings; получателей вычисляет читатель (этап 7).
    /// Порт 1:1 FirebaseBackend.saveMyLocation.
    func updateLocation(_ location: SharedLocation) async throws {
        guard isFirebaseConfigured else {
            throw SharingException(
                error: .unexpected("Firebase не сконфигурирован — запись геолокации невозможна"),
            )
        }
        let myUid = try requireMyUid()
        print("SharingRepositoryImpl.saveMyLocation: start")
        do {
            // TODO: проверить на CI — первое использование GeoPoint в проекте (FirebaseFirestore).
            try await Firestore.firestore()
                .collection(Self.LOCATIONS_COLLECTION)
                .document(myUid)
                .setData([
                    Self.FIELD_GEO: GeoPoint(latitude: location.latitude, longitude: location.longitude),
                    Self.FIELD_ACCURACY: location.accuracyMeters,
                    Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                ], merge: true)
            print("SharingRepositoryImpl.saveMyLocation: done")
        } catch {
            throw toSharingException(error)
        }
    }

    /// Частичная запись merge {isEnabled, updatedAt}: движок и уведомление не перезаписывают
    /// audience/allowedUids параллельным снимком автосейва с экрана настроек.
    /// Порт 1:1 FirebaseBackend.setSharingEnabled.
    func saveEnabled(_ isEnabled: Bool) async throws {
        guard isFirebaseConfigured else {
            throw SharingException(
                error: .unexpected("Firebase не сконфигурирован — запись настроек шаринга невозможна"),
            )
        }
        let myUid = try requireMyUid()
        print("SharingRepositoryImpl.setSharingEnabled: start")
        do {
            try await Firestore.firestore()
                .collection(Self.SHARING_SETTINGS_COLLECTION)
                .document(myUid)
                .setData([
                    Self.FIELD_IS_ENABLED: isEnabled,
                    Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                ], merge: true)
            print("SharingRepositoryImpl.setSharingEnabled: done")
        } catch {
            throw toSharingException(error)
        }
    }

    /// Realtime-слушатель флага isEnabled; отсутствующий документ — false (до первого
    /// сохранения шаринг считается выключенным), ошибка слушателя завершает поток.
    /// Порт 1:1 FirebaseBackend.listenSharingSettings + Android callbackFlow/awaitClose.
    func observeIsEnabled() -> AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            guard AuthRepositoryImpl.isFirebaseConfigured, let myUid = Auth.auth().currentUser?.uid else {
                print("SharingRepositoryImpl.listenSharingSettings: нет Firebase или пользователя")
                continuation.finish()
                return
            }
            print("SharingRepositoryImpl.listenSharingSettings: start")
            let listener = Firestore.firestore()
                .collection(Self.SHARING_SETTINGS_COLLECTION)
                .document(myUid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("SharingRepositoryImpl.listenSharingSettings: error — \(error)")
                        continuation.finish()
                        return
                    }
                    let isEnabled = snapshot?.exists == true
                        && (snapshot?.data()?[Self.FIELD_IS_ENABLED] as? Bool) == true
                    continuation.yield(isEnabled)
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// Realtime-настройки шаринга произвольного пользователя: по-документный слушатель
    /// sharingSettings/{uid} (этап 7, карта видимости). Deny (не-друг)/NOT_FOUND/!exists —
    /// НЕ ошибка, доставляется дефолт «не шарит»; ошибка слушателя завершает поток.
    /// Порт 1:1 FirebaseBackend.listenSharingSettingsByUid + isSharingAccessDenied
    /// (паттерн observeIsEnabled: onTermination → listener.remove()).
    func observeSettingsByUid(uid: String) -> AsyncStream<SharingSettings> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            guard AuthRepositoryImpl.isFirebaseConfigured, Auth.auth().currentUser != nil else {
                print("SharingRepositoryImpl.listenSharingSettingsByUid: нет Firebase или пользователя")
                continuation.finish()
                return
            }
            print("SharingRepositoryImpl.listenSharingSettingsByUid: start")
            let listener = Firestore.firestore()
                .collection(Self.SHARING_SETTINGS_COLLECTION)
                .document(uid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("SharingRepositoryImpl.listenSharingSettingsByUid: error — \(error)")
                        if Self.isSharingAccessDenied(error) {
                            // Deny — не ошибка: чужой документ трактуется как «не шарит».
                            continuation.yield(SharingSettings.defaultFor(uid: uid))
                            return
                        }
                        // Слушатель после ошибки терминально мёртв — завершаем поток;
                        // перезапуск возможен по повторной подписке (ScreenShown).
                        continuation.finish()
                        return
                    }
                    guard let snapshot, snapshot.exists else {
                        continuation.yield(SharingSettings.defaultFor(uid: uid))
                        return
                    }
                    continuation.yield(Self.toSettings(snapshot, uid: uid))
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    // ------------------------------------------------------------------
    // Маппинг документов и ошибок (порт FirebaseBackend).
    // ------------------------------------------------------------------

    /// DocumentSnapshot → SharingSettings (порт FirebaseBackend, общий для get/getByUid).
    private static func toSettings(_ snapshot: DocumentSnapshot, uid: String) -> SharingSettings {
        let data: [String: Any] = snapshot.data() ?? [:]
        let updatedAt = (data[Self.FIELD_UPDATED_AT] as? Timestamp).map(Self.millisecondsSince1970) ?? 0
        return SharingSettings(
            uid: uid,
            isEnabled: (data[Self.FIELD_IS_ENABLED] as? Bool) == true,
            audience: Self.toSharingAudience(data[Self.FIELD_AUDIENCE] as? String),
            allowedUids: Self.toStringList(data[Self.FIELD_ALLOWED_UIDS]),
            allowedGroupIds: Self.toStringList(data[Self.FIELD_ALLOWED_GROUP_IDS]),
            updatedAt: updatedAt,
        )
    }

    /// Строка документа → SharingAudience: неизвестное значение трактуется как allFriends
    /// с warning-логом (порт FirebaseBackend.toSharingAudience).
    private static func toSharingAudience(_ raw: String?) -> SharingAudience {
        if raw == Self.AUDIENCE_CUSTOM {
            return .custom
        }
        if let raw, raw != Self.AUDIENCE_ALL_FRIENDS {
            print("SharingRepositoryImpl.toSharingAudience: неизвестная аудитория \(raw) — трактую как ALL_FRIENDS")
        }
        return .allFriends
    }

    /// Обратный маппинг аудитории для снимка записи (имя enum-кейса Android).
    private static func toAudienceString(_ audience: SharingAudience) -> String {
        switch audience {
        case .allFriends:
            return Self.AUDIENCE_ALL_FRIENDS
        case .custom:
            return Self.AUDIENCE_CUSTOM
        }
    }

    /// PERMISSION_DENIED/NOT_FOUND для getSharingSettingsByUid: NOT_FOUND — несуществующий
    /// документ, PERMISSION_DENIED — не-друг; оба означают «настроек нет для читателя».
    /// Порт FirebaseBackend.isSharingAccessDenied; false — ошибка не из этого класса.
    private static func isSharingAccessDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode(rawValue: nsError.code) else {
            return false
        }
        // TODO: проверить на CI — сравнение enum-кейсов FirestoreErrorCode (.permissionDenied/.notFound).
        return code == .permissionDenied || code == .notFound
    }

    /// SharingException проходит как есть, сеть Firestore — networkUnavailable,
    /// остальное — unexpected с «код: сообщение»
    /// (порт FirebaseBackend.toSharingException + describeCause, паттерн toGroupsException).
    private func toSharingException(_ error: Error) -> SharingException {
        if let exception = error as? SharingException {
            return exception
        }
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded:
                return SharingException(error: .networkUnavailable)
            default:
                return SharingException(error: .unexpected("\(code): \(nsError.localizedDescription)"))
            }
        }
        return SharingException(error: .unexpected(nsError.localizedDescription))
    }

    /// Текущий пользователь обязателен во всех операциях шаринга
    /// (порт FirebaseBackend.noCurrentUserForSharing).
    private func requireMyUid() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SharingException(error: .unexpected("Нет текущего пользователя Firebase в операциях шаринга"))
        }
        return uid
    }

    /// Timestamp Firestore → millis (порт Android getSeconds*1000 + getNanoseconds/1e6).
    private static func millisecondsSince1970(_ timestamp: Timestamp) -> Int64 {
        // TODO: проверить на CI — приведение поля Firestore к Timestamp (seconds/nanoseconds).
        timestamp.seconds * 1000 + Int64(timestamp.nanoseconds) / 1_000_000
    }

    /// Приводит значение поля списка к списку строк; не-строковые элементы пропускаются.
    private static func toStringList(_ raw: Any?) -> [String] {
        guard let list = raw as? [Any] else {
            return []
        }
        return list.compactMap { $0 as? String }
    }
}
