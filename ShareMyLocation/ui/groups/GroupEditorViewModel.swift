import Foundation
import Observation

/**
 ViewModel экрана управления группой (создание/редактирование). Поток друзей перезапускается
 при каждом screenShown (отмена и новый Task — порт flatMapLatest(refreshTrigger) Android);
 группа в режиме редактирования читается одноразово — getGroup, ошибка → экран-ошибка
 с «Повторить» (повтор = повторный screenShown).
 Порт 1:1 из Android GroupEditorViewModel.kt.
 Локальный выбор состава (`selectedUids`) отделён от Firestore: он хранится без пересечения
 и пересекается с актуальными друзьями (`friendUids`) при отображении и при сохранении —
 «протухшие» uid (друг удалён, но остался в memberUids) не попадают ни на экран, ни в запись,
 а выбор не теряется в гонке «группа пришла раньше первой эмиссии потока друзей».
 Android-риск stale Closed (канал переживёт уход с экрана и закроет следующее открытие)
 здесь отсутствует: ViewModel не singleton — sheet пересоздаёт её на каждый показ
 (GroupEditorScreen через Container), effects-стрим умирает вместе с ней.
 Единственная публичная точка входа для UI — onIntent.
 */
@MainActor
@Observable
final class GroupEditorViewModel {
    private(set) var state: GroupEditorUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<GroupEditorEffect>
    private let effectsContinuation: AsyncStream<GroupEditorEffect>.Continuation

    private let groupsInteractor: GroupsInteractor
    private let friendsInteractor: FriendsInteractor
    private let groupEditorUiConverter: GroupEditorUiConverter

    /**
     Локальный выбор состава экрана: raw-набор (memberUids группы + переключения пользователя).
     Пересечение с `friendUids` выполняется при отображении чекбоксов и при сохранении.
     */
    private var selectedUids: Set<String> = []

    /// Актуальные друзья владельца по последней эмиссии потока; защита от «протухших» uid.
    private var friendUids: Set<String> = []

    /// Realtime-задача потока друзей; перезапускается при каждом screenShown.
    private var friendsTask: Task<Void, Never>?

    init(
        groupsInteractor: GroupsInteractor,
        friendsInteractor: FriendsInteractor,
        groupEditorUiConverter: GroupEditorUiConverter,
    ) {
        self.groupsInteractor = groupsInteractor
        self.friendsInteractor = friendsInteractor
        self.groupEditorUiConverter = groupEditorUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: GroupEditorEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
        restartFriendsStream()
    }

    deinit {
        friendsTask?.cancel()
    }

    func onIntent(_ intent: GroupEditorIntent) {
        switch intent {
        case .screenShown(let groupId):
            onScreenShown(groupId: groupId)
        case .nameChanged(let value):
            state.name = value
        case .memberToggled(let uid):
            toggleMember(uid: uid)
        case .saveClicked:
            save()
        case .deleteClicked:
            state.isDeleteDialogVisible = true
        case .deleteConfirmed:
            delete()
        case .deleteDialogDismissed:
            state.isDeleteDialogVisible = false
        case .errorDismissed:
            state.actionError = nil
        }
    }

    /**
     Вход на экран = чистый лист: вместе с перезапуском загрузки сбрасываются транзиентные
     флаги прошлой сессии (isSaving, isDeleting, isDeleteDialogVisible) и форма create-режима
     (name, selectedUids; в edit-режиме их перезаполнит загрузка группы). Порт 1:1 Android
     onScreenShown.
     */
    private func onScreenShown(groupId: String?) {
        selectedUids = []
        state.groupId = groupId
        state.isLoading = true
        state.isLoadFailed = false
        state.loadError = nil
        state.actionError = nil
        state.name = ""
        state.isSaving = false
        state.isDeleting = false
        state.isDeleteDialogVisible = false
        restartFriendsStream()
        if let groupId {
            loadGroup(groupId)
        }
    }

    /// Одноразовая перечитка группы: имя — в поле ввода, состав — в локальный выбор экрана.
    private func loadGroup(_ groupId: String) {
        Task {
            switch await groupsInteractor.getGroup(groupId: groupId) {
            case .success(let group):
                selectedUids = Set(group.memberUids)
                state.isLoading = false
                state.isLoadFailed = false
                state.loadError = nil
                state.name = group.name
                // Ремапп чекбоксов: защита гонки «группа пришла раньше первой эмиссии
                // потока друзей» — friends уже на экране перечитываются по selectedUids.
                state.friends = state.friends.map { friend in
                    var updated = friend
                    updated.isChecked = selectedUids.contains(friend.uid)
                    return updated
                }
            case .failure(let error):
                onLoadFailed(error)
            }
        }
    }

    /**
     Экран-ошибка загрузки. Причина уточняется только для ошибок группы (в частности
     groupNotFound); падение realtime-потока друзей даёт generic-текст (nil).
     */
    private func onLoadFailed(_ error: GroupsError?) {
        state.isLoading = false
        state.isLoadFailed = true
        state.loadError = error.map(groupEditorUiConverter.convertError)
    }

    /// Перезапуск realtime-потока друзей (порт viewModelScope.launch + flatMapLatest(refreshTrigger)).
    /// Конец потока без отмены = обрыв слушателя: guard !Task.isCancelled отделяет плановую
    /// отмену (screenShown/deinit) от обрыва, который даёт экран-ошибку.
    private func restartFriendsStream() {
        friendsTask?.cancel()
        friendsTask = Task {
            for await users in friendsInteractor.observeFriends() {
                guard !Task.isCancelled else { return }
                state.isLoading = false
                friendUids = Set(users.map(\.uid))
                state.friends = users.map {
                    groupEditorUiConverter.convertFriend($0, isChecked: selectedUids.contains($0.uid))
                }
            }
            guard !Task.isCancelled else { return }
            // Пассивное падение — экран-ошибка с «Повторить», не баннер действия.
            print("GroupEditorViewModel: Realtime-поток друзей прервался")
            onLoadFailed(nil)
        }
    }

    private func toggleMember(uid: String) {
        if selectedUids.contains(uid) {
            selectedUids.remove(uid)
        } else {
            selectedUids.insert(uid)
        }
        state.friends = state.friends.map { friend in
            var updated = friend
            if friend.uid == uid {
                updated.isChecked.toggle()
            }
            return updated
        }
    }

    /**
     Сохранение: создание — createGroup (имя + сырой selectedUids — состав, взятый
     с чекбоксов актуальных друзей, ⊆ друзей по построению; пустой состав допустим),
     редактирование — updateGroup (имя + пересечение selectedUids ∩ friendUids:
     «протухшие» uid отсекаются). Успех закрывает экран: список групп обновится
     realtime-слушателем вкладки, колбэки «результата» не используются.
     */
    private func save() {
        guard !state.isSaving, !state.isLoading else { return }
        let groupId = state.groupId
        let name = state.name
        let memberUids = Array(selectedUids.intersection(friendUids))
        state.isSaving = true
        Task {
            let result: Result<Void, GroupsError>
            if let groupId {
                result = await groupsInteractor.updateGroup(
                    groupId: groupId,
                    rawName: name,
                    memberUids: memberUids,
                )
            } else {
                // groupId созданной группы не нужен: экран закрывается, список обновится сам.
                switch await groupsInteractor.createGroup(rawName: name, memberUids: Array(selectedUids)) {
                case .success:
                    result = .success(())
                case .failure(let error):
                    result = .failure(error)
                }
            }
            switch result {
            case .success:
                effectsContinuation.yield(.closed)
            case .failure(let error):
                onActionError(error)
            }
        }
    }

    private func delete() {
        guard !state.isDeleting, !state.isSaving else { return }
        guard let groupId = state.groupId else { return }
        state.isDeleting = true
        state.isDeleteDialogVisible = false
        Task {
            switch await groupsInteractor.deleteGroup(groupId: groupId) {
            case .success:
                effectsContinuation.yield(.closed)
            case .failure(let error):
                onActionError(error)
            }
        }
    }

    /// Ошибки действий приходят из интерактора уже типизированными (GroupsError) —
    /// разворачивать в unexpected, как Android, не требуется.
    private func onActionError(_ error: GroupsError) {
        print("GroupEditorViewModel: Действие с группой не удалось — \(error)")
        state.isSaving = false
        state.isDeleting = false
        state.actionError = groupEditorUiConverter.convertError(error)
    }
}
