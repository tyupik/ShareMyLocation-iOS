import SwiftUI

/// Поле ввода email; errorText подсвечивает поле и выводится под ним.
/// Порт Android AuthEmailField.kt.
struct AuthEmailField: View {
    @Binding var text: String
    let isEnabled: Bool
    let errorText: String?

    var body: some View {
        AuroraField(
            title: "Email",
            text: $text,
            isEnabled: isEnabled,
            errorText: errorText,
            textContentType: .emailAddress,
        )
    }
}

#Preview {
    AuthEmailField(text: .constant("user@example.com"), isEnabled: true, errorText: nil)
        .padding(16)
}
