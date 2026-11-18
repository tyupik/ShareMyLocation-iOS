import SwiftUI

/**
 Диалог подтверждения удаления группы. Порт 1:1 из Android GroupDeleteConfirmDialog.kt
 (M3 AlertDialog → confirmationDialog; строки — дословно groups_delete_dialog_*).
 ViewModifier: состояние isPresented держит вызывающая сторона (GroupEditorScreen,
 флаг isDeleteDialogVisible из UiState), кнопка «Удалить» — destructive.
 */
struct GroupDeleteConfirmDialog: ViewModifier {
    let groupName: String
    let isBusy: Bool
    let isPresented: Binding<Bool>
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Удалить группу?",
            isPresented: isPresented,
            titleVisibility: .visible,
        ) {
            Button("Удалить", role: .destructive, action: onConfirm)
                .disabled(isBusy)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(
                "Группа «\(groupName)» будет удалена. "
                    + "Друзья останутся в вашем списке, участники не узнают об удалении",
            )
        }
    }
}
