"""
Prompt templates for the AI chatbot.
Includes system prompt with user context injection.
"""


def build_system_prompt(user_context: dict) -> str:
    """Build system prompt with personalized user context."""

    habits_text = ""
    if user_context.get("habits"):
        habits_list = []
        for h in user_context["habits"]:
            streak = h.get("streak", 0)
            rate = h.get("rate", 0)
            habits_list.append(f"  - {h['name']} (категория: {h['category']}, серия: {streak} дней, выполнение: {rate}%)")
        habits_text = "\n".join(habits_list)
    else:
        habits_text = "  Пользователь ещё не добавил привычки."

    analytics_text = ""
    if user_context.get("analytics"):
        a = user_context["analytics"]
        analytics_text = (
            f"  Всего привычек: {a.get('total', 0)}, активных: {a.get('active', 0)}\n"
            f"  Сегодня выполнено: {a.get('today_done', 0)} из {a.get('today_total', 0)}\n"
            f"  Общий процент выполнения: {a.get('overall_rate', 0)}%\n"
            f"  Лучшая серия: {a.get('best_streak', 0)} дней\n"
            f"  Оптимальное время: {a.get('optimal_time', 'не определено')}"
        )

    dangers_text = ""
    if user_context.get("dangers"):
        dangers_text = "\n".join(f"  - {d['message']}" for d in user_context["dangers"])
    else:
        dangers_text = "  Нет проблемных периодов."

    recommendations_text = ""
    if user_context.get("recommendations"):
        recommendations_text = "\n".join(
            f"  - {r['title']}: {r['reason']}" for r in user_context["recommendations"]
        )
    else:
        recommendations_text = "  Нет рекомендаций."

    return f"""Ты — персональный AI-коуч по формированию полезных привычек и осознанности в мобильном приложении.
Твоя миссия — не просто выдавать сухие факты, а помогать пользователю находить внутреннюю мотивацию, рефлексировать и достигать целей.

ПРАВИЛА И СТИЛЬ КОУЧИНГА:
- Отвечай на русском языке, доброжелательно, эмпатично и профессионально.
- Будь позитивным, но честным. Если есть негативные тренды (много пропусков) — мягко обрати на это внимание.
- Используй эмодзи умеренно и к месту.
- Задавай 1 короткий вовлекающий вопрос в конце ответа, чтобы стимулировать рефлексию (например: "Как думаешь, что тебе мешает?", "Какое самое маленькое действие ты можешь сделать сегодня?").
- Учитывай контекст пользователя ниже, чтобы давать максимально персонализированные ответы.
- Если пользователь на серии — хвали его за упорство персонально!
- Если пользователь часто пропускает — помоги разобраться в причинах (усталость, нехватка времени, слишком большая цель).
- Предлагай микро-шаги вместо больших изменений.
- Если уместно, предлагай пользователю новые привычки, которые органично впишутся в его жизнь.

КОНТЕКСТ ПОЛЬЗОВАТЕЛЯ:
Имя: {user_context.get('username', 'Пользователь')}

Привычки:
{habits_text}

Аналитика:
{analytics_text}

Проблемные периоды:
{dangers_text}

Рекомендации:
{recommendations_text}
"""


def build_motivation_message(streak: int, habit_name: str) -> str:
    """Generate streak motivation message."""
    if streak >= 30:
        return f"🏆 Невероятно! {habit_name} — уже {streak} дней подряд! Ты формируешь настоящую привычку!"
    elif streak >= 14:
        return f"🔥 Отлично! {streak} дней подряд с '{habit_name}'! Две недели — это серьёзно!"
    elif streak >= 7:
        return f"⭐ Целая неделя! {streak} дней '{habit_name}' подряд. Продолжай в том же духе!"
    elif streak >= 3:
        return f"💪 {streak} дня подряд '{habit_name}'! Хорошее начало, не останавливайся!"
    elif streak == 1:
        return f"✅ Отлично, '{habit_name}' выполнена сегодня! Завтра будет 2 дня подряд!"
    else:
        return f"🌱 Каждый день — новый шанс. Попробуй выполнить '{habit_name}' сегодня!"


def build_recovery_message(habit_name: str, last_streak: int) -> str:
    """Generate message after streak break."""
    if last_streak >= 7:
        return (f"Ты пропустил '{habit_name}', но помни — у тебя была серия в {last_streak} дней! "
                f"Это показывает, что ты можешь. Начни новую серию сегодня! 💪")
    else:
        return (f"Не переживай из-за пропуска '{habit_name}'. "
                f"Главное — не два пропуска подряд. Вернись к привычке сегодня! 🌱")

