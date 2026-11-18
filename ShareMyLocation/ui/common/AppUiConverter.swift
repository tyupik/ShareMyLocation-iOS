/// Ui-модель корневой навигации. Порт 1:1 из Android AppUiConverter.kt.
struct AppUiModel {
    let isAuthenticated: Bool

    /// Вошедший пользователь ещё не прошёл онбординг ProfileSetup.
    let requiresOnboarding: Bool
}

/// Конвертер бизнес-моделей в Ui-модель корневой навигации.
/// Порт 1:1 из Android AppUiConverter.kt.
struct AppUiConverter {
    /// - Parameters:
    ///   - user: пользователь сохранённой сессии либо nil.
    ///   - profile: его документ users/{uid} либо nil (нет сессии или ошибка чтения).
    ///     В этапе 1 вызывается с nil; реальный профиль подключит этап 3.
    func convert(_ user: User?, _ profile: User?) -> AppUiModel {
        AppUiModel(
            isAuthenticated: user != nil,
            requiresOnboarding: user != nil && profile != nil && !(profile?.hasCompletedOnboarding ?? true),
        )
    }
}
