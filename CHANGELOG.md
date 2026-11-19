# Changelog

Все заметные изменения проекта документируются здесь.
Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/).

## [Unreleased]

### Добавлено

- Каркас репозитория: AGENTS.md, пайплайн разработки (dev-pipeline + агенты),
  план порта `docs/port-plan.md`, ресурсы (шрифты Manrope, стиль карты AURORA).
- Этап 1: каркас iOS-приложения — `project.yml` (XcodeGen, iOS 17, SwiftPM: Firebase,
  GoogleMaps, GoogleSignIn, Factory, Mantis), точка входа `@main` с защитой на отсутствие
  `GoogleService-Info.plist`, тема AURORA 1:1 из Android (цвета, типографика Manrope,
  формы, градиенты), 7 общих компонентов (GlassCard, GradientPrimaryButton и др.),
  минимальный срез auth (репозиторий/интерактор на FirebaseAuth), корневая MVI-пара
  AppContract/AppViewModel с заглушками веток навигации.
- CI: workflow `ios-build.yml` — сборка unsigned `.ipa` на macos-runner
  (xcodegen → xcodebuild → артефакт `ShareMyLocation-unsigned-ipa`).
- Нормализация PostScript-имён шрифтов Manrope (все 5 ttf несли имя «Manrope-ExtraLight»).
- Этап 2: экран входа — email/password, Google (GIDSignIn) и Sign in with Apple; контракт MVI
  Auth (UiState/Intent/Effect, порт 1:1 из Android), интерактор и репозиторий (маппинг ошибок
  FirebaseAuth/Firestore, ensureUserDocument), AuthScreen в стиле AURORA (стеклянные поля,
  переключатель режимов, градиентная кнопка), подключение в корневую навигацию.
- Этап 2: entitlements Sign in with Apple, ассет ic_google, компонент AuroraField.
- CI: наблюдаемость сборки (кэш SwiftPM, таймаут, лог ошибок в артефакт), лейбл macos-latest,
  пакет GoogleMaps → googlemaps/ios-maps-sdk (GoogleMaps-iOS-SPM удалён из GitHub).
- Этап 3: профиль и онбординг — PhoneNormalizer (порт 1:1), аватар-пайплайн (PhotosPicker /
  камера → круглый кроп Mantis → сжатие 1024px/JPEG 0.8 → файловый кэш uid:version →
  транзакция blob+avatarVersion в Firestore), экраны Profile и ProfileSetup(isEditMode),
  онбординг: настоящее чтение users/{uid} в корне, hasCompletedOnboarding при сохранении;
  временная точка входа профиля в Main-заглушке (удаляется на этапе 4).
- Этап 3: entitlements камеры (NSCameraUsageDescription), токен auroraDanger,
  AuroraField + keyboardType.
- Этап 4: друзья и главный контейнер — поиск по телефону (вручную и из контактов через
  CNContactPicker), заявки в друзья (send с препроверками, accept/removeFriend-транзакции
  с arrayUnion/arrayRemove), realtime-списки (слушатели без orderBy, чанки по 10,
  кэш профилей в синглтон-интеракторе), секция групп (read-срез), sheet заявок с
  колокольчиком и badge; MainScreen с табами Карта/Друзья/Профиль и кастомным навбаром-пилюлей
  (статичная версия, полировка — этап 9), временная интеграция этапа 3 удалена, выход
  переехал в MainViewModel.
- Этап 5: группы — полный GroupsInteractor (getGroup/createGroup/updateGroup/deleteGroup,
  валидация имени trim ≤ 50, groupNotFound для несуществующих/недоступных), репозиторий
  с точным контрактом Firestore (update — merge ровно трёх полей); GroupEditorScreen
  (создание/редактирование: имя, чекбоксы друзей, удаление с диалогом) как sheet поверх
  MainScreen (temp-баннер удалён).
- Этап 6: настройки шаринга — SharingSettingsScreen как sheet поверх Main (тумблер «Делиться
  геопозицией» с запросом CoreLocation when-in-use и баннером при отказе, радио аудитории
  «Все друзья»/«Выбранные люди и группы», чекбоксы людей/групп), автосохранение полным
  снимком с оптимистичным откатом, подсказка при пустой CUSTOM; полный контракт
  SharingRepository/Interactor (включая updateLocation/observeIsEnabled — задел этапа 8),
  запрос прав через CLLocationManager с continuation-обёрткой.
- Этап 7: live-карта — realtime-конвейер (друзья → настройки шаринга → видимые uid → точки
  + тик 5 с «как давно»), гдеIn-чанки по 10 с fallback на по-документные слушатели при
  permission-denied, Google Maps SDK с тёмным стилем AURORA, маркеры-аватары с неоновыми
  кольцами (цвет детерминирован по uid портом Java hashCode), «Показать меня», слежение
  камеры zoom 16, чип «На карте: N», sheet-список; без API-ключа — заглушка
  (ключ подставляется локально в Info.plist GMSApiKeyKey, не в git).
- Этап 8: фоновой движок и уведомления — LocationSharingEngine на CoreLocation
  (allowsBackgroundLocationUpdates, throttle 5 с, merge-write locations/{uid}, гейт прав
  и сессии, стоп при отзыве прав/PERMISSION_DENIED×2), оркестрация от realtime
  observeIsEnabled в AppViewModel с восстановлением при запуске, явный стоп перед signOut;
  NotificationWatcher (заявки в друзья + «друг начал шарить», дедуп/baseline/retry 30 с) →
  локальные уведомления UNUserNotificationCenter с категориями friend_requests/friend_sharing;
  запрос права уведомлений при первом входе в Main.
- Этап 9: полировка AURORA — навбар-пилюля с блюром (.ultraThinMaterial + tint 0.55), пружинное
  перекатывание (damping 0.75) и пульс 0.94→1.0 выбранного таба, badge auroraOnDanger;
  edge-to-edge карта с mapPadding (нативные контролы Google над пилюлей), зазоры 132/28;
  поля ввода 56 pt со сплошной danger-рамкой ошибки; lineSpacing-калибровка типографики;
  двойное свечение фона снято; sheet кропа аватара защищён от свайп-закрытия.
- Этап 10: инструкция сайдлоада `docs/sideload.md` — проверенная установка unsigned `.ipa` с CI
  на iPhone через Sideloadly с бесплатным Apple ID на Windows: драйверы Apple (веб-iTunes
  вместо Store-версий), модификация `.ipa` до подписи (внедрение `GoogleService-Info.plist`,
  ключ карты `GMSApiKeyKey` и URL scheme Google — в 7-Zip или Python-скриптом с plistlib),
  доверие разработчику, переподпись каждые 7 дней без потери данных, честные ограничения
  (3 приложения, 10 App ID, Sign in with Apple может не завестись) и таблица типичных ошибок.

### Изменено

- Этап 10: README актуализирован — статус «порт завершён, все 9 функциональных этапов,
  паритет с Android v1.1», раздел «Возможности», стек дополнен геолокацией
  (CoreLocation + LocationSharingEngine) и локальными уведомлениями, сборка описана через
  артефакт `ShareMyLocation-unsigned-ipa`, установка — ссылка на `docs/sideload.md`.
- Этап 10: AppDelegate конфигурирует GoogleSignIn для сайдлоад-сборок — если в бандле есть
  `GoogleService-Info.plist`, из него читается `CLIENT_ID` и задаётся
  `GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID:)` (GoogleSignIn-iOS 7+
  не подхватывает plist автоматически — кнопка Google всегда возвращала notConfigured);
  без plist поведение прежнее.
