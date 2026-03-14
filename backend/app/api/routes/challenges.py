"""
Challenges routes — AI-generated challenges, streak recovery, weekly reports.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import date, datetime, timedelta, timezone
import json
import logging

from app.db.database import get_db
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.mood_log import MoodLog
from app.models.challenge import Challenge, ChallengeType, ChallengeStatus, WeeklyReport
from app.schemas.challenges import (
    ChallengeResponse, WeeklyReportResponse, StreakRecoveryResponse,
)
from app.api.auth_utils import get_current_user
from app.api.routes.habits import _compute_streak, _completion_rate

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/challenges", tags=["challenges"])


# ─── Challenges ──────────────────────────────────────────────
@router.get("/", response_model=list[ChallengeResponse])
async def get_challenges(
    status_filter: ChallengeStatus | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get user's challenges, optionally filtered by status."""
    query = select(Challenge).where(Challenge.user_id == current_user.id)
    if status_filter:
        query = query.where(Challenge.status == status_filter)
    query = query.order_by(Challenge.created_at.desc())

    result = await db.execute(query)
    challenges = result.scalars().all()

    responses = []
    for c in challenges:
        resp = ChallengeResponse.model_validate(c)
        resp.progress_pct = round(c.current_count / c.target_count * 100, 1) if c.target_count > 0 else 0
        responses.append(resp)
    return responses


@router.post("/generate", response_model=list[ChallengeResponse])
async def generate_challenges(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate AI challenges based on user's habits and patterns."""
    # Check if we already have active challenges
    result = await db.execute(
        select(Challenge).where(
            Challenge.user_id == current_user.id,
            Challenge.status == ChallengeStatus.ACTIVE,
        )
    )
    active = result.scalars().all()
    if len(active) >= 3:
        return [_to_response(c) for c in active]

    # Get user habits and stats
    result = await db.execute(
        select(Habit).where(Habit.user_id == current_user.id, Habit.is_active == True)
    )
    habits = result.scalars().all()
    if not habits:
        return []

    today = date.today()
    new_challenges = []

    # 1. Daily challenge — pick the most struggling habit
    rates = {}
    for h in habits:
        rates[h.id] = await _completion_rate(db, h.id, days=14)

    worst_id = min(rates, key=rates.get) if rates else None
    worst_habit = next((h for h in habits if h.id == worst_id), None) if worst_id else None

    if worst_habit and rates.get(worst_id, 100) < 70:
        daily = Challenge(
            user_id=current_user.id,
            type=ChallengeType.DAILY,
            title=f"Фокус на '{worst_habit.name}'",
            description=f"Выполни '{worst_habit.name}' сегодня! Твой текущий показатель: {rates[worst_id]:.0f}%.",
            target_habit_id=worst_habit.id,
            target_count=1,
            reward_text="🎯 +10 к силе воли!",
            start_date=today,
            end_date=today,
        )
        db.add(daily)
        new_challenges.append(daily)

    # 2. Weekly challenge — complete all habits for 5 days
    weekly = Challenge(
        user_id=current_user.id,
        type=ChallengeType.WEEKLY,
        title="Неделя продуктивности",
        description=f"Выполни все {len(habits)} привычек 5 дней на этой неделе.",
        target_count=5,
        reward_text="🏆 Мастер привычек!",
        start_date=today,
        end_date=today + timedelta(days=7),
    )
    db.add(weekly)
    new_challenges.append(weekly)

    # 3. Improvement challenge — improve worst category
    categories = {}
    for h in habits:
        cat = h.category
        categories.setdefault(cat, []).append(rates.get(h.id, 0))

    if categories:
        worst_cat = min(categories, key=lambda c: sum(categories[c]) / len(categories[c]))
        cat_rate = sum(categories[worst_cat]) / len(categories[worst_cat])
        if cat_rate < 80:
            improvement = Challenge(
                user_id=current_user.id,
                type=ChallengeType.IMPROVEMENT,
                title=f"Прокачай '{worst_cat}'",
                description=f"Повысь выполнение привычек в категории '{worst_cat}' с {cat_rate:.0f}% до 80%.",
                target_count=len(categories[worst_cat]) * 5,
                reward_text="📈 Категория улучшена!",
                start_date=today,
                end_date=today + timedelta(days=7),
            )
            db.add(improvement)
            new_challenges.append(improvement)

    await db.commit()
    for c in new_challenges:
        await db.refresh(c)

    return [_to_response(c) for c in new_challenges]


@router.post("/{challenge_id}/progress", response_model=ChallengeResponse)
async def update_challenge_progress(
    challenge_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Increment challenge progress. Automatically completes if target reached."""
    result = await db.execute(
        select(Challenge).where(
            Challenge.id == challenge_id,
            Challenge.user_id == current_user.id,
        )
    )
    challenge = result.scalar_one_or_none()
    if not challenge:
        raise HTTPException(status_code=404, detail="Challenge not found")

    if challenge.status != ChallengeStatus.ACTIVE:
        raise HTTPException(status_code=400, detail="Challenge is not active")

    challenge.current_count += 1
    if challenge.current_count >= challenge.target_count:
        challenge.status = ChallengeStatus.COMPLETED
        challenge.completed_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(challenge)
    return _to_response(challenge)


# ─── Streak Recovery ─────────────────────────────────────────
@router.get("/streak-recovery", response_model=list[StreakRecoveryResponse])
async def get_streak_recovery(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Detect broken streaks and offer recovery challenges."""
    result = await db.execute(
        select(Habit).where(Habit.user_id == current_user.id, Habit.is_active == True)
    )
    habits = result.scalars().all()
    today = date.today()
    recoveries = []

    for habit in habits:
        # Get recent logs
        result = await db.execute(
            select(HabitLog)
            .where(HabitLog.habit_id == habit.id, HabitLog.completed == True)
            .order_by(HabitLog.date.desc())
            .limit(60)
        )
        completed_logs = result.scalars().all()
        if not completed_logs:
            continue

        last_completed = completed_logs[0].date
        days_missed = (today - last_completed).days

        if days_missed < 2:
            continue  # No broken streak

        # Calculate what the streak was before break
        streak_before = 0
        for i, log in enumerate(completed_logs):
            if i == 0:
                streak_before = 1
                continue
            diff = (completed_logs[i - 1].date - log.date).days
            if diff <= habit.cooldown_days:
                streak_before += 1
            else:
                break

        if streak_before < 3:
            continue  # Not a meaningful streak to recover

        # Generate recovery message
        if streak_before >= 14:
            msg = (f"У тебя была впечатляющая серия {streak_before} дней для '{habit.name}'! "
                   f"Пропуск — это не конец. Давай вернёмся к привычке прямо сейчас! 🔥")
        elif streak_before >= 7:
            msg = (f"Целая неделя ({streak_before} дней) '{habit.name}' — это было круто! "
                   f"Давай начнём новую серию сегодня. 💪")
        else:
            msg = (f"Серия {streak_before} дня для '{habit.name}' сломалась. Не беда! "
                   f"Главное — вернуться. Один шаг — и ты снова в игре! 🌱")

        # Create a recovery challenge if none exists
        result = await db.execute(
            select(Challenge).where(
                Challenge.user_id == current_user.id,
                Challenge.type == ChallengeType.STREAK_RECOVERY,
                Challenge.target_habit_id == habit.id,
                Challenge.status == ChallengeStatus.ACTIVE,
            )
        )
        existing_challenge = result.scalar_one_or_none()

        if not existing_challenge:
            recovery_target = min(streak_before, 7)
            recovery_challenge = Challenge(
                user_id=current_user.id,
                type=ChallengeType.STREAK_RECOVERY,
                title=f"Верни серию '{habit.name}'",
                description=f"Выполни '{habit.name}' {recovery_target} дней подряд, чтобы восстановить серию!",
                target_habit_id=habit.id,
                target_count=recovery_target,
                reward_text=f"🔥 Серия восстановлена! Новая цель: {streak_before + 5} дней!",
                start_date=today,
                end_date=today + timedelta(days=recovery_target + 2),
            )
            db.add(recovery_challenge)
            await db.commit()
            await db.refresh(recovery_challenge)
            existing_challenge = recovery_challenge

        challenge_resp = _to_response(existing_challenge) if existing_challenge else None

        recoveries.append(StreakRecoveryResponse(
            habit_id=habit.id,
            habit_name=habit.name,
            lost_streak=streak_before,
            recovery_message=msg,
            challenge=challenge_resp,
        ))

    return recoveries


# ─── Weekly Report ───────────────────────────────────────────
@router.get("/weekly-report", response_model=WeeklyReportResponse | None)
async def get_weekly_report(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the latest weekly report or generate one if current week is missing."""
    today = date.today()
    week_start = today - timedelta(days=today.weekday())  # Monday

    # Check if report exists for this week
    result = await db.execute(
        select(WeeklyReport).where(
            WeeklyReport.user_id == current_user.id,
            WeeklyReport.week_start == week_start,
        )
    )
    report = result.scalar_one_or_none()

    if not report:
        report = await _generate_weekly_report(db, current_user, week_start)

    resp = WeeklyReportResponse.model_validate(report)
    return resp


@router.get("/weekly-reports", response_model=list[WeeklyReportResponse])
async def get_weekly_reports_history(
    limit: int = 8,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get history of weekly reports."""
    result = await db.execute(
        select(WeeklyReport)
        .where(WeeklyReport.user_id == current_user.id)
        .order_by(WeeklyReport.week_start.desc())
        .limit(limit)
    )
    reports = result.scalars().all()
    responses = []
    for r in reports:
        resp = WeeklyReportResponse.model_validate(r)
        responses.append(resp)
    return responses


# ─── Helpers ─────────────────────────────────────────────────
def _to_response(c: Challenge) -> ChallengeResponse:
    resp = ChallengeResponse.model_validate(c)
    resp.progress_pct = round(c.current_count / c.target_count * 100, 1) if c.target_count > 0 else 0
    return resp


async def _generate_weekly_report(
    db: AsyncSession, user: User, week_start: date
) -> WeeklyReport:
    """Generate a weekly report from habit data."""
    week_end = week_start + timedelta(days=6)

    # Get habits
    result = await db.execute(
        select(Habit).where(Habit.user_id == user.id, Habit.is_active == True)
    )
    habits = result.scalars().all()

    # Get logs for the week
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id.in_([h.id for h in habits]),
            HabitLog.date >= week_start,
            HabitLog.date <= week_end,
        )
    )
    logs = result.scalars().all()

    total_possible = len(habits) * 7
    completed = sum(1 for l in logs if l.completed)
    rate = round(completed / total_possible * 100, 1) if total_possible > 0 else 0

    # Best/worst habit
    habit_stats: dict[int, dict] = {}
    for h in habits:
        h_logs = [l for l in logs if l.habit_id == h.id]
        h_completed = sum(1 for l in h_logs if l.completed)
        habit_stats[h.id] = {
            "name": h.name,
            "completed": h_completed,
            "rate": h_completed / 7 * 100 if h_logs else 0,
        }

    best_h = max(habit_stats.values(), key=lambda x: x["rate"]) if habit_stats else None
    worst_h = min(habit_stats.values(), key=lambda x: x["rate"]) if habit_stats else None

    # Streak
    max_streak = 0
    for h in habits:
        streak = await _compute_streak(db, h.id, h.cooldown_days)
        max_streak = max(max_streak, streak)

    # Mood average
    result = await db.execute(
        select(MoodLog).where(
            MoodLog.user_id == user.id,
            MoodLog.date >= week_start,
            MoodLog.date <= week_end,
        )
    )
    moods = result.scalars().all()
    mood_avg = round(sum(m.score for m in moods) / len(moods), 2) if moods else None

    # AI summary
    summary_parts = []
    if rate >= 80:
        summary_parts.append(f"🏆 Отличная неделя! Выполнено {rate:.0f}% привычек.")
    elif rate >= 50:
        summary_parts.append(f"👍 Неплохая неделя: {rate:.0f}% привычек выполнено.")
    else:
        summary_parts.append(f"📊 Неделя была непростой: {rate:.0f}% выполнения.")

    if best_h and best_h["rate"] > 0:
        summary_parts.append(f"Лучшая привычка — '{best_h['name']}' ({best_h['rate']:.0f}%).")
    if worst_h and worst_h["rate"] < 100:
        summary_parts.append(f"Стоит подтянуть '{worst_h['name']}' ({worst_h['rate']:.0f}%).")
    if mood_avg:
        if mood_avg >= 4:
            summary_parts.append(f"Настроение на высоте! Средняя оценка: {mood_avg}.")
        elif mood_avg >= 3:
            summary_parts.append(f"Настроение стабильное: {mood_avg}/5.")
        else:
            summary_parts.append(f"Настроение ниже среднего ({mood_avg}/5). Попробуй добавить приятные привычки!")

    tips = []
    if worst_h and worst_h["rate"] < 50:
        tips.append(f"Попробуй привязать '{worst_h['name']}' к уже устоявшейся привычке (habit stacking).")
    if rate < 60:
        tips.append("Сфокусируйся на 2-3 главных привычках вместо того, чтобы делать всё сразу.")
    if max_streak >= 7:
        tips.append("Твоя серия растёт! Поставь промежуточную цель — удвой текущий рекорд.")
    if not tips:
        tips.append("Продолжай в том же духе! Стабильность — ключ к успеху.")

    report = WeeklyReport(
        user_id=user.id,
        week_start=week_start,
        week_end=week_end,
        total_habits=total_possible,
        completed_count=completed,
        completion_rate=rate,
        best_habit=best_h["name"] if best_h else None,
        worst_habit=worst_h["name"] if worst_h else None,
        longest_streak=max_streak,
        mood_avg=mood_avg,
        ai_summary=" ".join(summary_parts),
        ai_tips=json.dumps(tips, ensure_ascii=False),
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return report
