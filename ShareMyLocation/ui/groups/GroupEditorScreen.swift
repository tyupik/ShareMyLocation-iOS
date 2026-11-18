import Factory
import SwiftUI

/**
 Экран управления группой: `groupId` == nil — создание, иначе — редактирование существующей.
 Навигацию выполняет вызывающая сторона через `onClosed`: экран сам не знает про back stack,
 лямбда вызывается только из коллекции Effect. Перечитывание при показе экрана — через
 `GroupEditorIntent.screenShown`. Порт 1:1 из Android GroupEditorScreen.kt
 (M3 Column/LazyColumn → VStack/ScrollView; строки — дословно groups_* strings.xml).
 */
struct GroupEditorScreen: View {
    let groupId: String?
    let onClosed: () -> Void

    @State private var viewModel: GroupEditorViewModel

    init(groupId: String?, onClosed: @escaping () -> Void) {
        self.groupId = groupId
        self.onClosed = onClosed
        _viewModel = State(initialValue: Container.shared.groupEditorViewModel())
    }

    var body: some View {
        GroupEditorContent(
            state: viewModel.state,
            onIntent: { viewModel.onIntent($0) },
        )
        .frame(maxWidth: .infinity)
        // Фон sheet'а — как в FriendsRequestsSheet (AURORA surfaceVariant), на весь контент,
        // чтобы состояния загрузки/ошибки не показывали системный фон.
        .background(AuroraColors.auroraSurfaceVariant.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .task {
            // На каждый показ — чистый лист + перезапуск realtime-потока друзей
            // (порт LaunchedEffect(Unit) Android).
            viewModel.onIntent(.screenShown(groupId: groupId))
        }
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case .closed:
                    onClosed()
                }
            }
        }
    }
}

/// Контент экрана: производные флаги считаются здесь, а не в ViewModel
/// (чистый UI-расчёт, порт GroupEditorContent Android).
private struct GroupEditorContent: View {
    let state: GroupEditorUiState
    let onIntent: (GroupEditorIntent) -> Void

    var body: some View {
        if state.isLoading {
            ProgressView()
                .tint(AuroraColors.auroraIndigoLight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.isLoadFailed {
            GroupEditorLoadError(
                text: loadErrorText(state.loadError),
                onRetry: { onIntent(.screenShown(groupId: state.groupId)) },
            )
        } else {
            form
                .modifier(
                    GroupDeleteConfirmDialog(
                        groupName: state.name,
                        isBusy: state.isDeleting,
                        isPresented: Binding(
                            get: { state.isDeleteDialogVisible },
                            set: { newValue in
                                // Закрытие диалога любым способом без подтверждения — снять флаг.
                                if !newValue {
                                    onIntent(.deleteDialogDismissed)
                                }
                            },
                        ),
                        onConfirm: { onIntent(.deleteConfirmed) },
                    ),
                )
        }
    }

    private var form: some View {
        // Производные флаги экрана: чистый UI-расчёт, не бизнес-состояние. Пустой состав допустим.
        let isCreateMode = state.groupId == nil
        let selectedCount = state.friends.filter(\.isChecked).count
        let canSave = !state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !state.isSaving && !state.isLoading

        return VStack(spacing: 16) {
            Text(isCreateMode ? "Новая группа" : "Редактирование группы")
                .font(.auroraHeadlineMedium)
                .tracking(AuroraTypography.HEADLINE_TRACKING)
                .foregroundStyle(AuroraColors.auroraText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionError = state.actionError {
                GroupEditorErrorBanner(
                    text: actionErrorText(actionError),
                    onDismiss: { onIntent(.errorDismissed) },
                )
            }

            GroupEditorNameField(
                text: Binding(
                    get: { state.name },
                    set: { onIntent(.nameChanged($0)) },
                ),
                isEnabled: !state.isSaving,
            )

            Text("Выбрано участников: \(selectedCount)")
                .font(.auroraTitleSmall)
                .foregroundStyle(AuroraColors.auroraTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(state.friends, id: \.uid) { member in
                        GroupMemberCheckRow(
                            member: member,
                            isEnabled: !state.isSaving,
                            onToggle: { onIntent(.memberToggled(uid: member.uid)) },
                        )
                    }
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            GroupEditorSaveButton(
                isEnabled: canSave,
                isLoading: state.isSaving,
                onClick: { onIntent(.saveClicked) },
            )
            if !isCreateMode {
                GroupEditorDeleteButton(
                    isEnabled: !state.isSaving && !state.isDeleting,
                    onClick: { onIntent(.deleteClicked) },
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Текст экрана-ошибки: groupNotFound/сеть показываются явно, остальное — generic
/// (дословно Android loadErrorText; null-ветка и emptyName/nameTooLong — groups_load_error).
private func loadErrorText(_ error: GroupsUiError?) -> String {
    switch error {
    case .some(.network):
        return "Нет подключения к сети. Проверьте интернет и попробуйте снова"
    case .some(.groupNotFound):
        return "Группа не найдена. Возможно, она уже удалена"
    case .some(.unexpected):
        return "Не удалось выполнить действие. Попробуйте ещё раз"
    case .some(.emptyName), .some(.nameTooLong), .none:
        return "Не удалось загрузить группу. Проверьте интернет и попробуйте снова"
    }
}

/// Текст баннера ошибки действия (дословно Android actionErrorText).
private func actionErrorText(_ error: GroupsUiError) -> String {
    switch error {
    case .network:
        return "Нет подключения к сети. Проверьте интернет и попробуйте снова"
    case .emptyName:
        return "Введите название группы"
    case .nameTooLong:
        return "Название слишком длинное (максимум 50 символов)"
    case .groupNotFound:
        return "Группа не найдена. Возможно, она уже удалена"
    case .unexpected:
        return "Не удалось выполнить действие. Попробуйте ещё раз"
    }
}
