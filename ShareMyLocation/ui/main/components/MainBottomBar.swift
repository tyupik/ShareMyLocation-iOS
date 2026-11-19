import SwiftUI

/**
 Нижняя навигация главного экрана: плавающая пилюля AURORA с вкладками Карта, Друзья,
 Профиль. Фон — блюр-подложка (.ultraThinMaterial + тонировка auroraBackground 0.55 —
 порт auroraHazeStyle; noise-фактор Haze не воспроизводим — признанная замена этапа 9;
 GMSMapView — обычный UIView, material блюрит его как любой контент под панелью).
 Активный таб — одна градиентная пилюля на весь навбар: «перекатывается» пружиной
 (response 0.35, damping 0.75) к выбранному табу и пульсирует 0.94→1.0 (MediumBouncy,
 damping 0.5); цвет контента вкладок перетекает следом (spring 0.35/1.0 — без overshoot).
 Порт 1:1 из Android MainBottomBar.kt; пульс и смещение — эфемерное UI-состояние
 (@State/производные), НЕ бизнес-состояние.
 */
struct MainBottomBar: View {
    let selectedTab: MainTab
    let friendsBadgeCount: Int
    let onTabSelected: (MainTab) -> Void

    /// Пульс пилюли (0.94 → 1.0) — эфемерное UI-состояние анимации, не бизнес-состояние.
    @State private var pillPulse: CGFloat = 1

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
        .background { panelBackground }
        .overlay(Capsule().strokeBorder(AuroraColors.auroraGlassBorder, lineWidth: 1))
        .padding(.horizontal, Self.NAVBAR_HORIZONTAL_PADDING)
        .padding(.bottom, Self.NAVBAR_BOTTOM_PADDING)
        // Пульс пилюли: при первом появлении (аналог LaunchedEffect(selectedTab) Android,
        // который проигрывает и на первом композиционировании) и при каждой смене таба.
        .onAppear { triggerPillPulse() }
        .onChange(of: selectedTab) { _, _ in triggerPillPulse() }
    }

    /**
     Подложка панели и пилюля активного таба: блюр (material + tint 0.55 — порт
     auroraHazeStyle) → единая градиентная пилюля за контентом выбранной вкладки.
     Ширина таба — вся ширина навбара минус отступы ряда контента, делённая на число
     вкладок (аналог weight(1f) Android); пилюля смещается пружиной «перекатывания».
     */
    private var panelBackground: some View {
        ZStack {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(AuroraColors.auroraBackground.opacity(Self.NAVBAR_TINT_ALPHA))
            GeometryReader { proxy in
                let tabWidth = (proxy.size.width - 2 * Self.TABS_ROW_PADDING) / CGFloat(MainTab.allCases.count)
                Capsule()
                    .fill(AuroraBrushes.auroraButtonBrush)
                    .frame(width: tabWidth)
                    .scaleEffect(pillPulse)
                    .padding(.vertical, Self.PILL_VERTICAL_INSET)
                    .offset(x: Self.TABS_ROW_PADDING + tabWidth * CGFloat(selectedTab.index))
                    .animation(
                        .spring(
                            response: Self.PILL_SPRING_RESPONSE,
                            dampingFraction: Self.PILL_SPRING_DAMPING_RATIO,
                        ),
                        value: selectedTab,
                    )
            }
        }
    }

    /**
     Пульс пилюли «в такт» переключению: мгновенное поджатие 0.94 без анимации
     (disablesAnimations глушит в том числе .animation-модификатор перекатывания) и
     упругий возврат к 1.0. Возврат — со следующего тика runloop: синхронная склейка
     двух мутаций свела бы пульс к «нет анимации» (рендерится только финальное значение).
     */
    private func triggerPillPulse() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pillPulse = Self.PILL_PULSE_START_SCALE
        }
        Task { @MainActor in
            withAnimation(
                .spring(
                    response: Self.PILL_PULSE_RESPONSE,
                    dampingFraction: Self.PILL_PULSE_DAMPING_RATIO,
                ),
            ) {
                pillPulse = 1
            }
        }
    }

    /// Отступы контента вкладок внутри навбара (Android TABS_ROW_*_PADDING = 8).
    private static let TABS_ROW_PADDING: CGFloat = 8

    /// Вертикальный зазор пилюли активного таба от краёв навбара: стекло видно сверху и снизу.
    private static let PILL_VERTICAL_INSET: CGFloat = 8

    /// Альфа тонировки панели поверх блюра (Android HazeTint auroraBackground 0.55).
    private static let NAVBAR_TINT_ALPHA = 0.55

    /// Пружина «перекатывания» пилюли (порт animateDpAsState spring(dampingRatio = 0.75)).
    private static let PILL_SPRING_RESPONSE: CGFloat = 0.35
    private static let PILL_SPRING_DAMPING_RATIO: CGFloat = 0.75

    /// Начальный масштаб пульса пилюли (Android PILL_PULSE_START_SCALE = 0.94).
    private static let PILL_PULSE_START_SCALE: CGFloat = 0.94

    /// Пружина возврата пульса: MediumBouncy (damping 0.5) на дефолтной жёсткости
    /// spring() Compose (stiffness 400 → response ≈ 0.3).
    private static let PILL_PULSE_RESPONSE: CGFloat = 0.3
    private static let PILL_PULSE_DAMPING_RATIO: CGFloat = 0.5

    /// Горизонтальный отступ пилюли-навбара от краёв экрана (Android h16).
    private static let NAVBAR_HORIZONTAL_PADDING: CGFloat = 16

    /// Отступ пилюли-навбара от края safe area (Android bottom12; навигационную панель
    /// учитывает safeAreaInset — navigationBarsPadding Android не нужен).
    private static let NAVBAR_BOTTOM_PADDING: CGFloat = 12
}

/// Описание вкладки: SF-символ, подпись и позиция для пилюли. Порт MAIN_TAB_ITEMS Android
/// (строки — дословно main_tab_map/main_tab_friends/main_tab_profile из strings.xml).
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

    /// Позиция вкладки в CaseIterable-порядке — множитель смещения пилюли (аналог
    /// MAIN_TAB_ITEMS.indexOfFirst Android).
    var index: Int {
        MainTab.allCases.firstIndex(of: self) ?? 0
    }
}

/**
 Одна вкладка навбара: контент поверх единой пилюли фона (пилюлю рисует MainBottomBar за
 всеми вкладками); у «Друзей» — бейдж заявок. Цвет контента перетекает пружиной
 0.35/1.0 (порт animateColorAsState Android, без overshoot).
 */
private struct MainTabItemView: View {
    let tab: MainTab
    let isSelected: Bool
    let badgeCount: Int
    let onSelected: () -> Void

    /// Вертикальный отступ контента вкладки (Android padding vertical 10).
    private static let CONTENT_VERTICAL_PADDING: CGFloat = 10

    /// Пружина цвета контента вкладки (дефолтный spring() Compose ≈ 0.3, NoBouncy = 1.0).
    private static let CONTENT_COLOR_SPRING_RESPONSE: CGFloat = 0.35
    private static let CONTENT_COLOR_SPRING_DAMPING_RATIO: CGFloat = 1.0

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
            .animation(
                .spring(
                    response: Self.CONTENT_COLOR_SPRING_RESPONSE,
                    dampingFraction: Self.CONTENT_COLOR_SPRING_DAMPING_RATIO,
                ),
                value: isSelected,
            )
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
                    .foregroundStyle(AuroraColors.auroraOnDanger)
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
