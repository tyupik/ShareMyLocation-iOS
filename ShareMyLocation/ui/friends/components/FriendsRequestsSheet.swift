import SwiftUI

/**
 Sheet входящих заявок в друзья: открывается по колокольчику в FriendsHeader (isPresented
 держит вызывающая сторона — FriendsScreen, состояние isRequestsSheetVisible).
 Ошибка действия (принять/отклонить) показывается inline над списком; упавший realtime-поток —
 как FriendsLoadError с «Повторить». Пустое состояние обязательно: realtime-поток может
 обнулить requests при открытом листе (последнюю заявку приняли/отклонили).
 Порт 1:1 из Android FriendsRequestsSheet.kt (строки — дословно friends_section_requests/
 friends_empty_requests; M3 ModalBottomSheet → системный sheet).
 */
struct FriendsRequestsSheet: View {
    let requests: [FriendRequestUiModel]
    let busyUid: String?
    let isRequestsLoadFailed: Bool
    let errorText: String?
    let onAcceptClick: (String) -> Void
    let onDeclineClick: (String) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Заявки")
                .font(.auroraTitleMedium)
                .foregroundStyle(AuroraColors.auroraText)
                .padding(.top, 16)
            if let errorText {
                Text(errorText)
                    .font(.auroraBodyMedium)
                    .foregroundStyle(AuroraColors.auroraTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if isRequestsLoadFailed {
                FriendsLoadError(onRetry: onRetry)
            } else if requests.isEmpty {
                FriendsEmptyState(text: "Заявок пока нет")
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(requests, id: \.fromUid) { request in
                            FriendsRequestCard(
                                request: request,
                                isBusy: busyUid == request.fromUid,
                                onAcceptClick: { onAcceptClick(request.fromUid) },
                                onDeclineClick: { onDeclineClick(request.fromUid) },
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(AuroraColors.auroraSurfaceVariant.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    FriendsRequestsSheet(
        requests: [],
        busyUid: nil,
        isRequestsLoadFailed: false,
        errorText: nil,
        onAcceptClick: { _ in },
        onDeclineClick: { _ in },
        onRetry: {},
    )
}
