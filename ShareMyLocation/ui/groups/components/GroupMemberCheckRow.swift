import SwiftUI

/**
 Строка участника группы: чекбокс и имя друга; клик по всей строке переключает чекбокс.
 Аватары в чекбоксах сознательно не показываются (как в Android).
 */
struct GroupMemberCheckRow: View {
    let member: GroupMemberUiModel
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                checkbox
                Text(member.displayName)
                    .font(.auroraBodyLarge)
                    .foregroundStyle(AuroraColors.auroraText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            // Зона клика — вся ширина строки (порт Row.clickable Android).
            .contentShape(Rectangle())
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    /// Кастомный чекбокс 22×22 (M3 Checkbox → токены AURORA): checked — заливка/рамка
    /// индиго и галочка, unchecked — стекло.
    private var checkbox: some View {
        RoundedRectangle(cornerRadius: AuroraShapes.small)
            .fill(member.isChecked ? AuroraColors.auroraIndigoLight : AuroraColors.auroraGlass)
            .overlay(
                RoundedRectangle(cornerRadius: AuroraShapes.small)
                    .strokeBorder(
                        member.isChecked ? AuroraColors.auroraIndigoLight : AuroraColors.auroraGlassBorder,
                        lineWidth: 1,
                    ),
            )
            .overlay {
                if member.isChecked {
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
        GroupMemberCheckRow(
            member: GroupMemberUiModel(uid: "u1", displayName: "Анна", isChecked: true),
            isEnabled: true,
            onToggle: {},
        )
        GroupMemberCheckRow(
            member: GroupMemberUiModel(uid: "u2", displayName: "Борис", isChecked: false),
            isEnabled: true,
            onToggle: {},
        )
    }
    .padding(16)
}
