import Foundation
import Observation

/**
 ViewModel вкладки «Карта». Realtime-поток видимых друзей перезапускается при каждом
 screenShown (отмена и новый Task); видимость друзей realtime-овая — интерактор
 слушает настройки шаринга друзей по uid. Счётчик друзей — отдельный поток: его ошибка
 глотается (как badge MainViewModel), падает только поток карты.
 Аватары дозагружаются по одному через ProfileInteractor.getAvatar и кэшируются
 по «uid:версия», чтобы карта/список не мигали плейсхолдером при обновлениях.
 Собственная локация — через MyLocationProviding (ViewModel без CoreLocation): флаг прав
 только из фактических грантов, фиксы — для центровки камеры.
 Единственная публичная точка входа для UI — onIntent.
 Порт 1:1 из Android MapViewModel.kt.
 */
@MainActor
@Observable
final class MapViewModel {
    private(set) var state: MapUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<MapEffect>
    private let effectsContinuation: AsyncStream<MapEffect>.Continuation

    private let mapInteractor: MapInteractor
    private let friendsInteractor: FriendsInteractor
    private let profileInteractor: ProfileInteractor
    private let myLocationProvider: MyLocationProviding
    private let mapUiConverter: MapUiConverter

    /// Резолвленные пути аватаров по ключу «uid:версия»; nil — аватара нет
    /// (паттерн FriendsViewModel: [String: String?], загрузка в полёте — .some(nil)).
    private var avatarPaths: [String: String?] = [:]

    /// Автозапрос прав отправляется ровно один раз за жизнь ViewModel; дальше — только кнопка.
    private var hasRequestedPermissions = false

    /**
     Отложенное желание центроваться: кнопка без прав НЕ центрирует — желание запоминается
     до результата диалога прав (паттерн pendingEnableRequest из SharingSettingsViewModel).
     */
    private var pendingLocateRequest = false

    /// Realtime-задачи; перезапускаются при каждом screenShown
    /// (порт viewModelScope.launch + flatMapLatest(refreshTrigger) Android).
    private var friendsCountTask: Task<Void, Never>?
    private var visibleFriendsTask: Task<Void, Never>?

    init(
        mapInteractor: MapInteractor,
        friendsInteractor: FriendsInteractor,
        profileInteractor: ProfileInteractor,
        myLocationProvider: MyLocationProviding,
        mapUiConverter: MapUiConverter,
    ) {
        self.mapInteractor = mapInteractor
        self.friendsInteractor = friendsInteractor
        self.profileInteractor = profileInteractor
        self.myLocationProvider = myLocationProvider
        self.mapUiConverter = mapUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: MapEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
        // Порт init { observeStreams() } Android: потоки стартуют сразу,
        // screenShown перезапустит их (refreshTrigger).
        startStreams()
    }

    deinit {
        friendsCountTask?.cancel()
        visibleFriendsTask?.cancel()
    }

    func onIntent(_ intent: MapIntent) {
        switch intent {
        case .screenShown:
            onScreenShown()
        case .friendSelected(let uid):
            onFriendSelected(uid: uid)
        case .showListClicked:
            state.isListVisible = true
        case .listDismissed:
            state.isListVisible = false
        case .locateMeClicked:
            onLocateMeClicked()
        case .locationPermissionsResult(let granted):
            onLocationPermissionsResult(granted: granted)
        }
    }

    /**
     Перезапуск realtime-потоков: вместе с задачами сбрасываем только isMapLoadFailed
     (пассивное падение восстанавливается по Повторить/входу на вкладку). visibleFriends,
     selectedUid и isListVisible не чистим: realtime-поток доставит свежие данные, а выбранного
     друга и открытый список пользователь не должен терять при перечитке. Порт 1:1 Android.
     */
    private func onScreenShown() {
        friendsCountTask?.cancel()
        visibleFriendsTask?.cancel()
        state.isMapLoadFailed = false
        refreshLocationPermission()
        startStreams()
    }

    /**
     Проверка прав и одноразовый фикс. При правах получаем последний известный фикс
     (myLocation обновится — камера отцентруется, если слежение не выбрано); без прав —
     первый раз за жизнь ViewModel тихо запрашиваем их, после отказа — молчим.
     */
    private func refreshLocationPermission() {
        let hasPermission = myLocationProvider.hasLocationPermission()
        state.hasLocationPermission = hasPermission
        if hasPermission {
            fetchMyLocation()
            return
        }
        if hasRequestedPermissions {
            return
        }
        hasRequestedPermissions = true
        effectsContinuation.yield(.requestLocationPermissions)
    }

    /** Toggle слежения камеры: повторный тап по выбранному другу снимает слежение. */
    private func onFriendSelected(uid: String) {
        state.selectedUid = state.selectedUid == uid ? nil : uid
    }

    /**
     Кнопка центровки «Показать меня»: без прав — запрос прав и запоминание желания;
     с правами — снятие слежения (иначе camera-эффект на ближайшем тике вернёт камеру
     к другу) и центровка на свежий фикс.
     */
    private func onLocateMeClicked() {
        if !myLocationProvider.hasLocationPermission() {
            pendingLocateRequest = true
            effectsContinuation.yield(.requestLocationPermissions)
            return
        }
        state.selectedUid = nil
        fetchMyLocation()
    }

    /**
     Результат диалога прав: отказ — флаг прав снимается, отложенное желание центроваться
     отбрасывается (после отказа кнопка — единственная точка входа). Выдача — фикс и
     центровка: если центровка была отложена с кнопки, слежение снимается (желание кнопки),
     иначе центруемся только когда друга не выбрано.
     */
    private func onLocationPermissionsResult(granted: Bool) {
        let isPendingLocate = pendingLocateRequest
        pendingLocateRequest = false
        state.hasLocationPermission = granted
        if granted && isPendingLocate {
            state.selectedUid = nil
        }
        if !granted {
            return
        }
        fetchMyLocation()
    }

    /**
     Одноразовый фикс для центровки: последний известный — мгновенно; его нет — one-shot
     currentLocation (задержка до секунд без индикатора — компромисс плана). nil-фикс —
     myLocation не трогаем, камеру не трогаем. При заданном selectedUid фикс всё равно
     получаем (точка на карте обновится), но камера продолжает следить за другом.
     */
    private func fetchMyLocation() {
        Task {
            let fix = await myLocationProvider.lastKnownLocation()
                ?? await myLocationProvider.currentLocation()
            guard let fix else { return }
            let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
            state.myLocation = mapUiConverter.convertMyLocation(fix, nowMillis: nowMillis)
        }
    }

    /// Запуск двух независимых realtime-задач (порт observeStreams Android).
    /// Конец потока без отмены = обрыв слушателя: guard !Task.isCancelled отделяет плановую
    /// отмену (screenShown/deinit) от обрыва.
    private func startStreams() {
        friendsCountTask = Task {
            for await friends in friendsInteractor.observeFriends() {
                guard !Task.isCancelled else { return }
                state.friendsCount = friends.count
            }
            guard !Task.isCancelled else { return }
            // Ошибка счётчика глотается (подход badge MainViewModel):
            // влияет только на текст пустого состояния.
            print("MapViewModel: Realtime-поток друзей (счётчик) прервался")
        }
        visibleFriendsTask = Task {
            for await friends in mapInteractor.observeVisibleFriends() {
                guard !Task.isCancelled else { return }
                let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
                state.isMapLoading = false
                state.visibleFriends = friends.map {
                    withCachedAvatar(friend: mapUiConverter.convertVisibleFriend($0, nowMillis: nowMillis))
                }
                resolveVisibleAvatars()
            }
            guard !Task.isCancelled else { return }
            // Пассивное падение потока карты — inline-состояние, не баннер.
            print("MapViewModel: Realtime-поток видимых друзей прервался")
            state.isMapLoading = false
            state.isMapLoadFailed = true
        }
    }

    /// Дозагрузка аватаров видимых друзей из текущего состояния; ошибка аватара не показывается.
    private func resolveVisibleAvatars() {
        for friend in state.visibleFriends {
            resolveAvatar(uid: friend.uid, version: friend.avatarVersion) { path in
                guard let index = state.visibleFriends.firstIndex(
                    where: { $0.uid == friend.uid && $0.avatarVersion == friend.avatarVersion },
                ) else { return }
                state.visibleFriends[index].avatarPath = path
            }
        }
    }

    /**
     Резолвит аватар как в FriendsViewModel: ошибка остаётся плейсхолдером с инициалом.
     Кэш по ключу «uid:версия» не даёт перезапускать загрузку при каждом обновлении карты;
     при неудаче ключ освобождается для повторной попытки на следующей эмиссии.
     */
    private func resolveAvatar(uid: String, version: Int, onResolved: @escaping (String?) -> Void) {
        guard version > 0 else { return }
        let key = Self.avatarKey(uid: uid, version: version)
        if let cached = avatarPaths[key] {
            onResolved(cached)
            return
        }
        // nil-значение сохраняем под существующим ключом (загрузка в полёте) —
        // присваивание «голого» nil удалило бы ключ из [String: String?].
        avatarPaths[key] = .some(nil)
        Task {
            switch await profileInteractor.getAvatar(uid: uid, version: version) {
            case .success(let avatar):
                avatarPaths[key] = .some(avatar.cachedPath)
                onResolved(avatar.cachedPath)
            case .failure(let error):
                print("MapViewModel: Не удалось загрузить аватар — \(error)")
                avatarPaths.removeValue(forKey: key)
            }
        }
    }

    /// Подставляет уже резолвленный путь аватара, чтобы список не мигал плейсхолдером.
    private func withCachedAvatar(friend model: VisibleFriendUiModel) -> VisibleFriendUiModel {
        let key = Self.avatarKey(uid: model.uid, version: model.avatarVersion)
        guard let cached = avatarPaths[key] else {
            return model
        }
        var updated = model
        updated.avatarPath = cached
        return updated
    }

    /// Ключ кэша аватара: uid и версия, чтобы смена аватара перезагрузила файл.
    private static func avatarKey(uid: String, version: Int) -> String {
        "\(uid):\(version)"
    }
}
