import SwiftUI

/// Баннер ошибки AURORA (errorContainer): текст и опциональная кнопка закрытия.
/// Порт 1:1 из Android ErrorBanner.kt. `onDismiss == nil` — без кнопки закрытия
/// (кейс баннера «нет доступа к геолокации»).
struct ErrorBanner: View {
    let text: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onDismiss {
                HStack {
                    Text(text)
                        .font(.auroraBodyMedium)
                        .lineSpacing(AuroraTypography.BODY_MEDIUM_LINE_SPACING)
                        .foregroundStyle(AuroraColors.auroraOnErrorContainer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AuroraColors.auroraOnErrorContainer)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
            } else {
                Text(text)
                    .font(.auroraBodyMedium)
                    .lineSpacing(AuroraTypography.BODY_MEDIUM_LINE_SPACING)
                    .foregroundStyle(AuroraColors.auroraOnErrorContainer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AuroraShapes.medium)
                .fill(AuroraColors.auroraErrorContainer)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        ErrorBanner(text: "Неверный email или пароль", onDismiss: {})
        ErrorBanner(text: "Нет доступа к геолокации")
    }
    .padding(16)
}
