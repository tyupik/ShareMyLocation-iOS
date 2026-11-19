import SwiftUI

/// Типографика AURORA: Manrope, порт 1:1 таблицы из Android `ui/theme/Type.kt`.
/// Вес задаётся PostScript-именем статического инстанса из Resources/Fonts
/// (Manrope-Regular/Medium/SemiBold/Bold/ExtraBold).
///
/// Таблица M3 (размер/lineHeight/letterSpacing, pt) — для сверки при полировке (этап 9);
/// Font API SwiftUI не несёт line-height, межстрочный интервал задаётся на `Text`
/// через `.lineSpacing(lineHeight - размер)`, мелкий положительный letterSpacing — `.tracking()`:
///
/// | Стиль             | Вес       | Размер | lineHeight | letterSpacing |
/// |-------------------|-----------|--------|------------|---------------|
/// | auroraDisplayLarge  | ExtraBold | 57     | 64         | −0.5          |
/// | auroraDisplayMedium | ExtraBold | 45     | 52         | −0.5          |
/// | auroraDisplaySmall  | ExtraBold | 36     | 44         | −0.5          |
/// | auroraHeadlineLarge | ExtraBold | 32     | 40         | −0.5          |
/// | auroraHeadlineMedium| ExtraBold | 28     | 36         | −0.5          |
/// | auroraHeadlineSmall | ExtraBold | 24     | 32         | −0.5          |
/// | auroraTitleLarge    | Bold      | 22     | 28         | —             |
/// | auroraTitleMedium   | SemiBold  | 16     | 24         | 0.15          |
/// | auroraTitleSmall    | SemiBold  | 14     | 20         | 0.1           |
/// | auroraBodyLarge     | Regular   | 16     | 24         | 0.5           |
/// | auroraBodyMedium    | Medium    | 14     | 20         | 0.25          |
/// | auroraBodySmall     | Medium    | 12     | 16         | 0.4           |
/// | auroraLabelLarge    | SemiBold  | 14     | 20         | 0.1           |
/// | auroraLabelMedium   | SemiBold  | 12     | 16         | 0.5           |
/// | auroraLabelSmall    | SemiBold  | 11     | 16         | 0.5           |
enum AuroraTypography {
    /// Отрицательный трекинг заголовков ExtraBold (макет −0.02em): применяется на `Text`
    /// через `.tracking(AuroraTypography.HEADLINE_TRACKING)`.
    static let HEADLINE_TRACKING: CGFloat = -0.5

    /// Межстрочный интервал body-стилей (lineHeight − размер из M3-таблицы выше): применяется
    /// на многострочных `Text` через `.lineSpacing(...)`; на однострочных — no-op.
    static let BODY_SMALL_LINE_SPACING: CGFloat = 4   // 16 − 12
    static let BODY_MEDIUM_LINE_SPACING: CGFloat = 6  // 20 − 14
    static let BODY_LARGE_LINE_SPACING: CGFloat = 8   // 24 − 16
}

/// Aurora-стили текста. Системные `Font`-расширения не переопределяются.
extension Font {
    static var auroraDisplayLarge: Font { .custom("Manrope-ExtraBold", size: 57) }
    static var auroraDisplayMedium: Font { .custom("Manrope-ExtraBold", size: 45) }
    static var auroraDisplaySmall: Font { .custom("Manrope-ExtraBold", size: 36) }

    static var auroraHeadlineLarge: Font { .custom("Manrope-ExtraBold", size: 32) }
    static var auroraHeadlineMedium: Font { .custom("Manrope-ExtraBold", size: 28) }
    static var auroraHeadlineSmall: Font { .custom("Manrope-ExtraBold", size: 24) }

    static var auroraTitleLarge: Font { .custom("Manrope-Bold", size: 22) }
    static var auroraTitleMedium: Font { .custom("Manrope-SemiBold", size: 16) }
    static var auroraTitleSmall: Font { .custom("Manrope-SemiBold", size: 14) }

    static var auroraBodyLarge: Font { .custom("Manrope-Regular", size: 16) }
    static var auroraBodyMedium: Font { .custom("Manrope-Medium", size: 14) }
    static var auroraBodySmall: Font { .custom("Manrope-Medium", size: 12) }

    static var auroraLabelLarge: Font { .custom("Manrope-SemiBold", size: 14) }
    static var auroraLabelMedium: Font { .custom("Manrope-SemiBold", size: 12) }
    static var auroraLabelSmall: Font { .custom("Manrope-SemiBold", size: 11) }
}
