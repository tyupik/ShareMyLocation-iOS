import SwiftUI

/// Палитра AURORA «ночной неон»: порт 1:1 из Android `ui/theme/Color.kt`.
/// Единственное место проекта, где допустимы hex-значения цветов.
enum AuroraColors {
    static let auroraBackground = Color(hex: 0x0B1020)
    static let auroraText = Color(hex: 0xF1F5F9)
    static let auroraTextMuted = Color(hex: 0x8A94AD)

    /// Градиентные акценты: индиго → циан.
    static let auroraIndigo = Color(hex: 0x6366F1)
    static let auroraIndigoLight = Color(hex: 0x818CF8)
    static let auroraCyan = Color(hex: 0x22D3EE)
    static let auroraMint = Color(hex: 0x34D399)
    static let auroraOnGradient = Color(hex: 0x041018)

    /// «Стекло»: полупрозрачные заливки и рамки карточек/пилюль.
    /// Альфа — точное значение из ARGB Android: 0x0EFFFFFF (α 0x0E ≈ 0.055).
    static let auroraGlass = Color(white: 1, opacity: 0.055)
    /// ARGB 0x1AFFFFFF (α 0x1A ≈ 0.102).
    static let auroraGlassBorder = Color(white: 1, opacity: 0.102)
    /// ARGB 0x8C22D3EE (α 0x8C ≈ 0.549).
    static let auroraAccentBorder = Color(hex: 0x22D3EE, alpha: 0.549)
    /// ARGB 0x1222D3EE (α 0x12 ≈ 0.071).
    static let auroraSelectedGlass = Color(hex: 0x22D3EE, alpha: 0.071)

    /// Danger-стекло (ghost-danger кнопка выхода).
    /// ARGB 0x14F87171 (α 0x14 ≈ 0.078).
    static let auroraDangerGlass = Color(hex: 0xF87171, alpha: 0.078)
    /// ARGB 0x38F87171 (α 0x38 ≈ 0.220).
    static let auroraDangerBorder = Color(hex: 0xF87171, alpha: 0.220)

    /// Роли контейнеров из Android `Theme.kt`, нужные общим компонентам.
    static let auroraSurfaceVariant = Color(hex: 0x1B2440)
    static let auroraErrorContainer = Color(hex: 0x2A1518)
    static let auroraOnErrorContainer = Color(hex: 0xFDA4A4)

    /// Палитра неоновых колец маркеров друзей (детерминированный выбор по uid).
    static let markerNeonColors: [Color] = [
        Color(hex: 0xF472B6),
        Color(hex: 0x34D399),
        Color(hex: 0xA78BFA),
        Color(hex: 0xFBBF24),
        Color(hex: 0x22D3EE),
        Color(hex: 0x38BDF8),
        Color(hex: 0xFB7185),
        Color(hex: 0xFB923C),
    ]
}

private extension Color {
    /// RGB-hex (0xRRGGBB) с опциональной альфой; используется только внутри дизайн-системы.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha,
        )
    }
}
