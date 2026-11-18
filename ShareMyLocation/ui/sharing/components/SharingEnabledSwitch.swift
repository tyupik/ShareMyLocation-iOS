import SwiftUI

/**
 Строка главного переключателя шаринга: стеклянная карточка, подпись и кастомный
 switch-индикатор AURORA; клик по всей строке переключает. Системный Toggle не используется —
 индикатор рисуется капсулой 44×26 в токенах AURORA (M3 Switch → токены). Выключенное
 состояние — обещание приватности «уже выключено», поэтому без задержек.
 Порт 1:1 из Android SharingEnabledSwitch.kt.
 */
// TODO: проверить на CI — визуал кастомного switch-индикатора (анимация knob'а, размеры).
struct SharingEnabledSwitch: View {
    let isChecked: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        GlassCard(action: { onToggle(!isChecked) }) {
            HStack(spacing: 12) {
                Text("Делиться геопозицией")
                    .font(.auroraBodyLarge)
                    .foregroundStyle(AuroraColors.auroraText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                switchIndicator
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Зона клика — вся ширина строки (порт Row.clickable Android).
            .contentShape(Rectangle())
            .padding(12)
        }
    }

    /// Кастомный индикатор: капсула 44×26; checked — заливка индиго и белый knob справа,
    /// unchecked — стекло и рамка, knob слева. Белый — thumb M3 Switch Android (системный
    /// константный цвет, не токен темы).
    private var switchIndicator: some View {
        ZStack(alignment: isChecked ? .trailing : .leading) {
            Capsule()
                .fill(isChecked ? AuroraColors.auroraIndigo : AuroraColors.auroraGlass)
            if !isChecked {
                Capsule()
                    .strokeBorder(AuroraColors.auroraGlassBorder, lineWidth: 1)
            }
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .padding(3)
        }
        .frame(width: 44, height: 26)
        .animation(.easeInOut(duration: 0.15), value: isChecked)
    }
}

#Preview {
    VStack(spacing: 8) {
        SharingEnabledSwitch(isChecked: true, onToggle: { _ in })
        SharingEnabledSwitch(isChecked: false, onToggle: { _ in })
    }
    .padding(16)
    .background(AuroraColors.auroraSurfaceVariant.ignoresSafeArea())
}
