# ShareMyLocation — iOS

Нативный iOS-порт Android-приложения [ShareMyLocation](https://github.com/tyupik/ShareMyLocation):
шаринг геолокации в реальном времени — друзья по номеру телефона, группы, гибкая аудитория
шаринга, live-карта.

**Порт завершён**: выполнены все 9 функциональных этапов [плана порта](docs/port-plan.md),
паритет с Android v1.1. Пишется тем же мультиагентным AI-пайплайном «планировщик → разработчик →
ревьюер»; стандарты — в [AGENTS.md](AGENTS.md).

## Возможности

- Вход по email, через Google и Sign in with Apple
- Профиль и онбординг — имя, телефон, аватар (фото, камера, круглый кроп)
- Друзья по номеру телефона: поиск, заявки, realtime-список
- Группы друзей с редактором состава
- Гибкая аудитория шаринга: все друзья или выбранные люди и группы
- Фоновый шаринг своей геопозиции — запись в Firestore каждые 5 секунд
- Live-карта: realtime-маркеры друзей с аватарами, «Показать меня», слежение камеры

## Стек

| Слой | Инструменты |
|---|---|
| UI | SwiftUI (iOS 17+), тёмная тема AURORA «ночной неон», Manrope |
| Архитектура | MVI (State / Intent / Effect) + Clean Architecture, UDF |
| DI | Factory |
| Язык | Swift (toolchain 6, language mode 5), Swift Concurrency |
| Auth | Firebase Auth (email/password, Google, Sign in with Apple) |
| Данные | Cloud Firestore (realtime-подписки, общий проект с Android-версией) |
| Карты | Google Maps SDK for iOS |
| Геолокация | CoreLocation + LocationSharingEngine (фоновой режим `location`) |
| Уведомления | локальные `UNUserNotificationCenter` (пушей нет — как в Android) |
| Навигация | NavigationStack + собственный контейнер табов |

## Сборка

Локальной сборки нет (машина разработки — Windows, Xcode отсутствует). Проект собирает CI
репозитория [tyupik/ShareMyLocation-iOS](https://github.com/tyupik/ShareMyLocation-iOS):
GitHub Actions на `macos-runner`, workflow
[`.github/workflows/ios-build.yml`](.github/workflows/ios-build.yml) — XcodeGen генерирует
`.xcodeproj` из `project.yml`, `xcodebuild` собирает Release с `CODE_SIGNING_ALLOWED=NO`,
`.app` упаковывается в `.ipa` (zip). Результат — артефакт `ShareMyLocation-unsigned-ipa`
с файлом `ShareMyLocation-unsigned.ipa` на странице последнего зелёного run
([Actions](https://github.com/tyupik/ShareMyLocation-iOS/actions)); скачивание артефактов
доступно только авторизованным в GitHub.

## Установка на iPhone (сайдлоад)

Аккаунт Apple Developer не используется. Подробная пошаговая инструкция —
[docs/sideload.md](docs/sideload.md): на Windows `.ipa` подписывается через Sideloadly
бесплатным Apple ID (подпись живёт 7 дней, потом переподпись тем же Apple ID с тем же
bundle id — перезапись с сохранением данных). Перед подписью в `.ipa` обязательно внедряется
`GoogleService-Info.plist` из Firebase Console (без него вход не работает), опционально —
ключ карты и URL scheme Google. Максимум 3 sideload-приложения на устройство; Sign in with
Apple под переподписью может не завестись (известное ограничение сайдлоада — тестировать
email и Google). Фоновая геолокация и локальные уведомления работают.
