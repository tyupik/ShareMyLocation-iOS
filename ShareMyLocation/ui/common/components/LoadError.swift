import SwiftUI

/// Состояние ошибки загрузки AURORA: текст причины и кнопка повтора.
/// Порт 1:1 из Android LoadError.kt. `isCentered` — экран-ошибка целиком
/// (центр + паддинг 24); иначе inline-состояние секции (вертикальный отступ 16).
/// `retryText` — строка повтора, у фич разные ресурсы.
struct LoadError: View {
    let text: String
    let retryText: String
    let onRetry: () -> Void
    var isCentered: Bool = false

    @ViewBuilder
    var body: some View {
        if isCentered {
            column
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
        } else {
            column
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
    }

    private var column: some View {
        VStack {
            Text(text)
                .font(.auroraBodyMedium)
                .lineSpacing(AuroraTypography.BODY_MEDIUM_LINE_SPACING)
                .foregroundStyle(AuroraColors.auroraTextMuted)
                .multilineTextAlignment(.center)
            Button {
                onRetry()
            } label: {
                Text(retryText)
                    .font(.auroraLabelLarge)
                    .foregroundStyle(AuroraColors.auroraIndigoLight)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    LoadError(
        text: "Не удалось загрузить друзей",
        retryText: "Повторить",
        onRetry: {},
    )
    .padding(16)
}
