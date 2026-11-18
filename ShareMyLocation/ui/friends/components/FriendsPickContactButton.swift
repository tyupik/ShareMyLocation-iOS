import SwiftUI
import UIKit

/**
 Кнопка «Выбрать из контактов» рядом с полем поиска: открывает системный контакт-пикер,
 выбранный телефон подставляется в поиск. Как и поле поиска, гасится, пока выполняется
 действие с другом (isEnabled). Порт 1:1 из Android FriendsPickContactButton.kt
 (строка — дословно friends_search_pick_contact; Android Icons.Outlined.PersonSearch
 → SF person.text.search).
 */
struct FriendsPickContactButton: View {
    /// Доступность SF-символа проверяется в рантайме: person.text.search появился в iOS 17,
    /// отсутствующий символ рендерится пустым — подстраховка через UIImage (см. TODO ниже).
    private static let CONTACT_SEARCH_SYMBOL = "person.text.search"

    /// Запасной символ, если основной не найдётся на рантайм-версии iOS.
    private static let CONTACT_SEARCH_FALLBACK_SYMBOL = "magnifyingglass"

    let isEnabled: Bool
    let onClick: () -> Void

    var body: some View {
        GlassIconButton(
            systemImage: Self.contactSearchSymbol,
            accessibilityLabel: "Выбрать из контактов",
            action: onClick,
            isEnabled: isEnabled,
        )
    }

    // TODO: проверить на CI — UIImage(systemName:) как проверка доступности SF-символа.
    private static var contactSearchSymbol: String {
        UIImage(systemName: CONTACT_SEARCH_SYMBOL) != nil
            ? CONTACT_SEARCH_SYMBOL
            : CONTACT_SEARCH_FALLBACK_SYMBOL
    }
}

#Preview {
    FriendsPickContactButton(isEnabled: true, onClick: {})
        .padding(16)
}
