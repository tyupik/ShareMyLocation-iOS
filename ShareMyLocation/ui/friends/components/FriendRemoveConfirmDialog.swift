import SwiftUI

/**
 Диалог подтверждения удаления друга. Порт 1:1 из Android FriendRemoveConfirmDialog.kt
 (M3 AlertDialog → confirmationDialog; строки — дословно friends_remove_dialog_*).
 ViewModifier: состояние isPresented держит вызывающая сторона (FriendsScreen,
 снимок removeDialogFriend из UiState), кнопка «Удалить» — destructive.
 */
struct FriendRemoveConfirmDialog: ViewModifier {
    let friendName: String
    let isBusy: Bool
    let isPresented: Binding<Bool>
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Удалить друга?",
            isPresented: isPresented,
            titleVisibility: .visible,
        ) {
            Button("Удалить", role: .destructive, action: onConfirm)
                .disabled(isBusy)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("\(friendName) будет удалён из ваших друзей. Вы перестанете видеть его геопозицию, а он — вашу")
        }
    }
}
