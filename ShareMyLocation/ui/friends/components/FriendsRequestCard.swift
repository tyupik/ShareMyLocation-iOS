import SwiftUI

/**
 Карточка входящей заявки: аватар, имя и кнопки «Отклонить» (muted) / «Принять» (акцент).
 Порт 1:1 из Android FriendsRequestCard.kt (строки — дословно friends_accept_button/
 friends_decline_button; M3 TextButton/Button → muted-текст и градиентная капсула AURORA).
 */
struct FriendsRequestCard: View {
    let request: FriendRequestUiModel
    let isBusy: Bool
    let onAcceptClick: () -> Void
    let onDeclineClick: () -> Void

    /// Сторона аватара в карточке (Android CARD_AVATAR_SIZE).
    private static let CARD_AVATAR_SIZE: CGFloat = 56

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                ProfileAvatar(
                    displayName: request.fromName,
                    localPath: request.avatarPath,
                    size: Self.CARD_AVATAR_SIZE,
                )
                Text(request.fromName)
                    .font(.auroraTitleMedium)
                    .foregroundStyle(AuroraColors.auroraText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if isBusy {
                    ProgressView()
                        .tint(AuroraColors.auroraIndigoLight)
                } else {
                    Button(action: onDeclineClick) {
                        Text("Отклонить")
                            .font(.auroraLabelLarge)
                            .foregroundStyle(AuroraColors.auroraTextMuted)
                    }
                    .buttonStyle(.plain)
                    Button(action: onAcceptClick) {
                        Text("Принять")
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
    FriendsRequestCard(
        request: FriendRequestUiModel(
            fromUid: "uid",
            fromName: "Иван",
            fromAvatarVersion: 0,
            avatarPath: nil,
        ),
        isBusy: false,
        onAcceptClick: {},
        onDeclineClick: {},
    )
    .padding(16)
}
