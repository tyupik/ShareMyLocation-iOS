import Factory
import SwiftUI

/// Минимальная длина пароля Firebase Auth.
private let MIN_PASSWORD_LENGTH = 6

/**
 Экран входа/регистрации: собирает UI-элементы из components и маппит состояние в их параметры.
 Навигацию выполняет вызывающая сторона через onAuthenticated: экран сам не знает про back stack,
 лямбда вызывается только из коллекции Effect. Порт Android AuthScreen.kt; Apple-кнопка —
 iOS-расширение (обязателен по правилу App Store 4.8).
 */
struct AuthScreen: View {
    let onAuthenticated: () -> Void

    @State private var viewModel: AuthViewModel

    init(onAuthenticated: @escaping () -> Void) {
        self.onAuthenticated = onAuthenticated
        _viewModel = State(initialValue: Container.shared.authViewModel())
    }

    var body: some View {
        AuthContent(
            state: viewModel.state,
            onIntent: { viewModel.onIntent($0) },
        )
        .task {
            // На каждый показ — no-op: форма сбрасывается только при повторном показе
            // после успешной аутентификации (см. AuthViewModel.onScreenShown).
            viewModel.onIntent(.screenShown)
        }
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case .navigateToMain:
                    onAuthenticated()
                }
            }
        }
    }
}

/// Контент экрана: производные флаги валидности и тексты ошибок считаются здесь,
/// а не в ViewModel (чистый UI-расчёт, порт AuthContent Android).
private struct AuthContent: View {
    let state: AuthUiState
    let onIntent: (AuthIntent) -> Void

    var body: some View {
        let isSignUp = state.mode == .signUp
        let isLoading = state.isLoading
        // Кнопка активна, только если форма заполнена, а в signUp подтверждение пароля совпадает.
        let isFormValid = state.email.contains("@")
            && state.password.count >= MIN_PASSWORD_LENGTH
            && (!isSignUp || state.repeatedPassword == state.password)
            && (!isSignUp || !state.displayName.trimmingCharacters(in: .whitespaces).isEmpty)

        // Тексты ошибок по полю/баннеру: порт when-маппинга из AuthScreen.kt
        // + iOS-кейс googleNotConfigured.
        let emailErrorText: String?
        let passwordErrorText: String?
        let bannerErrorText: String?

        switch state.error {
        case .some(.emailAlreadyInUse):
            emailErrorText = "Этот email уже зарегистрирован"
            passwordErrorText = nil
            bannerErrorText = nil
        case .some(.invalidCredentials):
            emailErrorText = nil
            passwordErrorText = isSignUp ? nil : "Неверный email или пароль"
            bannerErrorText = isSignUp ? "Проверьте email и пароль (минимум 6 символов)" : nil
        case .some(.networkUnavailable):
            emailErrorText = nil
            passwordErrorText = nil
            bannerErrorText = "Нет подключения к сети. Проверьте интернет и попробуйте снова"
        case .some(.unexpected):
            emailErrorText = nil
            passwordErrorText = nil
            bannerErrorText = "Что-то пошло не так. Попробуйте ещё раз"
        case .some(.googleNotConfigured):
            emailErrorText = nil
            passwordErrorText = nil
            bannerErrorText = "Сервисы Google не настроены"
        case .none:
            emailErrorText = nil
            passwordErrorText = nil
            bannerErrorText = nil
        }

        // Совпадение паролей — чистый UI-расчёт, не ошибка аутентификации.
        let confirmErrorText: String? =
            if isSignUp, !state.repeatedPassword.isEmpty, state.repeatedPassword != state.password {
                "Пароли не совпадают"
            } else {
                nil
            }

        AuroraBackdrop {
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 32)

                    if let bannerErrorText {
                        AuthErrorBanner(text: bannerErrorText, onDismiss: { onIntent(.errorDismissed) })
                    }

                    Text(isSignUp ? "Регистрация" : "Вход")
                        .font(.auroraHeadlineMedium)
                        .tracking(AuroraTypography.HEADLINE_TRACKING)
                        .foregroundStyle(AuroraColors.auroraText)

                    AuthModeSwitcher(
                        mode: state.mode,
                        isEnabled: !isLoading,
                        onModeChanged: { onIntent(.modeChanged($0)) },
                    )

                    AuthEmailField(
                        text: Binding(
                            get: { state.email },
                            set: { onIntent(.emailChanged($0)) },
                        ),
                        isEnabled: !isLoading,
                        errorText: emailErrorText,
                    )

                    if isSignUp {
                        AuthDisplayNameField(
                            text: Binding(
                                get: { state.displayName },
                                set: { onIntent(.displayNameChanged($0)) },
                            ),
                            isEnabled: !isLoading,
                        )
                    }

                    AuthPasswordField(
                        text: Binding(
                            get: { state.password },
                            set: { onIntent(.passwordChanged($0)) },
                        ),
                        isEnabled: !isLoading,
                        errorText: passwordErrorText,
                    )

                    if isSignUp {
                        AuthConfirmPasswordField(
                            text: Binding(
                                get: { state.repeatedPassword },
                                set: { onIntent(.repeatedPasswordChanged($0)) },
                            ),
                            isEnabled: !isLoading,
                            errorText: confirmErrorText,
                        )
                    }

                    AuthSubmitButton(
                        title: isSignUp ? "Зарегистрироваться" : "Войти",
                        isEnabled: isFormValid,
                        isLoading: isLoading,
                    ) {
                        onIntent(isSignUp ? .signUpWithEmailClicked : .signInWithEmailClicked)
                    }

                    AuthOrDivider()

                    AuthGoogleButton(isEnabled: !isLoading) {
                        // Сначала включается состояние загрузки (внутри интента),
                        // затем ViewModel сам идёт за токеном к GoogleSignInRequesting.
                        onIntent(.googleSignInClicked)
                    }

                    AuthAppleButton(
                        isEnabled: !isLoading,
                        // Тап по кнопке (onRequest, до открытия sheet) поднимает isLoading —
                        // без этого guard'ы ViewModel отбросят креденшел/отмену/ошибку.
                        onSignInRequested: { onIntent(.appleSignInClicked) },
                        onCredentialReceived: { idToken, rawNonce, fullName in
                            onIntent(.appleCredentialReceived(idToken: idToken, rawNonce: rawNonce, fullName: fullName))
                        },
                        onCancelled: { onIntent(.appleSignInCancelled) },
                        onFailed: { onIntent(.appleSignInFailed(reason: $0)) },
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

#Preview {
    AuthContent(state: .initial, onIntent: { _ in })
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
