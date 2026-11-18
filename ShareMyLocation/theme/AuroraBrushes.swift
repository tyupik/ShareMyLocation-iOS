import SwiftUI

/// Градиенты AURORA: порт 1:1 из Android `ui/theme/Brush.kt`.
/// Кнопки/активные пилюли — горизонталь (96° макета ≈ горизонталь),
/// кольца аватаров — диагональ (135°), свечение фона — радиальный спад альфы к прозрачному.
enum AuroraBrushes {
    /// Primary-кнопка: индиго → циан.
    static let auroraButtonBrush = LinearGradient(
        colors: [AuroraColors.auroraIndigo, AuroraColors.auroraCyan],
        startPoint: .leading,
        endPoint: .trailing,
    )

    /// Кольца аватаров: диагональный индиго → циан.
    static let auroraAvatarBrush = LinearGradient(
        colors: [AuroraColors.auroraIndigo, AuroraColors.auroraCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Зарезервирован для акцентного градиентного текста (светлые акценты индиго → циан).
    static let auroraAccentBrush = LinearGradient(
        colors: [AuroraColors.auroraIndigoLight, AuroraColors.auroraCyan],
        startPoint: .leading,
        endPoint: .trailing,
    )

    /// Свечение фона: индиго 0.67 → прозрачный.
    /// endRadius — половина диаметра свечения AuroraBackdrop (420 / 2 = 210).
    static let auroraGlowIndigo = RadialGradient(
        colors: [AuroraColors.auroraIndigo.opacity(0.67), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 210,
    )

    /// Свечение фона: циан 0.53 → прозрачный.
    /// endRadius — половина диаметра свечения AuroraBackdrop (460 / 2 = 230).
    static let auroraGlowCyan = RadialGradient(
        colors: [AuroraColors.auroraCyan.opacity(0.53), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 230,
    )
}
