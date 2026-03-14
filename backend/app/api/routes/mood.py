"""
Mood tracking routes — CRUD for mood logs + mood-habit correlations.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import date, timedelta
from app.db.database import get_db
from app.models.user import User
from app.models.mood_log import MoodLog
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.schemas.mood import (
    MoodLogCreate, MoodLogResponse, MoodAnalytics, MoodHabitCorrelation,
)
from app.api.auth_utils import get_current_user
import numpy as np

router = APIRouter(prefix="/mood", tags=["mood"])


@router.post("/", response_model=MoodLogResponse, status_code=201)
async def log_mood(
    data: MoodLogCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Log mood for a specific date (upsert)."""
    result = await db.execute(
        select(MoodLog).where(
            MoodLog.user_id == current_user.id,
            MoodLog.date == data.date,
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(existing, field, value)
        await db.commit()
        await db.refresh(existing)
        return existing

    mood = MoodLog(user_id=current_user.id, **data.model_dump())
    db.add(mood)
    await db.commit()
    await db.refresh(mood)
    return mood


@router.get("/", response_model=list[MoodLogResponse])
async def get_mood_logs(
    days: int = 30,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get mood logs for the last N days."""
    since = date.today() - timedelta(days=days)
    result = await db.execute(
        select(MoodLog)
        .where(MoodLog.user_id == current_user.id, MoodLog.date >= since)
        .order_by(MoodLog.date.desc())
    )
    return result.scalars().all()


@router.get("/today", response_model=MoodLogResponse | None)
async def get_today_mood(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get today's mood entry."""
    result = await db.execute(
        select(MoodLog).where(
            MoodLog.user_id == current_user.id,
            MoodLog.date == date.today(),
        )
    )
    return result.scalar_one_or_none()


@router.get("/analytics", response_model=MoodAnalytics)
async def get_mood_analytics(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get mood analytics with habit correlations."""
    today = date.today()

    # Get mood logs
    result = await db.execute(
        select(MoodLog)
        .where(MoodLog.user_id == current_user.id, MoodLog.date >= today - timedelta(days=30))
        .order_by(MoodLog.date.desc())
    )
    mood_logs = result.scalars().all()

    # Average mood 7d/30d
    moods_7d = [m for m in mood_logs if m.date >= today - timedelta(days=7)]
    avg_7d = round(np.mean([m.score for m in moods_7d]), 2) if moods_7d else None
    avg_30d = round(np.mean([m.score for m in mood_logs]), 2) if mood_logs else None

    # Mood trend
    if len(mood_logs) >= 7:
        recent_half = mood_logs[:len(mood_logs) // 2]
        older_half = mood_logs[len(mood_logs) // 2:]
        recent_avg = np.mean([m.score for m in recent_half])
        older_avg = np.mean([m.score for m in older_half])
        diff = recent_avg - older_avg
        if diff > 0.3:
            trend = "improving"
        elif diff < -0.3:
            trend = "declining"
        else:
            trend = "stable"
    else:
        trend = "stable"

    # Best/worst day of week
    day_names = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
    day_scores: dict[int, list[float]] = {}
    for m in mood_logs:
        dow = m.date.weekday()
        day_scores.setdefault(dow, []).append(m.score)

    best_day = None
    worst_day = None
    if day_scores:
        day_avgs = {d: np.mean(scores) for d, scores in day_scores.items()}
        best_day = day_names[max(day_avgs, key=day_avgs.get)]
        worst_day = day_names[min(day_avgs, key=day_avgs.get)]

    # Mood-habit correlations
    correlations = await _compute_mood_habit_correlations(db, current_user.id, mood_logs)

    mood_responses = [MoodLogResponse.model_validate(m) for m in mood_logs]

    # Generate AI Insight for mood
    ai_insight = None
    if mood_logs:
        try:
            from app.nlp.llm_provider import get_llm_provider
            provider = get_llm_provider()
            
            corr_text = ", ".join([f"{c.habit_name} ({c.interpretation})" for c in correlations[:3]]) or "нет явных"
            
            sys_prompt = (
                "Ты — AI-коуч по психологии привычек. Проанализируй данные о настроении пользователя и "
                "сделай ОДИН короткий, эмпатичный вывод (максимум 2-3 предложения) о том, как действия влияют на "
                "его самочувствие. Дай мягкий совет. Формат ответа - просто текст."
            )
            data_str = (
                f"Среднее настроение 7дн: {avg_7d}, 30дн: {avg_30d}. Тренд: {trend}. "
                f"Лучший день: {best_day}, худший: {worst_day}. "
                f"Топ влияющих привычек: {corr_text}."
            )
            msg = f"Проанализируй эти данные и дай короткий инсайт:\n{data_str}"
            
            insight = await provider.generate(sys_prompt, msg)
            if insight:
                ai_insight = insight.strip()
        except Exception:
            pass

    return MoodAnalytics(
        avg_mood_7d=avg_7d,
        avg_mood_30d=avg_30d,
        mood_trend=trend,
        best_day=best_day,
        worst_day=worst_day,
        correlations=correlations,
        mood_history=mood_responses,
        ai_insight=ai_insight,
    )


async def _compute_mood_habit_correlations(
    db: AsyncSession, user_id: int, mood_logs: list[MoodLog]
) -> list[MoodHabitCorrelation]:
    """Compute Pearson correlation between mood scores and habit completion."""
    if len(mood_logs) < 7:
        return []

    # Get user habits
    result = await db.execute(
        select(Habit).where(Habit.user_id == user_id, Habit.is_active == True)
    )
    habits = result.scalars().all()
    if not habits:
        return []

    # Build mood by date map
    mood_by_date = {m.date: m.score for m in mood_logs}
    dates = sorted(mood_by_date.keys())

    # Get all habit logs for the period
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id.in_([h.id for h in habits]),
            HabitLog.date.in_(dates),
        )
    )
    all_logs = result.scalars().all()

    # Build habit completion by date
    habit_logs_map: dict[int, dict[date, bool]] = {}
    for log in all_logs:
        habit_logs_map.setdefault(log.habit_id, {})[log.date] = log.completed

    correlations = []
    for habit in habits:
        h_logs = habit_logs_map.get(habit.id, {})
        if not h_logs:
            continue

        mood_vals = []
        habit_vals = []
        for d in dates:
            if d in mood_by_date and d in h_logs:
                mood_vals.append(mood_by_date[d])
                habit_vals.append(1.0 if h_logs[d] else 0.0)

        if len(mood_vals) < 5:
            continue

        mood_arr = np.array(mood_vals)
        habit_arr = np.array(habit_vals)

        if np.std(mood_arr) == 0 or np.std(habit_arr) == 0:
            continue

        corr = float(np.corrcoef(mood_arr, habit_arr)[0, 1])

        if abs(corr) < 0.1:
            interpretation = "neutral"
            desc = f"Нет явной связи между '{habit.name}' и настроением"
        elif corr > 0.3:
            interpretation = "positive"
            desc = f"Выполнение '{habit.name}' связано с улучшением настроения (+{corr:.0%})"
        elif corr > 0:
            interpretation = "positive"
            desc = f"'{habit.name}' слегка улучшает настроение (+{corr:.0%})"
        elif corr < -0.3:
            interpretation = "negative"
            desc = f"'{habit.name}' может быть связана со снижением настроения ({corr:.0%})"
        else:
            interpretation = "negative"
            desc = f"'{habit.name}' слегка снижает настроение ({corr:.0%})"

        correlations.append(MoodHabitCorrelation(
            habit_id=habit.id,
            habit_name=habit.name,
            correlation=round(corr, 3),
            interpretation=interpretation,
            description=desc,
        ))

    correlations.sort(key=lambda c: abs(c.correlation), reverse=True)
    return correlations
