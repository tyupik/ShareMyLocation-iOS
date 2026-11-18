import SwiftUI

/// Фон-свечение AURORA: два круга радиального градиента (индиго у верхнего правого угла,
/// циан у нижнего левого), уходящие за край экрана. Порт 1:1 из Android AuroraBackdrop.kt.
/// Контент рисуется поверх.
struct AuroraBackdrop<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(AuroraBrushes.auroraGlowIndigo)
                .frame(width: Self.INDIGO_GLOW_DIAMETER, height: Self.INDIGO_GLOW_DIAMETER)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 120, y: -140)
            Circle()
                .fill(AuroraBrushes.auroraGlowCyan)
                .frame(width: Self.CYAN_GLOW_DIAMETER, height: Self.CYAN_GLOW_DIAMETER)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -150, y: 140)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Диаметр индигового свечения.
    private static let INDIGO_GLOW_DIAMETER: CGFloat = 420

    /// Диаметр цианового свечения.
    private static let CYAN_GLOW_DIAMETER: CGFloat = 460
}

#Preview {
    AuroraBackdrop {
        Color.clear
    }
    .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
