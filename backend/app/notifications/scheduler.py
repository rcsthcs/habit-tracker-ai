"""
Notification Scheduler — генерирует персонализированные напоминания.
Сейчас: хранит в БД для polling из Flutter.
Потом: отправка через Firebase Cloud Messaging.
"""
from datetime import datetime, date, timezone, timedelta
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy import select
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.ml.pattern_analyzer import PatternAnalyzer
from app.config import get_settings
import logging

logger = logging.getLogger(__name__)


# In-memory notification store (for local dev; migrate to push in production)
pending_notifications: dict[int, list[dict]] = {}  # user_id -> [notifications]


async def check_and_generate_reminders():
    """Periodic task: check habits and generate reminders."""
    settings = get_settings()
    engine = create_async_engine(
        settings.DATABASE_URL,
    )
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as db:
        today = date.today()
        now = datetime.now(timezone.utc)

        # Get all active habits
        result = await db.execute(select(Habit).where(Habit.is_active == True))
        habits = result.scalars().all()

        for habit in habits:
            # Check if already completed today
            result = await db.execute(
                select(HabitLog).where(
                    HabitLog.habit_id == habit.id,
                    HabitLog.date == today,
                    HabitLog.completed == True,
                )
            )
            if result.scalar_one_or_none():
                continue  # Already done

            # Check if it's time to remind
            if habit.target_time:
                try:
                    target_hour, target_min = map(int, habit.target_time.split(":"))
                    target_dt = now.replace(hour=target_hour, minute=target_min)
                    # Remind 15 minutes before target time
                    if now >= target_dt - timedelta(minutes=15) and now <= target_dt + timedelta(minutes=30):
                        _add_notification(habit.user_id, {
                            "type": "reminder",
                            "habit_id": habit.id,
                            "title": f"Время для '{habit.name}'!",
                            "body": f"Не забудь выполнить привычку. У тебя отличная серия!",
                            "timestamp": now.isoformat(),
                        })
                except (ValueError, AttributeError):
                    pass

            # Late in the day reminder (after 20:00) for habits without target time
            if not habit.target_time and now.hour >= 20:
                _add_notification(habit.user_id, {
                    "type": "evening_reminder",
                    "habit_id": habit.id,
                    "title": f"Ещё не поздно!",
                    "body": f"Привычка '{habit.name}' ждёт тебя сегодня.",
                    "timestamp": now.isoformat(),
                })

    await engine.dispose()
    logger.info(f"Reminder check completed at {now}")


def _add_notification(user_id: int, notification: dict):
    """Add notification to pending store."""
    if user_id not in pending_notifications:
        pending_notifications[user_id] = []

    # Avoid duplicates
    existing_ids = {n.get("habit_id") for n in pending_notifications[user_id]}
    if notification.get("habit_id") not in existing_ids:
        pending_notifications[user_id].append(notification)


def get_user_notifications(user_id: int) -> list[dict]:
    """Get and clear pending notifications for a user."""
    notifications = pending_notifications.pop(user_id, [])
    return notifications


def create_scheduler() -> AsyncIOScheduler:
    """Create and configure the notification scheduler."""
    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        check_and_generate_reminders,
        "interval",
        minutes=15,
        id="reminder_check",
        replace_existing=True,
    )
    return scheduler

