import SwiftUI

/**
 Экран-ошибка первичного чтения настроек шаринга: текст причины и «Повторить» —
 повторный screenShown (паттерн GroupEditorLoadError).
 Порт 1:1 из Android SharingSettingsLoadError.kt (строки — дословно sharing_retry strings.xml).
 */
struct SharingSettingsLoadError: View {
    let text: String
    let onRetry: () -> Void

    var body: some View {
        LoadError(
            text: text,
            retryText: "Повторить",
            onRetry: onRetry,
            isCentered: true,
        )
    }
}

#Preview {
    SharingSettingsLoadError(
        text: "Не удалось загрузить настройки. Проверьте интернет и попробуйте снова",
        onRetry: {},
    )
}
