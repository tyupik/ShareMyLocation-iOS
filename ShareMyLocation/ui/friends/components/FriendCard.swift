import SwiftUI

/**
 Карточка друга: аватар, имя, телефон и действие «Удалить из друзей».
 Порт 1:1 из Android FriendCard.kt (строка — дословно friends_remove_button).
 */
struct FriendCard: View {
    let friend: FriendUiModel
    let isBusy: Bool
    let onRemoveClick: () -> Void

    /// Сторона аватара в карточке (Android CARD_AVATAR_SIZE).
    private static let CARD_AVATAR_SIZE: CGFloat = 56

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                ProfileAvatar(
                    displayName: friend.displayName,
                    localPath: friend.avatarPath,
                    size: Self.CARD_AVATAR_SIZE,
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.auroraTitleMedium)
                        .foregroundStyle(AuroraColors.auroraText)
                        .lineLimit(1)
                    if let phone = friend.phone {
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
                    Button(action: onRemoveClick) {
                        Text("Удалить из друзей")
                            .font(.auroraLabelLarge)
                            .foregroundStyle(AuroraColors.auroraIndigoLight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}

#Preview {
    FriendCard(
        friend: FriendUiModel(
            uid: "uid",
            displayName: "Иван",
            phone: "89991234567",
            avatarVersion: 0,
            avatarPath: nil,
        ),
        isBusy: false,
        onRemoveClick: {},
    )
    .padding(16)
}
