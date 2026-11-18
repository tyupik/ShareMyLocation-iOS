import SwiftUI

/**
 Замена карты при отсутствии API-ключа в Info.plist (project.yml): приложение не падает,
 вкладка показывает подсказку; GMSMapView не создаётся вовсе.
 Порт 1:1 из Android MapUnavailableNotice.kt (строка map_unavailable_no_api_key — дословно).
 */
struct MapUnavailableNotice: View {
    var body: some View {
        Text("Карта недоступна: не настроен API-ключ")
            .font(.auroraBodyLarge)
            .foregroundStyle(AuroraColors.auroraTextMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MapUnavailableNotice()
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
