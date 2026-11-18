import SwiftUI

/// Кнопка сохранения группы; в `isLoading` вместо текста показывает индикатор загрузки.
struct GroupEditorSaveButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let onClick: () -> Void

    var body: some View {
        GradientPrimaryButton(
            title: "Сохранить",
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: onClick,
        )
    }
}

#Preview {
    GroupEditorSaveButton(isEnabled: true, isLoading: false, onClick: {})
        .padding(16)
}
