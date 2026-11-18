/// Состояние корневой навигации: порт 1:1 из Android AppViewModel.kt.
/// Пока `isSessionResolved` равно false, стартовый экран не определён и UI показывает
/// индикатор загрузки. `requiresOnboarding` — вошедший пользователь ещё не прошёл
/// онбординг ProfileSetup.
struct AppUiState {
    var isSessionResolved: Bool = false
    var isAuthenticated: Bool = false
    var requiresOnboarding: Bool = false

    static let initial = AppUiState()
}

/// Системные события корневой навигации.
enum AppIntent {
    /// Аутентификация выполнена — нужно решить, куда вести дальше: онбординг или Main.
    /// Придёт из AuthScreen в этапе 2.
    case authCompleted
}

/// One-off события корневой навигации: маршрутизацией занимается AppRootView.
/// В этапе 1 не отправляются (ветка навигации уже отражена в state); отправка включится
/// вместе с AuthScreen в этапе 2.
enum AppEffect {
    case navigateToMain
    case navigateToProfileSetup
}
