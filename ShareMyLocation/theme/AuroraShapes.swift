import CoreGraphics

/// Скругления AURORA: порт 1:1 из Android `ui/theme/Shape.kt`.
/// Карточки — 22 (large), поля/кнопки — 16 (medium), нижняя навигация — 28 (extraLarge),
/// мелкие элементы — 12 (small).
enum AuroraShapes {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 22
    static let extraLarge: CGFloat = 28
}
