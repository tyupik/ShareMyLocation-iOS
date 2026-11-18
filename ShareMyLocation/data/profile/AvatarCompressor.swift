import UIKit

/// Сжатие изображения аватара: масштабирует до максимальной стороны MAX_SIDE_PX
/// и перекодирует в JPEG с качеством JPEG_QUALITY; результат кладёт в кэш приложения.
/// Кадрирование выполняет Mantis до вызова сжатия (Android-сэмплинг при декоде не нужен:
/// UIImage приходит in-memory уже декодированным). Порт 1:1 из Android AvatarCompressor.kt.
final class AvatarCompressor {
    /// Сжимает изображение и возвращает абсолютный путь к файлу в кэше.
    func compressToCache(_ image: UIImage) throws -> String {
        let scaled = scaleToFit(image)
        guard let jpeg = scaled.jpegData(compressionQuality: Self.JPEG_QUALITY) else {
            throw ProfileException(error: .unexpected("Не удалось закодировать изображение аватара в JPEG"))
        }
        let cacheFile = cacheDirectory.appendingPathComponent("avatar_\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
        try jpeg.write(to: cacheFile)
        return cacheFile.path
    }

    /// Читает подготовленный файл в память для записи в Firestore; если JPEG крупнее
    /// RECOMPRESS_THRESHOLD_BYTES, пережимается повторно с качеством RECOMPRESS_QUALITY.
    /// Неудача чтения файла — ошибка: пустые байты не должны пройти гард размера
    /// репозитория и залиться пустым блобом (в Android этот путь тоже падает исключением).
    /// Неудача декода при пережиме — исходные байты (порт Android ?: return bytes).
    /// Итоговый размер проверяет репозиторий: превышение лимита документа вернёт avatarTooLarge.
    func readBytes(cachedPath: String) throws -> Data {
        guard let bytes = FileManager.default.contents(atPath: cachedPath) else {
            throw ProfileException(error: .unexpected("Не удалось прочитать файл аватара: \(cachedPath)"))
        }
        guard bytes.count > Self.RECOMPRESS_THRESHOLD_BYTES else {
            return bytes
        }
        guard let image = UIImage(contentsOfFile: cachedPath),
            let recompressed = image.jpegData(compressionQuality: Self.RECOMPRESS_QUALITY) else {
            print("AvatarCompressor.readBytes: Не удалось пережать JPEG, отправляем исходные байты")
            return bytes
        }
        return recompressed
    }

    /// Масштабирует до максимальной стороны MAX_SIDE_PX с сохранением пропорций.
    private func scaleToFit(_ image: UIImage) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > Self.MAX_SIDE_PX, maxSide > 0 else {
            return image
        }
        let scale = Self.MAX_SIDE_PX / maxSide
        let width = max((size.width * scale).rounded(.down), 1)
        let height = max((size.height * scale).rounded(.down), 1)
        // scale: 1 — рендер в пикселях изображения, без масштаба экрана Retina
        // (порт Android Bitmap.createScaledBitmap: размеры заданы в пикселях).
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    /// Максимальная сторона аватара после сжатия.
    private static let MAX_SIDE_PX: CGFloat = 1024

    /// Качество JPEG при перекодировании (Android 80 из 100).
    private static let JPEG_QUALITY: CGFloat = 0.8

    /// Порог размера, после которого JPEG пережимается повторно (лимит документа Firestore — 1 МБ).
    private static let RECOMPRESS_THRESHOLD_BYTES = 700_000

    /// Качество JPEG при повторном сжатии (Android 50 из 100).
    private static let RECOMPRESS_QUALITY: CGFloat = 0.5
}
