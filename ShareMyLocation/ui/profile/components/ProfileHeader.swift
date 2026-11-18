import SwiftUI

/// Шапка профиля: круглый аватар в градиентном кольце AURORA и имя пользователя.
/// Порт 1:1 из Android ProfileHeader.kt (кольцо — фон-градиент под аватаром с отступом 4).
struct ProfileHeader: View {
    let displayName: String
    let avatarPath: String?

    var body: some View {
        VStack(spacing: 8) {
            ProfileAvatar(displayName: displayName, localPath: avatarPath)
                .padding(4)
                .background(
                    Circle()
                        .fill(AuroraBrushes.auroraAvatarBrush),
                )
            Text(displayName)
                .font(.auroraTitleLarge)
                .foregroundStyle(AuroraColors.auroraText)
        }
    }
}

#Preview {
    ProfileHeader(displayName: "Иван", avatarPath: nil)
        .padding(16)
}
