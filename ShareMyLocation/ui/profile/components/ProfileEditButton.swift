import SwiftUI

/// Кнопка «Редактировать»: стеклянная AURORA-кнопка, открывает ProfileSetup
/// в режиме редактирования. Порт 1:1 из Android ProfileEditButton.kt.
struct ProfileEditButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Редактировать")
                .font(.auroraLabelLarge)
                .foregroundStyle(AuroraColors.auroraText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
    }
}

#Preview {
    ProfileEditButton {}
        .padding(16)
}
