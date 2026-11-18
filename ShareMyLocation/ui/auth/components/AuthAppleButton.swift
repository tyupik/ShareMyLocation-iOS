import AuthenticationServices
import SwiftUI

/// Кнопка входа через Apple: системный SignInWithAppleButton в стиле .white
/// (на тёмном фоне AURORA) с обязательным scope fullName. `onSignInRequested` вызывается
/// из onRequest при тапе (до открытия sheet): экран отправляет .appleSignInClicked,
/// чтобы isLoading поднялся до прихода onCompletion — иначе guard'ы ViewModel
/// отбросят креденшел/отмену/ошибку. Nonce (анти-replay) генерируется при
/// конструировании запроса; raw хранится в @State и вместе с idToken уходит в
/// AuthIntent.appleCredentialReceived. Отмена sheet — отдельный интент.
struct AuthAppleButton: View {
    let isEnabled: Bool
    let onSignInRequested: () -> Void
    let onCredentialReceived: (_ idToken: String, _ rawNonce: String, _ fullName: String?) -> Void
    let onCancelled: () -> Void
    let onFailed: (_ reason: String?) -> Void

    /// Raw-nonce текущего запроса: живёт между конструированием запроса и onCompletion.
    @State private var currentRawNonce: String = ""

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            // Сначала интент (поднимает isLoading), затем nonce и системный sheet:
            // onRequest вызывается синхронно при тапе, раньше onCompletion.
            onSignInRequested()
            let nonce = AppleNonce.make()
            currentRawNonce = nonce.raw
            request.requestedScopes = [.fullName]
            request.nonce = nonce.hashed
        } onCompletion: { result in
            handleCompletion(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 44)
        .clipShape(RoundedRectangle(cornerRadius: AuroraShapes.medium))
        .disabled(!isEnabled)
    }

    private func handleCompletion(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            handleAuthorization(authorization)
        case .failure(let error):
            // Закрытие системного sheet — не ошибка: тихо возвращаем форму в исходное состояние.
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                print("AuthAppleButton: sheet Apple отменён пользователем")
                onCancelled()
                return
            }
            print("AuthAppleButton: ошибка авторизации Apple — \(error)")
            onFailed(error.localizedDescription)
        }
    }

    /// ASAuthorization → (idToken, rawNonce, fullName); fullName собирается из
    /// givenName + familyName и приходит только при первой авторизации пользователя.
    private func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            onFailed("Неожиданный тип креденшела Apple: \(type(of: authorization.credential))")
            return
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty else {
            onFailed("Apple вернул авторизацию без identityToken")
            return
        }
        var fullName: String? = nil
        if let components = credential.fullName {
            let parts = [components.givenName, components.familyName].compactMap { $0 }
            let joined = parts.joined(separator: " ")
            fullName = joined.isEmpty ? nil : joined
        }
        onCredentialReceived(idToken, currentRawNonce, fullName)
    }
}

#Preview {
    AuthAppleButton(
        isEnabled: true,
        onSignInRequested: {},
        onCredentialReceived: { _, _, _ in },
        onCancelled: {},
        onFailed: { _ in },
    )
    .padding(16)
}
