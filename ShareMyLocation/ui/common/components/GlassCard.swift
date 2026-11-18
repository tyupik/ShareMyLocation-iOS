import SwiftUI

/// Стеклянная карточка AURORA: полупрозрачная заливка и рамка, крупное скругление (22).
/// Порт 1:1 из Android GlassCard.kt. `isSelected` — выбранная опция: циановая заливка
/// и акцентная рамка. Паддинг не задаёт — его оставляют вызывающие (внутри карточек).
struct GlassCard<Content: View>: View {
    /// Клик по карточке; nil — некликабельная карточка.
    var action: (() -> Void)? = nil
    var isSelected: Bool = false
    @ViewBuilder var content: () -> Content

    @ViewBuilder
    var body: some View {
        if let action {
            Button(action: action) {
                cardBody
            }
            .buttonStyle(.plain)
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(content: content)
            .background(
                RoundedRectangle(cornerRadius: AuroraShapes.large)
                    .fill(isSelected ? AuroraColors.auroraSelectedGlass : AuroraColors.auroraGlass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraShapes.large)
                    .strokeBorder(
                        isSelected ? AuroraColors.auroraAccentBorder : AuroraColors.auroraGlassBorder,
                        lineWidth: 1,
                    )
            )
    }
}

#Preview {
    GlassCard {
        Text("Карточка")
            .font(.auroraBodyMedium)
            .foregroundStyle(AuroraColors.auroraText)
            .padding(16)
    }
    .padding(16)
}
