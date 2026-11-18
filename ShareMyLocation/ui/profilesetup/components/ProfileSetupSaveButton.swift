import SwiftUI

/// Кнопка сохранения профиля; в isLoading вместо текста показывает индикатор загрузки.
/// Порт 1:1 из Android ProfileSetupSaveButton.kt.
struct ProfileSetupSaveButton: View {
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
    VStack(spacing: 12) {
        ProfileSetupSaveButton(title: "Готово", isEnabled: true, isLoading: false, action: {})
        ProfileSetupSaveButton(title: "Сохранить", isEnabled: false, isLoading: true, action: {})
    }
    .padding(16)
}
