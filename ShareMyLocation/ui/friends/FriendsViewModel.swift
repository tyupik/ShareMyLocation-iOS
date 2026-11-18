import Contacts
import Foundation
import Observation

/**
 ViewModel вкладки «Друзья». Realtime-потоки друзей, заявок и групп перезапускаются при каждом
 screenShown (отмена и новый Task на три потока); потоки независимы — ошибка одного показывает
 inline-состояние своей секции, не ломая другие. Аватары дозагружаются по одному
 через ProfileInteractor.getAvatar и кэшируются по «uid:версия», чтобы списки
 не мигали плейсхолдером при обновлениях.
 Порт 1:1 из Android FriendsViewModel.kt. Единственная публичная точка входа для UI — onIntent.
 */
@MainActor
@Observable
final class FriendsViewModel {
    private(set) var state: FriendsUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<FriendsEffect>
    private let effectsContinuation: AsyncStream<FriendsEffect>.Continuation

    private let friendsInteractor: FriendsInteractor
    private let contactsInteractor: ContactsInteractor
    private let groupsInteractor: GroupsInteractor
    private let profileInteractor: ProfileInteractor
    private let friendsUiConverter: FriendsUiConverter

    /// Бизнес-заявки по fromUid: нужны для accept/decline, Ui-модель их не тянет.
    private var incomingRequestsByUid: [String: FriendRequest] = [:]

    /// Резолвленные пути аватаров по ключу «uid:версия»; nil — аватара нет (ключ сохраняется,
    /// чтобы не дублировать загрузку; при неудаче ключ освобождается — порт MutableMap<String, String?>).
    private var avatarPaths: [String: String?] = [:]

    /// Realtime-задачи трёх секций; перезапускаются при каждом screenShown
    /// (порт viewModelScope.launch + flatMapLatest(refreshTrigger) Android).
    private var friendsTask: Task<Void, Never>?
    private var requestsTask: Task<Void, Never>?
    private var groupsTask: Task<Void, Never>?

    init(
        friendsInteractor: FriendsInteractor,
        contactsInteractor: ContactsInteractor,
        groupsInteractor: GroupsInteractor,
        profileInteractor: ProfileInteractor,
        friendsUiConverter: FriendsUiConverter,
    ) {
        self.friendsInteractor = friendsInteractor
        self.contactsInteractor = contactsInteractor
        self.groupsInteractor = groupsInteractor
        self.profileInteractor = profileInteractor
        self.friendsUiConverter = friendsUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: FriendsEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
    }

    deinit {
        friendsTask?.cancel()
        requestsTask?.cancel()
        groupsTask?.cancel()
    }

    func onIntent(_ intent: FriendsIntent) {
        switch intent {
        case .screenShown:
            onScreenShown()
        case .requestsBellClicked:
            state.isRequestsSheetVisible = true
        case .requestsSheetDismissed:
            state.isRequestsSheetVisible = false
        case .searchQueryChanged(let value):
            state.searchQuery = value
            state.searchState = .idle
        case .searchClicked:
            search()
        case .searchCleared:
            clearSearch()
        case .contactPicked(let contact):
            onContactPicked(contact)
        case .addFriendClicked(let uid):
            addFriend(uid: uid)
        case .acceptRequestClicked(let fromUid):
            acceptRequest(fromUid: fromUid)
        case .declineRequestClicked(let fromUid):
            declineRequest(fromUid: fromUid)
        case .removeFriendClicked(let uid):
            showRemoveDialog(uid: uid)
        case .removeFriendConfirmed:
            removeConfirmedFriend()
        case .removeFriendDialogDismissed:
            state.removeDialogFriend = nil
        case .createGroupClicked:
            openGroupEditor(groupId: nil)
        case .groupClicked(let groupId):
            openGroupEditor(groupId: groupId)
        case .errorDismissed:
            state.actionError = nil
        }
    }

    /**
     Перезапуск realtime-потоков трактуется как чистый лист: вместе с задачами сбрасываем
     actionError, все три флага пассивной недоступности секций, поиск (вход на вкладку =
     чистый лист поиска: searchQuery, searchState, busyUid), открытый диалог удаления друга
     (removeDialogFriend) и sheet заявок (isRequestsSheetVisible).
     Списки friends/incomingRequests/groups НЕ чистим — realtime-потоки доставят свежие данные.
     Следствие (осознанно): guard `busyUid == nil → return` после сброса не защищает от
     повторного клика по действию, оставшемуся в полёте с предыдущего показа вкладки, —
     вечный спиннер после logout хуже теоретического дубля, а серверные операции устойчивы.
     Внутрисессионные action-ошибки это не затрагивает: они ставятся после screenShown
     и живут до dismiss или следующего показа вкладки. Порт 1:1 Android onScreenShown.
     */
    private func onScreenShown() {
        friendsTask?.cancel()
        requestsTask?.cancel()
        groupsTask?.cancel()
        state.actionError = nil
        state.isFriendsLoadFailed = false
        state.isRequestsLoadFailed = false
        state.isGroupsLoadFailed = false
        state.searchQuery = ""
        state.searchState = .idle
        state.busyUid = nil
        state.removeDialogFriend = nil
        state.isRequestsSheetVisible = false
        startStreams()
    }

    /// Запуск трёх независимых realtime-задач. Конец потока без отмены = обрыв слушателя:
    /// guard !Task.isCancelled отделяет плановую отмену (screenShown/deinit) от обрыва,
    /// который показывает inline-ошибку своей секции.
    private func startStreams() {
        friendsTask = Task {
            for await users in friendsInteractor.observeFriends() {
                guard !Task.isCancelled else { return }
                state.isFriendsLoading = false
                state.friends = users.map { withCachedAvatar(friendUiModel: friendsUiConverter.convertFriend($0)) }
                resolveFriendAvatars()
            }
            guard !Task.isCancelled else { return }
            print("FriendsViewModel: Realtime-поток друзей прервался")
            state.isFriendsLoading = false
            state.isFriendsLoadFailed = true
        }
        requestsTask = Task {
            for await requests in friendsInteractor.observeIncomingFriendRequests() {
                guard !Task.isCancelled else { return }
                // associateBy(fromUid): при дублях побеждает последняя.
                incomingRequestsByUid = Dictionary(
                    requests.map { ($0.fromUid, $0) },
                    uniquingKeysWith: { _, right in right },
                )
                state.incomingRequests = requests.map {
                    withCachedAvatar(requestUiModel: friendsUiConverter.convertRequest($0))
                }
                resolveRequestAvatars()
            }
            guard !Task.isCancelled else { return }
            print("FriendsViewModel: Realtime-поток заявок прервался")
            state.isRequestsLoadFailed = true
        }
        groupsTask = Task {
            for await groups in groupsInteractor.observeGroups() {
                guard !Task.isCancelled else { return }
                state.isGroupsLoading = false
                state.groups = groups.map(friendsUiConverter.convertGroup)
            }
            guard !Task.isCancelled else { return }
            print("FriendsViewModel: Realtime-поток групп прервался")
            state.isGroupsLoading = false
            state.isGroupsLoadFailed = true
        }
    }

    /// Открытие редактора группы поверх Main — только через Effect, без прямых колбэков.
    private func openGroupEditor(groupId: String?) {
        effectsContinuation.yield(.openGroupEditor(groupId: groupId))
    }

    private func search() {
        let query = state.searchQuery
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.searchState.isLoading {
            return
        }
        // Валидация до похода в репозиторий: некорректный номер сразу показываем как ошибку поиска.
        if !PhoneNormalizer.isValid(PhoneNormalizer.normalize(query)) {
            state.searchState = .error(.invalidPhone)
            return
        }
        state.searchState = .loading
        Task {
            switch await friendsInteractor.searchByPhone(rawPhone: query) {
            case .success(let user):
                onSearchSuccess(user)
            case .failure(let error):
                onSearchFailure(error)
            }
        }
    }

    private func onSearchSuccess(_ user: User) {
        let uiModel = friendsUiConverter.convertFriend(user)
        state.searchState = .found(uiModel)
        resolveAvatar(uid: uiModel.uid, version: uiModel.avatarVersion) { path in
            updateFoundAvatar(uid: uiModel.uid, path: path)
        }
    }

    /// UserNotFound показывается как отдельное «не найдено», остальное — как ошибка поиска.
    private func onSearchFailure(_ error: FriendsError) {
        print("FriendsViewModel: Поиск по телефону не удался — \(error)")
        let searchState: FriendsSearchUiState
        if case .userNotFound = error {
            searchState = .notFound
        } else {
            searchState = .error(friendsUiConverter.convertError(error))
        }
        state.searchState = searchState
    }

    private func clearSearch() {
        state.searchQuery = ""
        state.searchState = .idle
    }

    /**
     Выбран контакт из телефонной книги: подставляем его первый непустой телефон в поле
     поиска и сразу запускаем обычный поиск (нормализация и валидация — внутри search).
     nil — пикер закрыт без выбора, реакция не нужна. searchState заранее в loading
     НЕ ставим: guard в search заблокировал бы автопоиск. Порт 1:1 Android onContactPicked.
     */
    private func onContactPicked(_ contact: CNContact?) {
        guard let contact else { return }
        Task {
            switch await contactsInteractor.getPhone(from: contact) {
            case .success(let phone):
                state.searchQuery = phone
                search()
            case .failure(let error):
                print("FriendsViewModel: Чтение телефона контакта не удалось — \(error)")
                state.actionError = friendsUiConverter.convertContactError(error)
            }
        }
    }

    private func addFriend(uid: String) {
        guard state.busyUid == nil else { return }
        state.busyUid = uid
        Task {
            switch await friendsInteractor.sendFriendRequest(toUid: uid) {
            case .success:
                state.busyUid = nil
                state.searchState = .idle
                effectsContinuation.yield(.friendRequestSent)
            case .failure(let error):
                onActionError(error)
            }
        }
    }

    private func acceptRequest(fromUid: String) {
        guard let request = incomingRequestsByUid[fromUid] else { return }
        guard state.busyUid == nil else { return }
        state.busyUid = fromUid
        Task {
            switch await friendsInteractor.acceptFriendRequest(request: request) {
            case .success:
                state.busyUid = nil
            case .failure(let error):
                onActionError(error)
            }
        }
    }

    private func declineRequest(fromUid: String) {
        guard let request = incomingRequestsByUid[fromUid] else { return }
        guard state.busyUid == nil else { return }
        state.busyUid = fromUid
        Task {
            switch await friendsInteractor.declineFriendRequest(request: request) {
            case .success:
                state.busyUid = nil
            case .failure(let error):
                onActionError(error)
            }
        }
    }

    /**
     Открытие диалога подтверждения удаления: фиксируем снимок друга на момент клика.
     Без guard busyUid — как DeleteClicked в GroupEditor: диалог не серверная операция,
     busyUid защищает само удаление внутри removeFriend(uid:).
     */
    private func showRemoveDialog(uid: String) {
        state.removeDialogFriend = state.friends.first { $0.uid == uid }
    }

    /**
     Удаление по подтверждению: работаем по снимку removeDialogFriend, поэтому операция
     выполняется, даже если друг исчез из realtime-списка, пока был открыт диалог
     (удаление идемпотентно, ошибка уйдёт в actionError). Диалог закрываем сразу.
     */
    private func removeConfirmedFriend() {
        guard let friend = state.removeDialogFriend else { return }
        state.removeDialogFriend = nil
        removeFriend(uid: friend.uid)
    }

    private func removeFriend(uid: String) {
        guard state.busyUid == nil else { return }
        state.busyUid = uid
        Task {
            switch await friendsInteractor.removeFriend(friendUid: uid) {
            case .success:
                state.busyUid = nil
            case .failure(let error):
                onActionError(error)
            }
        }
    }

    private func onActionError(_ error: FriendsError) {
        print("FriendsViewModel: Действие с друзьями не удалось — \(error)")
        state.busyUid = nil
        state.actionError = friendsUiConverter.convertError(error)
    }

    /// Дозагрузка аватаров друзей из текущего состояния; ошибка аватара не показывается.
    private func resolveFriendAvatars() {
        for friend in state.friends {
            resolveAvatar(uid: friend.uid, version: friend.avatarVersion) { path in
                guard let index = state.friends.firstIndex(
                    where: { $0.uid == friend.uid && $0.avatarVersion == friend.avatarVersion },
                ) else { return }
                state.friends[index].avatarPath = path
            }
        }
    }

    /// Дозагрузка аватаров заявок из текущего состояния.
    private func resolveRequestAvatars() {
        for request in state.incomingRequests {
            resolveAvatar(uid: request.fromUid, version: request.fromAvatarVersion) { path in
                guard let index = state.incomingRequests.firstIndex(
                    where: { $0.fromUid == request.fromUid && $0.fromAvatarVersion == request.fromAvatarVersion },
                ) else { return }
                state.incomingRequests[index].avatarPath = path
            }
        }
    }

    private func updateFoundAvatar(uid: String, path: String?) {
        guard case .found(var user) = state.searchState, user.uid == uid else { return }
        user.avatarPath = path
        state.searchState = .found(user)
    }

    /**
     Резолвит аватар как в ProfileViewModel: ошибка остаётся плейсхолдером с инициалом.
     Кэш по ключу «uid:версия» не даёт перезапускать загрузку при каждом обновлении списков;
     при неудаче ключ освобождается для повторной попытки на следующей эмиссии.
     */
    private func resolveAvatar(uid: String, version: Int, onResolved: @escaping (String?) -> Void) {
        guard version > 0 else { return }
        let key = Self.avatarKey(uid: uid, version: version)
        if let cached = avatarPaths[key] {
            onResolved(cached)
            return
        }
        // nil-значение сохраняем под существующим ключом (загрузка в полёте) —
        // присваивание «голого» nil удалило бы ключ из [String: String?].
        avatarPaths[key] = .some(nil)
        Task {
            switch await profileInteractor.getAvatar(uid: uid, version: version) {
            case .success(let avatar):
                avatarPaths[key] = .some(avatar.cachedPath)
                onResolved(avatar.cachedPath)
            case .failure(let error):
                print("FriendsViewModel: Не удалось загрузить аватар — \(error)")
                avatarPaths.removeValue(forKey: key)
            }
        }
    }

    /// Подставляет уже резолвленный путь аватара, чтобы список не мигал плейсхолдером.
    private func withCachedAvatar(friendUiModel model: FriendUiModel) -> FriendUiModel {
        let key = Self.avatarKey(uid: model.uid, version: model.avatarVersion)
        guard let cached = avatarPaths[key] else {
            return model
        }
        var updated = model
        updated.avatarPath = cached
        return updated
    }

    /// Подставляет уже резолвленный путь аватара, чтобы список не мигал плейсхолдером.
    private func withCachedAvatar(requestUiModel model: FriendRequestUiModel) -> FriendRequestUiModel {
        let key = Self.avatarKey(uid: model.fromUid, version: model.fromAvatarVersion)
        guard let cached = avatarPaths[key] else {
            return model
        }
        var updated = model
        updated.avatarPath = cached
        return updated
    }

    /// Ключ кэша аватара: uid и версия, чтобы смена аватара перезагрузила файл.
    private static func avatarKey(uid: String, version: Int) -> String {
        "\(uid):\(version)"
    }
}
