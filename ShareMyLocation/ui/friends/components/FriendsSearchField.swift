import SwiftUI

/**
 Поле поиска друзей по номеру телефона: phone-клавиатура, отправка поиска (IME action Search
 через AuroraField.onSubmit), кнопка очистки xmark. Порт 1:1 из Android FriendsSearchField.kt
 (строки — дословно friends_search_placeholder/friends_search_clear; плейсхолдер Android —
 статичная метка AuroraField, подгонка — этап 9).
 */
struct FriendsSearchField: View {
    @Binding var text: String
    let isEnabled: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        AuroraField(
            title: "Номер телефона",
            text: $text,
            isEnabled: isEnabled,
            keyboardType: .phonePad,
            onSubmit: onSubmit,
        )
        .overlay(alignment: .trailing) {
            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(AuroraColors.auroraTextMuted)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                // Метка AuroraField выше поля: центрируем кнопку по зоне ввода.
                .padding(.top, 16)
                .accessibilityLabel("Очистить поиск")
            }
        }
    }
}

#Preview {
    FriendsSearchField(
        text: .constant("89991234567"),
        isEnabled: true,
        onSubmit: {},
        onClear: {},
    )
    .padding(16)
}
