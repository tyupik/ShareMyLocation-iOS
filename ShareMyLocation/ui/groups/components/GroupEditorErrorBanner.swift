import SwiftUI

/// Баннер ошибки действия над группой (сохранить/удалить) над формой редактора.
struct GroupEditorErrorBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        ErrorBanner(text: text, onDismiss: onDismiss)
    }
}
