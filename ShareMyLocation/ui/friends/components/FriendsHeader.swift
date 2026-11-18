import SwiftUI

/**
 Заголовок вкладки «Друзья» с колокольчиком заявок справа: заявки живут в sheet'е,
 поэтому отдельной секции в теле вкладки больше нет. Порт 1:1 из Android FriendsHeader.kt
 (строка — дословно friends_screen_title из strings.xml).
 */
struct FriendsHeader: View {
    let requestCount: Int
    let onBellClick: () -> Void

    var body: some View {
        HStack {
            Text("Друзья")
                .font(.auroraTitleMedium)
                .foregroundStyle(AuroraColors.auroraText)
            Spacer()
            FriendsRequestsBellButton(
                requestCount: requestCount,
                onClick: onBellClick,
            )
        }
    }
}

#Preview {
    FriendsHeader(requestCount: 3, onBellClick: {})
        .padding(16)
}
