# ShareMyLocation — iOS

Нативный iOS-порт Android-приложения [ShareMyLocation](https://github.com/tyupik/ShareMyLocation):
шаринг геолокации в реальном времени — друзья по номеру телефона, группы, гибкая аудитория
шаринга, live-карта. Пишется тем же мультиагентным AI-пайплайном «планировщик → разработчик →
ревьюер»; стандарты — в [AGENTS.md](AGENTS.md), этапы порта — в [docs/port-plan.md](docs/port-plan.md).

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
| Навигация | NavigationStack + собственный контейнер табов |

## Сборка

Локальной сборки нет (машина разработки — Windows, Xcode отсутствует). Проект собирает CI:
GitHub Actions на `macos-runner` — XcodeGen генерирует `.xcodeproj` из `project.yml`,
`xcodebuild` собирает **unsigned** `.ipa` (артефакт workflow). Схема сборки — Android-репозиторий.

## Установка на iPhone (сайдлоад)

Аккаунт Apple Developer не используется. Артефакт CI подписывается локально через
Sideloadly (Windows) бесплатным Apple ID — подпись действует 7 дней, потом переподпись.
Подробная инструкция — `docs/sideload.md` (появится на этапе 10 плана порта).

Ограничения сайдлоада (ожидаемы, не баги):

- Sign in with Apple может не работать под переподписью — тестировать вход по email и Google;
- фоновая геолокация и локальные уведомления работают;
- пушей нет (требуют платного аккаунта) — как и в Android-версии, уведомления локальные.
