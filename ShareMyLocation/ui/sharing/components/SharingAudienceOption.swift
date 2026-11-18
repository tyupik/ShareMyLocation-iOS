import SwiftUI

/**
 Radio-строка выбора аудитории шаринга: стеклянная карточка с кастомным радио-индикатором
 (M3 RadioButton → токены) и подписью; клик по всей строке выбирает вариант.
 Порт 1:1 из Android SharingAudienceOption.kt.
 */
// TODO: проверить на CI — визуал радио-индикатора (кольцо + точка, размеры 22×22).
struct SharingAudienceOption: View {
    let label: String
    let isSelected: Bool
    let onClick: () -> Void

    var body: some View {
        GlassCard(action: onClick, isSelected: isSelected) {
            HStack(spacing: 12) {
                radioButton
                Text(label)
                    .font(.auroraBodyLarge)
                    .foregroundStyle(AuroraColors.auroraText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Зона клика — вся ширина строки (порт Row.clickable Android).
            .contentShape(Rectangle())
            .padding(12)
        }
    }

    /// Кастомный радио-индикатор 22×22: selected — кольцо + точка индиго-светлый,
    /// unselected — кольцо стеклянной рамки.
    private var radioButton: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? AuroraColors.auroraIndigoLight : AuroraColors.auroraGlassBorder,
                    lineWidth: 1.5,
                )
            if isSelected {
                Circle()
                    .fill(AuroraColors.auroraIndigoLight)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 22, height: 22)
    }
}

#Preview {
    VStack(spacing: 8) {
        SharingAudienceOption(label: "Все друзья", isSelected: true, onClick: {})
        SharingAudienceOption(label: "Выбранные люди и группы", isSelected: false, onClick: {})
    }
    .padding(16)
    .background(AuroraColors.auroraSurfaceVariant.ignoresSafeArea())
}
