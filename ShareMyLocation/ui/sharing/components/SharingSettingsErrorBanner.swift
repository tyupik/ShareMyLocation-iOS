import SwiftUI

/**
 Баннер ошибки автосохранения настроек шаринга над формой (паттерн GroupEditorErrorBanner).
 Порт 1:1 из Android SharingSettingsErrorBanner.kt.
 */
struct SharingSettingsErrorBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        ErrorBanner(text: text, onDismiss: onDismiss)
    }
}

#Preview {
    SharingSettingsErrorBanner(text: "Не удалось сохранить. Попробуйте ещё раз", onDismiss: {})
        .padding(16)
}
