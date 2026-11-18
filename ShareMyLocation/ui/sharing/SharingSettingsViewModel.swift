import Foundation
import Observation

/**
 ViewModel экрана настроек шаринга. Ключевое решение — автосохранение без кнопки «Сохранить»:
 каждый change-intent (1) обновляет UiState сразу (optimistic), (2) собирает полный снимок
 всех пяти полей и (3) записывает его через интерактор; снимок идемпотентен. Полёт записи
 отменяется новым изменением, поэтому записи не конкурируют. При неудаче — оптимистичный
 откат к `lastSaved`, если состояние экрана всё ещё соответствует записанному снимку,
 и inline-баннер ошибки в любом случае.

 Локальный выбор (`rawSelectedUids`/`rawSelectedGroupIds`) отделён от Firestore: хранится
 без пересечения и пересекается с актуальными друзьями/группами при отображении и записи —
 «протухшие» id (друг/группа удалены) не попадают ни на экран, ни в документ
 (паттерн GroupEditorViewModel). При allFriends списки выбора сохраняются как есть —
 возврат в custom восстанавливает выбор.

 Чтение документа одноразовое, НЕ realtime: документ редактирует только владелец с этого
 экрана, realtime-слушатель конкурировал бы с optimistic-состоянием автосейва.
 Realtime-потоки друзей и групп перезапускаются при каждом screenShown (отмена и новый
 Task — порт flatMapLatest(refreshTrigger) Android); их падение — inline-состояние секции,
 не экран-ошибка. Единственная публичная точка входа для UI — onIntent.
 Порт 1:1 из Android SharingSettingsViewModel.kt.
 */
@MainActor
@Observable
final class SharingSettingsViewModel {
    private(set) var state: SharingSettingsUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<SharingSettingsEffect>
    private let effectsContinuation: AsyncStream<SharingSettingsEffect>.Continuation

    private let sharingInteractor: SharingInteractor
    private let friendsInteractor: FriendsInteractor
    private let groupsInteractor: GroupsInteractor
    private let locationPermissionRequester: LocationPermissionRequesting
    private let sharingSettingsUiConverter: SharingSettingsUiConverter

    /// Последний успешно записанный снимок; дефолт после чтения. Откат автосейва — к нему.
    private var lastSaved: SharingSettings?

    /// Raw-выбор «Люди»: списки из документа + переключения; пересечение с друзьями — при записи.
    private var rawSelectedUids: Set<String> = []

    /// Raw-выбор «Группы»: id из документа + переключения; пересечение с группами — при записи.
    private var rawSelectedGroupIds: Set<String> = []

    /// Актуальные друзья владельца по последней эмиссии потока; защита от «протухших» uid.
    private var friendUids: Set<String> = []

    /// Актуальные группы владельца по последней эмиссии потока.
    private var groupIds: Set<String> = []

    /// Полёт автосохранения; новое изменение отменяет предыдущую запись (снимок идемпотентен).
    private var saveTask: Task<Void, Never>?

    /// Realtime-задачи потоков секций; перезапускаются при каждом screenShown.
    private var friendsTask: Task<Void, Never>?
    private var groupsTask: Task<Void, Never>?

    /**
     Желаемое включение тумблера, отложенное до результата запроса прав: тумблер без прав
     НЕ переключается, true запоминается здесь; после locationPermissionsResult сбрасывается.
     Сохраняется 1:1 с Android (там поле тоже переживает повороты как обычное свойство VM).
     */
    private var pendingEnableRequest = false

    init(
        sharingInteractor: SharingInteractor,
        friendsInteractor: FriendsInteractor,
        groupsInteractor: GroupsInteractor,
        locationPermissionRequester: LocationPermissionRequesting,
        sharingSettingsUiConverter: SharingSettingsUiConverter,
    ) {
        self.sharingInteractor = sharingInteractor
        self.friendsInteractor = friendsInteractor
        self.groupsInteractor = groupsInteractor
        self.locationPermissionRequester = locationPermissionRequester
        self.sharingSettingsUiConverter = sharingSettingsUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: SharingSettingsEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
        restartFriendsStream()
        restartGroupsStream()
    }

    deinit {
        friendsTask?.cancel()
        groupsTask?.cancel()
        saveTask?.cancel()
    }

    func onIntent(_ intent: SharingSettingsIntent) {
        switch intent {
        case .screenShown:
            onScreenShown()
        case .enabledToggled(let value):
            onEnabledToggled(value)
        case .audienceSelected(let audience):
            onAudienceSelected(audience)
        case .friendToggled(let uid):
            onFriendToggled(uid: uid)
        case .groupToggled(let groupId):
            onGroupToggled(groupId: groupId)
        case .saveErrorDismissed:
            state.saveError = nil
        case .locationPermissionsResult(let granted):
            onLocationPermissionsResult(granted: granted)
        }
    }

    /**
     Вход на экран = чистый лист: сброс транзиентов прошлой сессии (isSaving, saveError,
     экран-ошибка, флаги секций) — ViewModel переживает пересоздание sheet'а, унаследованная
     занятость навсегда дизейблила бы экран (урок Фазы 4) — плюс одноразовая перечитка
     документа и перезапуск realtime-потоков. Порт 1:1 Android onScreenShown.
     */
    private func onScreenShown() {
        saveTask?.cancel()
        restartFriendsStream()
        restartGroupsStream()
        state.isLoading = true
        state.isLoadFailed = false
        state.loadError = nil
        state.isSaving = false
        state.saveError = nil
        state.isFriendsLoadFailed = false
        state.isGroupsLoadFailed = false
        state.isPermissionMissing = false
        loadSettings()
    }

    /// Одноразовая перечитка документа; отсутствующий документ — дефолт от интерактора, не ошибка.
    private func loadSettings() {
        Task {
            switch await sharingInteractor.getSettings() {
            case .success(let settings):
                lastSaved = settings
                applySettings(settings)
                state.isLoading = false
                state.isLoadFailed = false
                state.loadError = nil
            case .failure(let error):
                print("SharingSettingsViewModel: Не удалось загрузить настройки шаринга — \(error)")
                state.isLoading = false
                state.isLoadFailed = true
                state.loadError = sharingSettingsUiConverter.convertError(error)
            }
        }
    }

    /// Применяет прочитанный/откаченный снимок к raw-выбору и строкам секций.
    private func applySettings(_ settings: SharingSettings) {
        rawSelectedUids = Set(settings.allowedUids)
        rawSelectedGroupIds = Set(settings.allowedGroupIds)
        state.isEnabled = settings.isEnabled
        // Документ «включён», но права не выданы: движок работать не может — баннер.
        state.isPermissionMissing = settings.isEnabled && !locationPermissionRequester.hasLocationPermission()
        state.audience = sharingSettingsUiConverter.convertAudience(settings.audience)
        state.friends = state.friends.map { friend in
            var updated = friend
            updated.isChecked = rawSelectedUids.contains(friend.id)
            return updated
        }
        state.groups = state.groups.map { group in
            var updated = group
            updated.isChecked = rawSelectedGroupIds.contains(group.id)
            return updated
        }
    }

    /// Перезапуск realtime-потока друзей (порт viewModelScope.launch + flatMapLatest).
    /// Конец потока без отмены = обрыв слушателя: guard !Task.isCancelled отделяет плановую
    /// отмену (screenShown/deinit) от обрыва, который даёт inline-ошибку секции.
    private func restartFriendsStream() {
        friendsTask?.cancel()
        friendsTask = Task {
            for await users in friendsInteractor.observeFriends() {
                guard !Task.isCancelled else { return }
                friendUids = Set(users.map(\.uid))
                state.friends = users.map {
                    sharingSettingsUiConverter.convertFriend($0, isChecked: rawSelectedUids.contains($0.uid))
                }
            }
            guard !Task.isCancelled else { return }
            // Пассивное падение секции — inline-состояние, не баннер и не экран-ошибка.
            print("SharingSettingsViewModel: Realtime-поток друзей прервался")
            state.isFriendsLoadFailed = true
        }
    }

    /// Перезапуск realtime-потока групп; семантика обрыва — как у потока друзей.
    private func restartGroupsStream() {
        groupsTask?.cancel()
        groupsTask = Task {
            for await groups in groupsInteractor.observeGroups() {
                guard !Task.isCancelled else { return }
                groupIds = Set(groups.map(\.groupId))
                state.groups = groups.map {
                    sharingSettingsUiConverter.convertGroup($0, isChecked: rawSelectedGroupIds.contains($0.groupId))
                }
            }
            guard !Task.isCancelled else { return }
            // Пассивное падение секции — inline-состояние, не баннер и не экран-ошибка.
            print("SharingSettingsViewModel: Realtime-поток групп прервался")
            state.isGroupsLoadFailed = true
        }
    }

    private func onEnabledToggled(_ value: Bool) {
        if value && !locationPermissionRequester.hasLocationPermission() {
            // Гейт прав: тумблер НЕ переключается и не персистится — «включено без прав»
            // было бы ложным обещанием (движок не стартует); желаемое включение ждёт диалога прав.
            pendingEnableRequest = true
            state.isPermissionMissing = true
            effectsContinuation.yield(.requestLocationPermissions)
            return
        }
        state.isEnabled = value
        state.isPermissionMissing = false
        // Включение при custom с пустым выбором = «локацию не увидит никто» — подсказка.
        if value && state.audience == .custom && isSelectionEmpty() {
            sendHint()
        }
        persist()
    }

    /**
     Результат системного диалога прав: отказ — тумблер остаётся выключенным (персист не был),
     баннер объясняет причину; выдача — выполняем отложенное включение обычным автосейвом
     ПОЛНЫМ снимком (не saveEnabled — как в Android).
     */
    private func onLocationPermissionsResult(granted: Bool) {
        pendingEnableRequest = false
        if !granted {
            state.isPermissionMissing = true
            return
        }
        state.isEnabled = true
        state.isPermissionMissing = false
        persist()
    }

    private func onAudienceSelected(_ audience: SharingAudienceUi) {
        if audience == state.audience { return }
        state.audience = audience
        // Переход в custom с пустым выбором = «локацию не увидит никто» — подсказка.
        if audience == .custom && isSelectionEmpty() {
            sendHint()
        }
        persist()
    }

    private func onFriendToggled(uid: String) {
        if rawSelectedUids.contains(uid) {
            rawSelectedUids.remove(uid)
        } else {
            rawSelectedUids.insert(uid)
        }
        state.friends = state.friends.map { friend in
            var updated = friend
            if friend.id == uid {
                updated.isChecked.toggle()
            }
            return updated
        }
        persist()
    }

    private func onGroupToggled(groupId: String) {
        if rawSelectedGroupIds.contains(groupId) {
            rawSelectedGroupIds.remove(groupId)
        } else {
            rawSelectedGroupIds.insert(groupId)
        }
        state.groups = state.groups.map { group in
            var updated = group
            if group.id == groupId {
                updated.isChecked.toggle()
            }
            return updated
        }
        persist()
    }

    /**
     Автосохранение: сборка и запись полного снимка всех пяти полей (идемпотентная merge-запись).
     «Протухшие» id отсекаются пересечением с актуальными друзьями/группами; при allFriends
     списки выбора сохраняются как есть. Предыдущий полёт записи отменяется — записи
     не конкурируют и не приходят в Firestore не по порядку.
     */
    private func persist() {
        guard lastSaved != nil else { return }
        let snapshot = buildSnapshot()
        state.isSaving = true
        saveTask?.cancel()
        saveTask = Task {
            let result = await sharingInteractor.saveSettings(snapshot)
            // Отменённый полёт не применяет результат — аналог отмены корутины Android
            // (CancellationException на await): иначе старая запись перезаписала бы lastSaved.
            guard !Task.isCancelled else { return }
            switch result {
            case .success:
                lastSaved = snapshot
                state.isSaving = false
            case .failure(let error):
                onSaveFailed(snapshot: snapshot, error: error)
            }
        }
    }

    /**
     Полный снимок настроек для записи: isEnabled, аудитория и пересечённые с актуальностью
     списки выбора — «протухшие» id (друг/группа удалены) не попадают в документ.
     */
    private func buildSnapshot() -> SharingSettings {
        SharingSettings(
            uid: lastSaved?.uid ?? "",
            isEnabled: state.isEnabled,
            audience: sharingSettingsUiConverter.toBusiness(state.audience),
            allowedUids: Array(rawSelectedUids.intersection(friendUids)),
            allowedGroupIds: Array(rawSelectedGroupIds.intersection(groupIds)),
        )
    }

    /**
     Неудача автосохранения: если состояние экрана всё ещё соответствует записанному снимку
     (новых изменений не было) — оптимистичный откат к `lastSaved`; в любом случае — баннер.
     */
    private func onSaveFailed(snapshot: SharingSettings, error: SharingError) {
        print("SharingSettingsViewModel: Автосохранение настроек шаринга не удалось — \(error)")
        if isStateUnchangedSince(snapshot) {
            rollbackToLastSaved()
        }
        state.isSaving = false
        state.saveError = sharingSettingsUiConverter.convertError(error)
    }

    /**
     Состояние не изменилось с момента снимка, если тумблер/аудитория те же и отмеченные
     строки совпадают с его списками: отмеченные на экране строки = raw-выбор ∩ актуальные,
     как и списки снимка, поэтому равенство означает «переключений не было».
     */
    private func isStateUnchangedSince(_ snapshot: SharingSettings) -> Bool {
        let checkedFriendIds = Set(state.friends.filter(\.isChecked).map(\.id))
        let checkedGroupIds = Set(state.groups.filter(\.isChecked).map(\.id))
        return state.isEnabled == snapshot.isEnabled &&
            state.audience == sharingSettingsUiConverter.convertAudience(snapshot.audience) &&
            checkedFriendIds == Set(snapshot.allowedUids) &&
            checkedGroupIds == Set(snapshot.allowedGroupIds)
    }

    /// Оптимистичный откат: тумблер, аудитория, raw-выбор и чекбоксы — к последнему успешному снимку.
    private func rollbackToLastSaved() {
        guard let saved = lastSaved else { return }
        rawSelectedUids = Set(saved.allowedUids)
        rawSelectedGroupIds = Set(saved.allowedGroupIds)
        state.isEnabled = saved.isEnabled
        state.audience = sharingSettingsUiConverter.convertAudience(saved.audience)
        state.friends = state.friends.map { friend in
            var updated = friend
            updated.isChecked = rawSelectedUids.contains(friend.id)
            return updated
        }
        state.groups = state.groups.map { group in
            var updated = group
            updated.isChecked = rawSelectedGroupIds.contains(group.id)
            return updated
        }
    }

    /// Пустой выбор = нет ни одного отмеченного человека и группы (raw, без пересечения).
    private func isSelectionEmpty() -> Bool {
        rawSelectedUids.isEmpty && rawSelectedGroupIds.isEmpty
    }

    private func sendHint() {
        effectsContinuation.yield(.showEmptyAudienceHint)
    }
}
