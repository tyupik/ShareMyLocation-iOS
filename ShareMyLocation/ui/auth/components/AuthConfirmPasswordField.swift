import SwiftUI

/// Поле подтверждения пароля (режим регистрации) с переключателем видимости.
/// errorText — например, «Пароли не совпадают». Порт Android AuthConfirmPasswordField.kt.
struct AuthConfirmPasswordField: View {
    @Binding var text: String
    let isEnabled: Bool
    let errorText: String?

    var body: some View {
        AuroraField(
            title: "Подтвердите пароль",
            text: $text,
            isEnabled: isEnabled,
            errorText: errorText,
            isSecure: true,
        )
    }
}

#Preview {
    AuthConfirmPasswordField(text: .constant("secret"), isEnabled: true, errorText: "Пароли не совпадают")
        .padding(16)
}
