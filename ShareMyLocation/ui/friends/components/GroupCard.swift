import SwiftUI

/**
 Карточка группы: имя и подпись «N участников»; клик открывает редактор группы.
 Счётчик может завышаться, если из друзей недавно удалили участника группы
 (чистка memberUids отложена — этап 5); редактор покажет актуальный состав.
 Порт 1:1 из Android GroupCard.kt; плюрализация groups_member_count (one/few/many)
 локальная — без PluralStringResource (см. план этапа 4).
 */
struct GroupCard: View {
    let group: GroupUiModel
    let onGroupClick: () -> Void

    var body: some View {
        GlassCard(action: onGroupClick) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.auroraTitleMedium)
                    .foregroundStyle(AuroraColors.auroraText)
                    .lineLimit(1)
                Text(memberCountText)
                    .font(.auroraBodyMedium)
                    .foregroundStyle(AuroraColors.auroraTextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    /// Локальная плюрализация Android plurals groups_member_count:
    /// «1 участник» / «2–4 участника» / «N участников» (правила русского склонения).
    private var memberCountText: String {
        let count = group.memberCount
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1, mod100 != 11 {
            return "\(count) участник"
        }
        if (2...4).contains(mod10), !(12...14).contains(mod100) {
            return "\(count) участника"
        }
        return "\(count) участников"
    }
}

#Preview {
    VStack(spacing: 12) {
        GroupCard(
            group: GroupUiModel(groupId: "g1", name: "Родные", memberCount: 1),
            onGroupClick: {},
        )
        GroupCard(
            group: GroupUiModel(groupId: "g2", name: "Друзья", memberCount: 3),
            onGroupClick: {},
        )
        GroupCard(
            group: GroupUiModel(groupId: "g3", name: "Коллеги", memberCount: 11),
            onGroupClick: {},
        )
    }
    .padding(16)
}
