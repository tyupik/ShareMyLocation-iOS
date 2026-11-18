/// Режим экрана аутентификации: вход или регистрация. Порт 1:1 из Android AuthContract.kt.
enum AuthMode {
    case signIn
    case signUp
}

/// SSOT для экрана входа/регистрации. Порт 1:1 из Android AuthContract.kt.
/// Форма переживает повторный `.task` при возврате на экран (сбрасывать её на каждый
/// показ нельзя); целиком сбрасывается на `screenShown` после успешной аутентификации
/// (выход из аккаунта) — см. AuthIntent.screenShown. Ошибки показываются инлайн на форме
/// и переживают пересоздание вью; сбрасываются при вводе, переключении режима и новом сабмите.
struct AuthUiState {
    var mode: AuthMode = .signIn
    var email: String = ""
    var password: String = ""

    /// Заполняется только в режиме signUp: второе поле для подтверждения пароля.
    var repeatedPassword: String = ""

    /// Заполняется только в режиме signUp и попадает в users/{uid}.displayName.
    var displayName: String = ""

    var isLoading: Bool = false
    var error: AuthUiError? = nil

    static let initial = AuthUiState()
}

/// Действия пользователя и системные события провайдеров входа (порт 1:1
/// из Android AuthIntent + iOS-расширение Apple, зеркальное Google).
enum AuthIntent {
    /// Экран показан. На каждый показ — no-op (форма переживает повторный `.task`);
    /// повторный показ после успешной аутентификации (выход из аккаунта) целиком
    /// сбрасывает форму в AuthUiState.initial.
    case screenShown

    // Ввод текста
    case emailChanged(String)
    case passwordChanged(String)
    case repeatedPasswordChanged(String)
    case displayNameChanged(String)

    /// Переключение режима: сбрасывает пароли и ошибку, email сохраняет.
    case modeChanged(AuthMode)

    // Email/Password
    case signInWithEmailClicked
    case signUpWithEmailClicked

    // Google: клик поднимает isLoading, дальше ViewModel сам запрашивает токен
    // у GoogleSignInRequesting и маршрутизирует результат через кейсы ниже.
    case googleSignInClicked

    /// UI-слой получил idToken от Google SDK и передаёт его на обмен в интерактор.
    case googleCredentialReceived(idToken: String)

    /// Пользователь закрыл системный диалог выбора аккаунта.
    case googleSignInCancelled

    /// SDK вернул ошибку (нет сети, нет сконфигурированного клиента и т.п.).
    case googleSignInFailed(reason: String?)

    // Apple (iOS-расширение, зеркально Google): клик поднимает isLoading,
    // системный sheet открывает AuthAppleButton, результат приходит в кейсы ниже.
    case appleSignInClicked

    /// UI-слой получил idToken + rawNonce (анти-replay) от Apple и передаёт их
    /// на обмен в интерактор; fullName приходит только при первой авторизации.
    case appleCredentialReceived(idToken: String, rawNonce: String, fullName: String?)

    /// Пользователь закрыл системный sheet Apple.
    case appleSignInCancelled

    /// Авторизация Apple вернула ошибку.
    case appleSignInFailed(reason: String?)

    /// Пользователь закрыл баннер с ошибкой.
    case errorDismissed
}

/// One-off события экрана (порт 1:1 из Android AuthEffect).
enum AuthEffect {
    /// Аутентификация успешна, документ users/{uid} создан или обновлён.
    case navigateToMain
}
