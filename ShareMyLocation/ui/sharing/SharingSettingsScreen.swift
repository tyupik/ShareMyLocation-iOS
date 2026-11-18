import Factory
import SwiftUI

/**
 Экран настроек шаринга геолокации: главный тумблер, выбор аудитории и секции чекбоксов
 «Люди»/«Группы». Автосохранение без кнопки «Сохранить»: каждое изменение немедленно пишется
 ViewModel'ю, `SharingSettingsUiState.isSaving` показывает индикатор «Сохранение…»,
 ошибка записи — inline-баннер. Секции выбора видны только в custom и остаются
 редактируемыми при выключенном тумблере. Подсказка о пустой аудитории — локальный
 оверлей-снекбар из Effect (аналог Snackbar Android). Перечитывание при показе — через
 `SharingSettingsIntent.screenShown`. Права геолокации: системный диалог запускается из
 Effect requestLocationPermissions во ВНУТРЕННЕМ Task (не в теле for await — иначе
 обработка эффектов застрянет за системным диалогом), результат возвращается intent'ом
 `locationPermissionsResult`. Закрытие выполняет вызывающая сторона (свайп/тап вне —
 сброс sheet-флага в MainScreen). Порт 1:1 из Android SharingSettingsScreen.kt.
 */
struct SharingSettingsScreen: View {
    @State private var viewModel: SharingSettingsViewModel

    /// Подсказка «сейчас локацию не увидит никто» — эфемерное UI-состояние Snackbar-аналога.
    @State private var isHintShown = false

    /// Задача автоскрытия подсказки: отменяется при повторном показе, чтобы ранний таймер
    /// не скрыл новую подсказку раньше срока.
    @State private var hintHideTask: Task<Void, Never>?

    init() {
        _viewModel = State(initialValue: Container.shared.sharingSettingsViewModel())
    }

    var body: some View {
        SharingSettingsContent(
            state: viewModel.state,
            onIntent: { viewModel.onIntent($0) },
        )
        .frame(maxWidth: .infinity)
        // Фон sheet'а — AURORA surfaceVariant на весь контент, чтобы состояния загрузки/
        // ошибки не показывали системный фон (паттерн GroupEditorScreen).
        .background(AuroraColors.auroraSurfaceVariant.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .overlay(alignment: .bottom) {
            if isHintShown {
                // Подсказка о пустой CUSTOM-аудитории: аналог Snackbar Android
                // (авто-скрытие без DispatchQueue).
                Text("Сейчас локацию не увидит никто: выберите людей и группы или включите \"Все друзья\"")
                    .font(.auroraBodyMedium)
                    .foregroundStyle(AuroraColors.auroraText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AuroraColors.auroraSurfaceVariant))
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHintShown)
        .task {
            // На каждый показ — чистый лист + перечитка документа + перезапуск realtime-потоков
            // (порт LaunchedEffect(Unit) Android).
            viewModel.onIntent(.screenShown)
        }
        .task {
            // Гонка «sheet закрыт свайпом, Task прав ждёт решения»: отправка
            // .locationPermissionsResult в умирающую ViewModel безвредна — состояние
            // больше никому не показывается.
            for await effect in viewModel.effects {
                switch effect {
                case .showEmptyAudienceHint:
                    showHint()
                case .requestLocationPermissions:
                    // ВНУТРЕННИЙ Task (fire-and-forget, как permissionLauncher.launch Android):
                    // ожидание системного диалога НЕ блокирует цикл эффектов — Task наследует
                    // MainActor у .task, подсказка о пустом выборе покажется, не застряв за диалогом.
                    Task {
                        let requester = Container.shared.locationPermissionRequester()
                        let granted = await requester.requestWhenInUse()
                        viewModel.onIntent(.locationPermissionsResult(granted: granted))
                    }
                }
            }
        }
    }

    /// Показ подсказки на ~2 секунды; авто-скрытие без DispatchQueue (только Task).
    /// Повторный показ отменяет предыдущий таймер скрытия: без отмены более ранний
    /// Task.sleep скрыл бы новую подсказку раньше срока.
    private func showHint() {
        hintHideTask?.cancel()
        hintHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            isHintShown = false
        }
    }
}

/// Контент экрана: производные флаги считаются здесь, а не в ViewModel
/// (чистый UI-расчёт, порт SharingSettingsContent Android).
private struct SharingSettingsContent: View {
    let state: SharingSettingsUiState
    let onIntent: (SharingSettingsIntent) -> Void

    var body: some View {
        if state.isLoading {
            ProgressView()
                .tint(AuroraColors.auroraIndigoLight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.isLoadFailed {
            SharingSettingsLoadError(
                text: loadErrorText(state.loadError),
                onRetry: { onIntent(.screenShown) },
            )
        } else {
            form
        }
    }

    private var form: some View {
        // Производный флаг: секции выбора видны только в custom (при выключенном тумблере тоже).
        let isCustomAudience = state.audience == .custom

        return ScrollView {
            VStack(spacing: 16) {
                Text("Настройки шаринга")
                    .font(.auroraHeadlineMedium)
                    .tracking(AuroraTypography.HEADLINE_TRACKING)
                    .foregroundStyle(AuroraColors.auroraText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if state.isSaving {
                    // Индикатор «Сохранение…»: контролы при автосохранении не дизейблятся.
                    Text("Сохранение…")
                        .font(.auroraTitleSmall)
                        .foregroundStyle(AuroraColors.auroraTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let saveError = state.saveError {
                    SharingSettingsErrorBanner(
                        text: errorText(saveError),
                        onDismiss: { onIntent(.saveErrorDismissed) },
                    )
                }

                if state.isPermissionMissing {
                    // Баннер «нет доступа к геолокации»: без dismiss — исчезает сам, когда права
                    // выданы (результат диалога) или документ выключен (перезагрузка по screenShown).
                    SharingPermissionBanner(
                        text: "Нет доступа к геолокации: разрешите доступ в настройках, чтобы делиться позицией",
                    )
                }

                SharingEnabledSwitch(
                    isChecked: state.isEnabled,
                    onToggle: { onIntent(.enabledToggled($0)) },
                )

                SharingAudienceOption(
                    label: "Все друзья",
                    isSelected: state.audience == .allFriends,
                    onClick: { onIntent(.audienceSelected(.allFriends)) },
                )
                SharingAudienceOption(
                    label: "Выбранные люди и группы",
                    isSelected: isCustomAudience,
                    onClick: { onIntent(.audienceSelected(.custom)) },
                )

                if isCustomAudience {
                    selectionSections
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Секции «Люди»/«Группы»: падение секции — inline-ошибка, пустая — плейсхолдер (паттерн Friends).
    @ViewBuilder
    private var selectionSections: some View {
        Text("Люди")
            .font(.auroraTitleMedium)
            .foregroundStyle(AuroraColors.auroraText)
            .frame(maxWidth: .infinity, alignment: .leading)
        if state.isFriendsLoadFailed {
            // Падение секции людей не скрывает других секций: inline-состояние + «Повторить».
            LoadError(
                text: "Не удалось загрузить настройки. Проверьте интернет и попробуйте снова",
                retryText: "Повторить",
                onRetry: { onIntent(.screenShown) },
            )
        } else if state.friends.isEmpty {
            SharingSectionPlaceholder(text: "Друзей пока нет")
        } else {
            ForEach(state.friends, id: \.id) { friend in
                SharingCheckRow(
                    row: friend,
                    onToggle: { onIntent(.friendToggled(uid: friend.id)) },
                )
            }
        }

        Text("Группы")
            .font(.auroraTitleMedium)
            .foregroundStyle(AuroraColors.auroraText)
            .frame(maxWidth: .infinity, alignment: .leading)
        if state.isGroupsLoadFailed {
            // Падение секции групп не скрывает других секций: inline-состояние + «Повторить».
            LoadError(
                text: "Не удалось загрузить настройки. Проверьте интернет и попробуйте снова",
                retryText: "Повторить",
                onRetry: { onIntent(.screenShown) },
            )
        } else if state.groups.isEmpty {
            SharingSectionPlaceholder(text: "Групп пока нет")
        } else {
            ForEach(state.groups, id: \.id) { group in
                SharingCheckRow(
                    row: group,
                    onToggle: { onIntent(.groupToggled(groupId: group.id)) },
                )
            }
        }
    }
}

/// Плейсхолдер пустой секции выбора: «Друзей пока нет» / «Групп пока нет».
private struct SharingSectionPlaceholder: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.auroraBodyMedium)
            .foregroundStyle(AuroraColors.auroraTextMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

/// Текст экрана-ошибки: сеть показывается явно, остальное — generic
/// (дословно Android loadErrorText; null-ветка — sharing_load_error).
private func loadErrorText(_ error: SharingUiError?) -> String {
    switch error {
    case .some(.network):
        return "Нет подключения к сети. Проверьте интернет и попробуйте снова"
    case .some(.unexpected):
        return "Не удалось сохранить. Попробуйте ещё раз"
    case .none:
        return "Не удалось загрузить настройки. Проверьте интернет и попробуйте снова"
    }
}

/// Текст баннера ошибки автосохранения (дословно Android errorText).
private func errorText(_ error: SharingUiError) -> String {
    switch error {
    case .network:
        return "Нет подключения к сети. Проверьте интернет и попробуйте снова"
    case .unexpected:
        return "Не удалось сохранить. Попробуйте ещё раз"
    }
}
