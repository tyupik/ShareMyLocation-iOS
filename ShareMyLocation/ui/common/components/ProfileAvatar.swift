import SwiftUI
import UIKit

/// Круглый аватар с плейсхолдером (первая буква имени) — общий элемент экранов профиля.
/// Порт 1:1 из Android ProfileAvatar.kt. `localPath` — путь к файлу JPEG в кэше приложения;
/// nil или отсутствующий файл — плейсхолдер. `size` — сторона аватара; по умолчанию 112
/// для совместимости с шапкой профиля. Файловый кэш (AvatarCache) — этап 3.
struct ProfileAvatar: View {
    let displayName: String
    let localPath: String?
    var size: CGFloat = 112

    var body: some View {
        if let image = loadedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            placeholder
        }
    }

    /// JPEG из файла кэша; nil — файла нет или не читается.
    private var loadedImage: UIImage? {
        guard let localPath else {
            return nil
        }
        return UIImage(contentsOfFile: localPath)
    }

    private var placeholder: some View {
        Circle()
            .fill(AuroraColors.auroraSurfaceVariant)
            .frame(width: size, height: size)
            .overlay {
                Text(placeholderInitial)
                    .font(.auroraTitleLarge)
                    .foregroundStyle(AuroraColors.auroraTextMuted)
            }
    }

    /// Первая буква имени в верхнем регистре; пустое имя — «?».
    private var placeholderInitial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return "?"
        }
        return String(first).uppercased()
    }
}

#Preview("Плейсхолдер") {
    ProfileAvatar(displayName: "Иван", localPath: nil)
}

#Preview("Пустое имя") {
    ProfileAvatar(displayName: "", localPath: nil, size: 56)
}
