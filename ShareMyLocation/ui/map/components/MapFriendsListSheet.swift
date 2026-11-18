import SwiftUI

/**
 Список видимых друзей в sheet: карточка на друга, клик — слежение камеры. Закрытие любым
 способом (свайп, тап вне) — сброс sheet-флага вызывающей стороной (Binding от state).
 Пустое состояние обязательно: realtime-поток может обнулить friends при открытом листе
 (последний друг перестал делиться). Порт 1:1 из Android MapFriendsListSheet.kt
 (строка map_list_empty — дословно; M3 ModalBottomSheet → системный sheet, паттерн
 FriendsRequestsSheet).
 */
struct MapFriendsListSheet: View {
    let friends: [VisibleFriendUiModel]
    let onFriendClick: (String) -> Void

    var body: some View {
        Group {
            if friends.isEmpty {
                Text("Никто из друзей сейчас не делится")
                    .font(.auroraBodyLarge)
                    .foregroundStyle(AuroraColors.auroraTextMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 32)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(friends, id: \.uid) { friend in
                            MapFriendListCard(
                                friend: friend,
                                onClick: { onFriendClick(friend.uid) },
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(AuroraColors.auroraSurfaceVariant.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    MapFriendsListSheet(friends: [], onFriendClick: { _ in })
}
