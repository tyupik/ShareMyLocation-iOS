# Установка ShareMyLocation на iPhone: сайдлоад через Sideloadly (Windows)

Инструкция для установки приложения на iPhone **без** аккаунта Apple Developer, без TestFlight
и без App Store — на Windows, бесплатным Apple ID. Все факты о Sideloadly и лимитах — из
официального [FAQ](https://sideloadly.io/faq.html); ограничения описаны честно, без маркетинга.

## Что это

- CI репозитория ([Actions](https://github.com/tyupik/ShareMyLocation-iOS/actions)) собирает
  **unsigned** `.ipa` — workflow [`.github/workflows/ios-build.yml`](../.github/workflows/ios-build.yml),
  артефакт `ShareMyLocation-unsigned-ipa`, внутри файл `ShareMyLocation-unsigned.ipa`.
- [Sideloadly](https://sideloadly.io) на Windows подписывает этот `.ipa` вашим бесплатным
  Apple ID и ставит на подключённый iPhone по кабелю.
- Подпись бесплатного Apple ID живёт **7 дней** — потом та же процедура повторяется
  за пару минут (см. [«Обновление и переподпись»](#обновление-и-переподпись)).

TestFlight, App Store и платный аккаунт Apple Developer **не используются**.

## Ограничения (честно)

| Ограничение | Что это значит |
|---|---|
| Подпись живёт 7 дней | Каждые 7 дней — переподпись. Тот же Apple ID + тот же bundle id → Sideloadly перезаписывает приложение **с сохранением данных** (профиль, друзья, настройки). |
| Максимум 3 sideload-приложения на устройство | Лимит бесплатного Apple ID (iOS 10+). Считаются все приложения, подписанные бесплатными сертификатами. |
| До 10 App ID за 7 дней | Каждая новая пара «bundle id + Apple ID» расходует лимит. Поэтому **не меняйте bundle id** — переподпись того же bundle id лимит не расходует. |
| Sign in with Apple может не завестись | Известное ограничение сайдлоада под переподписью, **не баг приложения**. Основные проверяемые провайдеры — email и Google. |
| Пушей нет | Уведомления — только локальные (`UNUserNotificationCenter`), как в Android-версии. Push требует платного аккаунта и не планируется. |
| Без ключа карты — заглушка | Вкладка «Карта» показывает уведомление о недоступности карты, остальное работает. Ключ подставляется на Шаге 4 (опционально). |

## Что понадобится

- Windows 10/11.
- iPhone + кабель (Wi-Fi-установка в бесплатном сценарии не используется).
- Бесплатный Apple ID.
- Аккаунт GitHub: артефакты Actions скачивают **только авторизованные** — войдите в GitHub.
- [7-Zip](https://www.7-zip.org) — правка `.ipa` без пересборки архива.
- Доступ к Firebase-проекту (см. Шаг 3) — для входа в приложение.
- [Sideloadly](https://sideloadly.io) — скачивайте **только с официального сайта**.

## Шаг 1. Драйверы Apple (без них Sideloadly не увидит iPhone)

1. Удалите версии iTunes / Apple Devices / Apple Music, установленные из **Microsoft Store** —
   их драйверы конфликтуют с веб-версией.
2. Установите **iTunes 64-bit** веб-установщиком с [apple.com/itunes](https://www.apple.com/itunes/)
   (кнопка «Скачать» на сайте, не из Store). Он ставит `Apple Mobile Device Support` и
   `Apple Application Support` — именно их использует Sideloadly для связи с iPhone.

Проверка: подключите iPhone кабелем → на телефоне нажмите «Доверять» → Sideloadly покажет
модель устройства в выпадающем списке.

## Шаг 2. Скачать .ipa из CI

1. Откройте [Actions репозитория](https://github.com/tyupik/ShareMyLocation-iOS/actions)
   (нужен вход в GitHub).
2. Выберите последний **зелёный** run на ветке `main`.
3. В блоке **Artifacts** скачайте `ShareMyLocation-unsigned-ipa` — это zip.
4. Распакуйте zip обычным Проводником — внутри `ShareMyLocation-unsigned.ipa`.

## Шаг 3. GoogleService-Info.plist из Firebase Console (критично!)

Без этого файла в приложении **не работает ни один вход** — Firebase не сконфигурирован,
кнопки входа честно отвечают ошибкой конфигурации (и это ожидаемое поведение, не краш).

Вариант А — у вас есть доступ к проекту `sharemylocation-d44b4`:

1. [Firebase Console](https://console.firebase.google.com) → проект `sharemylocation-d44b4`
   → шестерёнка → **Настройки проекта** → вкладка **Общие** → раздел **Ваши приложения**.
2. Выберите iOS-приложение с bundle id `ru.tyupik.sharemylocation`
   (или добавьте его: «Добавить приложение» → iOS → bundle id `ru.tyupik.sharemylocation`
   — опечатки не делать, см. ниже) → **Скачать GoogleService-Info.plist**.

Вариант Б — доступа к проекту нет: создайте **свой** Firebase-проект с **той же** bundle id
`ru.tyupik.sharemylocation`:

1. Firebase Console → «Добавить проект» → «Добавить приложение» → iOS →
   bundle id `ru.tyupik.sharemylocation` → скачать `GoogleService-Info.plist`.
2. В своём проекте включите **Authentication → Sign-in method → Email/Password**.
3. Создайте **Firestore Database** и примените правила из Android-репозитория — файл
   [`firestore.rules`](https://github.com/tyupik/ShareMyLocation/blob/main/firestore.rules)
   репозитория [tyupik/ShareMyLocation](https://github.com/tyupik/ShareMyLocation).
   Кроссплатформенная дружба Android ↔ iOS работает только при одинаковой схеме — имена
   коллекций, полей и правила менять нельзя.

**Bundle id переписывать ЗАПРЕЩЕНО** (ни в Sideloadly, ни в Info.plist):

- `GoogleService-Info.plist` привязан к bundle id `ru.tyupik.sharemylocation` — после смены
  Firebase перестанет принимать вход;
- каждый новый bundle id расходует лимит 10 App ID за 7 дней (см. «Ограничения»).

## Шаг 4. Модификация .ipa ДО подписи

CI собирает `.ipa` без конфигов (плейсхолдеры в git). Поэтому перед подписью в архив нужно
внести три вещи — **до** Sideloadly, потому что Sideloadly подписывает всё содержимое как есть:

1. `GoogleService-Info.plist` — в корень `Payload/ShareMyLocation.app/` (без него — нет входа).
2. Ключ карты в `Info.plist` → `GMSApiKeyKey` (опционально, без него — заглушка карты).
3. URL scheme Google в `Info.plist` → `CFBundleURLTypes → CFBundleURLSchemes` (для входа Google).

> **Правьте архив только через 7-Zip.** Распаковка «Извлечь всё» и пересборка Проводником
> **ЗАПРЕЩЕНЫ** — так ломается структура `.ipa` (лишний верхний уровень папок, пути, атрибуты
> записей), и установка падает на подписи.

### Способ A: 7-Zip (основной)

1. Правый клик на `ShareMyLocation-unsigned.ipa` → **7-Zip → Открыть архив**.
2. В архиве откройте `Payload` → `ShareMyLocation.app`.
3. **Внедрить plist**: перетащите `GoogleService-Info.plist` из Проводника в окно 7-Zip —
   файл должен лечь **в корень `ShareMyLocation.app`** (рядом с `Info.plist`). 7-Zip
   предупредит о копировании в архив — подтвердите.
4. **Ключ карты** (опционально, нужен для live-карты):
   - Получите ключ: [Google Cloud Console](https://console.cloud.google.com) → **APIs & Services →
     Library → Maps SDK for iOS → Enable** → **Credentials → Create credentials → API key** →
     ограничьте ключ приложением по bundle id `ru.tyupik.sharemylocation` (Application restrictions →
     iOS apps).
   - Перетащите `Info.plist` из окна 7-Zip в любую папку (это извлечение), откройте
     текстовым редактором и замените плейсхолдер:

     ```xml
     <key>GMSApiKeyKey</key>
     <string>TODO_MAPS_API_KEY</string>
     ```

     на свой ключ между `<string>` и `</string>`.
5. **URL scheme Google** (нужен для входа через Google): в том же `Info.plist` найдите

   ```xml
   <key>CFBundleURLSchemes</key>
   <array>
       <string>com.googleusercontent.apps.TODO_REVERSED_CLIENT_ID</string>
   </array>
   ```

   и замените плейсхолдер на значение `REVERSED_CLIENT_ID` из внедрённого на шаге 3
   `GoogleService-Info.plist` (откройте его текстовым редактором — ключ `REVERSED_CLIENT_ID`,
   строка вида `com.googleusercontent.apps.1234567890-abcdefg.apps.xyz`).
6. Перетащите отредактированный `Info.plist` обратно в окно 7-Zip (в `Payload/ShareMyLocation.app`)
   с подтверждением замены, закройте архив.

> Формат `Info.plist` в артефакте ожидается **XML** (XcodeGen пишет текстовый plist,
> `GENERATE_INFOPLIST_FILE: NO` в [project.yml](../project.yml)). Если при открытии в редакторе
> вы видите бинарные байты — используйте способ B.

### Способ B: Python (если Info.plist бинарный)

Python 3 читает и пишет plist в обоих форматах (`plistlib`), zipfile умеет только пересборку
архива целиком — скрипт ниже делает всё разом: внедряет `GoogleService-Info.plist`, подставляет
ключ карты и меняет URL scheme. `REVERSED_CLIENT_ID` скрипт берёт сам из скачанного plist.

1. Сохраните скрипт в `patch_ipa.py` рядом с `.ipa`:

   ```python
   """Модификация unsigned .ipa перед подписью (Windows, stdlib без зависимостей).

   Использование:
       python patch_ipa.py ShareMyLocation-unsigned.ipa GoogleService-Info.plist [КЛЮЧ_КАРТЫ]
   """
   import os
   import plistlib
   import sys
   import tempfile
   import zipfile

   APP_DIR = "Payload/ShareMyLocation.app/"
   INFO_PLIST_PATH = APP_DIR + "Info.plist"
   GOOGLE_PLIST_PATH = APP_DIR + "GoogleService-Info.plist"
   PLACEHOLDER_SCHEME = "com.googleusercontent.apps.TODO_REVERSED_CLIENT_ID"
   PLACEHOLDER_MAP_KEY = "TODO_MAPS_API_KEY"


   def main() -> None:
       if len(sys.argv) < 3:
           raise SystemExit(__doc__)
       ipa_path, google_plist_path = sys.argv[1], sys.argv[2]
       map_key = sys.argv[3] if len(sys.argv) > 3 else None

       with open(google_plist_path, "rb") as f:
           google_plist = plistlib.load(f)
       reversed_client_id = google_plist.get("REVERSED_CLIENT_ID")
       if not reversed_client_id:
           print("ВНИМАНИЕ: в GoogleService-Info.plist нет REVERSED_CLIENT_ID — URL scheme не изменён")

       with zipfile.ZipFile(ipa_path) as src:
           entries = [(info, src.read(info.filename)) for info in src.infolist()]

       fd, tmp_path = tempfile.mkstemp(suffix=".ipa")
       os.close(fd)
       with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as dst:
           for info, data in entries:
               if info.filename == GOOGLE_PLIST_PATH:
                   raise SystemExit("GoogleService-Info.plist уже в архиве — повторная модификация не нужна")
               if info.filename == INFO_PLIST_PATH:
                   plist = plistlib.loads(data)
                   if map_key:
                       plist["GMSApiKeyKey"] = map_key
                       print("GMSApiKeyKey подставлен")
                   if reversed_client_id:
                       url_types = plist["CFBundleURLTypes"]
                       schemes = url_types[0]["CFBundleURLSchemes"]
                       url_types[0]["CFBundleURLSchemes"] = [
                           reversed_client_id if scheme == PLACEHOLDER_SCHEME else scheme
                           for scheme in schemes
                       ]
                       print("URL scheme Google заменён на", reversed_client_id)
                   data = plistlib.dumps(plist, fmt=plistlib.FMT_XML)
               dst.writestr(info, data)
           with open(google_plist_path, "rb") as f:
               dst.writestr(GOOGLE_PLIST_PATH, f.read())
           print("GoogleService-Info.plist внедрён")

       os.replace(tmp_path, ipa_path)
       print("Готово:", ipa_path)


   if __name__ == "__main__":
       main()
   ```

2. Выполните (ключ карты опционален — без него будет заглушка карты):

   ```bat
   python patch_ipa.py ShareMyLocation-unsigned.ipa GoogleService-Info.plist ВАШ_КЛЮЧ_КАРТЫ
   ```

3. Скрипт печатает, что изменил, и перезаписывает `.ipa` по месту. Проверить результат можно,
   открыв архив в 7-Zip: в `Payload/ShareMyLocation.app` должны лежать `GoogleService-Info.plist`
   и `Info.plist` (теперь XML) с подставленными значениями.

## Шаг 5. Установка через Sideloadly

1. Скачайте и установите Sideloadly **только с [sideloadly.io](https://sideloadly.io)**.
2. Подключите iPhone кабелем → на телефоне «Доверять этому компьютеру» → в Sideloadly
   выберите устройство в выпадающем списке.
3. Перетащите модифицированный `.ipa` в окно Sideloadly.
4. Введите **Apple ID** и пароль. При двухфакторной аутентификации — введите код с iPhone.
   App-specific пароли на бесплатном аккаунте надёжно не работают — используйте основной.
5. **Advanced options НЕ ТРОГАТЬ**: в частности, bundle id менять нельзя (см. Шаг 3 —
   Firebase привязан к bundle id + лимит App ID).
6. **Start** → дождитесь «Done». Приложение появится на домашнем экране.

## Шаг 6. Доверие разработчику

На iPhone: **Настройки → Основные → VPN и управление устройством** →
«Apple Development: `<ваш Apple ID>`» → **Доверять**. Без этого запуск обрывается
«Приложению не разрешено работать на вашем устройстве».

## Шаг 7. Первый запуск

1. Войдите по **email** (регистрация + вход). Вход через **Google** работает, если выполнен
   Шаг 4, Способ A пункты 3 и 5 (plist + URL scheme) — конфигурация GoogleSignIn читается
   приложением из внедрённого plist. **Sign in with Apple** может не сработать (известное
   ограничение сайдлоада — не баг).
2. Завершите онбординг (имя, телефон, аватар).
3. Включите «Делиться геопозицией» — приложение запросит право на геолокацию
   (сначала «при использовании», Always — при включении фонового шаринга).
4. Право на уведомления приложение запросит при первом входе на главный экран.

## Обновление и переподпись

Каждые 7 дней:

1. Свежий `.ipa` — последний зелёный run в Actions (Шаг 2) и та же модификация из Шага 4.
2. Тот же Apple ID, тот же bundle id → Sideloadly **перезаписывает** приложение без потери
   данных (профиль, друзья, настройки шаринга остаются в Firestore, локальные — тоже).
3. Если iPhone показывает «подпись истекла» — просто повторите Шаг 5.

## Типичные ошибки

| Ошибка | Решение |
|---|---|
| `A valid provisioning profile for this executable was not found` / `The identity used to sign the executable is no longer valid` | Расхождение даты/времени на ПК и iPhone — проверьте обе, включите автосинхронизацию; если не помогло — переподпишите заново. |
| `LOCKDOWN_E_INVALID_HOST_ID` | iPhone «не узнал» компьютер: на телефоне «Доверять», переподключить кабель; не помогло — перезагрузить и ПК, и iPhone. |
| `NP_E_CONN_FAILED` / `AFC_E_MUX_ERROR` | Стоит iTunes из Microsoft Store — удалите, поставьте веб-версию (Шаг 1). |
| «Ненадёжный разработчик» при запуске | Не выполнен Шаг 6. |
| Лимит 10 App ID исчерпан | Подождать до 7 дней с первой подписи или использовать другой Apple ID. Не менять bundle id. |
| `0xe8008024` / `Provisioning Profile is Banned` | Сертификат Apple ID забанен лимитами: Sideloadly → **Advanced → Revoke Certificates** → повторить установку. |
| Вкладка карты — заглушка | На Шаге 4 не подставлен `GMSApiKeyKey`. |
| Кнопка Google отвечает «не сконфигурирован» | На Шаге 4 не внедрён `GoogleService-Info.plist` (или нет `CLIENT_ID`). Кнопка Apple — известное ограничение сайдлоада. |

## Чего не делаем

- TestFlight и App Store — не используем и не планируем.
- Платный аккаунт Apple Developer — не используем (поэтому нет пушей, App Groups, CloudKit, Widgets).
- Изменений кода для сайдлоада — все правки только внутри `.ipa` локально; плейсхолдеры
  `TODO_MAPS_API_KEY` и `com.googleusercontent.apps.TODO_REVERSED_CLIENT_ID` остаются в git.
