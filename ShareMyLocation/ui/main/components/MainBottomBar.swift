import SwiftUI

/// Нижняя навигация главного экрана: плавающая пилюля AURORA с вкладками Карта, Друзья,
/// Профиль. Статичная рабочая версия этапа 4: пилюля активного таба — градиентная капсула
/// за контентом выбранного таба; пружинное «перекатывание» и пульс 0.94→1.0 — этап 9.
/// Порт 1:1 из Android MainBottomBar.kt (без haze-блюра и анимаций).
struct MainBottomBar: View {
    let selectedTab: MainTab
    let friendsBadgeCount: Int
    let onTabSelected: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                MainTabItemView(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badgeCount: tab == .friends ? friendsBadgeCount : 0,
                    onSelected: { onTabSelected(tab) },
                )
            }
        }
        .padding(Self.TABS_ROW_PADDING)
        // Стадионная форма (радиус = половина высоты) — единый язык скругления с пилюлей
        // активного таба: «пилюля в пилюле».
        .background(Capsule().fill(AuroraColors.auroraGlass))
        .overlay(Capsule().strokeBorder(AuroraColors.auroraGlassBorder, lineWidth: 1))
        .padding(.horizontal, Self.NAVBAR_HORIZONTAL_PADDING)
        .padding(.bottom, Self.NAVBAR_BOTTOM_PADDING)
    }

    /// Отступы контента вкладок внутри навбара (Android TABS_ROW_*_PADDING = 8).
    private static let TABS_ROW_PADDING: CGFloat = 8

    /// Горизонтальный отступ пилюли-навбара от краёв экрана (Android h16).
    private static let NAVBAR_HORIZONTAL_PADDING: CGFloat = 16

    /// Отступ пилюли-навбара от края safe area (Android bottom12; навигационную панель
    /// учитывает safeAreaInset — navigationBarsPadding Android не нужен).
    private static let NAVBAR_BOTTOM_PADDING: CGFloat = 12
}

/// Описание вкладки: SF-символ и подпись. Порт MAIN_TAB_ITEMS Android (строки — дословно
/// main_tab_map/main_tab_friends/main_tab_profile из strings.xml).
private extension MainTab {
    var label: String {
        switch self {
        case .map:
            return "Карта"
        case .friends:
            return "Друзья"
        case .profile:
            return "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .map:
            return "map"
        case .friends:
            return "person.2"
        case .profile:
            return "person"
        }
    }
}

/// Одна вкладка навбара: пилюля активного таба — градиентная капсула за контентом
/// (вертикальный отступ 10, как в Android), у «Друзей» — бейдж заявок.
private struct MainTabItemView: View {
    let tab: MainTab
    let isSelected: Bool
    let badgeCount: Int
    let onSelected: () -> Void

    /// Вертикальный отступ контента вкладки (Android padding vertical 10).
    private static let CONTENT_VERTICAL_PADDING: CGFloat = 10

    var body: some View {
        Button(action: onSelected) {
            VStack(spacing: 2) {
                if badgeCount > 0 {
                    badgeOverlay {
                        symbol
                    }
                } else {
                    symbol
                }
                Text(tab.label)
                    .font(.auroraLabelMedium)
                    .foregroundStyle(contentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Self.CONTENT_VERTICAL_PADDING)
            .background {
                if isSelected {
                    // Пилюля активного таба: рисуется за контентом вкладки (этап 4 — статично).
                    Capsule().fill(AuroraBrushes.auroraButtonBrush)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// SF-символ вкладки; у выбранной — вариант .fill (аналог filled/outlined пары Android).
    private var symbol: some View {
        Image(systemName: tab.systemImage)
            // TODO: проверить на CI — .environment(\.symbolVariants, .fill) на Image(systemName:).
            .environment(\.symbolVariants, isSelected ? .fill : .none)
            .font(.system(size: 22))
            .foregroundStyle(contentColor)
    }

    @ViewBuilder
    private func badgeOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .overlay(alignment: .topTrailing) {
                // Капсула danger — аналог M3 Badge на вкладке «Друзья»; нулевой бейдж не рисуется.
                Text("\(badgeCount)")
                    .font(.auroraLabelSmall)
                    .foregroundStyle(AuroraColors.auroraBackground)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(AuroraColors.auroraDanger))
                    .offset(x: 10, y: -4)
            }
    }

    /// Активный таб — контент градиента (auroraOnGradient), остальные — muted.
    private var contentColor: Color {
        isSelected ? AuroraColors.auroraOnGradient : AuroraColors.auroraTextMuted
    }
}

#Preview {
    VStack {
        Spacer()
        MainBottomBar(
            selectedTab: .friends,
            friendsBadgeCount: 2,
            onTabSelected: { _ in },
        )
    }
    .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
