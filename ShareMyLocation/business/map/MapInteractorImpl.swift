import Foundation

/**
 Реализация интерактора карты: realtime-конвейер «друзья → их настройки шаринга →
 набор видимых uid → их точки локаций».
 Порт 1:1 из Android MapInteractorImpl.kt (flatMapLatest → вложенные Task с явной отменой).

 Имена/аватар-версии и uid берутся из одного потока FriendsInteractor.observeFriends
 (интерактор не отдаёт сырые uid, а дублирующий запрос профилей не нужен); поток друзей
 уже дедуплицирован — distinctUntilChanged не нужен. Настройки шаринга друзей — realtime
 по-документные слушатели SharingRepository.observeSettingsByUid, сливаются в слепок
 здесь (осознанное расхождение с Android: там оба метода в MapRepository): выключение/
 включение шаринга и смена аудитории/allowedUids у друга меняют набор видимых без
 перезахода на вкладку. Проекция видимых uid дедуплицируется по предыдущему набору:
 locations-этап перезапускается только при фактической смене набора видимых. Состав групп —
 одноразовый get при пересборке проекции (обновится на следующий ScreenShown). Тик 5 с
 проходит сквозь конвейер сам — переэмиссия каждые 5 секунд старит «как давно» на экране,
 не перезапуская слушатели.

 Все мутируемые состояния конвейера живут в MainActor-задачах (паттерн FriendsInteractorImpl):
 Firestore-колбэки доходят до потребителей через AsyncStream и разбираются последовательно.
 */
final class MapInteractorImpl: MapInteractor {
    private let mapRepository: MapRepository
    private let sharingRepository: SharingRepository
    private let friendsInteractor: FriendsInteractor
    private let groupsInteractor: GroupsInteractor
    private let authInteractor: AuthInteractor

    init(
        mapRepository: MapRepository,
        sharingRepository: SharingRepository,
        friendsInteractor: FriendsInteractor,
        groupsInteractor: GroupsInteractor,
        authInteractor: AuthInteractor,
    ) {
        self.mapRepository = mapRepository
        self.sharingRepository = sharingRepository
        self.friendsInteractor = friendsInteractor
        self.groupsInteractor = groupsInteractor
        self.authInteractor = authInteractor
    }

    func observeVisibleFriends() -> AsyncStream<[VisibleFriend]> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let rootTask = Task { @MainActor in
                var pipelineTask: Task<Void, Never>? = nil
                defer {
                    pipelineTask?.cancel()
                }
                for await friends in friendsInteractor.observeFriends() {
                    guard !Task.isCancelled else { return }
                    // flatMapLatest: новая эмиссия друзей отменяет предыдущий конвейер
                    // (все per-uid слушатели настроек и locations-этап) и запускает новый.
                    pipelineTask?.cancel()
                    pipelineTask = Task { @MainActor in
                        await runSettingsStage(friends: friends, continuation: continuation)
                    }
                }
                // Поток друзей кончился (ошибка слушателя) — падение всего конвейера.
                continuation.finish()
            }
            continuation.onTermination = { _ in
                rootTask.cancel()
            }
        }
    }

    // MARK: - Этап настроек

    /**
     Этап настроек (порт flatMapLatest по друзьям): per-uid слушатели настроек сливаются
     в mergedSettings; каждая доставка пересчитывает проекцию видимых uid, и при фактической
     смене набора перезапускает locations-этап. Отсутствующий слепок (слушатель ещё не
     доставил документ) — «не видно» до первой доставки. Ошибка любого per-uid слушателя
     (конец потока без отмены) падением закрывает весь поток карты.
     */
    private func runSettingsStage(
        friends: [User],
        continuation: AsyncStream<[VisibleFriend]>.Continuation,
    ) async {
        let uids = friends.map(\.uid)
        var mergedSettings: [String: SharingSettings] = [:]
        var lastVisibleUids: [String]? = nil
        var locationsStageTask: Task<Void, Never>? = nil
        let (settingsStream, settingsContinuation) = AsyncStream.makeStream(
            of: (uid: String, settings: SharingSettings).self,
            bufferingPolicy: .unbounded,
        )
        var childTasks: [Task<Void, Never>] = []
        defer {
            locationsStageTask?.cancel()
            for child in childTasks {
                child.cancel()
            }
        }

        if uids.isEmpty {
            // Android: репозиторий настроек на пустом списке друзей шлёт единичный пустой
            // слепок (слушателей не создаёт); проекция даёт пустой набор видимых —
            // locations-этап сам выдаст пустой список (единичный yield + тики).
            locationsStageTask = Task { @MainActor in
                await runLocationsStage(friends: friends, visibleUids: [], continuation: continuation)
            }
            // Конвейер висит открытым до отмены (новая эмиссия друзей / смерть корня).
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.IDLE_POLL_NANOS)
            }
            return
        }

        // По-документный слушатель настроек на uid друга (слияние слепка — здесь).
        for uid in uids {
            childTasks.append(Task { @MainActor in
                for await settings in sharingRepository.observeSettingsByUid(uid: uid) {
                    guard !Task.isCancelled else { return }
                    settingsContinuation.yield((uid, settings))
                }
                // Конец per-uid потока без отмены = ошибка слушателя (deny/!exists приходят
                // как defaultFor, не finish) — падение всего конвейера.
                guard !Task.isCancelled else { return }
                settingsContinuation.finish()
            })
        }

        for await update in settingsStream {
            mergedSettings[update.uid] = update.settings
            let visibleUids: [String]
            do {
                let myUid = await authInteractor.getCurrentUser()?.uid
                visibleUids = try await projectVisibleUids(
                    friends: friends,
                    myUid: myUid,
                    settingsByUid: mergedSettings,
                )
            } catch {
                // Сетевые ошибки не глотаются — падение закрывает поток целиком
                // (экран покажет состояние ошибки).
                print("MapInteractorImpl: Конвейер видимости упал — \(error)")
                continuation.finish()
                return
            }
            // Дедупликация по предыдущему набору: locations-этап перезапускается
            // только при фактической смене набора видимых.
            if visibleUids != lastVisibleUids {
                lastVisibleUids = visibleUids
                locationsStageTask?.cancel()
                locationsStageTask = Task { @MainActor in
                    await runLocationsStage(
                        friends: friends,
                        visibleUids: visibleUids,
                        continuation: continuation,
                    )
                }
            }
        }
        // Выход из цикла без отмены = какой-то per-uid слушатель умер — весь поток падает.
        guard !Task.isCancelled else { return }
        continuation.finish()
    }

    /**
     Видит ли текущий пользователь локацию friend: настройка из realtime-слепка активна
     и аудитория пускает. Отсутствующий слепок (myUid nil / settings nil — слушатель ещё
     не доставил документ) — «не видно» до первой доставки. Порт 1:1 Android isVisible.
     */
    private func isVisible(
        friend: User,
        myUid: String?,
        settings: SharingSettings?,
    ) async throws -> Bool {
        guard let myUid, let settings else {
            return false
        }
        if !settings.isEnabled {
            return false
        }
        switch settings.audience {
        case .allFriends:
            return true
        case .custom:
            return settings.allowedUids.contains(myUid)
                || try await hasGroupMembership(settings.allowedGroupIds, myUid: myUid)
        }
    }

    /** Состоит ли myUid в memberUids хотя бы одной группы из groupIds. */
    private func hasGroupMembership(_ groupIds: [String], myUid: String) async throws -> Bool {
        for groupId in groupIds {
            guard let group = try await resolveGroup(groupId: groupId) else { continue }
            if group.memberUids.contains(myUid) {
                return true
            }
        }
        return false
    }

    /**
     Группа по id; протухший allowedGroupIds (удалена/недоступна — groupNotFound) — nil,
     группа не учитывается. Остальные ошибки не глотаются: закрывают поток (throw).
     */
    private func resolveGroup(groupId: String) async throws -> Group? {
        switch await groupsInteractor.getGroup(groupId: groupId) {
        case .success(let group):
            return group
        case .failure(.groupNotFound):
            return nil
        case .failure(let error):
            throw GroupsException(error: error)
        }
    }

    /**
     Проекция видимых uid: друзья, чья настройка из слепка активна и аудитория пускает,
     в порядке списка друзей (порт map+filter Android). myUid читается один раз
     на проекцию, как в Android.
     */
    private func projectVisibleUids(
        friends: [User],
        myUid: String?,
        settingsByUid: [String: SharingSettings],
    ) async throws -> [String] {
        var visibleUids: [String] = []
        for friend in friends {
            if try await isVisible(friend: friend, myUid: myUid, settings: settingsByUid[friend.uid]) {
                visibleUids.append(friend.uid)
            }
        }
        return visibleUids
    }

    // MARK: - Этап точек

    /// Событие locations-этапа: снапшот точек или тик.
    private enum LocationsTrigger {
        case locations([String: FriendLocation])
        case tick
    }

    /**
     Этап точек (порт combine(observeLocationsByUids, visibilityTicker)): слушатель чанков
     копит latestLocations, тик 5 с реэмитит тот же список («как давно» стареет на экране).
     Любая ветка yields — экран обновляется и на новую точку, и на тик. Ошибка слушателя
     чанков (конец потока без отмены) — падение всего конвейера.
     */
    private func runLocationsStage(
        friends: [User],
        visibleUids: [String],
        continuation: AsyncStream<[VisibleFriend]>.Continuation,
    ) async {
        var latestLocations: [String: FriendLocation] = [:]
        let (triggerStream, triggerContinuation) = AsyncStream.makeStream(
            of: LocationsTrigger.self,
            bufferingPolicy: .unbounded,
        )
        let locationsTask = Task { @MainActor in
            for await locations in mapRepository.observeLocationsByUids(uids: visibleUids) {
                guard !Task.isCancelled else { return }
                triggerContinuation.yield(.locations(locations))
            }
            guard !Task.isCancelled else { return }
            triggerContinuation.finish()
        }
        let tickerTask = Task { @MainActor in
            while !Task.isCancelled {
                triggerContinuation.yield(.tick)
                try? await Task.sleep(nanoseconds: Self.TICK_INTERVAL_NANOS)
            }
        }
        defer {
            locationsTask.cancel()
            tickerTask.cancel()
        }

        for await trigger in triggerStream {
            switch trigger {
            case .locations(let locations):
                latestLocations = locations
                continuation.yield(project(friends: friends, locations: latestLocations))
            case .tick:
                // Тик реэмитит тот же список — ViewModel пересчитает «как давно».
                continuation.yield(project(friends: friends, locations: latestLocations))
            }
        }
        guard !Task.isCancelled else { return }
        continuation.finish()
    }

    /**
     Проекция списка видимых друзей: точки locations, дополненные именем/аватар-версией
     из текущего набора друзей (порт mapNotNull Android). Друзья без точки пропускаются.
     */
    private func project(friends: [User], locations: [String: FriendLocation]) -> [VisibleFriend] {
        friends.compactMap { friend in
            guard let location = locations[friend.uid] else { return nil }
            return VisibleFriend(
                uid: friend.uid,
                displayName: friend.displayName ?? "",
                avatarVersion: friend.avatarVersion,
                latitude: location.latitude,
                longitude: location.longitude,
                accuracyMeters: location.accuracyMeters,
                updatedAtMillis: location.updatedAtMillis,
            )
        }
    }

    /// Период переэмиссии видимых друзей для старения метки «как давно» (TICK_INTERVAL_MS).
    private static let TICK_INTERVAL_NANOS: UInt64 = 5_000_000_000

    /// Опрос отмены в ожидании новой эмиссии друзей (пустой список друзей).
    private static let IDLE_POLL_NANOS: UInt64 = 1_000_000_000
}
