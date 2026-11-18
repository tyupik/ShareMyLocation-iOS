/// Результат запроса Google-токена. iOS-аналог GoogleCredentialOutcome из Android
/// ui/auth/GoogleCredentialRequest.kt: success/cancelled/failed портированы 1:1,
/// notConfigured — iOS-специфика (GoogleSignIn-iOS без конфигурации).
enum GoogleSignInOutcome {
    /// Пользователь выбрал аккаунт: idToken для обмена на Firebase-сессию;
    /// accessToken нужен Firebase-креденшелу GoogleAuthProvider.
    case success(idToken: String, accessToken: String?)

    /// Пользователь закрыл системный диалог выбора аккаунта — не ошибка.
    case cancelled

    /// SDK вернул ошибку (нет Play Services-аналога, сетевой сбой и т.п.).
    case failed(reason: String?)

    /// GoogleSignIn-iOS не сконфигурирован (нет GoogleService-Info.plist,
    /// GIDSignIn.configuration не задан) — баннер «Сервисы Google не настроены».
    case notConfigured
}

/// Источник Google-токена для обмена на Firebase-сессию. Протокол живёт в business,
/// реализация (GIDSignIn) — в data/auth: ViewModel не знает про GoogleSignIn SDK.
protocol GoogleSignInRequesting {
    /// Показывает системный диалог выбора Google-аккаунта и возвращает токены;
    /// без побочных эффектов для UiState — их ведёт AuthViewModel по outcome.
    func requestIdToken() async -> GoogleSignInOutcome
}
