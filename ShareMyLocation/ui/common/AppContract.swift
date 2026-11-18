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
    case authCompleted

    /// Онбординг завершён (профиль сохранён): повторный resolve сессии, на этот раз
    /// с отправкой Effect (целевой экран — Main).
    case onboardingCompleted

    /// Запрошен выход из аккаунта. Временная интеграция этапа 3 — удалить на этапе 4:
    /// в Android выход живёт в контракте MainViewModel, здесь временно
    /// AppViewModel просто вызывает signOut (observeAuthState сам переразрешит сессию).
    case signOutRequested
}

/// One-off события корневой навигации: маршрутизацией занимается AppRootView.
/// В этапе 1 не отправляются (ветка навигации уже отражена в state); отправка включится
/// вместе с AuthScreen в этапе 2.
enum AppEffect {
    case navigateToMain
    case navigateToProfileSetup
}
