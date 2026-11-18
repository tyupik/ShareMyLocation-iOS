import SwiftUI

/// Поле ввода имени профиля. Порт 1:1 из Android ProfileSetupNameField.kt.
struct ProfileSetupNameField: View {
    @Binding var text: String
    let isEnabled: Bool

    var body: some View {
        AuroraField(
            title: "Имя",
            text: $text,
            isEnabled: isEnabled,
        )
    }
}

#Preview {
    ProfileSetupNameField(text: .constant("Иван"), isEnabled: true)
        .padding(16)
}
