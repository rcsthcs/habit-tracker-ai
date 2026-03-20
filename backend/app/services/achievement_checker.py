"""
Achievement Checker — проверяет и разблокирует достижения.
Вызывается после логирования привычки и создания привычки.
"""
from datetime import date, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.achievement import Achievement, AchievementType, ACHIEVEMENT_META
from app.models.notification import Notification
from app.notifications.push_service import send_push_to_user
import logging

logger = logging.getLogger(__name__)


async def _has_achievement(db: AsyncSession, user_id: int, achievement_type: str) -> bool:
    result = await db.execute(
        select(Achievement).where(
            Achievement.user_id == user_id,
            Achievement.achievement_type == achievement_type,
        )
    )
    return result.scalar_one_or_none() is not None


async def _unlock(db: AsyncSession, user_id: int, achievement_type: str) -> Achievement | None:
    """Unlock an achievement and create a notification. Returns the new achievement or None if already exists."""
    if await _has_achievement(db, user_id, achievement_type):
        return None

    achievement = Achievement(
        user_id=user_id,
        achievement_type=achievement_type,
    )
    db.add(achievement)

    meta = ACHIEVEMENT_META.get(achievement_type, {})
    notification = Notification(
        user_id=user_id,
        type="achievement",
        title=f"{meta.get('icon', '🏅')} Достижение разблокировано!",
        body=f"{meta.get('title', achievement_type)}: {meta.get('description', '')}",
    )
    db.add(notification)
    await db.flush()
    await send_push_to_user(
        db=db,
        user_id=user_id,
        title=notification.title,
        body=notification.body,
        data={"type": notification.type, "notification_id": str(notification.id)},
    )

    logger.info(f"🏅 User {user_id} unlocked achievement: {achievement_type}")
    return achievement


async def check_and_unlock(db: AsyncSession, user_id: int) -> list[str]:
    """Check all achievement conditions and unlock new ones. Returns list of newly unlocked types."""
    unlocked = []

    # --- FIRST_HABIT: has at least 1 habit ---
    habit_count_res = await db.execute(
        select(func.count(Habit.id)).where(Habit.user_id == user_id)
    )
    habit_count = habit_count_res.scalar() or 0

    if habit_count >= 1:
        if await _unlock(db, user_id, AchievementType.FIRST_HABIT):
            unlocked.append(AchievementType.FIRST_HABIT)

    # --- FIVE_HABITS: 5 active habits ---
    active_count_res = await db.execute(
        select(func.count(Habit.id)).where(
            Habit.user_id == user_id, Habit.is_active == True
        )
    )
    active_count = active_count_res.scalar() or 0

    if active_count >= 5:
        if await _unlock(db, user_id, AchievementType.FIVE_HABITS):
            unlocked.append(AchievementType.FIVE_HABITS)

    # --- TOTAL_100_LOGS: 100 completed logs ---
    total_completed_res = await db.execute(
        select(func.count(HabitLog.id)).where(
            HabitLog.habit_id.in_(
                select(Habit.id).where(Habit.user_id == user_id)
            ),
            HabitLog.completed == True,
        )
    )
    total_completed = total_completed_res.scalar() or 0

    if total_completed >= 100:
        if await _unlock(db, user_id, AchievementType.TOTAL_100_LOGS):
            unlocked.append(AchievementType.TOTAL_100_LOGS)

    # --- STREAK achievements: check max streak across all habits ---
    habits_res = await db.execute(
        select(Habit).where(Habit.user_id == user_id, Habit.is_active == True)
    )
    habits = habits_res.scalars().all()

    from app.api.routes.habits import _compute_streak

    max_streak = 0
    today = date.today()
    for habit in habits:
        streak = await _compute_streak(db, habit.id, habit.cooldown_days)
        if streak > max_streak:
            max_streak = streak

    if max_streak >= 7:
        if await _unlock(db, user_id, AchievementType.STREAK_7):
            unlocked.append(AchievementType.STREAK_7)
    if max_streak >= 30:
        if await _unlock(db, user_id, AchievementType.STREAK_30):
            unlocked.append(AchievementType.STREAK_30)
    if max_streak >= 100:
        if await _unlock(db, user_id, AchievementType.STREAK_100):
            unlocked.append(AchievementType.STREAK_100)

    # --- WEEK_PERFECT: all habits completed every day in the last 7 days ---
    if habits:
        today = date.today()
        week_perfect = True
        for i in range(7):
            day = today - timedelta(days=i)
            for habit in habits:
                log_res = await db.execute(
                    select(HabitLog).where(
                        HabitLog.habit_id == habit.id,
                        HabitLog.date == day,
                        HabitLog.completed == True,
                    )
                )
                if not log_res.scalar_one_or_none():
                    week_perfect = False
                    break
            if not week_perfect:
                break

        if week_perfect:
            if await _unlock(db, user_id, AchievementType.WEEK_PERFECT):
                unlocked.append(AchievementType.WEEK_PERFECT)

    # --- MONTH_PERFECT: all habits completed every day in the last 30 days ---
    if habits:
        month_perfect = True
        for i in range(30):
            day = today - timedelta(days=i)
            for habit in habits:
                log_res = await db.execute(
                    select(HabitLog).where(
                        HabitLog.habit_id == habit.id,
                        HabitLog.date == day,
                        HabitLog.completed == True,
                    )
                )
                if not log_res.scalar_one_or_none():
                    month_perfect = False
                    break
            if not month_perfect:
                break

        if month_perfect:
            if await _unlock(db, user_id, AchievementType.MONTH_PERFECT):
                unlocked.append(AchievementType.MONTH_PERFECT)

    await db.flush()
    return unlocked



