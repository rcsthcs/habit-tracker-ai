"""
Notification Scheduler — генерирует персонализированные напоминания,
проверяет челленджи и создает недельные отчёты.
"""
from datetime import datetime, date, timezone, timedelta
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy import select
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.notification import Notification
from app.models.challenge import Challenge, ChallengeStatus
from app.models.user import User
from app.config import get_settings
from app.notifications.push_service import send_push_to_user
import logging

logger = logging.getLogger(__name__)


async def _add_notification_db(db: AsyncSession, user_id: int, type_: str,
                                title: str, body: str, habit_id: int | None = None):
    """Add a notification to DB, avoiding duplicates for same habit+type today."""
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    existing = await db.execute(
        select(Notification).where(
            Notification.user_id == user_id,
            Notification.type == type_,
            Notification.habit_id == habit_id,
            Notification.created_at >= today_start,
        )
    )
    if existing.scalar_one_or_none():
        return  # Already notified today

    notification = Notification(
        user_id=user_id,
        type=type_,
        title=title,
        body=body,
        habit_id=habit_id,
    )
    db.add(notification)
    await db.flush()
    await send_push_to_user(
        db=db,
        user_id=user_id,
        title=title,
        body=body,
        data={
            "type": type_,
            "notification_id": str(notification.id),
            "habit_id": str(habit_id) if habit_id is not None else "",
        },
    )


async def check_and_generate_reminders():
    """Periodic task: check habits and generate reminders."""
    settings = get_settings()
    engine = create_async_engine(settings.DATABASE_URL)
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

            # Check if it's time to remind (target_time based)
            if habit.target_time:
                try:
                    target_hour, target_min = map(int, habit.target_time.split(":"))
                    target_dt = now.replace(hour=target_hour, minute=target_min)
                    if now >= target_dt - timedelta(minutes=15) and now <= target_dt + timedelta(minutes=30):
                        await _add_notification_db(
                            db, habit.user_id, "reminder",
                            f"Время для '{habit.name}'!",
                            f"Не забудь выполнить привычку. У тебя отличная серия!",
                            habit.id,
                        )
                except (ValueError, AttributeError):
                    pass

            # Late in the day reminder (after 20:00) for habits without target time
            if not habit.target_time and now.hour >= 20:
                await _add_notification_db(
                    db, habit.user_id, "evening_reminder",
                    "Ещё не поздно!",
                    f"Привычка '{habit.name}' ждёт тебя сегодня.",
                    habit.id,
                )

        await db.commit()

    await engine.dispose()
    logger.info(f"Reminder check completed at {now}")


async def expire_old_challenges():
    """Expire challenges that have passed their end date."""
    settings = get_settings()
    engine = create_async_engine(settings.DATABASE_URL)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as db:
        today = date.today()
        result = await db.execute(
            select(Challenge).where(
                Challenge.status == ChallengeStatus.ACTIVE,
                Challenge.end_date < today,
            )
        )
        expired = result.scalars().all()
        for c in expired:
            c.status = ChallengeStatus.EXPIRED

        # Notify users about expired challenges
        for c in expired:
            await _add_notification_db(
                db, c.user_id, "challenge_expired",
                "Челлендж завершён",
                f"Челлендж '{c.title}' истёк. Попробуй сгенерировать новый!",
            )

        await db.commit()

    await engine.dispose()
    logger.info(f"Challenge expiry check completed, {len(expired)} expired")


async def auto_update_challenge_progress():
    """Auto-check and update challenge progress based on habit logs."""
    settings = get_settings()
    engine = create_async_engine(settings.DATABASE_URL)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as db:
        today = date.today()

        # Get all active challenges
        result = await db.execute(
            select(Challenge).where(Challenge.status == ChallengeStatus.ACTIVE)
        )
        challenges = result.scalars().all()

        for c in challenges:
            if c.target_habit_id:
                # Count completed days in challenge period
                result = await db.execute(
                    select(HabitLog).where(
                        HabitLog.habit_id == c.target_habit_id,
                        HabitLog.date >= c.start_date,
                        HabitLog.date <= min(today, c.end_date),
                        HabitLog.completed == True,
                    )
                )
                completed_logs = result.scalars().all()
                c.current_count = len(completed_logs)
            else:
                # Generic challenge: count days where ALL habits were completed
                result = await db.execute(
                    select(Habit).where(
                        Habit.user_id == c.user_id,
                        Habit.is_active == True,
                    )
                )
                habits = result.scalars().all()
                if not habits:
                    continue

                full_days = 0
                for day_offset in range((min(today, c.end_date) - c.start_date).days + 1):
                    check_date = c.start_date + timedelta(days=day_offset)
                    result = await db.execute(
                        select(HabitLog).where(
                            HabitLog.habit_id.in_([h.id for h in habits]),
                            HabitLog.date == check_date,
                            HabitLog.completed == True,
                        )
                    )
                    day_completed = len(result.scalars().all())
                    if day_completed >= len(habits):
                        full_days += 1
                c.current_count = full_days

            # Auto-complete
            if c.current_count >= c.target_count:
                c.status = ChallengeStatus.COMPLETED
                c.completed_at = datetime.now(timezone.utc)
                await _add_notification_db(
                    db, c.user_id, "challenge_completed",
                    "🎉 Челлендж выполнен!",
                    f"Ты завершил '{c.title}'! {c.reward_text}",
                )

        await db.commit()

    await engine.dispose()
    logger.info("Challenge progress update completed")



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
    scheduler.add_job(
        expire_old_challenges,
        "cron",
        hour=0,
        minute=5,
        id="challenge_expiry",
        replace_existing=True,
    )
    scheduler.add_job(
        auto_update_challenge_progress,
        "interval",
        minutes=30,
        id="challenge_progress",
        replace_existing=True,
    )
    return scheduler

