import SwiftUI

/// Inline-состояние упавшей секции: строка ошибки и «Повторить»
/// (перезапускает потоки по screenShown). Порт 1:1 из Android FriendsLoadError.kt
/// (строки — дословно friends_load_error/friends_retry).
struct FriendsLoadError: View {
    let onRetry: () -> Void

    var body: some View {
        LoadError(
            text: "Не удалось загрузить. Проверьте интернет и попробуйте снова",
            retryText: "Повторить",
            onRetry: onRetry,
        )
    }
}

#Preview {
    FriendsLoadError(onRetry: {})
        .padding(16)
}
