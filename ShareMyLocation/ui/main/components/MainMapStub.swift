import SwiftUI

/// Временная заглушка вкладки «Карта»: реальная карта (Google Maps, тёмный стиль,
/// realtime-маркеры) подключается на этапе 7.
struct MainMapStub: View {
    var body: some View {
        Text("Карта — этап 7")
            .font(.auroraHeadlineSmall)
            .foregroundStyle(AuroraColors.auroraTextMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainMapStub()
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
