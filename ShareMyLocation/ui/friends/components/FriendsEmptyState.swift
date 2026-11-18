import SwiftUI

/**
 Плейсхолдер пустой секции: «Заявок пока нет» / «Друзей пока нет» / «Групп пока нет».
 Порт 1:1 из Android FriendsEmptyState.kt (строки — дословно friends_empty_*/groups_empty).
 */
struct FriendsEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.auroraBodyMedium)
            .foregroundStyle(AuroraColors.auroraTextMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}

#Preview {
    FriendsEmptyState(text: "Друзей пока нет")
        .padding(16)
}
