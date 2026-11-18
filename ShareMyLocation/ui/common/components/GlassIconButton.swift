import SwiftUI

/// Квадратная стеклянная кнопка-иконка AURORA (стекло + рамка, скругление 16):
/// колокольчик заявок в друзьях, кнопки-иконки рядом с полем поиска.
/// Порт 1:1 из Android GlassIconButton.kt. `badge` — необязательный бейдж поверх
/// стеклянного квадрата (правый верхний угол).
struct GlassIconButton<Badge: View>: View {
    let systemImage: String
    let accessibilityLabel: String?
    let action: () -> Void
    var isEnabled: Bool = true
    @ViewBuilder var badge: () -> Badge

    init(
        systemImage: String,
        accessibilityLabel: String?,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        @ViewBuilder badge: @escaping () -> Badge = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.isEnabled = isEnabled
        self.badge = badge
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(AuroraColors.auroraText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(width: Self.GLASS_ICON_BUTTON_SIDE, height: Self.GLASS_ICON_BUTTON_SIDE)
        .background(
            RoundedRectangle(cornerRadius: AuroraShapes.medium)
                .fill(AuroraColors.auroraGlass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraShapes.medium)
                .strokeBorder(AuroraColors.auroraGlassBorder, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            badge()
        }
        .accessibilityLabel(accessibilityLabel.map(Text.init))
    }

    /// Сторона квадратной стеклянной кнопки.
    private static let GLASS_ICON_BUTTON_SIDE: CGFloat = 44
}

#Preview {
    GlassIconButton(
        systemImage: "bell",
        accessibilityLabel: "Заявки",
        action: {},
    )
}
