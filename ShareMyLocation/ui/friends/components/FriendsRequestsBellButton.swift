import SwiftUI

/**
 Кнопка-«колокольчик» заявок в друзья: открывает sheet со списком заявок.
 Бейдж с количеством показывается только при requestCount > 0 (как бейдж вкладки друзей
 в MainBottomBar): нулевой бейдж визуального шума не добавляет. Порт 1:1 из Android
 FriendsRequestsBellButton.kt (строка — дословно friends_requests_bell).
 */
struct FriendsRequestsBellButton: View {
    let requestCount: Int
    let onClick: () -> Void

    var body: some View {
        GlassIconButton(
            systemImage: "bell",
            accessibilityLabel: "Заявки в друзья",
            action: onClick,
        ) {
            if requestCount > 0 {
                Text("\(requestCount)")
                    .font(.auroraLabelSmall)
                    .foregroundStyle(AuroraColors.auroraBackground)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(AuroraColors.auroraDanger))
                    // Бейдж «наползает» на угол стеклянного квадрата (аналог BadgedBox M3).
                    .offset(x: 8, y: -6)
            }
        }
    }
}

#Preview {
    FriendsRequestsBellButton(requestCount: 2, onClick: {})
        .padding(16)
}
