import SwiftUI

/**
 Inline-баннер «нет доступа к геолокации» (паттерн SharingSettingsErrorBanner Android).
 Без кнопки закрытия: состояние isPermissionMissing сбрасывается не пользователем, а
 фактом выдачи прав (результат системного диалога) или выключением шаринга (screenShown).
 Порт 1:1 из Android SharingPermissionBanner.kt.
 */
struct SharingPermissionBanner: View {
    let text: String

    var body: some View {
        ErrorBanner(text: text)
    }
}

#Preview {
    SharingPermissionBanner(text: "Нет доступа к геолокации: разрешите доступ в настройках, чтобы делиться позицией")
        .padding(16)
}
