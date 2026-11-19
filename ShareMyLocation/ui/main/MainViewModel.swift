import Foundation
import Observation

/// ViewModel главного экрана-контейнера: хранит выбранную вкладку, badge входящих заявок
/// в друзья, выполняет выход из аккаунта и однократный запрос права на уведомления.
/// Явный стоп движка шаринга перед выходом (LocationSharingEngine) — порт Android
/// MainViewModel.signOut 1:1; запрос права на уведомления выполняется здесь системным
/// диалогом (Effect не нужен — UI не участвует). Единственная публичная точка входа
/// для UI — onIntent.
@MainActor
@Observable
final class MainViewModel {
    private(set) var state: MainUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<MainEffect>
    private let effectsContinuation: AsyncStream<MainEffect>.Continuation

    private let authInteractor: AuthInteractor
    private let friendsInteractor: FriendsInteractor
    private let locationSharingEngine: LocationSharingEngine
    private let notificationPermissionController: NotificationPermissionController

    /// Активная badge-задача: перезапускается при каждой смене вкладки
    /// (порт badgeTrigger + flatMapLatest Android).
    private var badgeTask: Task<Void, Never>?

    init(
        authInteractor: AuthInteractor,
        friendsInteractor: FriendsInteractor,
        locationSharingEngine: LocationSharingEngine,
        notificationPermissionController: NotificationPermissionController,
    ) {
        self.authInteractor = authInteractor
        self.friendsInteractor = friendsInteractor
        self.locationSharingEngine = locationSharingEngine
        self.notificationPermissionController = notificationPermissionController
        let (stream, continuation) = AsyncStream.makeStream(
            of: MainEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
        // Badge слушает с момента создания (порт init { observePendingRequests() } Android):
        // счётчик актуален и на вкладке «Карта», до первого переключения табов.
        restartBadgeTask()
        maybeRequestNotificationsPermission()
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

    /**
     Разовый запрос права на уведомления (порт maybeRequestNotificationsPermission Android):
     диалог показывается, только если право фактически не выдано и ещё ни разу не
     показывалось (флаг в NotificationPermissionController ставится при любом результате —
     отказ не навязывает повторный запрос).
     */
    private func maybeRequestNotificationsPermission() {
        Task {
            let isGranted = await notificationPermissionController.isGranted()
            guard !isGranted, notificationPermissionController.shouldRequest() else { return }
            let granted = await notificationPermissionController.requestAuthorization()
            notificationPermissionController.onRequestResult(granted: granted)
        }
    }

    private func signOut() {
        Task {
            // Явный стоп движка ДО выхода (этап 8, порт Android): смерть Firestore-слушателя
            // после signOut не мгновенна, иначе движок продолжил бы писать и ловить
            // PERMISSION_DENIED.
            locationSharingEngine.setSharingEnabled(false)
            await authInteractor.signOut()
            effectsContinuation.yield(.navigateToAuth)
        }
    }
}
