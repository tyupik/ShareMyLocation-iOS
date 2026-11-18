import SwiftUI

/// Переключатель режима Вход/Регистрация: кастомная стеклянная пилюля AURORA
/// (вместо системного segmented-контрола). Выбранная опция — циановое стекло
/// с акцентной рамкой, как в GlassCard(isSelected:). Порт Android AuthModeSwitcher.kt.
struct AuthModeSwitcher: View {
    let mode: AuthMode
    let isEnabled: Bool
    let onModeChanged: (AuthMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            segmentButton(title: "Вход", target: .signIn)
            segmentButton(title: "Регистрация", target: .signUp)
        }
        .disabled(!isEnabled)
    }

    private func segmentButton(title: String, target: AuthMode) -> some View {
        let isSelected = mode == target
        return Button {
            onModeChanged(target)
        } label: {
            Text(title)
                .font(.auroraLabelLarge)
                .foregroundStyle(isSelected ? AuroraColors.auroraCyan : AuroraColors.auroraTextMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: AuroraShapes.medium)
                        .fill(isSelected ? AuroraColors.auroraSelectedGlass : AuroraColors.auroraGlass),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AuroraShapes.medium)
                        .strokeBorder(
                            isSelected ? AuroraColors.auroraAccentBorder : AuroraColors.auroraGlassBorder,
                            lineWidth: 1,
                        ),
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthModeSwitcher(mode: .signIn, isEnabled: true, onModeChanged: { _ in })
        .padding(16)
}
