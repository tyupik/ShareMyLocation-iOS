import SwiftUI

/// Поле ввода телефона; errorText показывается под полем и подсвечивает его как ошибочное.
/// Порт 1:1 из Android ProfileSetupPhoneField.kt (клавиатура phonePad).
struct ProfileSetupPhoneField: View {
    @Binding var text: String
    let isEnabled: Bool
    let errorText: String?

    var body: some View {
        AuroraField(
            title: "Телефон",
            text: $text,
            isEnabled: isEnabled,
            errorText: errorText,
            keyboardType: .phonePad,
        )
    }
}

#Preview {
    ProfileSetupPhoneField(text: .constant("+79991234567"), isEnabled: true, errorText: nil)
        .padding(16)
}
