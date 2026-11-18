import SwiftUI

/// Кнопка запроса удаления группы; доступна только в режиме редактирования
/// (порт Android GroupEditorDeleteButton.kt: TextButton с colorScheme.error).
struct GroupEditorDeleteButton: View {
    let isEnabled: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text("Удалить группу")
                .font(.auroraLabelLarge)
                .foregroundStyle(AuroraColors.auroraDanger)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    GroupEditorDeleteButton(isEnabled: true, onClick: {})
        .padding(16)
}
