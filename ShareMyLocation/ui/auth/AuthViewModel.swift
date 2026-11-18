import Foundation
import Observation

/// ViewModel экрана входа/регистрации. Порт 1:1 из Android AuthViewModel.kt:
/// получает от интерактора бизнес-результат, через AuthUiConverter переводит его
/// в Ui-модель и кладёт в состояние. iOS-специфика: результат Google-запроса
/// ViewModel добывает сам (GoogleSignInRequesting), Apple-креденшел приносит
/// AuthAppleButton через интенты. Единственная публичная точка входа для UI — onIntent.
@MainActor
@Observable
final class AuthViewModel {
    private(set) var state: AuthUiState = .initial

    /// One-off события экрана; navigateToMain — единственный кейс (как в Android).
    let effects: AsyncStream<AuthEffect>
    private let effectsContinuation: AsyncStream<AuthEffect>.Continuation

    /// Признак завершённой в этой сессии VM успешной аутентификации: сброс формы на повторный показ.
    private var wasAuthenticated = false

    private let authInteractor: AuthInteractor
    private let googleSignInRequester: GoogleSignInRequesting
    private let authUiConverter: AuthUiConverter

    init(
        authInteractor: AuthInteractor,
        googleSignInRequester: GoogleSignInRequesting,
        authUiConverter: AuthUiConverter,
    ) {
        self.authInteractor = authInteractor
        self.googleSignInRequester = googleSignInRequester
        self.authUiConverter = authUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: AuthEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
    }

    func onIntent(_ intent: AuthIntent) {
        switch intent {
        case .screenShown:
            onScreenShown()
        case .emailChanged(let value):
            onEmailChanged(value)
        case .passwordChanged(let value):
            onPasswordChanged(value)
        case .repeatedPasswordChanged(let value):
            onRepeatedPasswordChanged(value)
        case .displayNameChanged(let value):
            onDisplayNameChanged(value)
        case .modeChanged(let mode):
            onModeChanged(mode)
        case .signInWithEmailClicked:
            signInWithEmail()
        case .signUpWithEmailClicked:
            signUpWithEmail()
        case .googleSignInClicked:
            onGoogleSignInClicked()
        case .googleCredentialReceived(let idToken):
            exchangeGoogleCredential(idToken: idToken, accessToken: nil)
        case .googleSignInCancelled:
            onGoogleSignInCancelled()
        case .googleSignInFailed(let reason):
            onGoogleSignInFailed(reason: reason)
        case .appleSignInClicked:
            onAppleSignInClicked()
        case .appleCredentialReceived(let idToken, let rawNonce, let fullName):
            exchangeAppleCredential(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
        case .appleSignInCancelled:
            onAppleSignInCancelled()
        case .appleSignInFailed(let reason):
            onAppleSignInFailed(reason: reason)
        case .errorDismissed:
            state.error = nil
        }
    }

    /// Повторный показ экрана после успешной аутентификации (выход из аккаунта) — полный
    /// чистый лист: форма, isLoading и остаточная ошибка сбрасываются. На каждый показ
    /// сбрасывать нельзя: `.task` перезапускается при возврате на экран, и форма потеряла бы ввод.
    private func onScreenShown() {
        guard wasAuthenticated else { return }
        wasAuthenticated = false
        state = .initial
    }

    private func onEmailChanged(_ value: String) {
        state.email = value
        state.error = nil
    }

    private func onPasswordChanged(_ value: String) {
        state.password = value
        state.error = nil
    }

    private func onRepeatedPasswordChanged(_ value: String) {
        state.repeatedPassword = value
        state.error = nil
    }

    private func onDisplayNameChanged(_ value: String) {
        state.displayName = value
        state.error = nil
    }

    private func onModeChanged(_ mode: AuthMode) {
        guard state.mode != mode else { return }
        state.mode = mode
        state.password = ""
        state.repeatedPassword = ""
        state.error = nil
    }

    private func signInWithEmail() {
        guard !state.isLoading else { return }
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = state.password
        state.isLoading = true
        state.error = nil
        Task {
            let result = await authInteractor.signInWithEmail(email: email, password: password)
            handleUiModel(authUiConverter.convert(result))
        }
    }

    private func signUpWithEmail() {
        guard !state.isLoading else { return }
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = state.password
        let displayName = state.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.isLoading = true
        state.error = nil
        Task {
            let result = await authInteractor.signUpWithEmail(
                email: email,
                password: password,
                displayName: displayName,
            )
            handleUiModel(authUiConverter.convert(result))
        }
    }

    /// Клик по кнопке Google: включаем загрузку и сами запрашиваем токен у SDK
    /// (в Android Credential Manager запрашивал экран; здесь обёртка в data-слое).
    /// Результат маршрутизируется через те же обработчики, что и публичные интенты Google.
    private func onGoogleSignInClicked() {
        guard !state.isLoading else { return }
        state.isLoading = true
        state.error = nil
        Task {
            switch await googleSignInRequester.requestIdToken() {
            case .success(let idToken, let accessToken):
                exchangeGoogleCredential(idToken: idToken, accessToken: accessToken)
            case .cancelled:
                onGoogleSignInCancelled()
            case .failed(let reason):
                onGoogleSignInFailed(reason: reason)
            case .notConfigured:
                handleUiModel(.error(.googleNotConfigured))
            }
        }
    }

    private func exchangeGoogleCredential(idToken: String, accessToken: String?) {
        guard state.isLoading else { return }
        Task {
            let result = await authInteractor.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            handleUiModel(authUiConverter.convert(result))
        }
    }

    /// Отмена диалога Google — не ошибка: тихо возвращаем форму в исходное состояние.
    private func onGoogleSignInCancelled() {
        guard state.isLoading else { return }
        print("AuthViewModel: Google sign-in sheet cancelled by user")
        state.isLoading = false
    }

    private func onGoogleSignInFailed(reason: String?) {
        guard state.isLoading else { return }
        print("AuthViewModel: Google Sign-In failed — \(reason ?? "no reason")")
        handleUiModel(.error(.unexpected(reason)))
    }

    /// Клик по кнопке Apple: включаем загрузку; системный sheet открывает AuthAppleButton,
    /// его onCompletion приходит в интенты appleCredentialReceived/cancelled/failed.
    private func onAppleSignInClicked() {
        guard !state.isLoading else { return }
        state.isLoading = true
        state.error = nil
    }

    private func exchangeAppleCredential(idToken: String, rawNonce: String, fullName: String?) {
        guard state.isLoading else { return }
        Task {
            let result = await authInteractor.signInWithApple(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
            handleUiModel(authUiConverter.convert(result))
        }
    }

    /// Отмена sheet Apple — не ошибка: тихо возвращаем форму в исходное состояние.
    private func onAppleSignInCancelled() {
        guard state.isLoading else { return }
        print("AuthViewModel: Apple sign-in sheet cancelled by user")
        state.isLoading = false
    }

    private func onAppleSignInFailed(reason: String?) {
        guard state.isLoading else { return }
        print("AuthViewModel: Apple Sign-In failed — \(reason ?? "no reason")")
        handleUiModel(.error(.unexpected(reason)))
    }

    private func handleUiModel(_ uiModel: AuthUiModel) {
        switch uiModel {
        case .success:
            onAuthSuccess()
        case .error(let error):
            onAuthError(error)
        }
    }

    private func onAuthSuccess() {
        wasAuthenticated = true
        state.isLoading = false
        effectsContinuation.yield(.navigateToMain)
    }

    private func onAuthError(_ error: AuthUiError) {
        print("AuthViewModel: auth failed — \(error)")
        state.isLoading = false
        state.error = error
    }
}
