import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

/// Реализация чтения групп поверх Firestore напрямую: Android-обёртка FirebaseBackend
/// не портируется, groups-метод listenMyGroups перенесён сюда. Read-срез этапа 4;
/// запись появится в этапе 5. Порт 1:1 из Android GroupsRepositoryImpl.kt +
/// FirebaseBackend.listenMyGroups/toGroup.
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
                    let groups = snapshot?.documents.compactMap(Self.toGroup) ?? []
                    continuation.yield(groups)
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// DocumentSnapshot → Group (порт FirebaseBackend.toGroup); nil-ветка невозможна —
    /// compactMap сохраняет типовой запас для будущих полей.
    private static func toGroup(_ document: QueryDocumentSnapshot) -> Group? {
        let data = document.data()
        let createdAt = (data[Self.FIELD_CREATED_AT] as? Timestamp).map(Self.millisecondsSince1970) ?? 0
        return Group(
            groupId: document.documentID,
            name: (data[Self.FIELD_NAME] as? String) ?? "",
            memberUids: Self.toStringList(data[Self.FIELD_MEMBER_UIDS]),
            createdAt: createdAt,
        )
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
