import FirebaseAuth
import FirebaseFirestore

/**
 Реализация карты поверх Firestore (порт 1:1 из Android MapRepositoryImpl.kt; Android-обёртка
 FirebaseBackend не портируется — listenLocationsByUids/listenLocationByUid перенесены сюда).
 Приложение переживает отсутствие GoogleService-Info.plist: все методы проверяют
 isFirebaseConfigured и не крашатся.

 Realtime-слушатели Firestore проброшены наружу через AsyncStream: данные уходят в поток
 через yield, ошибка слушателя завершает поток — перезапуск возможен по повторной подписке
 (например, по ScreenShown). Колбэки Firestore приходят в свой поток — их обработка
 (состояние чанков, регистрация fallback-слушателей) конфинится в MainActor-задачи,
 чтобы состояние чанков не raced.
 */
final class MapRepositoryImpl: MapRepository {
    /// Firebase сконфигурирован (GoogleService-Info.plist в бандле и configure() вызван).
    private var isFirebaseConfigured: Bool {
        AuthRepositoryImpl.isFirebaseConfigured
    }

    /// Имена коллекций/полей — те же, что в Android FirebaseBackend:
    /// кроссплатформенная дружба требует точного совпадения схемы Firestore.
    private static let LOCATIONS_COLLECTION = "locations"
    private static let FIELD_GEO = "geo"
    private static let FIELD_ACCURACY = "accuracy"
    private static let FIELD_UPDATED_AT = "updatedAt"

    /// Лимит Firestore на whereIn по documentId (MAX_WHERE_IN_UIDS).
    private static let MAX_WHERE_IN_UIDS = 10

    func observeLocationsByUids(uids: [String]) -> AsyncStream<[String: FriendLocation]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            guard isFirebaseConfigured, Auth.auth().currentUser != nil else {
                print("MapRepositoryImpl.listenLocationsByUids: нет Firebase или пользователя")
                continuation.finish()
                return
            }
            if uids.isEmpty {
                // whereIn с пустым списком Firestore запрещает — пустой список видимых друзей
                // означает пустой результат без слушателей (снимать нечего).
                continuation.yield([:])
                return
            }
            print("MapRepositoryImpl.listenLocationsByUids: start, size=\(uids.count)")
            // Хранилище чанков и регистраций: мутируется только на MainActor
            // (set up-задача и onTermination — из произвольного потока). Cancel до старта
            // set up-задачи не оставит слушателей: тело guard'ится по Task.isCancelled,
            // после старта выполняется без точек остановки — снятие via onTermination
            // сериализуется с ним на MainActor.
            let storage = ListenerStorage()
            let setupTask = Task { @MainActor in
                guard !Task.isCancelled else { return }
                Self.attachListeners(
                    uids: uids,
                    storage: storage,
                    continuation: continuation,
                )
            }
            continuation.onTermination = { _ in
                Task { @MainActor in
                    storage.registrations.forEach { $0.remove() }
                    storage.registrations.removeAll()
                }
                setupTask.cancel()
            }
        }
    }

    // ------------------------------------------------------------------
    // Слушатели чанков и fallback (порт observeLocationsByUids Android).
    // ------------------------------------------------------------------

    /// Регистрации слушателей и чанки: экземпляр на одну подписку observeLocationsByUids.
    private final class ListenerStorage {
        var registrations: [ListenerRegistration] = []
        var chunks: [LocationsChunk] = []
    }

    /**
     Навешивает whereIn-чанки (по MAX_WHERE_IN_UIDS) с fallback'ом на по-документные
     слушатели при PERMISSION_DENIED. Выполняется на MainActor.
     */
    private static func attachListeners(
        uids: [String],
        storage: ListenerStorage,
        continuation: AsyncStream<[String: FriendLocation]>.Continuation,
    ) {
        /** Объединённый слепок всех чанков — единственное, что уходит наружу. */
        func mergedLocations() -> [String: FriendLocation] {
            var merged: [String: FriendLocation] = [:]
            for chunk in storage.chunks {
                merged.merge(chunk.currentLocations) { _, new in new }
            }
            return merged
        }

        /**
         Fallback (rules are not filters): whereIn-чанк с get()-правилом друга не provable
         и отклоняется целиком (PERMISSION_DENIED). По-документные слушатели оцениваются
         правилами по конкретному документу и работают под тем же правилом — видимость
         по-прежнему гейтит Firestore.
         */
        func observeChunkDocuments(_ chunk: LocationsChunk) {
            for uid in chunk.uids {
                // TODO: проверить на CI — по-документный addSnapshotListener locations/{uid}.
                let registration = Firestore.firestore()
                    .collection(LOCATIONS_COLLECTION)
                    .document(uid)
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            // Слушатель после ошибки терминально мёртв — закрываем поток.
                            print("MapRepositoryImpl.listenLocationByUid: error — \(error)")
                            continuation.finish()
                            return
                        }
                        let locations = Self.parseLocations(snapshot)
                        Task { @MainActor in
                            chunk.apply(locations)
                        }
                    }
                storage.registrations.append(registration)
            }
        }

        var index = uids.startIndex
        while index < uids.endIndex {
            let end = uids.index(
                index,
                offsetBy: MAX_WHERE_IN_UIDS,
                limitedBy: uids.endIndex,
            ) ?? uids.endIndex
            let chunkUids = Array(uids[index..<end])
            index = end

            let chunk = LocationsChunk(uids: chunkUids) {
                continuation.yield(mergedLocations())
            }
            storage.chunks.append(chunk)
            // TODO: проверить на CI — whereField(FieldPath.documentID(), in:) + addSnapshotListener.
            let registration = Firestore.firestore()
                .collection(LOCATIONS_COLLECTION)
                .whereField(FieldPath.documentID(), in: chunkUids)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        let nsError = error as NSError
                        // TODO: проверить на CI — PERMISSION_DENIED из NSError слушателя.
                        let isDenied = nsError.domain == FirestoreErrorDomain
                            && FirestoreErrorCode(rawValue: nsError.code) == .permissionDenied
                        if isDenied {
                            // Слушатель после ошибки терминально мёртв — просто уходим
                            // на fallback; регистрация снимется в onTermination.
                            Task { @MainActor in
                                observeChunkDocuments(chunk)
                            }
                        } else {
                            print("MapRepositoryImpl.listenLocationsByUids: error — \(error)")
                            continuation.finish()
                        }
                        return
                    }
                    let locations = Self.parseQueryLocations(snapshot)
                    Task { @MainActor in
                        chunk.apply(locations)
                    }
                }
            storage.registrations.append(registration)
        }
    }

    // ------------------------------------------------------------------
    // Маппинг документов (порт FirebaseBackend.toFriendLocation).
    // ------------------------------------------------------------------

    /// QuerySnapshot whereIn-чанка → карта [uid: FriendLocation].
    private static func parseQueryLocations(_ snapshot: QuerySnapshot?) -> [String: FriendLocation] {
        var locations: [String: FriendLocation] = [:]
        guard let snapshot else {
            return locations
        }
        for document in snapshot.documents {
            guard let location = toFriendLocation(document) else { continue }
            locations[location.uid] = location
        }
        return locations
    }

    /// DocumentSnapshot locations/{uid} → карта с нулем или одной точкой
    /// (отсутствующий документ — пустая карта, не ошибка).
    private static func parseLocations(_ snapshot: DocumentSnapshot?) -> [String: FriendLocation] {
        guard let snapshot, snapshot.exists, let location = toFriendLocation(snapshot) else {
            return [:]
        }
        return [location.uid: location]
    }

    /// DocumentSnapshot → FriendLocation; nil, если geo отсутствует.
    private static func toFriendLocation(_ snapshot: DocumentSnapshot) -> FriendLocation? {
        guard let data = snapshot.data(), let geo = data[FIELD_GEO] as? GeoPoint else {
            print("MapRepositoryImpl.toFriendLocation: в документе \(snapshot.documentID) нет geo")
            return nil
        }
        let accuracy = data[FIELD_ACCURACY] as? Double ?? 0.0
        let updatedAt = (data[FIELD_UPDATED_AT] as? Timestamp).map(Self.millisecondsSince1970) ?? 0
        return FriendLocation(
            uid: snapshot.documentID,
            latitude: geo.latitude,
            longitude: geo.longitude,
            accuracyMeters: accuracy,
            updatedAtMillis: updatedAt,
        )
    }

    /// Timestamp Firestore → millis (порт Android getSeconds*1000 + getNanoseconds/1e6).
    private static func millisecondsSince1970(_ timestamp: Timestamp) -> Int64 {
        // TODO: проверить на CI — приведение поля Firestore к Timestamp (seconds/nanoseconds).
        timestamp.seconds * 1000 + Int64(timestamp.nanoseconds) / 1_000_000
    }

    /**
     Чанк whereIn-запроса: копит свою часть объединённой карты локаций и уведомляет
     об обновлении, чтобы наружу уходил полный слепок. Порт 1:1 Android LocationsChunk.
     Мутируется только на MainActor (см. observeLocationsByUids).
     */
    private final class LocationsChunk {
        let uids: [String]
        private let onUpdated: () -> Void
        private var locations: [String: FriendLocation] = [:]

        var currentLocations: [String: FriendLocation] {
            locations
        }

        init(uids: [String], onUpdated: @escaping () -> Void) {
            self.uids = uids
            self.onUpdated = onUpdated
        }

        /** Заменяет свою часть свежим снапшотом и переэмитирует объединённую карту. */
        func apply(_ locations: [String: FriendLocation]) {
            for uid in uids {
                self.locations.removeValue(forKey: uid)
            }
            self.locations.merge(locations) { _, new in new }
            onUpdated()
        }
    }
}
