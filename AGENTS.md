# AGENTS.md

**ВАЖНО: отвечай только на русском языке. Это обязательное требование, не рекомендация.**

Проект: ShareMyLocation — iOS. Нативный порт Android-приложения (шаринг геолокации в реальном
времени: друзья по номеру телефона, группы, гибкая аудитория шаринга, live-карта).
Источник порта (логика, контракты, дизайн): `E:\projects\ShareMyLocation` локально или
https://github.com/tyupik/ShareMyLocation — детали этапов в `docs/port-plan.md`.

Архитектура: MVI (State, Intent, Effect) + Clean Architecture.
UI: SwiftUI (iOS 17+), тёмная тема AURORA «ночной неон».
Язык: Swift 6 toolchain, language mode Swift 5, Swift Concurrency (async/await, AsyncStream).
DI: Factory (SwiftPM).
Данные: Firebase (Auth, Firestore, Analytics) через SwiftPM.
Карты: Google Maps SDK for iOS.
Навигация: NavigationStack + собственный контейнер табов (кастомный навбар AURORA).

---

# Специфика окружения (читать обязательно)

## Нет локальной сборки

Рабочая машина — Windows, Xcode на ней НЕ существует. Следствия:

- Никто (разработчик, ревьюер, координатор) не запускает `xcodebuild` локально — он недоступен.
- Компиляцию проверяет ТОЛЬКО CI (GitHub Actions, `macos-runner`) после пуша.
- Из-за этого действует правило «компилируем вслепую»: использовать только API из утверждённого
  стека (см. Tech Stack), сверять сигнатуры с уже написанным кодом проекта и с исходником порта;
  не выдумывать методы. Сомнительное место — пометить в отчёте «проверить на CI».
- Упавший CI — первый пункт следующего цикла: мини-фикс сборки разрешено делать без полного
  пайплайна.

## Проект Xcode генерируется

`.xcodeproj` НЕ коммитится (в `.gitignore`). Source of truth — `project.yml` (XcodeGen).
CI ставит XcodeGen и генерирует проект перед сборкой.

## Сайдлоад вместо App Store

Аккаунт Apple Developer НЕ используется. Установка на iPhone — сайдлоадом через Sideloadly
(на Windows) с бесплатным Apple ID: подпись живёт 7 дней, потом переподпись.

- CI собирает **unsigned** `.ipa` (артефакт workflow) — подписывает его Sideloadly локально.
- Разрешены только entitlements, доступные personal team: фоновый режим `location`
  (это ключ Info.plist, работает), Sign in with Apple (может не завестись под переподписью —
  это известное ограничение сайдлоада, НЕ баг; основные тестируемые провайдеры — email и Google).
- Запрещено планировать фичи, требующие платного аккаунта: APNs/FCM-пуши, App Groups,
  CloudKit, Widgets, Associated Domains. Уведомления в приложении — только локальные
  (`UNUserNotificationCenter`), как в Android-версии.
- Не «чинить» перечисленные особенности сайдлоада — они ожидаемы.

---

# Структура проекта

Bundle id: `ru.tyupik.sharemylocation`. Слои Clean Architecture — те же, что в Android-версии:

- `business/` — интеракторы, бизнес-модели (BusinessModel), протоколы репозиториев.
- `data/` — реализации репозиториев (Firebase, CoreLocation, контакты, кэш), binding-расширения
  `Container` (аналог Hilt-модулей) для data-слоя.
- `ui/` — SwiftUI-экраны: MVI-контракт (UiState/Intent/Effect), ViewModel, конвертер,
  компоненты экрана, корневая навигация.

Внутри каждого слоя — отдельная директория на экран/фичу: `ui/auth`, `business/auth`,
`data/auth`. Общие для нескольких экранов классы — в `common`-директории слоя:
`ui/common`, `business/common`, `data/common`.

```text
ShareMyLocation/                  # корень app-таргета
├── App/
│   ├── ShareMyLocationApp.swift  # @main, FirebaseApp.configure()
│   ├── AppDelegate.swift         # UIApplicationDelegateAdaptor
│   └── AppRootView.swift         # корневой switch: Auth / ProfileSetup / Main
├── business/
│   ├── auth/        # AuthInteractor(+Impl), AuthRepository (протокол), AuthResult, AuthError
│   ├── profile/     # + PhoneNormalizer (порт 1:1 из Android!)
│   ├── friends/ groups/ sharing/ map/ contacts/ notifications/
│   └── common/      # User
├── data/
│   ├── auth/        # AuthRepositoryImpl + Container-расширение (binding)
│   ├── profile/     # AvatarCompressor, AvatarCache
│   ├── map/         # MyLocationProviderImpl, LocationSharingEngine
│   ├── notifications/
│   └── ...
├── ui/
│   ├── common/      # общие компоненты: GlassCard, AuroraBackdrop, ProfileAvatar, ...
│   │   └── components/  # один файл — один View
│   ├── auth/
│   │   ├── components/  # AuthModeSwitcher, AuthErrorBanner, AuthEmailField, ...
│   │   ├── AuthScreen.swift
│   │   ├── AuthViewModel.swift
│   │   ├── AuthContract.swift   # AuthUiState, AuthIntent, AuthEffect, AuthMode
│   │   └── AuthUiConverter.swift # конвертер + AuthUiModel, AuthUiError
│   └── main/ map/ friends/ profile/ profilesetup/ groups/ sharing/
├── theme/           # AuroraColors, Manrope (типографика), AuroraBrushes, AuroraShapes
└── Resources/
    ├── GoogleService-Info.plist   # в git — нужен CI (аналог google-services.json в Android)
    ├── Fonts/                     # Manrope, 5 начертаний ttf
    ├── map_style_aurora.json      # тёмный стиль Google Maps — порт 1:1 из Android
    └── Localizable.xcstrings      # русский язык интерфейса
```

UI-компоненты экрана — в `ui/<фича>/components/`, один файл — один View (например,
`AuthEmailField.swift`, `AuthErrorBanner.swift`). `AuthScreen.swift` только собирает элементы,
считает производные флаги и маппит состояние в их параметры.

# Поток данных

Firebase → Repository (протокол в business) → Interactor (business, возвращает BusinessModel)
→ ViewModel (ui) → Converter → UiModel → UiState.

- Интерактор возвращает бизнес-модели (`AuthResult`, `User`), а не ошибки-исключения наружу
  и не DTO источника данных.
- ViewModel не знает про data-слой: получает BusinessModel от интерактора и передаёт в конвертер
  (`<Фича>UiConverter`).
- Конвертер выдаёт UiModel; ViewModel кладёт её в UiState (или отправляет Effect).
- UI не знает про бизнес-модели — только UiModel/UiState.
- Экран перечитывает данные при каждом появлении: `.task { viewModel.onIntent(.screenShown) }` —
  ViewModel может переживать повторный вход на экран, полагаться только на init нельзя.

---

# MVI Architecture Rules

## Тройка MVI

Каждая фича обязана иметь три составляющие:

1. **State (UiState)**
   - Единственный `struct` на весь экран, иммутабельный для наружного наблюдателя.
   - Хранится в ViewModel как `private(set) var state: UiState` (внутри — обычное присваивание
     полей struct; наружу через `@Observable` читается только).
   - Начальное состояние обязательно: `static let initial = ...`.

2. **Intent**
   - `enum` со всеми действиями пользователя/системы (associated values для payload).
   - UI вызывает `viewModel.onIntent(intent)` — единственную публичную функцию.
   - Запрещены публичные методы типа `onEmailChanged(_:)`, `submit()`.

3. **Effect**
   - `enum` для one-off событий: навигация, Toast, Snackbar, диалог.
   - Expose через `AsyncStream<Effect>` (создаётся вместе с `continuation`,
   `bufferingPolicy: .unbounded` — аналог `Channel(BUFFERED)`), свойство `effects`.
   - Запрещено класть Effect в State (иначе повторится при пересоздании вью).

## ViewModel

- `@MainActor @Observable final class <Фича>ViewModel`.
- Все Intent обрабатываются в `Task { }` (аналог `viewModelScope.launch`).
- Внутри — `private(set) var state` и `AsyncStream<Effect>.Continuation`.
- **Никаких прямых вызовов Firebase/GoogleMaps** — только через Interactor.
- Создание в экране — единый паттерн:

```swift
struct AuthScreen: View {
    @State private var viewModel: AuthViewModel

    init() {
        _viewModel = State(initialValue: Container.shared.authViewModel())
    }
}
```

## Repository

- Протокол в `business/<фича>`, реализация в `data/<фича>`.
- `async throws`-методы; на границе интерактора ошибки превращаются в бизнес-результаты
  (`Result<T, BusinessError>` или enum-результат).
- Repository — единственный, кто знает про источники данных.

## UI (SwiftUI)

- View получает `state` (или сам viewModel) и `onIntent: (Intent) -> Void`.
- Собирает Effect: `.task { for await effect in viewModel.effects { ... } }`.
- Производные флаги считаются в `AuthScreen`, а не в ViewModel.

## Single Source of Truth

- `UiState` — SSOT для UI; Repository — SSOT для данных.
- **Никогда** не смешивать локальные `@State`-переменные с бизнес-состоянием (`@State` — только
  для эфемерного UI: видим ли sheet-флаг из UiState, а не наоборот).

## Навигация

- Навигационные события проходят через Effect, а не вызываются напрямую из лямбды кнопки.
- Корень: `AppRootView` — switch по `AppUiState` (спиннер → Auth → ProfileSetup → Main).
- Поверх Main (`GroupEditor`, `SharingSettings`) — модальные `sheet`.
- Табы — собственный контейнер (ZStack + кастомный навбар-пилюля), НЕ `TabView`.

---

# Tech Stack

## Core

- Swift 6 toolchain, language mode Swift 5, strict concurrency НЕ включаем
- SwiftUI, iOS 17.0 deployment target
- Swift Concurrency: `async/await`, `AsyncStream`, `AsyncSequence`, `Task`
- Factory (DI) — регистрации в `extension Container`, binding-расширения data-слоя в `data/<фича>`

## Firebase (SwiftPM)

- `firebase-ios-sdk`: FirebaseAuth, FirebaseFirestore, FirebaseAnalytics
- GoogleService-Info.plist от iOS-приложения проекта `sharemylocation-d44b4`
- Схема Firestore, имена полей и `firestore.rules` — БЕЗ ИЗМЕНЕНИЙ относительно Android
  (кроссплатформенная дружба Android ↔ iOS должна работать)

## Auth

- Email/password — Firebase Auth
- Google — GoogleSignIn-iOS SDK
- Sign in with Apple — `ASAuthorization` (обязателен по правилу App Store 4.8)

## Карты

- Google Maps SDK for iOS, стиль — `map_style_aurora.json` (порт 1:1)
- Обёртка карты — `UIViewRepresentable` в фиче `ui/map` (единственное разрешённое место
  прямого UIKit-моста)

## Геолокация

- CoreLocation; фоновой шаринг — `LocationSharingEngine` (data/sharing):
  `UIBackgroundModes = [location]`, `allowsBackgroundLocationUpdates`,
  `pausesLocationUpdatesAutomatically = false`, throttle 5 с, merge-write в `locations/{uid}`
- Права — двухшагово: сначала `whenInUse`, Always отдельно при включении фонового шаринга

## Прочее

- Кроп аватара — Mantis (круглый кроп)
- Контакты — `CNContactPickerViewController` (ContactsUI, без разрешения)
- Уведомления — `UNUserNotificationCenter` (локальные)
- Кэш аватаров — файлы в caches по `uid:version`, загрузка `UIImage(contentsOfFile:)`

---

# Design System (AURORA)

Единственная тема — тёмная «ночной неон». Дизайн-токены портируются из Android 1:1.

## Цвета

- Все hex живут ТОЛЬКО в `theme/AuroraColors.swift` (это дизайн-система, не Material roles).
- Вне `theme/` хардкод hex/rgb ЗАПРЕЩЁН — только токены `AuroraColors.*`.
- Ключевые токены: фон `#0B1020`, текст `#F1F5F9`, muted `#8A94AD`, индиго `#6366F1`/`#818CF8`,
  циан `#22D3EE`, мята `#34D399`, onGradient `#041018`; стекло: заливка `#0EFFFFFF`,
  рамка `#1AFFFFFF`; выбранное — `#1222D3EE`/рамка `#8C22D3EE`; danger-стекло
  `#14F87171`/`#38F87171`; палитра 8 неоновых цветов маркеров (детерминированный выбор по uid).

## Типографика

- Шрифт Manrope (5 начертаний ttf), заголовки ExtraBold с трекингом −0.5.
- Свои модификаторы в `theme/`, НЕ переопределять системные `Font`-расширения глобально.

## Формы и материалы

- Скругления 12/16/22/28 (small/medium/large/extraLarge) — `theme/AuroraShapes.swift`.
- Стекло — `.ultraThinMaterial`/`.regularMaterial` + tint; блюр навбара — material + tint 0.55.
- Градиенты в `theme/AuroraBrushes.swift`: кнопка — горизонтальный индиго→циан, аватар —
  диагональный, фон — два радиальных свечения (индиго 0.67 / циан 0.53 → transparent).

## Анимации

- Пружины: `spring(response:dampingFraction:)` ≈ damping 0.75; пульс пилюли таба 0.94→1.0.

---

# Swift Conventions

## Асинхронность

- `Task { }` внутри `@MainActor` ViewModel для обработки Intent.
- `async`-функции только в Repository/Interactor.
- Колбэк-API (Firebase listeners, GIDSignIn, CNContactPicker) оборачиваются в
  `AsyncStream`/`withCheckedThrowingContinuation` на границе data-слоя.

## Обработка ошибок

- Repository — `async throws`; Interactor превращает в бизнес-результат.
- В ViewModel: `Result.fold`-аналог — `switch result { case .success: ... case .failure: ... }`.
- НЕ глотать ошибки — логировать (`print`/os_log) и преобразовывать в состояние ошибки.

## Комментарии

- `///` KDoc-аналог для публичных функций; комментарии — на русском.
- НЕ комментировать очевидное.

## Форматирование

- Отступы: 4 пробела. Не табы.
- Максимальная длина строки: 120 символов.
- Trailing commas — в многострочных коллекциях.
- Пустая строка между логическими блоками — приветствуется.

## Именование MVI-компонентов (как в Android)

- ViewModel: `AuthViewModel`, `GroupsViewModel`
- UiState: `AuthUiState`; Intent: `AuthIntent`; Effect: `AuthEffect`
- Repository: протокол `AuthRepository`, реализация `AuthRepositoryImpl`
- Константы: `SCREAMING_SNAKE_CASE` (`MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT_MS`)

---

# Запрещено

- ❌ Combine — только Swift Concurrency (обёртки колбэков через AsyncStream/continuation)
- ❌ `DispatchQueue.main.async` — только `@MainActor`
- ❌ Force unwrap `!`, `try!`, `as!` — кроме `#Preview` и известных-не-нулевых ресурсов
  (Bundle/UIFont) с комментарием-обоснованием
- ❌ `AnyView` — использовать generics/`@ViewBuilder`/протоколы View
- ❌ Прямые вызовы Firebase/GoogleMaps из ViewModel
- ❌ UI-тесты и юнит-тесты (`*Test.swift`) — на этом этапе не пишем, test-таргеты не добавляем
- ❌ APNs/FCM, App Groups, CloudKit, Widgets — требуют платного аккаунта (см. Сайдлоад)
- ❌ Коммит `.xcodeproj`, `DerivedData`, `build/`
- ❌ Сторонние зависимости вне утверждённого списка: firebase-ios-sdk, GoogleMaps,
  GoogleSignIn-iOS, Factory, Mantis
- ❌ Хардкод hex/rgb вне `theme/AuroraColors.swift`
- ❌ UIKit-вью в фичах кроме обёртки карты (`ui/map`)

---

# Пайплайн разработки (главный процесс)

Разработка идёт циклами оркестратора — скилл `dev-pipeline`:
`планировщик → разработчик → ревьюер ⟲ (цикл правок до вердикта APPROVE)`.

- **Один цикл = один этап из `docs/port-plan.md`.** Этапы выполняются по порядку.
- **Этапы запускаются подряд без запроса подтверждения пользователю** — постоянное
  разрешение выдано (2026-11-18): завершив этап (APPROVE + зелёный CI), координатор сразу
  начинает следующий. Останов — только по явной просьбе пользователя или на блокере,
  который пользователь должен разрешить сам.
- Координатор (основная сессия) код не пишет — только оркестрирует субагентов.
- **После вердикта APPROVE** координатор ОБЯЗАН (постоянное разрешение пользователя выдано):
  1. добавить пункт в `CHANGELOG.md` в секцию `## [Unreleased]`;
  2. закоммитить (сообщение на русском, формат `<Этап N>: <что сделано>`);
  3. запушить в `origin main`.
- CI на каждый пуш собирает unsigned `.ipa`. Упал — следующий цикл начинается с мини-фикса
  сборки (разрешено без полного пайплайна).
- Планировщик и разработчик сверяются с Android-источником (путь в `docs/port-plan.md`):
  контракты, модели, логика и дизайн портируются, а не изобретаются.

---

# Общие соглашения

## Сохранение технических артефактов

**Никогда не переводить, не переписывать и не «улучшать»:** блоки кода, CLI-команды
(`xcodebuild`, `xcodegen`, `git`), пути к файлам, стек-трейсы, логи, JSON-ключи,
идентификаторы (`applicationId`, `serverClientId`, `projectId`).

## Цитаты пользователя

Если пользователь что-то процитировал — сохраняй в кавычках как есть.

## Сообщения об ошибках инструментов

Сообщения об ошибках Xcode/CI/компилятора оставлять на английском, как есть.

## CHANGELOG

Каждый этап — пункт в `CHANGELOG.md` (секции: Добавлено / Изменено / Исправлено) тем же
коммитом.

## Язык ответов агента

**ОБЯЗАТЕЛЬНОЕ ТРЕБОВАНИЕ:** агент отвечает только на русском. Комментарии в коде — на русском.
Сообщения коммитов — на русском. Технические артефакты — как есть.

---

**НАПОМИНАНИЕ: отвечай только на русском языке. Это обязательное требование.**
