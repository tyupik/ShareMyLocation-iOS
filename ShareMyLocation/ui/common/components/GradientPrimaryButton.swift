import SwiftUI

/// Градиентная primary-кнопка AURORA (индиго → циан): единый стиль submit-кнопок.
/// Порт 1:1 из Android GradientPrimaryButton.kt. В `isLoading` вместо текста показывает
/// индикатор загрузки; disabled — приглушённый градиент.
///
/// Высота: вертикальный паддинг 8 + minHeight 44 (зона тапа Apple HIG; Android-эквивалент
/// M3 Button — contentPadding 8 + minHeight 40, точная подгонка высоты — этап 9).
struct GradientPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(AuroraColors.auroraOnGradient)
                } else {
                    Text(title)
                        .font(.auroraLabelLarge)
                        .foregroundStyle(AuroraColors.auroraOnGradient)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: AuroraShapes.medium)
                    .fill(AuroraBrushes.auroraButtonBrush)
                    .opacity(isEnabled && !isLoading ? 1 : Self.DISABLED_GRADIENT_ALPHA)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }

    /// Альфа градиента в disabled-состоянии.
    private static let DISABLED_GRADIENT_ALPHA: Double = 0.38
}

#Preview {
    VStack(spacing: 12) {
        GradientPrimaryButton(
            title: "Продолжить",
            isEnabled: true,
            isLoading: false,
            action: {},
        )
        GradientPrimaryButton(
            title: "Загрузка",
            isEnabled: true,
            isLoading: true,
            action: {},
        )
    }
    .padding(16)
}
