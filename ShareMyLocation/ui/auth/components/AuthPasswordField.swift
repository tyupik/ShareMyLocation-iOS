import SwiftUI

/// Поле ввода пароля с переключателем видимости; errorText подсвечивает поле
/// и выводится под ним. Порт Android AuthPasswordField.kt.
struct AuthPasswordField: View {
    @Binding var text: String
    let isEnabled: Bool
    let errorText: String?

    var body: some View {
        AuroraField(
            title: "Пароль",
            text: $text,
            isEnabled: isEnabled,
            errorText: errorText,
            isSecure: true,
        )
    }
}

#Preview {
    AuthPasswordField(text: .constant("secret"), isEnabled: true, errorText: nil)
        .padding(16)
}
