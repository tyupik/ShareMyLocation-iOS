import SwiftUI

/// Кнопка «Делиться геопозицией»: открывает настройки шаринга
/// (градиентная AURORA-кнопка). Порт 1:1 из Android ProfileSharingButton.kt.
struct ProfileSharingButton: View {
    let action: () -> Void

    var body: some View {
        GradientPrimaryButton(
            title: "Делиться геопозицией",
            isEnabled: true,
            isLoading: false,
            action: action,
        )
    }
}

#Preview {
    ProfileSharingButton {}
        .padding(16)
}
