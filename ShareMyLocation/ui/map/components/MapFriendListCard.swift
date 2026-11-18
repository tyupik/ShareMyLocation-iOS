import SwiftUI

/**
 Карточка друга в списке: аватар, имя и «как давно»; клик — слежение камеры за другом.
 Порт 1:1 из Android MapFriendListCard.kt.
 */
struct MapFriendListCard: View {
    let friend: VisibleFriendUiModel
    let onClick: () -> Void

    var body: some View {
        GlassCard(action: onClick) {
            HStack(spacing: 12) {
                ProfileAvatar(
                    displayName: friend.displayName,
                    localPath: friend.avatarPath,
                    size: CARD_AVATAR_SIZE,
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.auroraTitleMedium)
                        .foregroundStyle(AuroraColors.auroraText)
                        .lineLimit(1)
                    Text(friend.lastSeenLabel)
                        .font(.auroraBodyMedium)
                        .foregroundStyle(AuroraColors.auroraTextMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    /// Размер аватара карточки.
    private static let CARD_AVATAR_SIZE: CGFloat = 48
}

#Preview {
    MapFriendListCard(
        friend: VisibleFriendUiModel(
            uid: "uid",
            displayName: "Иван",
            avatarVersion: 0,
            avatarPath: nil,
            latitude: 0,
            longitude: 0,
            accuracyMeters: 0,
            updatedAtMillis: 0,
            lastSeenLabel: "Только что",
        ),
        onClick: {},
    )
    .padding(16)
    .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
