import Foundation
import Observation

/// ViewModel главного экрана-контейнера: хранит выбранную вкладку, badge входящих заявок
/// в друзья и выполняет выход из аккаунта. Явный стоп шаринга перед выходом
/// (LocationSharingController) — этап 8; запрос права на уведомления — этап 8.
/// Порт 1:1 из Android MainViewModel.kt. Единственная публичная точка входа для UI — onIntent.
@MainActor
@Observable
final class MainViewModel {
    private(set) var state: MainUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<MainEffect>
    private let effectsContinuation: AsyncStream<MainEffect>.Continuation

    private let authInteractor: AuthInteractor
    private let friendsInteractor: FriendsInteractor

    /// Активная badge-задача: перезапускается при каждой смене вкладки
    /// (порт badgeTrigger + flatMapLatest Android).
    private var badgeTask: Task<Void, Never>?

    init(authInteractor: AuthInteractor, friendsInteractor: FriendsInteractor) {
        self.authInteractor = authInteractor
        self.friendsInteractor = friendsInteractor
        let (stream, continuation) = AsyncStream.makeStream(
            of: MainEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
        // Badge слушает с момента создания (порт init { observePendingRequests() } Android):
        // счётчик актуален и на вкладке «Карта», до первого переключения табов.
        restartBadgeTask()
    }

    deinit {
        badgeTask?.cancel()
    }

    func onIntent(_ intent: MainIntent) {
        switch intent {
        case .tabSelected(let tab):
            state.selectedTab = tab
            restartBadgeTask()
        case .signOutClicked:
            signOut()
        }
    }

    /// Badge входящих заявок. ViewModel переживает logout→login, поэтому слушатель
    /// перезапускается при каждой смене вкладки (порт observePendingRequests + badgeTrigger
    /// Android): старый поток после смены аккаунта умирает (например, PERMISSION_DENIED),
    /// и без перезапуска badge второго аккаунта остался бы мёртвым навсегда.
    /// Ошибка (обрыв потока) глотается НАМЕРЕННО (контракт MainUiState не содержит
    /// error-поля): badge остаётся с последним значением.
    private func restartBadgeTask() {
        badgeTask?.cancel()
        badgeTask = Task {
            for await requests in friendsInteractor.observeIncomingFriendRequests() {
                guard !Task.isCancelled else { return }
                state.pendingRequestsCount = requests.count
            }
            // Конец потока без отмены — realtime-обрыв слушателя: badge остаётся
            // с последним значением, восстановление при следующей смене вкладки.
            guard !Task.isCancelled else { return }
            print("MainViewModel: Realtime-поток входящих заявок прервался")
        }
    }

    private func signOut() {
        Task {
            // Явный стоп сервиса ДО выхода (Фаза 8): смерть Firestore-слушателя после signOut
            // не мгновенна, иначе движок шаринга продолжил бы писать и ловить PERMISSION_DENIED.
            await authInteractor.signOut()
            effectsContinuation.yield(.navigateToAuth)
        }
    }
}
