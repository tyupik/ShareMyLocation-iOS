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
