import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

/// Реализация друзей поверх Firestore напрямую: Android-обёртка FirebaseBackend не
/// портируется (Java-класс специфики билда Android), friends-методы FirebaseBackend
/// перенесены сюда. Порт 1:1 FriendsRepositoryImpl.kt + FirebaseBackend (findUsersByPhone/
/// getUsersByUids/getMyFriendUids/getFriendRequest/sendFriendRequest/acceptFriendRequest/
/// declineFriendRequest/deleteFriendRequest/removeFriend/listenIncomingFriendRequests/
/// listenMyFriendUids). Приложение переживает отсутствие GoogleService-Info.plist:
/// все методы проверяют isFirebaseConfigured и не крашатся.
///
/// Realtime-слушатели обёрнуты в AsyncStream на границе data-слоя: данные уходят в поток
/// через yield, ошибка слушателя завершает поток — перезапуск возможен по повторной
/// подписке (например, по ScreenShown). Конец потока без отмены подписки ViewModel
/// трактует как обрыв и показывает inline-ошибку секции.
final class FriendsRepositoryImpl: FriendsRepository {
    /// Firebase сконфигурирован (GoogleService-Info.plist в бандле и configure() вызван).
    private var isFirebaseConfigured: Bool {
        AuthRepositoryImpl.isFirebaseConfigured
    }

    /// Имена коллекций/полей — те же, что в Android FirebaseBackend:
    /// кроссплатформенная дружба требует точного совпадения схемы Firestore.
    private static let USERS_COLLECTION = "users"
    private static let FRIEND_REQUESTS_COLLECTION = "friendRequests"
    private static let FIELD_EMAIL = "email"
    private static let FIELD_DISPLAY_NAME = "displayName"
    private static let FIELD_PHONE = "phone"
    private static let FIELD_AVATAR_VERSION = "avatarVersion"
    private static let FIELD_HAS_COMPLETED_ONBOARDING = "hasCompletedOnboarding"
    private static let FIELD_FRIEND_UIDS = "friendUids"
    private static let FIELD_FROM_UID = "fromUid"
    private static let FIELD_TO_UID = "toUid"
    private static let FIELD_FROM_NAME = "fromName"
    private static let FIELD_FROM_AVATAR_VERSION = "fromAvatarVersion"
    private static let FIELD_STATUS = "status"
    private static let FIELD_CREATED_AT = "createdAt"
    private static let FIELD_UPDATED_AT = "updatedAt"
    private static let STATUS_PENDING = "PENDING"
    private static let STATUS_ACCEPTED = "ACCEPTED"

    /// Разделитель id документа заявки: "fromUid_toUid".
    private static let REQUEST_ID_SEPARATOR = "_"

    /// Лимит Firestore на whereIn по documentId.
    private static let MAX_WHERE_IN_UIDS = 10

    func findUsersByPhone(phone: String) async throws -> [User] {
        guard isFirebaseConfigured else {
            throw FriendsException(error: .unexpected("Firebase не сконфигурирован — поиск друзей невозможен"))
        }
        print("FriendsRepositoryImpl.findUsersByPhone: start")
        do {
            let snapshot = try await Firestore.firestore()
                .collection(Self.USERS_COLLECTION)
                .whereField(Self.FIELD_PHONE, isEqualTo: phone)
                .getDocuments()
            let users = snapshot.documents.map(Self.toUser)
            print("FriendsRepositoryImpl.findUsersByPhone: done, size=\(users.count)")
            return users
        } catch {
            throw toFriendsException(error)
        }
    }

    /// Профили пользователей по uid запросами whereIn по FieldPath.documentID, чанками по 10.
    func getUsersByUids(uids: [String]) async throws -> [User] {
        guard !uids.isEmpty else {
            return []
        }
        guard isFirebaseConfigured else {
            throw FriendsException(error: .unexpected("Firebase не сконфигурирован — чтение пользователей невозможно"))
        }
        print("FriendsRepositoryImpl.getUsersByUids: start, size=\(uids.count)")
        do {
            var users: [User] = []
            // whereIn Firestore принимает максимум 10 идентификаторов на запрос.
            var index = 0
            while index < uids.count {
                let chunkEnd = min(index + Self.MAX_WHERE_IN_UIDS, uids.count)
                let chunk = Array(uids[index..<chunkEnd])
                // TODO: проверить на CI — whereField(FieldPath.documentID(), in:) в firebase-ios-sdk.
                let snapshot = try await Firestore.firestore()
                    .collection(Self.USERS_COLLECTION)
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                users.append(contentsOf: snapshot.documents.map(Self.toUser))
                index = chunkEnd
            }
            print("FriendsRepositoryImpl.getUsersByUids: done, size=\(users.count)")
            return users
        } catch {
            throw toFriendsException(error)
        }
    }

    /// Отправляет PENDING-заявку пользователю `toUid`. Препроверки — по свежим данным Firestore,
    /// не по кэшам UI: уже друзья → AlreadyFriends; висящая PENDING-заявка (своя или встречная)
    /// → RequestAlreadySent/RequestAlreadyIncoming.
    /// Существующий ACCEPTED-документ пары — история последней заявки, барьером НЕ является:
    /// перед create stale-документы пары удаляются, затем заявка создаётся чистым create
    /// (setData без merge на существующий документ оценивается правилами как update и был бы
    /// запрещён). Последовательность delete→create не атомарна: разрыв между операциями
    /// оставляет «нет документа» — повторная попытка чисто создаёт его заново. Приемлемо.
    /// История пары не сохраняется: документ заявки отражает только последнюю заявку
    /// (осознанная цена). Порт 1:1 KDoc FriendsRepositoryImpl.sendFriendRequest.
    func sendFriendRequest(toUid: String) async throws {
        guard isFirebaseConfigured else {
            throw FriendsException(error: .unexpected("Firebase не сконфигурирован — отправка заявки невозможна"))
        }
        let myUid = try requireMyUid()
        print("FriendsRepositoryImpl.sendFriendRequest: start")
        do {
            if try await getMyFriendUids().contains(toUid) {
                throw FriendsException(error: .alreadyFriends)
            }
            let outgoing = try await getFriendRequest(fromUid: myUid, toUid: toUid)
            if let outgoing, outgoing.status == .pending {
                throw FriendsException(error: .requestAlreadySent)
            }
            let incoming = try await getFriendRequest(fromUid: toUid, toUid: myUid)
            if let incoming, incoming.status == .pending {
                throw FriendsException(error: .requestAlreadyIncoming)
            }
            // Stale ACCEPTED-документы удаляем, иначе create по тому же id стал бы update.
            if outgoing != nil {
                try await deleteFriendRequest(fromUid: myUid, toUid: toUid)
            }
            if incoming != nil {
                try await deleteFriendRequest(fromUid: toUid, toUid: myUid)
            }
            try await createPendingRequest(toUid: toUid, myUid: myUid)
            print("FriendsRepositoryImpl.sendFriendRequest: done")
        } catch {
            throw toFriendsException(error)
        }
    }

    /// Принимает заявку: транзакция ставит статус ACCEPTED и updatedAt в документе заявки
    /// и добавляет участников в friendUids ОБОИХ users-документов.
    /// Повторное принятие обработанной или удалённой заявки — идемпотентный успех.
    func acceptFriendRequest(request: FriendRequest) async throws {
        guard isFirebaseConfigured else {
            throw FriendsException(error: .unexpected("Firebase не сконфигурирован — принятие заявки невозможно"))
        }
        let myUid = try requireMyUid()
        print("FriendsRepositoryImpl.acceptFriendRequest: start")
        let firestore = Firestore.firestore()
        let requestDocument = firestore
            .collection(Self.FRIEND_REQUESTS_COLLECTION)
            .document(Self.requestId(request.fromUid, myUid))
        do {
            _ = try await firestore.runTransaction { (transaction, errorPointer) -> Any? in
                // TODO: проверить на CI — transaction.getDocument и setData(_:forDocument:merge:)
                // с FieldValue.arrayUnion внутри транзакции (паттерн ProfileRepositoryImpl).
                let requestSnapshot = try transaction.getDocument(requestDocument)
                let status = requestSnapshot.data()?[Self.FIELD_STATUS] as? String
                guard requestSnapshot.exists, status == Self.STATUS_PENDING else {
                    // Заявку уже обработали или удалили — считаем приём успешным (идемпотентность).
                    print("FriendsRepositoryImpl.acceptFriendRequest: request already handled")
                    return false
                }
                transaction.setData(
                    [
                        Self.FIELD_STATUS: Self.STATUS_ACCEPTED,
                        Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                    ],
                    forDocument: requestDocument,
                    merge: true,
                )
                Self.unionFriendUid(
                    transaction: transaction,
                    userDocument: firestore.collection(Self.USERS_COLLECTION).document(myUid),
                    friendUid: request.fromUid,
                )
                Self.unionFriendUid(
                    transaction: transaction,
                    userDocument: firestore.collection(Self.USERS_COLLECTION).document(request.fromUid),
                    friendUid: myUid,
                )
                return true
            }
            print("FriendsRepositoryImpl.acceptFriendRequest: done")
        } catch {
            throw toFriendsException(error)
        }
    }

    /// Отклоняет заявку: удаляет документ friendRequests/{fromUid_toUid}
    /// (статус DECLINED не персистится).
    func declineFriendRequest(request: FriendRequest) async throws {
        guard isFirebaseConfigured else {
            throw FriendsException(error: .unexpected("Firebase не сконфигурирован — отклонение заявки невозможно"))
        }
        let myUid = try requireMyUid()
        print("FriendsRepositoryImpl.declineFriendRequest: start")
        do {
            try await Firestore.firestore()
                .collection(Self.FRIEND_REQUESTS_COLLECTION)
                .document(Self.requestId(request.fromUid, myUid))
                .delete()
            print("FriendsRepositoryImpl.declineFriendRequest: done")
        } catch {
            throw toFriendsException(error)
        }
    }

    /// Удаляет друга: транзакция убирает участников друг у друга из friendUids (arrayRemove)
    /// в обоих users-документах и «гигиенически» удаляет stale-документы заявки пары
    /// (документ заявки отражает только последнюю заявку — см. KDoc sendFriendRequest).
    /// Delete строго guarded (exists-проверка): для несуществующего документа resource == null
    /// и resource-based delete-правило deny'ит всю транзакцию; чтения выполняются до записей.
    func removeFriend(friendUid: String) async throws {
        guard isFirebaseConfigured else {
            throw FriendsException(error: .unexpected("Firebase не сконфигурирован — удаление друга невозможно"))
        }
        let myUid = try requireMyUid()
        print("FriendsRepositoryImpl.removeFriend: start")
        let firestore = Firestore.firestore()
        let outgoingDocument = firestore
            .collection(Self.FRIEND_REQUESTS_COLLECTION)
            .document(Self.requestId(myUid, friendUid))
        let incomingDocument = firestore
            .collection(Self.FRIEND_REQUESTS_COLLECTION)
            .document(Self.requestId(friendUid, myUid))
        do {
            _ = try await firestore.runTransaction { (transaction, errorPointer) -> Any? in
                // TODO: проверить на CI — transaction.getDocument/delete и
                // FieldValue.arrayRemove внутри транзакции (паттерн ProfileRepositoryImpl).
                let outgoingPresent = try transaction.getDocument(outgoingDocument).exists
                let incomingPresent = try transaction.getDocument(incomingDocument).exists
                if outgoingPresent {
                    transaction.delete(outgoingDocument)
                }
                if incomingPresent {
                    transaction.delete(incomingDocument)
                }
                Self.removeFriendUid(
                    transaction: transaction,
                    userDocument: firestore.collection(Self.USERS_COLLECTION).document(myUid),
                    friendUid: friendUid,
                )
                Self.removeFriendUid(
                    transaction: transaction,
                    userDocument: firestore.collection(Self.USERS_COLLECTION).document(friendUid),
                    friendUid: myUid,
                )
                return true
            }
            print("FriendsRepositoryImpl.removeFriend: done")
        } catch {
            throw toFriendsException(error)
        }
    }

    /// Realtime-слушатель входящих PENDING-заявок текущего пользователя.
    /// Без orderBy: сортировка по createdAt выполняется на клиенте, поэтому
    /// композитные индексы для этого запроса не нужны.
    func observeIncomingFriendRequests() -> AsyncStream<[FriendRequest]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            guard AuthRepositoryImpl.isFirebaseConfigured, let myUid = Auth.auth().currentUser?.uid else {
                print("FriendsRepositoryImpl.listenIncomingFriendRequests: нет Firebase или пользователя")
                continuation.finish()
                return
            }
            print("FriendsRepositoryImpl.listenIncomingFriendRequests: start")
            let listener = Firestore.firestore()
                .collection(Self.FRIEND_REQUESTS_COLLECTION)
                .whereField(Self.FIELD_TO_UID, isEqualTo: myUid)
                .whereField(Self.FIELD_STATUS, isEqualTo: Self.STATUS_PENDING)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        // Ошибка слушателя завершает поток — ViewModel покажет inline-ошибку секции.
                        print("FriendsRepositoryImpl.listenIncomingFriendRequests: error — \(error)")
                        continuation.finish()
                        return
                    }
                    let requests = snapshot?.documents.compactMap(Self.toFriendRequest) ?? []
                    continuation.yield(requests)
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// Realtime-слушатель поля friendUids своего документа users
    /// (отсутствие поля — пустой список).
    func observeFriendUids() -> AsyncStream<[String]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            guard AuthRepositoryImpl.isFirebaseConfigured, let myUid = Auth.auth().currentUser?.uid else {
                print("FriendsRepositoryImpl.listenMyFriendUids: нет Firebase или пользователя")
                continuation.finish()
                return
            }
            print("FriendsRepositoryImpl.listenMyFriendUids: start")
            let listener = Firestore.firestore()
                .collection(Self.USERS_COLLECTION)
                .document(myUid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("FriendsRepositoryImpl.listenMyFriendUids: error — \(error)")
                        continuation.finish()
                        return
                    }
                    let uids = Self.toStringList(snapshot?.data()?[Self.FIELD_FRIEND_UIDS])
                    continuation.yield(uids)
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    // ------------------------------------------------------------------
    // Приватные помощники отправки заявки (порт friends-методов FirebaseBackend).
    // ------------------------------------------------------------------

    /// Список друзей текущего пользователя из поля friendUids его документа users
    /// (пустой, если поля нет).
    private func getMyFriendUids() async throws -> [String] {
        let myUid = try requireMyUid()
        print("FriendsRepositoryImpl.getMyFriendUids: start")
        let snapshot = try await Firestore.firestore()
            .collection(Self.USERS_COLLECTION)
            .document(myUid)
            .getDocument()
        let uids = Self.toStringList(snapshot.data()?[Self.FIELD_FRIEND_UIDS])
        print("FriendsRepositoryImpl.getMyFriendUids: done, size=\(uids.count)")
        return uids
    }

    /// Заявка friendRequests/{fromUid_toUid} либо nil, если документа нет.
    /// Используется для проверок «заявка уже отправлена / встречная заявка» по свежим данным.
    private func getFriendRequest(fromUid: String, toUid: String) async throws -> FriendRequest? {
        print("FriendsRepositoryImpl.getFriendRequest: start")
        let snapshot = try await Firestore.firestore()
            .collection(Self.FRIEND_REQUESTS_COLLECTION)
            .document(Self.requestId(fromUid, toUid))
            .getDocument()
        print("FriendsRepositoryImpl.getFriendRequest: done, exists=\(snapshot.exists)")
        return snapshot.exists ? Self.toFriendRequest(snapshot) : nil
    }

    /// Блокирующий delete документа friendRequests/{fromUid}_{toUid}. Вызывается только когда
    /// препроверка подтвердила существование документа: для несуществующего resource == null,
    /// resource-based delete-правило даст deny. Семантику отклонения не несёт.
    private func deleteFriendRequest(fromUid: String, toUid: String) async throws {
        print("FriendsRepositoryImpl.deleteFriendRequest: start")
        try await Firestore.firestore()
            .collection(Self.FRIEND_REQUESTS_COLLECTION)
            .document(Self.requestId(fromUid, toUid))
            .delete()
        print("FriendsRepositoryImpl.deleteFriendRequest: done")
    }

    /// Создаёт PENDING-заявку friendRequests/{fromUid_toUid} со снапшотом профиля отправителя
    /// (displayName, avatarVersion из своего документа users на момент отправки).
    /// Чистый setData (без merge): документ пары к этому моменту удалён.
    private func createPendingRequest(toUid: String, myUid: String) async throws {
        let mySnapshot = try await Firestore.firestore()
            .collection(Self.USERS_COLLECTION)
            .document(myUid)
            .getDocument()
        guard mySnapshot.exists else {
            throw FriendsException(error: .unexpected("Собственный документ users не найден при отправке заявки"))
        }
        let data = mySnapshot.data()
        let avatarVersion = (data?[Self.FIELD_AVATAR_VERSION] as? NSNumber).map { Int(truncatingIfNeeded: $0) } ?? 0
        let fromName = Self.firstNonEmpty(
            data?[Self.FIELD_DISPLAY_NAME] as? String,
            Auth.auth().currentUser?.displayName,
        ) ?? ""
        try await Firestore.firestore()
            .collection(Self.FRIEND_REQUESTS_COLLECTION)
            .document(Self.requestId(myUid, toUid))
            .setData([
                Self.FIELD_FROM_UID: myUid,
                Self.FIELD_TO_UID: toUid,
                Self.FIELD_FROM_NAME: fromName,
                Self.FIELD_FROM_AVATAR_VERSION: avatarVersion,
                Self.FIELD_STATUS: Self.STATUS_PENDING,
                Self.FIELD_CREATED_AT: FieldValue.serverTimestamp(),
                Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
            ])
    }

    /// Добавляет друга в friendUids users-документа внутри транзакции (merge, arrayUnion).
    private static func unionFriendUid(
        transaction: Transaction,
        userDocument: DocumentReference,
        friendUid: String,
    ) {
        transaction.setData(
            [
                Self.FIELD_FRIEND_UIDS: FieldValue.arrayUnion([friendUid]),
                Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
            ],
            forDocument: userDocument,
            merge: true,
        )
    }

    /// Убирает друга из friendUids users-документа внутри транзакции (merge, arrayRemove).
    private static func removeFriendUid(
        transaction: Transaction,
        userDocument: DocumentReference,
        friendUid: String,
    ) {
        transaction.setData(
            [
                Self.FIELD_FRIEND_UIDS: FieldValue.arrayRemove([friendUid]),
                Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
            ],
            forDocument: userDocument,
            merge: true,
        )
    }

    /// Id документа заявки: "fromUid_toUid".
    private static func requestId(_ fromUid: String, _ toUid: String) -> String {
        fromUid + REQUEST_ID_SEPARATOR + toUid
    }

    private func requireMyUid() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FriendsException(error: .unexpected("Нет текущего пользователя Firebase в операциях друзей"))
        }
        return uid
    }

    // ------------------------------------------------------------------
    // Маппинг документов и ошибок (порт FirebaseBackend).
    // ------------------------------------------------------------------

    /// DocumentSnapshot → User по полям документа users.
    private static func toUser(_ snapshot: DocumentSnapshot) -> User {
        let data = snapshot.data()
        let avatarVersion = (data?[Self.FIELD_AVATAR_VERSION] as? NSNumber)
            .map { Int(truncatingIfNeeded: $0) } ?? 0
        return User(
            uid: snapshot.documentID,
            email: data?[Self.FIELD_EMAIL] as? String,
            displayName: data?[Self.FIELD_DISPLAY_NAME] as? String,
            phone: data?[Self.FIELD_PHONE] as? String,
            avatarVersion: avatarVersion,
            hasCompletedOnboarding: (data?[Self.FIELD_HAS_COMPLETED_ONBOARDING] as? NSNumber)?.boolValue == true,
        )
    }

    /// DocumentSnapshot → FriendRequest; nil, если в документе нет fromUid или toUid.
    private static func toFriendRequest(_ snapshot: DocumentSnapshot) -> FriendRequest? {
        let data = snapshot.data()
        guard let fromUid = data?[Self.FIELD_FROM_UID] as? String,
            let toUid = data?[Self.FIELD_TO_UID] as? String
        else {
            print("FriendsRepositoryImpl.toFriendRequest: в документе \(snapshot.documentID) нет fromUid/toUid")
            return nil
        }
        let avatarVersion = (data?[Self.FIELD_FROM_AVATAR_VERSION] as? NSNumber)
            .map { Int(truncatingIfNeeded: $0) } ?? 0
        let createdAt = (data?[Self.FIELD_CREATED_AT] as? Timestamp).map(Self.millisecondsSince1970) ?? 0
        let status: FriendRequestStatus = (data?[Self.FIELD_STATUS] as? String) == Self.STATUS_ACCEPTED
            ? .accepted
            : .pending
        return FriendRequest(
            fromUid: fromUid,
            toUid: toUid,
            fromName: (data?[Self.FIELD_FROM_NAME] as? String) ?? "",
            fromAvatarVersion: avatarVersion,
            status: status,
            createdAt: createdAt,
        )
    }

    /// Timestamp Firestore → millis (порт Android getSeconds*1000 + getNanoseconds/1e6).
    private static func millisecondsSince1970(_ timestamp: Timestamp) -> Int64 {
        // TODO: проверить на CI — приведение поля Firestore к Timestamp (seconds/nanoseconds).
        timestamp.seconds * 1000 + Int64(timestamp.nanoseconds) / 1_000_000
    }

    /// Приводит значение поля friendUids к списку строк; не-строковые элементы пропускаются.
    private static func toStringList(_ raw: Any?) -> [String] {
        guard let list = raw as? [Any] else {
            return []
        }
        return list.compactMap { $0 as? String }
    }

    /// Первый непустой аргумент (порт FirebaseBackend.firstNonEmpty).
    private static func firstNonEmpty(_ primary: String?, _ fallback: String?) -> String? {
        if let primary, !primary.isEmpty {
            return primary
        }
        return fallback
    }

    /// FriendsException проходит как есть, сеть Firestore — networkUnavailable,
    /// остальное — unexpected с «код: сообщение»
    /// (порт FirebaseBackend.toFriendsException + describeCause).
    private func toFriendsException(_ error: Error) -> FriendsException {
        if let exception = error as? FriendsException {
            return exception
        }
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded:
                return FriendsException(error: .networkUnavailable)
            default:
                return FriendsException(error: .unexpected("\(code): \(nsError.localizedDescription)"))
            }
        }
        return FriendsException(error: .unexpected(nsError.localizedDescription))
    }
}
