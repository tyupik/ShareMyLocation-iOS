import SwiftUI

/**
 Карточка найденного по телефону пользователя с компактной кнопкой «Добавить в друзья».
 Порт 1:1 из Android FriendsSearchResultCard.kt (строка — дословно friends_add_button;
 M3 Button → компактная градиентная капсула AURORA).
 */
struct FriendsSearchResultCard: View {
    let user: FriendUiModel
    let isBusy: Bool
    let onAddClick: () -> Void

    /// Сторона аватара в карточке (Android CARD_AVATAR_SIZE).
    private static let CARD_AVATAR_SIZE: CGFloat = 56

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                ProfileAvatar(
                    displayName: user.displayName,
                    localPath: user.avatarPath,
                    size: Self.CARD_AVATAR_SIZE,
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.auroraTitleMedium)
                        .foregroundStyle(AuroraColors.auroraText)
                        .lineLimit(1)
                    if let phone = user.phone {
                        Text(phone)
                            .font(.auroraBodyMedium)
                            .foregroundStyle(AuroraColors.auroraTextMuted)
                    }
                }
                Spacer(minLength: 8)
                if isBusy {
                    ProgressView()
                        .tint(AuroraColors.auroraIndigoLight)
                } else {
                    Button(action: onAddClick) {
                        Text("Добавить в друзья")
                            .font(.auroraLabelMedium)
                            .foregroundStyle(AuroraColors.auroraOnGradient)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(AuroraBrushes.auroraButtonBrush))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}

#Preview {
    FriendsSearchResultCard(
        user: FriendUiModel(
            uid: "uid",
            displayName: "Иван",
            phone: "89991234567",
            avatarVersion: 0,
            avatarPath: nil,
        ),
        isBusy: false,
        onAddClick: {},
    )
    .padding(16)
}
