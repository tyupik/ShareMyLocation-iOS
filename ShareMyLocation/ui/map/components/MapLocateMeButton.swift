import SwiftUI

/**
 Круглая стеклянная кнопка центровки «Показать меня» (иконка геолокации вместо текста):
 центровка камеры на свою точку или запрос прав геолокации.
 Порт 1:1 из Android MapLocateMeButton.kt (строка map_locate_me — дословно; стеклянный
 стиль AURORA вместо системного FAB).
 */
struct MapLocateMeButton: View {
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Image(systemName: "location.fill")
                .foregroundStyle(AuroraColors.auroraText)
                .frame(width: Self.BUTTON_SIDE, height: Self.BUTTON_SIDE)
                .background(Circle().fill(AuroraColors.auroraGlass))
                .overlay(Circle().strokeBorder(AuroraColors.auroraGlassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Показать меня")
    }

    /// Сторона круглой кнопки (паттерн GlassIconButton).
    private static let BUTTON_SIDE: CGFloat = 44
}

#Preview {
    MapLocateMeButton(onClick: {})
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
