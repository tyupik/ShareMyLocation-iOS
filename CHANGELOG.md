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
