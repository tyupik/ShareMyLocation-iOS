import SwiftUI

/// Поле ввода названия группы: обёртка AuroraField (стекло + статичная метка над полем).
struct GroupEditorNameField: View {
    @Binding var text: String
    let isEnabled: Bool

    var body: some View {
        AuroraField(title: "Название группы", text: $text, isEnabled: isEnabled)
    }
}

#Preview {
    GroupEditorNameField(text: .constant("Родные"), isEnabled: true)
        .padding(16)
}
