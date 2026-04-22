# CLAUDE.md

Этот файл содержит руководство для Claude Code (claude.ai/code) при работе с данным репозиторием.

## Команды

```bash
# Запуск с локальным бэкендом (по умолчанию: http://192.168.50.186:5001)
flutter run

# Запуск с указанием конкретного бэкенда
flutter run --dart-define=API_BASE_URL=http://192.168.50.199:5000

# Запуск с кастомным URL для Google Auth
flutter run --dart-define=API_BASE_URL=http://... --dart-define=GOOGLE_AUTH_URL=http://...

# Анализ кода
flutter analyze

# Запуск всех тестов
flutter test

# Запуск одного тестового файла
flutter test test/path/to/test_file.dart

# Сборка APK
flutter build apk --dart-define=API_BASE_URL=http://...
```

## Архитектура

### Структура по фичам

`lib/` организован следующим образом:
- `features/` — экраны, сгруппированные по доменам: `auth`, `home`, `device`, `room`, `analytics`, `notifications`, `profile`, `onboarding`
- `core/` — общая инфраструктура: `api/`, `router/`, `services/`, `theme/`, `widgets/`
- `models/` — простые Dart-модели данных (без бизнес-логики)

### Управление состоянием

Используется `provider` (`ChangeNotifier` + `ChangeNotifierProvider`). Глобальные провайдеры регистрируются в корне приложения в `main.dart`:
- `AppThemeController` — тёмная/светлая тема
- `NotificationProvider` — список уведомлений + переключатель push-уведомлений

Контроллеры на уровне фич (например, `AuthController`) создаются локально через `ChangeNotifierProvider` на соответствующем экране.

### Навигация

`go_router` с `ShellRoute`, оборачивающим `/home`, `/analytics`, `/profile` (они разделяют нижнюю навигационную панель `MainShell`). Все остальные маршруты (авторизация, экраны устройств и т.д.) — верхнеуровневые `GoRoute`.

Начальный маршрут определяется `SessionRestoreService` при старте — перенаправляет на `/onboarding`, `/login` или `/home`.

### Взаимодействие с бэкендом

**REST** — `ApiService` (`core/api/api_service.dart`):
- Базовый URL из `--dart-define=API_BASE_URL` (по умолчанию `http://192.168.50.186:5001`)
- Все запросы автоматически добавляют Bearer-токен из `SessionStorageService`
- Использует `_requestWithFallback` для перебора нескольких путей эндпоинтов (обработка несовместимости версий API)

**MQTT** — `MqttService` (`core/api/mqtt_service.dart`):
- Синглтон, подключающийся к `broker.hivemq.com:1883`
- Используется для телеметрии и управления устройствами в реальном времени

**Push-уведомления** — Firebase Messaging с `flutter_local_notifications` для баннеров на переднем плане. Фоновый обработчик зарегистрирован как функция верхнего уровня (`firebaseMessagingBackgroundHandler`).

### Сессия / авторизация

Токены хранятся через `flutter_secure_storage` (с миграцией из устаревших ключей `SharedPreferences`). Сервисы:
- `SessionStorageService` — чтение/запись токенов и кэшированного пользователя
- `SessionRestoreService` — проверяет сохранённый токен при старте, возвращает начальный маршрут
- `SessionCleanupService` — очищает все данные сессии при выходе

### Локализация

`easy_localization` с JSON-файлами в `assets/translations/`: `ru.json`, `en.json`, `ky.json`. Язык по умолчанию — русский.

### Тема

`AppThemeController` сохраняет выбранный режим темы в `SharedPreferences`. `AppTheme` определяет `ThemeData` для светлого и тёмного режимов.
