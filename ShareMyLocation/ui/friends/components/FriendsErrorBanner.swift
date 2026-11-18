import SwiftUI

/// Баннер ошибки действия над друзьями/заявками над списком секций.
/// Порт 1:1 из Android FriendsErrorBanner.kt (обёртка ErrorBanner).
struct FriendsErrorBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        ErrorBanner(text: text, onDismiss: onDismiss)
    }
}

#Preview {
    FriendsErrorBanner(text: "Не удалось выполнить действие. Попробуйте ещё раз", onDismiss: {})
        .padding(16)
}
