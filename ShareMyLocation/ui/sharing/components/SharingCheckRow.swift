import SwiftUI

/**
 Строка чекбокса секций «Люди»/«Группы» настроек шаринга: стеклянная карточка, чекбокс
 и имя; клик по всей строке переключает чекбокс. Осознанный локальный аналог
 GroupMemberCheckRow без аватара: фичу groups не трогаем, в ui.common не выносим.
 Порт 1:1 из Android SharingCheckRow.kt.
 */
struct SharingCheckRow: View {
    let row: SharingCheckRowUiModel
    let onToggle: () -> Void

    var body: some View {
        GlassCard(action: onToggle) {
            HStack(spacing: 12) {
                checkbox
                Text(row.displayName)
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

    /// Кастомный чекбокс 22×22 (M3 Checkbox → токены AURORA): checked — заливка/рамка
    /// индиго-светлый и галочка, unchecked — стекло.
    private var checkbox: some View {
        RoundedRectangle(cornerRadius: AuroraShapes.small)
            .fill(row.isChecked ? AuroraColors.auroraIndigoLight : AuroraColors.auroraGlass)
            .overlay(
                RoundedRectangle(cornerRadius: AuroraShapes.small)
                    .strokeBorder(
                        row.isChecked ? AuroraColors.auroraIndigoLight : AuroraColors.auroraGlassBorder,
                        lineWidth: 1,
                    ),
            )
            .overlay {
                if row.isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AuroraColors.auroraOnGradient)
                }
            }
            .frame(width: 22, height: 22)
    }
}

#Preview {
    VStack(spacing: 8) {
        SharingCheckRow(
            row: SharingCheckRowUiModel(id: "uid-1", displayName: "Иван", isChecked: true),
            onToggle: {},
        )
        SharingCheckRow(
            row: SharingCheckRowUiModel(id: "uid-2", displayName: "Мария", isChecked: false),
            onToggle: {},
        )
    }
    .padding(16)
    .background(AuroraColors.auroraSurfaceVariant.ignoresSafeArea())
}
