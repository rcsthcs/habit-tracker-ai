# Habit Tracker AI 🧠✨

AI-powered мобильное приложение для формирования и поддержки полезных привычек.

**Stack:** Flutter (фронтенд) + Python FastAPI (бэкенд) + scikit-learn (ML) + Ollama (NLP чат-бот)

## Архитектура

```
habit app/
├── backend/           # Python FastAPI бэкенд
│   ├── app/
│   │   ├── api/       # REST API маршруты (auth, habits, chat, analytics)
│   │   ├── models/    # SQLAlchemy ORM модели
│   │   ├── schemas/   # Pydantic валидация
│   │   ├── ml/        # ML модуль (classifier, recommender, pattern_analyzer)
│   │   ├── nlp/       # NLP модуль (chatbot, LLM provider, prompts)
│   │   └── notifications/  # Планировщик уведомлений
│   └── main.py        # Точка входа FastAPI
└── mobile/            # Flutter приложение
    └── lib/
        ├── core/      # Конфиг, тема
        ├── models/    # Dart модели
        ├── services/  # API клиент
        ├── providers/ # Riverpod state management
        ├── screens/   # Экраны (home, progress, chat, settings)
        └── widgets/   # Компоненты (HabitCard, StreakBadge, AiTipCard)
```

## Быстрый старт

### 1. Бэкенд (Python)

```bash
cd backend

# Создать виртуальное окружение
python -m venv ../.venv
# Windows:
..\.venv\Scripts\activate
# macOS/Linux:
source ../.venv/bin/activate
# fish shell:
source ../.venv/bin/activate.fish

# Установить зависимости
pip install -r requirements.txt

# Запустить сервер
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Сервер запустится на http://localhost:8000
Документация API: http://localhost:8000/docs

### Настройка Google/Auth/Email/Push

1. Скопируйте `backend/.env.example` в `backend/.env` и заполните:
    - `GOOGLE_CLIENT_ID` (Web OAuth Client ID, не service account)
    - SMTP-параметры (`SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`, ...)
    - `FIREBASE_SERVICE_ACCOUNT_FILE` (абсолютный путь к JSON service account)
2. Для Flutter Google Sign-In укажите `googleServerClientId` в `mobile/lib/core/config.dart`.
3. После регистрации email должен быть подтвержден через `/api/auth/verify-email?token=...`.
4. Для push-уведомлений клиент должен отправить FCM token в `/api/notifications/device-token`.

### 2. AI Чат-бот (опционально)

Для полноценного AI-чата установи [Ollama](https://ollama.ai):

```bash
# Установить Ollama (https://ollama.ai)
# Скачать модель:
ollama pull llama3.2
```

Без Ollama чат-бот работает в fallback-режиме (rule-based ответы).

### 3. Flutter приложение

```bash
cd mobile

# Установить зависимости
flutter pub get

# Запустить на устройстве/эмуляторе
flutter run
```

## API Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/auth/register` | Регистрация |
| POST | `/api/auth/login` | Авторизация (OAuth2) |
| GET | `/api/auth/me` | Текущий пользователь |
| GET | `/api/habits/` | Список привычек |
| POST | `/api/habits/` | Создать привычку |
| PUT | `/api/habits/{id}` | Обновить привычку |
| DELETE | `/api/habits/{id}` | Удалить привычку |
| POST | `/api/habits/log` | Залогировать выполнение |
| GET | `/api/habits/{id}/logs` | История привычки |
| GET | `/api/analytics/` | Аналитика пользователя |
| GET | `/api/recommendations/` | AI рекомендации |
| POST | `/api/chat/` | Отправить сообщение в чат |
| GET | `/api/chat/history` | История чата |
| GET | `/api/notifications/` | Получить уведомления |

## ML Компоненты

- **Pattern Analyzer** — анализ временных паттернов (оптимальное время, опасные периоды)
- **Habit Difficulty Classifier** — RandomForest классификация сложности привычек
- **Recommender** — rule-based + коллаборативная фильтрация для рекомендаций новых привычек

## Миграция на продакшен

| Компонент | Сейчас (локально) | Продакшен |
|-----------|-------------------|-----------|
| БД | SQLite | PostgreSQL (поменять `DATABASE_URL`) |
| LLM | Ollama (локально) | OpenAI API (реализовать `OpenAIProvider`) |
| Уведомления | Локальные / polling | Firebase Cloud Messaging |
| Хостинг | localhost | Railway / VPS + Docker |
| ML модели | Файлы в `data/models/` | S3 / blob storage |

