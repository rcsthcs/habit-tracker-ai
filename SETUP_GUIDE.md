# 🚀 Инструкция по запуску Habit Tracker AI

## Шаг 1: Установка Flutter SDK

### Вариант A — Скачать zip (рекомендуется):
1. Скачайте Flutter SDK: https://docs.flutter.dev/get-started/install/windows/mobile
2. Распакуйте архив в `C:\flutter` (путь НЕ должен содержать пробелы)
3. Добавьте `C:\flutter\bin` в системную переменную PATH:
   - Нажмите **Win + R** → введите `sysdm.cpl` → Enter
   - Вкладка **Дополнительно** → **Переменные среды**
   - В **Системные переменные** найдите `Path` → **Изменить** → **Создать**
   - Добавьте: `C:\flutter\bin`
   - Нажмите **ОК** во всех окнах

### Вариант B — Через Git:
```powershell
git clone https://github.com/flutter/flutter.git -b stable C:\flutter
# Затем добавьте C:\flutter\bin в PATH (см. выше)
```

### Проверка:
Откройте **новый** терминал PowerShell и выполните:
```powershell
flutter --version
flutter doctor
```

## Шаг 2: Установка Android Studio (для эмулятора)

1. Скачайте: https://developer.android.com/studio
2. Установите и запустите
3. В Android Studio: **More Actions** → **SDK Manager**
4. Установите **Android SDK**, **Android SDK Command-line Tools**, **Android SDK Build-Tools**
5. Примите лицензии:
```powershell
flutter doctor --android-licenses
```

### Создание эмулятора:
1. В Android Studio: **More Actions** → **Virtual Device Manager**
2. **Create Device** → выберите Pixel 7 → Next
3. Скачайте образ системы (API 34) → Next → Finish
4. Нажмите ▶ для запуска эмулятора

## Шаг 3: Запуск Backend (Python)

```powershell
cd "C:\Users\rcsthcs\PycharmProjects\habit app\backend"

# Создайте виртуальное окружение (если ещё нет)
python -m venv .venv
.venv\Scripts\Activate.ps1

# Установите зависимости
pip install -r requirements.txt

# Запустите сервер
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
Сервер запустится на http://localhost:8000
Документация API: http://localhost:8000/docs

## Шаг 4: Запуск Flutter-приложения

### Из командной строки:
```powershell
cd "C:\Users\rcsthcs\PycharmProjects\habit app\mobile"

# Установка зависимостей
flutter pub get

# Проверка подключённых устройств
flutter devices

# Запуск на эмуляторе Android
flutter run

# Или запуск в Chrome (для быстрого тестирования)
flutter run -d chrome
```

### Из PyCharm (с плагином Flutter):
1. Откройте **File** → **Open** → выберите папку `mobile`
2. PyCharm предложит настроить Flutter SDK — укажите путь `C:\flutter`
3. Выберите устройство в выпадающем списке вверху (эмулятор или Chrome)
4. Нажмите зелёную кнопку ▶ (Run)

## Шаг 5: Запуск в Chrome (без Android Studio)

Если не хотите ставить Android Studio, можно запустить как веб-приложение:
```powershell
cd "C:\Users\rcsthcs\PycharmProjects\habit app\mobile"
flutter pub get
flutter run -d chrome
```

## ⚡ Быстрый старт (минимальный набор)

Для быстрого тестирования нужно:
1. Flutter SDK (обязательно)
2. Chrome (для веб-запуска) — уже есть
3. Python бэкенд (обязательно)

```powershell
# Терминал 1 — бэкенд:
cd "C:\Users\rcsthcs\PycharmProjects\habit app\backend"
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Терминал 2 — фронтенд:
cd "C:\Users\rcsthcs\PycharmProjects\habit app\mobile"
flutter pub get
flutter run -d chrome
```

## 🔧 Устранение проблем

### `flutter` не найден:
- Убедитесь, что `C:\flutter\bin` добавлен в PATH
- Перезапустите терминал/PyCharm после изменения PATH

### Ошибки `flutter doctor`:
```powershell
flutter doctor -v
```
Покажет детально, что нужно доустановить.

### Backend не запускается:
```powershell
pip install -r requirements.txt --force-reinstall
```

### Приложение не подключается к серверу:
- Для Chrome: сервер должен быть на `localhost:8000`
- Для Android эмулятора: URL `10.0.2.2:8000` (уже настроено в `config.dart`)

