import SwiftUI
import UIKit

/// Стеклянное поле ввода AURORA: аналог Android auroraOutlinedTextFieldColors
/// (стекло + рамка; фокус/ошибка меняют рамку, курсор и метку — акцент).
/// Метка статичная над полем (SwiftUI не имеет M3 floating label; точная подгонка —
/// этап 9). `errorText` выводится под полем и подсвечивает рамку danger-цветом.
/// `isSecure` включает SecureField с кнопкой-глазом.
struct AuroraField: View {
    let title: String
    @Binding var text: String
    var isEnabled: Bool = true
    var errorText: String? = nil
    var isSecure: Bool = false
    var textContentType: UITextContentType? = nil

    /// Раскладка клавиатуры (например, .phonePad у телефона профиля); дефолт не меняет
    /// поведение существующих полей auth.
    var keyboardType: UIKeyboardType = .default

    /// Колбэк отправки с клавиатуры (IME action Search у поля поиска друзей); nil —
    /// поведение прежних полей auth/profile (аддитивно, этап 4).
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    /// Видимость пароля — эфемерное UI-состояние поля (аналог rememberSaveable Android).
    @State private var isPasswordVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.auroraBodySmall)
                .foregroundStyle(
                    isFocused ? AuroraColors.auroraIndigoLight : AuroraColors.auroraTextMuted,
                )
            HStack(spacing: 8) {
                Group {
                    if isSecure && !isPasswordVisible {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .focused($isFocused)
                .disabled(!isEnabled)
                .textContentType(textContentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalizationMode)
                .autocorrectionDisabled(isAutocorrectionDisabled)
                .onSubmit {
                    onSubmit?()
                }
                .font(.auroraBodyLarge)
                .foregroundStyle(AuroraColors.auroraText)
                // Курсор и маркер выделения — акцентный индиго.
                .tint(AuroraColors.auroraIndigoLight)
                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(AuroraColors.auroraTextMuted)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: AuroraShapes.medium)
                    .fill(AuroraColors.auroraGlass),
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraShapes.medium)
                    .strokeBorder(borderColor, lineWidth: 1),
            )
            if let errorText {
                Text(errorText)
                    .font(.auroraBodySmall)
                    .foregroundStyle(AuroraColors.auroraOnErrorContainer)
            }
        }
    }

    /// Рамка: ошибка → danger, фокус → акцент, обычное состояние → стекло.
    private var borderColor: Color {
        if errorText != nil {
            return AuroraColors.auroraDangerBorder
        }
        return isFocused ? AuroraColors.auroraIndigoLight : AuroraColors.auroraGlassBorder
    }

    /// Email и пароль вводятся без капитализации, остальное (имя) — по словам.
    private var autocapitalizationMode: TextInputAutocapitalization? {
        isSecure || textContentType == .emailAddress ? .never : .words
    }

    /// Автокоррекция мешает email и паролям.
    private var isAutocorrectionDisabled: Bool {
        isSecure || textContentType == .emailAddress
    }
}

#Preview {
    VStack(spacing: 16) {
        AuroraField(title: "Email", text: .constant("user@example.com"))
        AuroraField(title: "Пароль", text: .constant("secret"), isSecure: true)
        AuroraField(title: "Email", text: .constant("user"), errorText: "Неверный email или пароль")
    }
    .padding(16)
}
