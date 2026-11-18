import SwiftUI

/// Разделитель «или» между способами входа. Порт Android AuthOrDivider.kt;
/// вместо outlineVariant — стеклянная рамка AURORA.
struct AuthOrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AuroraColors.auroraGlassBorder)
                .frame(height: 1)
            Text("или")
                .font(.auroraBodySmall)
                .foregroundStyle(AuroraColors.auroraTextMuted)
            Rectangle()
                .fill(AuroraColors.auroraGlassBorder)
                .frame(height: 1)
        }
    }
}

#Preview {
    AuthOrDivider()
        .padding(16)
}
