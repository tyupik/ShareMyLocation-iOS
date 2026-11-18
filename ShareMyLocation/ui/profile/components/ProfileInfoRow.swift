import SwiftUI

/// Строка контактных данных профиля (email, телефон): иконка и значение.
/// Порт 1:1 из Android ProfileInfoRow.kt (Icon 20dp + текст bodyLarge).
struct ProfileInfoRow: View {
    /// SF Symbol: "envelope" / "phone".
    let symbolName: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 20))
                .foregroundStyle(AuroraColors.auroraTextMuted)
                .frame(width: 20, height: 20)
            Text(text)
                .font(.auroraBodyLarge)
                .foregroundStyle(AuroraColors.auroraText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 12) {
        ProfileInfoRow(symbolName: "envelope", text: "ivan@example.com")
        ProfileInfoRow(symbolName: "phone", text: "+79991234567")
    }
    .padding(16)
}
