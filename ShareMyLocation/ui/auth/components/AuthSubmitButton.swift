import SwiftUI

/// Кнопка сабмита формы; в isLoading вместо текста показывает индикатор загрузки.
/// Порт Android AuthSubmitButton.kt (тонкая обёртка GradientPrimaryButton).
struct AuthSubmitButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        GradientPrimaryButton(
            title: title,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action,
        )
    }
}

#Preview {
    AuthSubmitButton(title: "Войти", isEnabled: true, isLoading: false, action: {})
        .padding(16)
}
