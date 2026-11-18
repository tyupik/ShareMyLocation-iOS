/**
 SSOT вкладки «Карта». Список видимых друзей приходит realtime-потоком (тики 5 с
 старят «как давно»), selectedUid и isListVisible переживают рекомпозиции;
 аватары резолвятся асинхронно, ошибка аватара остаётся плейсхолдером с инициалом.
 Порт 1:1 из Android MapContract.kt.
 */
struct MapUiState {
    /** Друзья, чья локация сейчас видна (маркеры карты и список). */
    var visibleFriends: [VisibleFriendUiModel] = []

    /**
     Всего друзей. Поле резервируется: после выноса empty-состояния в bottom-sheet списка
     UI его не читает.
     */
    var friendsCount: Int = 0

    /** Карта ещё не получила первую эмиссию realtime-потока точек. */
    var isMapLoading: Bool = true

    /** Пассивное падение realtime-потока; восстанавливается ScreenShown/Повторить. */
    var isMapLoadFailed: Bool = false

    /** Друг, за которым следует камера; повторный тап по нему снимает слежение. */
    var selectedUid: String? = nil

    /** Видимость списка видимых друзей (sheet) — состояние экрана, не локальный @State. */
    var isListVisible: Bool = false

    /**
     Реальное состояние рантайм-прав геолокации: проверка провайдером на ScreenShown
     и результат диалога прав. Гейтит isMyLocationEnabled — без фактических грантов
     Maps SDK падает, поэтому флаг только из фактических грантов, никогда не «оптимистично».
     */
    var hasLocationPermission: Bool = false

    /**
     Последняя известная моя точка для центровки камеры; nil — фикса нет, камеру не трогаем.
     Каждый свежий фикс несёт новый updatedAtMillis, поэтому повторный фикс по тем же
     координатам перезапускает camera-эффект (автоцентровка/кнопка).
     */
    var myLocation: MyLocationUiModel? = nil

    static let initial = MapUiState()
}

/** Действия пользователя на вкладке «Карта». Порт 1:1 из Android MapIntent. */
enum MapIntent {
    /** Вкладка показана: перезапуск realtime-потоков и перечитка прав/фикса. */
    case screenShown

    /**
     Тап по карточке списка ИЛИ по маркеру: toggle слежения камеры за другом uid
     (повторный тап по выбранному снимает слежение).
     */
    case friendSelected(uid: String)

    /** Открыт список видимых друзей. */
    case showListClicked

    /** Список закрыт (свайп, тап вне, назад). */
    case listDismissed

    /**
     Тап по кнопке центровки «Показать меня»: без прав — Effect requestLocationPermissions
     и отложенное желание центроваться; с правами — снятие слежения (selectedUid = nil,
     иначе камеру на тике вернёт к другу) и центровка на свежий фикс.
     */
    case locateMeClicked

    /**
     Результат системного диалога прав геолокации: выдан хотя бы один грант локации.
     granted = true — обновить hasLocationPermission и получить фикс; отказ — флаг снимается.
     */
    case locationPermissionsResult(granted: Bool)
}

/**
 One-off события экрана. Слежение камеры — производная состояния
 selectedUid/myLocation (императивное API карты живёт в Coordinator AuroraMapView,
 Effect не смог бы адресовать его без утечки UI во ViewModel), поэтому в Effect попадает
 только запрос системного диалога прав. Порт 1:1 из Android MapEffect.
 */
enum MapEffect {
    /** Экран запускает запрос прав геолокации (when-in-use). */
    case requestLocationPermissions
}
