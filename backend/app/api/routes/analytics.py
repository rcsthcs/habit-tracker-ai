from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import date, timedelta, datetime
from app.db.database import get_db
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.schemas.analytics import AnalyticsResponse
from app.api.auth_utils import get_current_user
from app.api.routes.habits import _compute_streak, _completion_rate

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/", response_model=AnalyticsResponse)
async def get_analytics(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Get all user habits
    result = await db.execute(
        select(Habit).where(Habit.user_id == current_user.id)
    )
    all_habits = result.scalars().all()
    active_habits = [h for h in all_habits if h.is_active]

    # Today's stats
    today = date.today()
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id.in_([h.id for h in active_habits]),
            HabitLog.date == today,
        )
    )
    today_logs = result.scalars().all()
    today_completed = sum(1 for l in today_logs if l.completed)

    # Streaks and completion rates
    streaks = {}
    rates = {}
    for habit in active_habits:
        streaks[habit.id] = await _compute_streak(db, habit.id)
        rates[habit.id] = await _completion_rate(db, habit.id)

    # Best streak and rates
    longest_streak = max(streaks.values()) if streaks else 0
    current_best = max(streaks.values()) if streaks else 0

    # Most consistent / struggled
    most_consistent = None
    most_struggled = None
    if rates:
        best_id = max(rates, key=rates.get)
        worst_id = min(rates, key=rates.get)
        best_habit = next((h for h in active_habits if h.id == best_id), None)
        worst_habit = next((h for h in active_habits if h.id == worst_id), None)
        most_consistent = best_habit.name if best_habit else None
        most_struggled = worst_habit.name if worst_habit else None

    # Overall completion rate
    all_rates = list(rates.values())
    overall_rate = round(sum(all_rates) / len(all_rates), 1) if all_rates else 0.0

    # Weekly completion (last 7 days)
    weekly = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        result = await db.execute(
            select(HabitLog).where(
                HabitLog.habit_id.in_([h.id for h in active_habits]),
                HabitLog.date == day,
            )
        )
        day_logs = result.scalars().all()
        if day_logs:
            day_rate = sum(1 for l in day_logs if l.completed) / len(day_logs) * 100
        else:
            day_rate = 0.0
        weekly.append(round(day_rate, 1))

    # Optimal time analysis
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id.in_([h.id for h in active_habits]),
            HabitLog.completed == True,
            HabitLog.completed_at.is_not(None),
        )
    )
    completed_logs = result.scalars().all()
    optimal_time = None
    if completed_logs:
        hours = [l.completed_at.hour for l in completed_logs if l.completed_at]
        if hours:
            from collections import Counter
            most_common_hour = Counter(hours).most_common(1)[0][0]
            optimal_time = f"{most_common_hour:02d}:00"

    return AnalyticsResponse(
        total_habits=len(all_habits),
        active_habits=len(active_habits),
        today_completed=today_completed,
        today_total=len(active_habits),
        overall_completion_rate=overall_rate,
        longest_streak=longest_streak,
        current_best_streak=current_best,
        most_consistent_habit=most_consistent,
        most_struggled_habit=most_struggled,
        optimal_time=optimal_time,
        weekly_completion=weekly,
    )

