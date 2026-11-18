/**
 SSOT экрана настроек шаринга геолокации. Ключевое решение — автосохранение без кнопки
 «Сохранить»: переключатель — обещание приватности «выключено = уже выключено», каждое
 изменение немедленно пишет полный снимок всех пяти полей документа (идемпотентно).
 Ошибка записи — оптимистичный откат к последнему успешному снимку + inline-баннер.
 Порт 1:1 из Android SharingSettingsContract.kt.
 */
struct SharingSettingsUiState {
    /// Первичное чтение документа; при каждом screenShown снова true — полноэкранный спиннер.
    var isLoading: Bool = true

    /// Экран-ошибка чтения; «Повторить» = повторный screenShown.
    var isLoadFailed: Bool = false

    /// Конкретная причина экрана-ошибки; nil — generic-текст.
    var loadError: SharingUiError? = nil

    /// Главный переключатель: выключен = локацию не видит никто; дефолт отсутствующего документа.
    var isEnabled: Bool = false

    /// Аудитория шаринга; секции выбора «Люди»/«Группы» видны только в `custom`.
    var audience: SharingAudienceUi = .allFriends

    /// Секция «Люди»: `SharingCheckRowUiModel.isChecked` = выбор ∩ актуальные друзья.
    var friends: [SharingCheckRowUiModel] = []

    /// Секция «Группы»: `SharingCheckRowUiModel.isChecked` = выбор ∩ актуальные группы.
    var groups: [SharingCheckRowUiModel] = []

    /// Пассивная недоступность realtime-секции «Люди» (паттерн Friends); восстанавливается screenShown.
    var isFriendsLoadFailed: Bool = false

    /// Пассивная недоступность realtime-секции «Группы»; восстанавливается screenShown.
    var isGroupsLoadFailed: Bool = false

    /// Только индикатор «Сохранение…»: контролы при автосохранении НЕ дизейблятся.
    var isSaving: Bool = false

    /// Ошибка автосохранения для баннера; сбрасывается по saveErrorDismissed и при каждом screenShown.
    var saveError: SharingUiError? = nil

    /**
     Баннер «нет доступа к геолокации»: попытка включить тумблер без прав, отказ в системном
     диалоге или документ «включён» при не выданных правах на screenShown. Включение без прав
     не персистится — движок без геолокации не работает.
     */
    var isPermissionMissing: Bool = false

    static let initial = SharingSettingsUiState()
}

/// Аудитория шаринга в терминах Ui-слоя.
enum SharingAudienceUi {
    /// Все друзья владельца.
    case allFriends

    /// Выбранные люди и группы; пустой выбор = «не видно никому» (валидно, есть подсказка).
    case custom
}

/// Действия пользователя на экране настроек шаринга. Порт 1:1 из Android SharingSettingsIntent.
enum SharingSettingsIntent {
    /**
     Экран показан: чистый лист транзиентов (isSaving, saveError, isLoadFailed и флаги секций),
     одноразовое чтение документа (отсутствующий — дефолт), перезапуск realtime-потоков
     друзей и групп. Повтор по «Повторить» — тот же intent.
     */
    case screenShown

    /// Переключение главного тумблера; сохраняется автосохранением.
    case enabledToggled(Bool)

    /// Выбор аудитории; сохраняется автосохранением.
    case audienceSelected(SharingAudienceUi)

    /// Переключение чекбокса друга; сохраняется автосохранением.
    case friendToggled(uid: String)

    /// Переключение чекбокса группы; сохраняется автосохранением.
    case groupToggled(groupId: String)

    /// Скрытие баннера ошибки автосохранения.
    case saveErrorDismissed

    /**
     Результат системного диалога прав геолокации: granted — персист isEnabled = true
     обычным автосейвом; отказ — тумблер остаётся выключенным, показывается баннер.
     */
    case locationPermissionsResult(granted: Bool)
}

/// One-off события экрана. Порт 1:1 из Android SharingSettingsEffect.
enum SharingSettingsEffect {
    /**
     Подсказка-снекбар «сейчас локацию не увидит никто»: переход в custom с пустым выбором
     или включение тумблера при custom с пустым выбором.
     */
    case showEmptyAudienceHint

    /**
     Запрос системного диалога прав геолокации: экран запускает requestWhenInUse через
     LocationPermissionRequester, результат возвращается intent'ом
     `locationPermissionsResult`.
     */
    case requestLocationPermissions
}
