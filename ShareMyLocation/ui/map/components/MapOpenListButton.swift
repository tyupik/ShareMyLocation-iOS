import SwiftUI

/**
 Чип «На карте: N»: стеклянный (AURORA), открывает список видимых друзей (sheet).
 Порт 1:1 из Android MapOpenListButton.kt (строка map_open_list — дословно).
 */
struct MapOpenListButton: View {
    let visibleCount: Int
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text("На карте: \(visibleCount)")
                .font(.auroraLabelLarge)
                .foregroundStyle(AuroraColors.auroraText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(AuroraColors.auroraGlass))
                .overlay(Capsule().strokeBorder(AuroraColors.auroraGlassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MapOpenListButton(visibleCount: 3, onClick: {})
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
