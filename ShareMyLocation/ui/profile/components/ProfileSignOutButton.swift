import SwiftUI

/// Кнопка «Выход»: ghost-danger AURORA (danger-стекло), инициирует выход из аккаунта.
/// Порт 1:1 из Android ProfileSignOutButton.kt.
struct ProfileSignOutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Выход")
                .font(.auroraLabelLarge)
                .foregroundStyle(AuroraColors.auroraDanger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AuroraShapes.medium)
                        .fill(AuroraColors.auroraDangerGlass),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AuroraShapes.medium)
                        .strokeBorder(AuroraColors.auroraDangerBorder, lineWidth: 1),
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileSignOutButton(action: {})
        .padding(16)
}
