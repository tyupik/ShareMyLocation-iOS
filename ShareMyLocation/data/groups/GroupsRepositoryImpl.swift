import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

/// Реализация групп поверх Firestore напрямую: Android-обёртка FirebaseBackend
/// не портируется, groups-методы listenMyGroups/getGroup/createGroup/updateGroup/
/// deleteGroup перенесены сюда. Порт 1:1 из Android GroupsRepositoryImpl.kt +
/// FirebaseBackend (groups-методы, toGroup, toGroupsException, isGroupAccessDenied).
/// Приложение переживает отсутствие GoogleService-Info.plist:
/// все методы проверяют isFirebaseConfigured и не крашатся.
///
/// Realtime-слушатель обёрнут в AsyncStream на границе data-слоя: данные уходят в поток
/// через yield, ошибка слушателя завершает поток — перезапуск возможен по повторной
/// подписке (например, по ScreenShown).
final class GroupsRepositoryImpl: GroupsRepository {
    /// Firebase сконфигурирован (GoogleService-Info.plist в бандле и configure() вызван).
    private var isFirebaseConfigured: Bool {
        AuthRepositoryImpl.isFirebaseConfigured
    }

    /// Имена коллекции/полей — те же, что в Android FirebaseBackend:
    /// кроссплатформенная дружба требует точного совпадения схемы Firestore.
    private static let GROUPS_COLLECTION = "groups"
    private static let FIELD_OWNER_ID = "ownerId"
    private static let FIELD_NAME = "name"
    private static let FIELD_MEMBER_UIDS = "memberUids"
    private static let FIELD_CREATED_AT = "createdAt"
    private static let FIELD_UPDATED_AT = "updatedAt"

    func observeMyGroups() -> AsyncStream<[Group]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            guard AuthRepositoryImpl.isFirebaseConfigured, let myUid = Auth.auth().currentUser?.uid else {
                print("GroupsRepositoryImpl.listenMyGroups: нет Firebase или пользователя")
                continuation.finish()
                return
            }
            print("GroupsRepositoryImpl.listenMyGroups: start")
            let listener = Firestore.firestore()
                .collection(Self.GROUPS_COLLECTION)
                .whereField(Self.FIELD_OWNER_ID, isEqualTo: myUid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        // Ошибка слушателя завершает поток — ViewModel покажет inline-ошибку секции.
                        print("GroupsRepositoryImpl.listenMyGroups: error — \(error)")
                        continuation.finish()
                        return
                    }
                    let groups = snapshot?.documents.map(Self.toGroup) ?? []
                    continuation.yield(groups)
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// Одноразовое чтение группы по id: PERMISSION_DENIED и NOT_FOUND мапятся в .groupNotFound
    /// ДО общей классификации — правило groups читает resource.data, поэтому get несуществующего
    /// документа даёт PERMISSION_DENIED (NOT_FOUND возможен из локального кэша отсутствия) —
    /// для клиента это одно состояние; create/update/delete сохраняют общую классификацию
    /// (unexpected с кодом). Ветка !exists — защита на случай снимка без deny
    /// (например, после смягчения правил). Порт 1:1 FirebaseBackend.getGroup.
    func getGroup(groupId: String) async throws -> Group {
        guard isFirebaseConfigured else {
            throw GroupsException(error: .unexpected("Firebase не сконфигурирован — чтение группы невозможно"))
        }
        try requireMyUid()
        print("GroupsRepositoryImpl.getGroup: start")
        do {
            let snapshot = try await Firestore.firestore()
                .collection(Self.GROUPS_COLLECTION)
                .document(groupId)
                .getDocument()
            print("GroupsRepositoryImpl.getGroup: done, exists=\(snapshot.exists)")
            guard snapshot.exists else {
                throw GroupsException(error: .groupNotFound)
            }
            return Self.toGroup(snapshot)
        } catch {
            if let nsError = Self.groupAccessDeniedCode(error) {
                print("GroupsRepositoryImpl.getGroup: access denied — \(nsError)")
                throw GroupsException(error: .groupNotFound)
            }
            throw toGroupsException(error)
        }
    }

    /// Создаёт groups/{autoId} с ownerId текущего пользователя, именем и составом memberUids
    /// (валидацию состава выполняют create-правила: memberUids ⊆ friendUids владельца, ≤ 100);
    /// createdAt/updatedAt — serverTimestamp. Авто-id генерируется офлайн, поэтому groupId
    /// известен сразу после успешного set. Порт 1:1 FirebaseBackend.createGroup.
    func createGroup(name: String, memberUids: [String]) async throws -> String {
        guard isFirebaseConfigured else {
            throw GroupsException(error: .unexpected("Firebase не сконфигурирован — создание группы невозможно"))
        }
        let myUid = try requireMyUid()
        print("GroupsRepositoryImpl.createGroup: start")
        do {
            let document = Firestore.firestore()
                .collection(Self.GROUPS_COLLECTION)
                .document()
            try await document.setData([
                Self.FIELD_OWNER_ID: myUid,
                Self.FIELD_NAME: name,
                Self.FIELD_MEMBER_UIDS: memberUids,
                Self.FIELD_CREATED_AT: FieldValue.serverTimestamp(),
                Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
            ])
            print("GroupsRepositoryImpl.createGroup: done, id=\(document.documentID)")
            return document.documentID
        } catch {
            throw toGroupsException(error)
        }
    }

    /// Обновляет группу merge'ем только {name, memberUids, updatedAt}: ownerId и createdAt
    /// не трогаются, поэтому правило update (affectedKeys().hasOnly) пропускает запись.
    /// Порт 1:1 FirebaseBackend.updateGroup.
    func updateGroup(groupId: String, name: String, memberUids: [String]) async throws {
        guard isFirebaseConfigured else {
            throw GroupsException(error: .unexpected("Firebase не сконфигурирован — обновление группы невозможно"))
        }
        try requireMyUid()
        print("GroupsRepositoryImpl.updateGroup: start")
        do {
            try await Firestore.firestore()
                .collection(Self.GROUPS_COLLECTION)
                .document(groupId)
                .setData([
                    Self.FIELD_NAME: name,
                    Self.FIELD_MEMBER_UIDS: memberUids,
                    Self.FIELD_UPDATED_AT: FieldValue.serverTimestamp(),
                ], merge: true)
            print("GroupsRepositoryImpl.updateGroup: done")
        } catch {
            throw toGroupsException(error)
        }
    }

    /// Блокирующий delete документа groups/{groupId}. Id приходит только из realtime-списка
    /// (документ существует): для несуществующего resource == null, resource-based
    /// delete-правило даст deny — как declineFriendRequest. Порт 1:1 FirebaseBackend.deleteGroup.
    func deleteGroup(groupId: String) async throws {
        guard isFirebaseConfigured else {
            throw GroupsException(error: .unexpected("Firebase не сконфигурирован — удаление группы невозможно"))
        }
        try requireMyUid()
        print("GroupsRepositoryImpl.deleteGroup: start")
        do {
            try await Firestore.firestore()
                .collection(Self.GROUPS_COLLECTION)
                .document(groupId)
                .delete()
            print("GroupsRepositoryImpl.deleteGroup: done")
        } catch {
            throw toGroupsException(error)
        }
    }

    // ------------------------------------------------------------------
    // Маппинг документов и ошибок (порт FirebaseBackend).
    // ------------------------------------------------------------------

    /// DocumentSnapshot → Group (порт FirebaseBackend.toGroup; обобщён с QueryDocumentSnapshot
    /// этапа 4, чтобы принимать и результат одноразового getDocument).
    private static func toGroup(_ snapshot: DocumentSnapshot) -> Group {
        let data: [String: Any] = snapshot.data() ?? [:]
        let createdAt = (data[Self.FIELD_CREATED_AT] as? Timestamp).map(Self.millisecondsSince1970) ?? 0
        return Group(
            groupId: snapshot.documentID,
            name: (data[Self.FIELD_NAME] as? String) ?? "",
            memberUids: Self.toStringList(data[Self.FIELD_MEMBER_UIDS]),
            createdAt: createdAt,
        )
    }

    /// Код Firestore-ошибки «группы нет для этого пользователя» для getGroup: resource-based
    /// read-правило groups даёт PERMISSION_DENIED для несуществующего/чужого документа,
    /// NOT_FOUND — для отсутствия по кэшу. Порт FirebaseBackend.isGroupAccessDenied;
    /// nil — ошибка не из этого класса (общая классификация в toGroupsException).
    private static func groupAccessDeniedCode(_ error: Error) -> FirestoreErrorCode? {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode(rawValue: nsError.code) else {
            return nil
        }
        // TODO: проверить на CI — сравнение enum-кейсов FirestoreErrorCode (.permissionDenied/.notFound).
        if code == .permissionDenied || code == .notFound {
            return code
        }
        return nil
    }

    /// GroupsException проходит как есть, сеть Firestore — networkUnavailable,
    /// остальное — unexpected с «код: сообщение»
    /// (порт FirebaseBackend.toGroupsException + describeCause).
    private func toGroupsException(_ error: Error) -> GroupsException {
        if let exception = error as? GroupsException {
            return exception
        }
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded:
                return GroupsException(error: .networkUnavailable)
            default:
                return GroupsException(error: .unexpected("\(code): \(nsError.localizedDescription)"))
            }
        }
        return GroupsException(error: .unexpected(nsError.localizedDescription))
    }

    /// Текущий пользователь обязателен во всех операциях с группами
    /// (порт FirebaseBackend.noCurrentUserForGroups).
    private func requireMyUid() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupsException(error: .unexpected("Нет текущего пользователя Firebase в операциях групп"))
        }
        return uid
    }

    /// Timestamp Firestore → millis (порт Android getSeconds*1000 + getNanoseconds/1e6).
    private static func millisecondsSince1970(_ timestamp: Timestamp) -> Int64 {
        // TODO: проверить на CI — приведение поля Firestore к Timestamp (seconds/nanoseconds).
        timestamp.seconds * 1000 + Int64(timestamp.nanoseconds) / 1_000_000
    }

    /// Приводит значение поля memberUids к списку строк; не-строковые элементы пропускаются.
    private static func toStringList(_ raw: Any?) -> [String] {
        guard let list = raw as? [Any] else {
            return []
        }
        return list.compactMap { $0 as? String }
    }
}
