import SwiftUI

/// Пикер аватара: круглое фото с бейджем камеры и подписью-кнопкой выбора изображения.
/// Порт 1:1 из Android ProfileSetupAvatarPicker.kt.
struct ProfileSetupAvatarPicker: View {
    let displayName: String
    let savedAvatarPath: String?

    /// Путь к сжатой копии нового аватара; пока есть — показывается вместо сохранённого.
    let localPath: String?
    let isEnabled: Bool
    let isEditMode: Bool
    let onPickRequest: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatar(
                    displayName: displayName,
                    localPath: localPath ?? savedAvatarPath,
                )
                Button(action: onPickRequest) {
                    Circle()
                        .fill(AuroraColors.auroraIndigo)
                        .frame(width: Self.BADGE_SIZE, height: Self.BADGE_SIZE)
                        .overlay {
                            Image(systemName: "camera")
                                .font(.system(size: Self.BADGE_ICON_SIZE))
                                .foregroundStyle(AuroraColors.auroraOnGradient)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
            }
            Button(action: onPickRequest) {
                Text(isEditMode ? "Сменить фото" : "Добавить фото")
                    .font(.auroraLabelLarge)
                    .foregroundStyle(AuroraColors.auroraIndigoLight)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
    }

    /// Размер бейджа камеры (Android BADGE_SIZE_DP).
    private static let BADGE_SIZE: CGFloat = 32

    /// Размер иконки внутри бейджа (Android BADGE_ICON_SIZE_DP).
    private static let BADGE_ICON_SIZE: CGFloat = 18
}

#Preview {
    ProfileSetupAvatarPicker(
        displayName: "Иван",
        savedAvatarPath: nil,
        localPath: nil,
        isEnabled: true,
        isEditMode: false,
        onPickRequest: {},
    )
    .padding(16)
}
