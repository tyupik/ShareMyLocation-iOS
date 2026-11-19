import FirebaseCore

/**
 Application-scoped наблюдатель уведомлений: живёт весь срок процесса и публикует локальные
 уведомления о двух событиях — входящая заявка в друзья и «друг начал делиться геопозицией»
 (uid появился в наборе видимых друзей). Стартует один раз из AppDelegate (порт
 ShareMyLocationApp.onCreate Android).
 Порт 1:1 из Android NotificationWatcher.kt: flatMapLatest + merge + retryWhen переписаны
 на Swift Concurrency (см. observeAuthAndData).

 Подписки пересобираются от realtime-потока аутентификации: пользователь не задан —
 дедуп-наборы сброшены и слушателей нет; смена пользователя (logout/login) сбрасывает
 наборы и мгновенно пересобирает data-подписки (flatMapLatest, без retry-паузы) — событие
 считается новым только для текущего аккаунта. Смерть любого Firestore-слушателя
 (конец его потока без отмены) умирает конвейер целиком — внешний цикл пережидает
 RETRY_DELAY_NANOS и переподписывается, дедуп-наборы при этом сохраняются (сброс —
 только по auth-переходу); первый снапшот каждой (пере)подписки — baseline: наполняет
 набор, но не уведомляет. Без сконфигурированного Firebase цикл завершается сразу:
 приложение работает без Firebase, бесконечные ретраи не нужны.

 Системные права и публикация — вне ответственности watcher'а: только NotificationPublisher
 (data-слой), поэтому без права события просто не доходят до системной шторы.
 */
// TODO: проверить на CI — TaskGroup с @MainActor-замыканиями (изоляция child-task)
// и AsyncStream-сигнализация смерти data-конвейера.
@MainActor
final class NotificationWatcher {
    private let authInteractor: AuthInteractor
    private let friendsInteractor: FriendsInteractor
    private let mapInteractor: MapInteractor
    private let notificationPublisher: NotificationPublisher

    init(
        authInteractor: AuthInteractor,
        friendsInteractor: FriendsInteractor,
        mapInteractor: MapInteractor,
        notificationPublisher: NotificationPublisher,
    ) {
        self.authInteractor = authInteractor
        self.friendsInteractor = friendsInteractor
        self.mapInteractor = mapInteractor
        self.notificationPublisher = notificationPublisher
    }

    /// Uid отправителей из предыдущего снапшота входящих заявок (дедуп «по предыдущему набору»).
    private var previousRequestUids: Set<String> = []

    /// Uid друзей из предыдущего снапшота видимых (дедуп «по предыдущему набору»).
    private var previousVisibleUids: Set<String> = []

    /// Uid, для которого наполнены наборы; смена (logout/login) сбрасывает их.
    private var dedupUid: String?

    private var started = false

    /// Активная data-подписка текущего пользователя (порт внутреннего потока flatMapLatest);
    /// пересоздаётся на каждую auth-эмиссию вошедшего пользователя.
    private var dataTask: Task<Void, Never>?

    /// Continuation сигнала смерти data-конвейера: живёт на одну «сессию» observeOnce.
    private var dataDeathContinuation: AsyncStream<Void>.Continuation?

    /// Идемпотентный старт наблюдения: повторные вызовы — no-op.
    func start() {
        guard !started else { return }
        started = true
        Task { await observeAuthAndData() }
    }

    // MARK: - Конвейер подписок (порт observeAuthAndData: flatMapLatest + retryWhen)

    /**
     Цикл уровня процесса: переподписка после смерти auth- или data-конвейера.
     Порт retryWhen: пауза RETRY_DELAY_NANOS и полный перезапуск (включая auth-слушатель);
     дедуп-наборы между ретраями сохраняются. Без Firebase — немедленное завершение без
     ретраев (observeAuthState в этом случае отдаёт nil и завершается, цикл бы крутился
     вхолостую).

     Проверка Firebase продублирована НАМЕРЕННО: `FirebaseApp.app() != nil` — тело
     AuthRepositoryImpl.isFirebaseConfigured — чтобы не заводить business→data зависимость
     (решение планировщика); при изменении тела флага в AuthRepositoryImpl синхронизировать.
     */
    private func observeAuthAndData() async {
        guard FirebaseApp.app() != nil else {
            print("NotificationWatcher: Firebase не сконфигурирован — наблюдатель не запускается")
            return
        }
        while !Task.isCancelled {
            await observeOnce()
            guard !Task.isCancelled else { return }
            let retryDelayMs = Self.RETRY_DELAY_NANOS / 1_000_000
            print("NotificationWatcher: Поток уведомлений упал — переподписка через \(retryDelayMs) мс")
            do {
                try await Task.sleep(nanoseconds: Self.RETRY_DELAY_NANOS)
            } catch {
                return
            }
        }
    }

    /**
     Одна «жизнь» конвейера: auth-подписка + data-подписки текущего пользователя.
     Возврат при смерти auth-потока ИЛИ при смерти любого data-потока (смерть одного
     отменяет второй — порт немедленного fail merge при ошибке Firestore-слушателя Android).
     Смена пользователя сюда не попадает: она обрабатывается consumeAuth мгновенно.
     */
    private func observeOnce() async {
        dataTask?.cancel()
        dataTask = nil
        let (deathStream, deathContinuation) = AsyncStream.makeStream(
            of: Void.self,
            bufferingPolicy: .unbounded,
        )
        dataDeathContinuation = deathContinuation

        await withTaskGroup(of: Void.self) { group in
            // auth-конвейер: на каждую эмиссию перезапускает data-подписку (порт flatMapLatest).
            group.addTask { @MainActor in
                await self.consumeAuth(deathContinuation: deathContinuation)
            }
            // Ожидатель: ЗАВЕРШАЕТСЯ на первом элементе deathStream (yield — смерть
            // data-конвейера) или на завершении потока (finish() — смерть auth-потока
            // из consumeAuth). Поэтому смерть Firestore-слушателя заявок/видимых друзей
            // завершает observeOnce() и запускает retry-цикл observeAuthAndData.
            group.addTask { @MainActor in
                for await _ in deathStream {
                    break
                }
            }
            _ = await group.next()
            group.cancelAll()
            await group.waitForAll()
        }
        dataDeathContinuation = nil
    }

    /// Читает auth-поток до его завершения; на каждую эмиссию перезапускает data-подписку.
    private func consumeAuth(deathContinuation: AsyncStream<Void>.Continuation) async {
        for await user in authInteractor.observeAuthState() {
            resetDedupFor(user)
            restartDataPipeline(isAuthorized: user != nil)
        }
        // auth-поток умер: data-конвейер не имеет смысла — отменяем и будим ожидатель.
        dataTask?.cancel()
        dataTask = nil
        deathContinuation.finish()
    }

    /// Перезапуск data-конвейера (порт ветвления flatMapLatest: user == nil — слушателей нет).
    private func restartDataPipeline(isAuthorized: Bool) {
        dataTask?.cancel()
        dataTask = nil
        guard isAuthorized else { return }
        let deathContinuation = dataDeathContinuation
        dataTask = Task {
            await observeDataSources(onDeath: deathContinuation)
        }
    }

    /**
     Realtime-потоки заявок и видимых друзей (порт observeDataSources + merge). Baseline-флаги
     локальны на одну (пере)подписку — в том числе после retry: первый снапшот наполняет
     дедуп-набор, не уведомляя о текущем состоянии. Сигнал смерти подаётся только при
     конце потока без отмены: отмена при смене пользователя — это flatMapLatest-переключение,
     а не смерть конвейера (retry-пауза не нужна).
     */
    private func observeDataSources(onDeath deathContinuation: AsyncStream<Void>.Continuation?) async {
        let requestsBaseline = BaselineFlag()
        let sharingBaseline = BaselineFlag()
        var anyDied = false
        await withTaskGroup(of: Bool.self) { group in
            // Каждая подписка — свой набор Firestore-слушателей (двойное чтение как в Android).
            group.addTask { @MainActor in
                await self.consumeRequests(baseline: requestsBaseline)
            }
            group.addTask { @MainActor in
                await self.consumeSharing(baseline: sharingBaseline)
            }
            // Смерть любого источника: отменяем второй (порт fail-fast merge Android).
            anyDied = await group.next() ?? false
            if anyDied {
                group.cancelAll()
            }
            for await died in group {
                anyDied = anyDied || died
            }
        }
        if anyDied {
            deathContinuation?.yield()
        }
    }

    /// Возвращает true, если поток завершился сам (смерть Firestore-слушателя),
    /// false — если задача была отменена (смена пользователя/стоп watcher'а).
    private func consumeRequests(baseline: BaselineFlag) async -> Bool {
        for await requests in friendsInteractor.observeIncomingFriendRequests() {
            guard !Task.isCancelled else { return false }
            handleRequestsSnapshot(requests, isBaseline: baseline.value)
            baseline.value = false
        }
        return !Task.isCancelled
    }

    /// См. consumeRequests.
    private func consumeSharing(baseline: BaselineFlag) async -> Bool {
        for await friends in mapInteractor.observeVisibleFriends() {
            guard !Task.isCancelled else { return false }
            handleSharingSnapshot(friends, isBaseline: baseline.value)
            baseline.value = false
        }
        return !Task.isCancelled
    }

    // MARK: - Дедуп и публикация (порт 1:1 Android)

    /// Сброс дедуп-наборов при смене пользователя; переподписка того же uid наборы сохраняет.
    private func resetDedupFor(_ user: User?) {
        if user?.uid == dedupUid {
            return
        }
        print("NotificationWatcher.resetDedupFor: uid=\(user?.uid ?? "nil")")
        previousRequestUids.removeAll()
        previousVisibleUids.removeAll()
        dedupUid = user?.uid
    }

    /// Новые входящие заявки: uid, которых не было в предыдущем снапшоте.
    private func handleRequestsSnapshot(_ requests: [FriendRequest], isBaseline: Bool) {
        let uids = Set(requests.map(\.fromUid))
        if isBaseline {
            replaceDedupSet(&previousRequestUids, with: uids)
            return
        }
        // Порт associateBy(fromUid): при дублях uid остаётся последняя заявка.
        let requestsByUid = Dictionary(
            requests.map { ($0.fromUid, $0) },
            uniquingKeysWith: { _, last in last },
        )
        for uid in uids.subtracting(previousRequestUids) {
            guard let request = requestsByUid[uid] else { continue }
            notificationPublisher.publish(
                .friendRequestReceived(fromUid: uid, fromName: request.fromName),
            )
        }
        replaceDedupSet(&previousRequestUids, with: uids)
    }

    /// Друзья, начавшие шарить: uid, которых не было в предыдущем снапшоте видимых.
    private func handleSharingSnapshot(_ friends: [VisibleFriend], isBaseline: Bool) {
        let uids = Set(friends.map(\.uid))
        if isBaseline {
            replaceDedupSet(&previousVisibleUids, with: uids)
            return
        }
        let friendsByUid = Dictionary(
            friends.map { ($0.uid, $0) },
            uniquingKeysWith: { _, last in last },
        )
        for uid in uids.subtracting(previousVisibleUids) {
            guard let friend = friendsByUid[uid] else { continue }
            notificationPublisher.publish(
                .friendStartedSharing(uid: uid, displayName: friend.displayName),
            )
        }
        replaceDedupSet(&previousVisibleUids, with: uids)
    }

    /// Предыдущий набор заменяется целиком: исчезнувший uid при повторном появлении — снова событие.
    private func replaceDedupSet(_ target: inout Set<String>, with uids: Set<String>) {
        target = uids
    }

    /// Box baseline-флага одной (пере)подписки: ссылочный тип — захватывается в задачи
    /// TaskGroup; обе задачи MainActor-изолированы, гонок нет.
    private final class BaselineFlag {
        var value = true
    }

    /// Пауза перед переподпиской упавших Firestore-слушателей (30 с, как RETRY_DELAY_MS Android).
    private static let RETRY_DELAY_NANOS: UInt64 = 30_000_000_000
}
