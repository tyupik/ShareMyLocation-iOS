import SwiftUI
import UIKit

/**
 Фабрика иконок маркеров друзей: круглая аватар-иконка с неоновым кольцом AURORA.
 Не-View хелпер (аналог rememberFriendMarkerIcon Android, вынесенный из композиции):
 UIGraphicsImageRenderer 40pt, кэш NSCache по ключу «uid|путь файла аватара», лимит ~32.
 Цвет кольца выбирается из AuroraColors.markerNeonColors детерминированно по uid —
 порт Java String.hashCode (Swift String.hash рандомизирован, индексы должны совпадать
 с Android). Аватар center-crop + клип по кругу; без аватара — круг с инициалом
 (паттерн плейсхолдера ProfileAvatar). Вызывается на main-потоке (из Coordinator карты).
 */
enum FriendMarkerIconFactory {
    /// Кэш иконок: ключ — композитный «uid|путь файла аватара», лимит ~32 — стартовый.
    private static let iconCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = MARKER_ICON_CACHE_SIZE
        return cache
    }()

    /**
     Иконка маркера: кольцо цвета по uid, заливка auroraSurfaceVariant, аватар либо инициал.
     Иконка пересоздаётся ТОЛЬКО при смене ключа (uid|avatarPath): тики координат двигают
     маркер без пересоздания иконки (Coordinator карты следит за сменой ключа).
     */
    static func icon(uid: String, avatarPath: String?, displayName: String) -> UIImage {
        let cacheKey = "\(uid)|\(avatarPath ?? "")" as NSString
        if let cached = iconCache.object(forKey: cacheKey) {
            return cached
        }
        let ringColor = UIColor(markerRingColor(uid: uid))
        let circleColor = UIColor(AuroraColors.auroraSurfaceVariant)
        let textColor = UIColor(AuroraColors.auroraTextMuted)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: CIRCLE_SIZE, height: CIRCLE_SIZE))
        let image = renderer.image { context in
            let center = CGPoint(x: CIRCLE_SIZE / 2, y: CIRCLE_SIZE / 2)
            let radius = CIRCLE_SIZE / 2 - BORDER_WIDTH

            // Неоновое кольцо: круг во весь холст.
            ringColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: CIRCLE_SIZE, height: CIRCLE_SIZE))

            // Заливка внутреннего круга.
            let circleRect = CGRect(
                x: BORDER_WIDTH,
                y: BORDER_WIDTH,
                width: radius * 2,
                height: radius * 2,
            )
            circleColor.setFill()
            context.cgContext.fillEllipse(in: circleRect)

            if let avatar = squareAvatar(from: avatarPath) {
                // Аватар: center-crop квадрат, клип по внутреннему кругу.
                context.cgContext.saveGState()
                context.cgContext.addEllipse(in: circleRect)
                context.cgContext.clip()
                avatar.draw(in: circleRect)
                context.cgContext.restoreGState()
            } else {
                // Инициал: первая буква имени, bold, 0.4 стороны круга.
                drawInitial(displayName: displayName, textColor: textColor, center: center)
            }
        }
        iconCache.setObject(image, forKey: cacheKey)
        return image
    }

    /** Цвет кольца по uid: порт Math.floorMod(hashCode, 8) — всегда неотрицательный индекс. */
    static func markerRingColor(uid: String) -> Color {
        let count = Int32(MARKER_NEON_COLORS_COUNT)
        let hash = javaHashCode(uid)
        let index = Int(((hash % count) + count) % count)
        return AuroraColors.markerNeonColors[index]
    }

    /**
     Порт Java String.hashCode: h = 31*h + c в Int32 с переполнением (&* &+), c — UTF-16
     код-юнит (char Java). Swift String.hash рандомизирован и не годится: индексы цветов
     должны совпадать с Android при одном uid.
     */
    private static func javaHashCode(_ string: String) -> Int32 {
        var hash: Int32 = 0
        for unit in string.utf16 {
            hash = hash &* 31 &+ Int32(unit)
        }
        return hash
    }

    /**
     Аватар из файла кэша, обрезанный center-crop до квадрата минимальной стороны
     (порт BitmapFactory-ветки Android); nil — файла нет или не читается.
     */
    private static func squareAvatar(from path: String?) -> UIImage? {
        guard let path, let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        let side = min(image.size.width, image.size.height)
        guard side > 0, let cgImage = image.cgImage else {
            return nil
        }
        // Crop по пиксельным координатам (масштаб image.scale учтён).
        let scale = image.scale
        let cropRect = CGRect(
            x: (image.size.width - side) / 2 * scale,
            y: (image.size.height - side) / 2 * scale,
            width: side * scale,
            height: side * scale,
        )
        guard let cropped = cgImage.cropping(to: cropRect.integral) else {
            return nil
        }
        return UIImage(cgImage: cropped)
    }

    /** Круг с инициалом: вертикальное центрирование по размеру текста. */
    private static func drawInitial(displayName: String, textColor: UIColor, center: CGPoint) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = trimmed.first.map(String.init)?.uppercased() ?? "?"
        let fontSize = CIRCLE_SIZE * INITIAL_TEXT_FRACTION
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: textColor,
        ]
        let textSize = (initial as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
        )
        (initial as NSString).draw(at: origin, withAttributes: attributes)
    }

    /// Сторона круглой иконки маркера (CIRCLE_SIZE_DP, стартовое значение плана).
    private static let CIRCLE_SIZE: CGFloat = 40

    /// Толщина кольца иконки (BORDER_WIDTH_DP).
    private static let BORDER_WIDTH: CGFloat = 3

    /// Лимит кэша иконок (MARKER_ICON_CACHE_SIZE).
    private static let MARKER_ICON_CACHE_SIZE = 32

    /// Доля стороны круга, занимаемая кеглем инициала (INITIAL_TEXT_FRACTION).
    private static let INITIAL_TEXT_FRACTION: CGFloat = 0.4

    /// Число неоновых цветов палитры маркеров.
    private static let MARKER_NEON_COLORS_COUNT = AuroraColors.markerNeonColors.count
}
