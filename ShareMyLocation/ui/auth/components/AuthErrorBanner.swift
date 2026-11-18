import SwiftUI

/// Баннер ошибки над формой: для ошибок без привязки к конкретному полю.
/// Порт Android AuthErrorBanner.kt (тонкая обёртка общего ErrorBanner с кнопкой закрытия).
struct AuthErrorBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        ErrorBanner(text: text, onDismiss: onDismiss)
    }
}

#Preview {
    AuthErrorBanner(text: "Что-то пошло не так. Попробуйте ещё раз", onDismiss: {})
        .padding(16)
}
