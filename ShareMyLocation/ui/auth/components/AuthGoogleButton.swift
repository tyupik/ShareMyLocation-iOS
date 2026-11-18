import SwiftUI

/// Кнопка входа через Google: стеклянная outlined-кнопка AURORA с четырёхцветной «G»
/// (фигуративный знак Google, ассет ic_google — порт Android ic_google.xml; без описания —
/// смысл кнопки несёт текст). Если ассета нет, Image ничего не рисует — кнопка не падает.
struct AuthGoogleButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image("ic_google")
                    .resizable()
                    .frame(width: 18, height: 18)
                Text("Войти через Google")
                    .font(.auroraLabelLarge)
                    .foregroundStyle(AuroraColors.auroraText)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: AuroraShapes.medium)
                    .fill(AuroraColors.auroraGlass),
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraShapes.medium)
                    .strokeBorder(AuroraColors.auroraGlassBorder, lineWidth: 1),
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    AuthGoogleButton(isEnabled: true, action: {})
        .padding(16)
}
