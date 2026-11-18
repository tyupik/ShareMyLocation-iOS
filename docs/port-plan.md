# План порта ShareMyLocation: Android → iOS

Один цикл оркестратора (планировщик → разработчик → ревьюер) = один этап этого документа.
После APPROVE каждого этапа: пункт в `CHANGELOG.md`, коммит, пуш; сборку проверяет CI.

**Источник порта:** `E:\projects\ShareMyLocation` (локально) или
https://github.com/tyupik/ShareMyLocation. Контракты MVI, бизнес-логика, схема Firestore,
дизайн-токены и поведение ошибок портируются оттуда, а не изобретаются. При расхождении
плана и Android-кода победает Android-код.

---

## Соответствие технологий

| Android | iOS |
|---|---|
| Kotlin 2.2 + Compose + Material 3 | Swift + SwiftUI + тема AURORA (своя, без M3) |
| `StateFlow<UiState>` | `@Observable private(set) var state: UiState` |
| `Channel(BUFFERED)` + `receiveAsFlow()` | `AsyncStream(bufferingPolicy: .unbounded)` + continuation |
| `viewModelScope.launch` | `Task { }` в `@MainActor` |
| `LaunchedEffect(Unit) { ScreenShown }` | `.task { viewModel.onIntent(.screenShown) }` |
| sealed class Intent/Effect | enum со associated values |
| Hilt (KSP) | Factory (`extension Container`) |
| Navigation 3 | NavigationStack + switch-корень AppRootView + sheet поверх Main |
| Haze (блюр) | `.ultraThinMaterial`/`.regularMaterial` + tint |
| Coil | не нужен — аватары из файлового кэша `UIImage(contentsOfFile:)` |
| vannikchat image-cropper | Mantis (круглый кроп) |
| maps-compose + стиль JSON | Google Maps SDK for iOS + тот же `map_style_aurora.json` |
| Play Services Location + foreground Service | CoreLocation + `LocationSharingEngine` (фоновый режим `location`) |
| Credential Manager + GoogleSignIn | GoogleSignIn-iOS + `ASAuthorization` (Sign in with Apple) |
| ACTION_PICK контакты | `CNContactPickerViewController` |
| SharedPreferences (флаг нотификаций) | `UserDefaults` |

## Схема Firestore (без изменений!)

Тот же проект `sharemylocation-d44b4`, те же коллекции — кроссплатформенная дружба работает:

- `users/{uid}`: email, displayName, phone (нормализованный), avatarVersion (Int, 0 = нет),
  hasCompletedOnboarding, friendUids [String], createdAt/updatedAt
- `avatars/{uid}`: jpeg (Data-блоб ≤ 900 КБ), updatedAt — транзакция блоб + инкремент версии
- `friendRequests/{fromUid}_{toUid}`: fromUid, toUid, fromName, fromAvatarVersion,
  status ("PENDING"|"ACCEPTED"), createdAt/updatedAt; слушатель — whereEqualTo(toUid, me) +
  status == PENDING, БЕЗ orderBy (сортировка на клиенте)
- `groups/{autoId}`: ownerId, name (≤ 50), memberUids (⊆ friendUids владельца), createdAt/updatedAt
- `sharingSettings/{uid}`: isEnabled, audience ("ALL_FRIENDS"|"CUSTOM"),
  allowedUids, allowedGroupIds, updatedAt
- `locations/{uid}`: geo (GeoPoint), accuracy (Double), updatedAt — merge-write каждые 5 с

Платформо-чувствительные behaviors data-слоя (портировать обязательно):

- **fallback whereIn**: если `in`-запрос по documentID отклонён правилами (PERMISSION_DENIED) —
  переход на по-документные слушатели;
- транзакции: accept заявки (status + arrayUnion friendUids у обоих), removeFriend
  (arrayRemove + guarded delete заявок пары);
- `PhoneNormalizer` — порт 1:1 (RU: 11 цифр с 7/8 → `8XXXXXXXXXX`, 10 цифр → `8…`;
  иностранные — цифры с `+`; валидность 10–15 цифр);
- таймаут всех сетевых вызовов — 30 с;
- `ensureUserDocument` merge при каждом логине;
- сжатие аватара: макс. сторона 1024 px, JPEG q=0.8, пережим q=0.5 при > 700 КБ
  (лимит документа Firestore 900 КБ).

## Фичи Android (что портируем)

9 MVI ViewModel: App, Auth, Main, Map, Friends, Profile, ProfileSetup, GroupEditor,
SharingSettings. Экраны: Auth, ProfileSetup (isEditMode), Main (табы Карта/Друзья/Профиль,
кастомный навбар-пилюля с бейджем заявок), Friends (поиск по телефону, заявки, группы),
GroupEditor, SharingSettings (тумблер, аудитория, автосейв с оптимистичным откатом),
Profile, Map (realtime-маркеры, «Показать меня», слежение камеры, чип «На карте: N»,
bottom-sheet список).

---

## Этапы

### Этап 1 — Каркас проекта и CI

- `project.yml` (XcodeGen): app-таргет ShareMyLocation, iOS 17.0, SwiftPM-зависимости
  (firebase-ios-sdk: Auth/Firestore/Analytics, GoogleMaps, GoogleSignIn-iOS, Factory, Mantis),
  Info.plist-ключи (права локации, фоновой режим `location`, URL scheme GoogleSignIn,
  NSContactPicker не нужен — пикер без прав).
- `.github/workflows/ios-build.yml`: macos-runner → brew xcodegen → generate →
  `xcodebuild -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` → упаковка
  `.app` в `Payload/` → zip → artifact `ShareMyLocation-unsigned.ipa`.
- `App/`: `@main` + `AppDelegate` (FirebaseApp.configure) + `AppRootView`-заглушка.
- `theme/`: AuroraColors (все токены), Manrope (5 ttf из Android `res/font/`), AuroraBrushes,
  AuroraShapes.
- `ui/common/components/`: GlassCard, GradientPrimaryButton, GlassIconButton, ErrorBanner,
  LoadError, AuroraBackdrop, ProfileAvatar.
- `Resources/`: GoogleService-Info.plist (руками заранее), map_style_aurora.json,
  Localizable.xcstrings (ru).
- AppViewModel/AppContract: resolve сессии (observeAuthState) + спиннер.
- Критерий: зелёный CI, artifact `.ipa`.

### Этап 2 — Auth

Интерактор/репозиторий (email+password, Google через GIDSignIn, Apple через ASAuthorization;
`AuthError`: invalidCredentials, emailAlreadyInUse, networkUnavailable, unexpected) →
AuthViewModel/Contract/Converter → AuthScreen (режимы вход/регистрация, поля, баннер ошибок,
кнопки Google и Apple) → Effect navigateToMain → `ensureUserDocument`.

### Этап 3 — Профиль и онбординг

ProfileInteractor + PhoneNormalizer + AvatarCompressor (1024px/JPEG 0.8/пережим 0.5) +
AvatarCache (`uid:version`); PhotosPicker + камера + круглый кроп Mantis; транзакция
blob+avatarVersion. ProfileSetupScreen (isEditMode), ProfileScreen (Loading/Content/Error),
`hasCompletedOnboarding = true` при сохранении.

### Этап 4 — Друзья

FriendsInteractor: searchByPhone (UserNotFound, RequestToSelf), заявки (send/accept-транзакция/
decline-delete/removeFriend-транзакция), observeIncomingFriendRequests, observeFriends
(чанки по 10, кэш профилей в синглтоне). FriendsScreen: поиск, CNContactPickerViewController,
колокольчик+badge, sheet заявок (Принять/Отклонить), список друзей с удалением (диалог),
секция групп.

### Этап 5 — Группы

GroupsInteractor: observeGroups (whereEqualTo ownerId, сортировка по имени на клиенте),
getGroup, createGroup (trim, ≤ 50), updateGroup, deleteGroup. GroupEditorScreen: имя,
чекбоксы друзей, удаление с диалогом.

### Этап 6 — Настройки шаринга

SharingInteractor: getSettings (default при отсутствии), saveSettings (полный снимок),
saveEnabled (частичная запись), observeIsEnabled. SharingSettingsScreen: тумблер (запрос прав
локации при включении, откат при отказе), радио аудитории, чекбоксы людей и групп, автосейв
с оптимистичным откатом и баннером ошибки, подсказка при пустом CUSTOM.

### Этап 7 — Live-карта

MapInteractor: конвейер друзья → realtime их sharingSettings → видимые uid
(`isEnabled && (ALL_FRIENDS || мой uid ∈ allowedUids || состою в группе из allowedGroupIds)`) →
realtime locations (whereIn чанками по 10 + fallback на по-документные при PERMISSION_DENIED)
+ тик 5 с (старение «как давно»). MyLocationProvider (lastKnown/one-shot). Google Maps:
тёмный стиль, маркеры-аватары с неоновыми кольцами (цвет по uid), «Показать меня»,
слежение камеры (zoom 16), чип «На карте: N», sheet-список, заглушка без ключа.

### Этап 8 — Фоновой движок и уведомления

`LocationSharingEngine` (data/sharing): CoreLocation, `allowsBackgroundLocationUpdates`,
throttle 5 с, merge-write `locations/{uid}`, старт/стоп из оркестратора AppViewModel по
realtime `isEnabled` (гейт прав и сессии, fail-safe стоп, явный стоп перед signOut,
восстановление при запуске процесса если isEnabled=true — аналог START_STICKY).
NotificationWatcher: слушатели заявок и «друг начал шарить» с дедупом по предыдущему набору,
baseline-снапшот без уведомления, retry 30 с → UNUserNotificationCenter (каналы-категории
friend_requests / friend_sharing). Permission-контроллер уведомлений с UserDefaults-флагом.

### Этап 9 — Полировка AURORA

Блюр навбара (material + tint 0.55), пружинная анимация пилюли таба (перекатывание, пульс
0.94→1.0, damping ≈ 0.75), edge-to-edge карта (safe-area через contentPadding), радиальные
свечения фона, 8 неоновых цветов маркеров. Сверка по скриншотам Android
(`docs/screenshots/01…07` в Android-репо).

### Этап 10 — Доки и инструкция сайдлоада

README (что это, статус, как собрать через CI), `docs/sideload.md`: пошаговая инструкция
Sideloadly на Windows (бесплатный Apple ID, 7 дней, переподпись), ограничения
(Sign in with Apple может не работать — тестировать email/Google; 3 приложения на устройство).
TestFlight/App Store НЕ делаем.

---

## Ограничения сайдлоада (не «чинить»)

- Подпись живёт 7 дней — потом переподпись в Sideloadly.
- Sign in with Apple под переподписью может не завестись — основные провайдеры теста: email, Google.
- Фоновая геолокация (UIBackgroundModes location) под переподписью работает.
- Локальные уведомления работают; пушей нет и не планируется (нет платного аккаунта).
