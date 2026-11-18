import Contacts
import Factory
import SwiftUI

/**
 Вкладка «Друзья»: поиск по номеру телефона (вручную или из контактов через
 CNContactPickerViewController — пикер без разрешений), список друзей и группы. Входящие
 заявки — в sheet'е по колокольчику (FriendsHeader, состояние FriendsUiState.isRequestsSheetVisible),
 чтобы не забивать тело вкладки. Realtime-обновления приходят потоками из интеракторов;
 перечитывание при показе вкладки выполняется через FriendsIntent.screenShown.
 Эффекты: friendRequestSent показывается оверлеем «Заявка отправлена» (аналог Snackbar),
 openGroupEditor уходит в onOpenGroupEditor. Удаление друга идёт через confirmationDialog
 (состояние FriendsUiState.removeDialogFriend). Порт 1:1 из Android FriendsScreen.kt.
 */
struct FriendsScreen: View {
    let onOpenGroupEditor: (String?) -> Void

    @State private var viewModel: FriendsViewModel

    /// Оверлей «Заявка отправлена» — эфемерное UI-состояние показа Snackbar-аналога.
    @State private var isRequestSentOverlayShown = false

    /// Задача автоскрытия оверлея: отменяется при повторном показе, чтобы ранний таймер
    /// не скрыл новый оверлей раньше срока.
    @State private var requestSentHideTask: Task<Void, Never>?

    /// Системный контакт-пикер: CNContact отдаёт выбранный контакт целиком.
    @State private var isContactsPickerPresented = false

    init(onOpenGroupEditor: @escaping (String?) -> Void) {
        self.onOpenGroupEditor = onOpenGroupEditor
        _viewModel = State(initialValue: Container.shared.friendsViewModel())
    }

    var body: some View {
        AuroraBackdrop {
            FriendsContent(
                state: viewModel.state,
                onIntent: { viewModel.onIntent($0) },
                onPickContact: { isContactsPickerPresented = true },
            )
            // Системный пикер контактов: sheet висит на контенте вкладки, чтобы презентации
            // не конфликтовали с sheet'ом заявок на внешнем контейнере.
            .sheet(isPresented: $isContactsPickerPresented) {
                ContactsPickerView { contact in
                    // Закрываем sheet и отдаём контакт в ViewModel (nil — закрыто без выбора).
                    isContactsPickerPresented = false
                    viewModel.onIntent(.contactPicked(contact))
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.state.isRequestsSheetVisible },
                set: { newValue in
                    // Закрытие sheet'а (свайп, тап вне) — сброс флага состояния.
                    if !newValue {
                        viewModel.onIntent(.requestsSheetDismissed)
                    }
                },
            ),
        ) {
            FriendsRequestsSheet(
                requests: viewModel.state.incomingRequests,
                busyUid: viewModel.state.busyUid,
                isRequestsLoadFailed: viewModel.state.isRequestsLoadFailed,
                errorText: viewModel.state.actionError.map(errorText),
                onAcceptClick: { viewModel.onIntent(.acceptRequestClicked(fromUid: $0)) },
                onDeclineClick: { viewModel.onIntent(.declineRequestClicked(fromUid: $0)) },
                onRetry: { viewModel.onIntent(.screenShown) },
            )
        }
        .modifier(
            FriendRemoveConfirmDialog(
                friendName: viewModel.state.removeDialogFriend?.displayName ?? "",
                isBusy: viewModel.state.busyUid == viewModel.state.removeDialogFriend?.uid,
                isPresented: Binding(
                    get: { viewModel.state.removeDialogFriend != nil },
                    set: { newValue in
                        // Закрытие диалога любым способом без подтверждения — снять снимок.
                        if !newValue {
                            viewModel.onIntent(.removeFriendDialogDismissed)
                        }
                    },
                ),
                onConfirm: { viewModel.onIntent(.removeFriendConfirmed) },
            ),
        )
        .overlay(alignment: .bottom) {
            if isRequestSentOverlayShown {
                // Заявка отправлена: аналог Snackbar Android (авто-скрытие без DispatchQueue).
                Text("Заявка отправлена")
                    .font(.auroraBodyMedium)
                    .foregroundStyle(AuroraColors.auroraText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AuroraColors.auroraSurfaceVariant))
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRequestSentOverlayShown)
        .task {
            // На каждый показ — перезапуск realtime-потоков (порт LaunchedEffect(Unit) Android).
            viewModel.onIntent(.screenShown)
        }
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case .friendRequestSent:
                    showRequestSentOverlay()
                case .openGroupEditor(let groupId):
                    onOpenGroupEditor(groupId)
                }
            }
        }
    }

    /// Показ оверлея на ~2 секунды; авто-скрытие без DispatchQueue (только Task).
    /// Повторный показ отменяет предыдущий таймер скрытия: без отмены более ранний
    /// Task.sleep скрыл бы новый оверлей раньше срока.
    private func showRequestSentOverlay() {
        requestSentHideTask?.cancel()
        requestSentHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            isRequestSentOverlayShown = false
        }
    }
}

/// Тело вкладки: секции поиска, друзей и групп. Порт FriendsContent Android
/// (LazyColumn → ScrollView + VStack, spacing 8, паддинги 16).
private struct FriendsContent: View {
    let state: FriendsUiState
    let onIntent: (FriendsIntent) -> Void
    let onPickContact: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                FriendsHeader(
                    requestCount: state.incomingRequests.count,
                    onBellClick: { onIntent(.requestsBellClicked) },
                )
                HStack(spacing: 8) {
                    FriendsSearchField(
                        text: Binding(
                            get: { state.searchQuery },
                            set: { onIntent(.searchQueryChanged($0)) },
                        ),
                        isEnabled: state.busyUid == nil,
                        onSubmit: { onIntent(.searchClicked) },
                        onClear: { onIntent(.searchCleared) },
                    )
                    FriendsPickContactButton(
                        isEnabled: state.busyUid == nil,
                        onClick: onPickContact,
                    )
                }
                if let actionError = state.actionError {
                    FriendsErrorBanner(
                        text: errorText(actionError),
                        onDismiss: { onIntent(.errorDismissed) },
                    )
                }
                switch state.searchState {
                case .idle:
                    EmptyView()
                case .loading:
                    sectionProgress
                case .found(let user):
                    FriendsSearchResultCard(
                        user: user,
                        isBusy: state.busyUid == user.uid,
                        onAddClick: { onIntent(.addFriendClicked(uid: user.uid)) },
                    )
                case .notFound:
                    FriendsEmptyState(text: "Пользователь с таким номером не найден")
                case .error(let error):
                    Text(errorText(error))
                        .font(.auroraBodyMedium)
                        .foregroundStyle(AuroraColors.auroraTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Друзья")
                    .font(.auroraTitleMedium)
                    .foregroundStyle(AuroraColors.auroraText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                if state.isFriendsLoadFailed {
                    // Падение секции друзей не скрывает других секций: inline-состояние + «Повторить».
                    FriendsLoadError(onRetry: { onIntent(.screenShown) })
                } else if state.isFriendsLoading {
                    sectionProgress
                } else if state.friends.isEmpty {
                    FriendsEmptyState(text: "Друзей пока нет")
                } else {
                    ForEach(state.friends, id: \.uid) { friend in
                        FriendCard(
                            friend: friend,
                            isBusy: state.busyUid == friend.uid,
                            onRemoveClick: { onIntent(.removeFriendClicked(uid: friend.uid)) },
                        )
                    }
                }
                GroupsHeader(onCreateClick: { onIntent(.createGroupClicked) })
                if state.isGroupsLoadFailed {
                    // Падение секции групп не скрывает других секций: inline-состояние + «Повторить».
                    FriendsLoadError(onRetry: { onIntent(.screenShown) })
                } else if state.isGroupsLoading {
                    sectionProgress
                } else if state.groups.isEmpty {
                    FriendsEmptyState(text: "Групп пока нет")
                } else {
                    ForEach(state.groups, id: \.groupId) { group in
                        GroupCard(
                            group: group,
                            onGroupClick: { onIntent(.groupClicked(groupId: group.groupId)) },
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Спиннер секции: центр строки, вертикальный отступ 16 (порт Android-секции loading).
    private var sectionProgress: some View {
        ProgressView()
            .tint(AuroraColors.auroraIndigoLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
}

/// Тексты ошибок — дословно Android strings.xml (friends_error_*).
private func errorText(_ error: FriendsUiError) -> String {
    switch error {
    case .network:
        return "Нет подключения к сети. Проверьте интернет и попробуйте снова"
    case .invalidPhone:
        return "Введите корректный номер телефона (10–15 цифр)"
    case .requestToSelf:
        return "Нельзя добавить себя в друзья"
    case .alreadyFriends:
        return "Вы уже друзья"
    case .requestAlreadySent:
        return "Заявка этому пользователю уже отправлена"
    case .requestAlreadyIncoming:
        return "Этот пользователь уже отправил вам заявку — примите её в списке заявок"
    case .contactNoPhone:
        return "У выбранного контакта нет телефона"
    case .contactReadFailed:
        return "Не удалось прочитать контакт. Попробуйте выбрать ещё раз"
    case .unexpected:
        return "Не удалось выполнить действие. Попробуйте ещё раз"
    }
}

#Preview {
    FriendsContent(
        state: FriendsUiState(isFriendsLoading: false),
        onIntent: { _ in },
        onPickContact: {},
    )
    .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
