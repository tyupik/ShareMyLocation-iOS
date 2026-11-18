import SwiftUI

/// Поле ввода имени, видно только в режиме регистрации. Порт Android AuthDisplayNameField.kt.
struct AuthDisplayNameField: View {
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
    AuthDisplayNameField(text: .constant("Иван"), isEnabled: true)
        .padding(16)
}
