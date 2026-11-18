import SwiftUI

/// Баннер ошибки над формой: для ошибок без привязки к конкретному полю.
/// Порт Android ProfileSetupErrorBanner.kt (тонкая обёртка общего ErrorBanner с кнопкой закрытия).
struct ProfileSetupErrorBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        ErrorBanner(text: text, onDismiss: onDismiss)
    }
}

#Preview {
    ProfileSetupErrorBanner(text: "Не удалось сохранить профиль. Попробуйте ещё раз", onDismiss: {})
        .padding(16)
}
