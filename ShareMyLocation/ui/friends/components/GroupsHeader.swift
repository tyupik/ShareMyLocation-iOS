import SwiftUI

/// Заголовок секции «Группы» с кнопкой «Создать» (открывает редактор в режиме создания;
/// на этапе 4 — баннер-заглушка в MainScreen). Порт 1:1 из Android GroupsHeader.kt
/// (строки — дословно groups_section/groups_create_button).
struct GroupsHeader: View {
    let onCreateClick: () -> Void

    var body: some View {
        HStack {
            Text("Группы")
                .font(.auroraTitleMedium)
                .foregroundStyle(AuroraColors.auroraText)
            Spacer()
            Button(action: onCreateClick) {
                Text("Создать")
                    .font(.auroraLabelLarge)
                    .foregroundStyle(AuroraColors.auroraIndigoLight)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    GroupsHeader(onCreateClick: {})
        .padding(16)
}
