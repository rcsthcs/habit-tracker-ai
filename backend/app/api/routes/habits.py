from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, date, timezone, timedelta
import re
from app.db.database import get_db
from app.models.user import User
from app.models.habit import Habit, HABIT_NAME_SUGGESTIONS
from app.models.habit_log import HabitLog
from app.models.challenge import Challenge, ChallengeStatus, ChallengeType
from app.schemas.habit import (
    HabitCreate, HabitUpdate, HabitResponse,
    HabitLogCreate, HabitLogResponse,
)
from app.api.auth_utils import get_current_user
from app.services.achievement_checker import check_and_unlock

router = APIRouter(prefix="/habits", tags=["habits"])


async def _compute_streak(db: AsyncSession, habit_id: int, cooldown_days: int = 1) -> int:
    """Compute current consecutive streak, respecting cooldown_days."""
    result = await db.execute(
        select(HabitLog)
        .where(HabitLog.habit_id == habit_id, HabitLog.completed == True)
        .order_by(HabitLog.date.desc())
    )
    logs = result.scalars().all()
    if not logs:
        return 0

    streak = 0
    expected_date = date.today()
    for log in logs:
        diff = (expected_date - log.date).days
        if diff == 0:
            streak += 1
            expected_date -= timedelta(days=cooldown_days)
        elif diff <= cooldown_days and streak == 0:
            # Allow if today not logged yet but last log is within cooldown
            expected_date = log.date
            streak = 1
            expected_date -= timedelta(days=cooldown_days)
        else:
            break
    return streak


async def _is_completed_today(db: AsyncSession, habit_id: int) -> bool:
    """Check if habit was completed today."""
    today = date.today()
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id == habit_id,
            HabitLog.date == today,
            HabitLog.completed == True,
        )
    )
    return result.scalar_one_or_none() is not None


async def _today_completions(db: AsyncSession, habit_id: int, local_date: date = None) -> int:
    """Count how many completed logs exist for today."""
    today = local_date if local_date else date.today()
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id == habit_id,
            HabitLog.date == today,
            HabitLog.completed == True,
        )
    )
    logs = result.scalars().all()
    return len(logs)


async def _compute_best_streak(db: AsyncSession, habit_id: int, cooldown_days: int = 1) -> int:
    """Compute the best (longest) streak ever for a habit."""
    result = await db.execute(
        select(HabitLog)
        .where(HabitLog.habit_id == habit_id, HabitLog.completed == True)
        .order_by(HabitLog.date.asc())
    )
    logs = result.scalars().all()
    if not logs:
        return 0

    best = 1
    current = 1
    for i in range(1, len(logs)):
        diff = (logs[i].date - logs[i - 1].date).days
        if diff == cooldown_days:
            current += 1
            best = max(best, current)
        elif diff > cooldown_days:
            current = 1
        # if diff < cooldown_days, skip (duplicate day, etc.)
    return best


async def _completion_rate(db: AsyncSession, habit_id: int, days: int = 30) -> float:
    """Compute completion rate over the last N days."""
    since = date.today() - timedelta(days=days)
    result = await db.execute(
        select(HabitLog).where(HabitLog.habit_id == habit_id, HabitLog.date >= since)
    )
    logs = result.scalars().all()
    if not logs:
        return 0.0
    completed = sum(1 for l in logs if l.completed)
    return round(completed / len(logs) * 100, 1)


async def _recalculate_active_challenges(
    db: AsyncSession,
    user_id: int,
    reference_date: date,
) -> None:
    result = await db.execute(
        select(Challenge).where(
            Challenge.user_id == user_id,
            Challenge.status == ChallengeStatus.ACTIVE,
            Challenge.start_date <= reference_date,
            Challenge.end_date >= reference_date,
        )
    )
    challenges = result.scalars().all()
    if not challenges:
        return

    habits_result = await db.execute(
        select(Habit).where(Habit.user_id == user_id, Habit.is_active == True)
    )
    active_habits = habits_result.scalars().all()
    active_habit_ids = [h.id for h in active_habits]
    habit_by_id = {h.id: h for h in active_habits}

    for challenge in challenges:
        new_count = challenge.current_count

        if challenge.type == ChallengeType.DAILY:
            if challenge.target_habit_id is None:
                continue
            logs_result = await db.execute(
                select(HabitLog).where(
                    HabitLog.habit_id == challenge.target_habit_id,
                    HabitLog.completed == True,
                    HabitLog.date >= challenge.start_date,
                    HabitLog.date <= challenge.end_date,
                )
            )
            new_count = 1 if logs_result.scalar_one_or_none() else 0

        elif challenge.type == ChallengeType.STREAK_RECOVERY:
            if challenge.target_habit_id is None:
                continue
            habit = habit_by_id.get(challenge.target_habit_id)
            if habit is None:
                continue
            streak = await _compute_streak(db, habit.id, habit.cooldown_days)
            new_count = min(streak, challenge.target_count)

        elif challenge.type == ChallengeType.WEEKLY:
            if not active_habit_ids:
                new_count = 0
            else:
                logs_result = await db.execute(
                    select(HabitLog).where(
                        HabitLog.habit_id.in_(active_habit_ids),
                        HabitLog.completed == True,
                        HabitLog.date >= challenge.start_date,
                        HabitLog.date <= challenge.end_date,
                    )
                )
                logs = logs_result.scalars().all()
                by_day: dict[date, set[int]] = {}
                for log in logs:
                    by_day.setdefault(log.date, set()).add(log.habit_id)
                new_count = sum(
                    1 for completed_habits in by_day.values()
                    if len(completed_habits) >= len(active_habit_ids)
                )

        elif challenge.type in {ChallengeType.IMPROVEMENT, ChallengeType.CATEGORY_FOCUS}:
            category_match = re.search(r"'([^']+)'", challenge.title or "")
            category = category_match.group(1).strip().lower() if category_match else None
            candidate_habits = active_habits
            if category:
                candidate_habits = [h for h in active_habits if (h.category or '').lower() == category]
            category_habit_ids = [h.id for h in candidate_habits]
            if not category_habit_ids:
                new_count = 0
            else:
                logs_result = await db.execute(
                    select(HabitLog).where(
                        HabitLog.habit_id.in_(category_habit_ids),
                        HabitLog.completed == True,
                        HabitLog.date >= challenge.start_date,
                        HabitLog.date <= challenge.end_date,
                    )
                )
                logs = logs_result.scalars().all()
                new_count = len(logs)

        new_count = max(0, min(new_count, challenge.target_count))
        challenge.current_count = new_count

        if new_count >= challenge.target_count:
            challenge.status = ChallengeStatus.COMPLETED
            if challenge.completed_at is None:
                challenge.completed_at = datetime.now(timezone.utc)


# --- Suggestions endpoint ---
@router.get("/suggestions/{category}")
async def get_name_suggestions(category: str):
    """Get habit name suggestions for a category."""
    suggestions = HABIT_NAME_SUGGESTIONS.get(category, HABIT_NAME_SUGGESTIONS["other"])
    return {"category": category, "suggestions": suggestions}


@router.get("/suggestions")
async def get_all_suggestions():
    """Get all habit name suggestions grouped by category."""
    return HABIT_NAME_SUGGESTIONS


@router.post("/", response_model=HabitResponse, status_code=status.HTTP_201_CREATED)
async def create_habit(
    habit_data: HabitCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    habit = Habit(user_id=current_user.id, **habit_data.model_dump())
    db.add(habit)
    await db.commit()
    await db.refresh(habit)

    # Check achievements (first_habit, five_habits)
    await check_and_unlock(db, current_user.id)
    await db.commit()

    response = HabitResponse.model_validate(habit)
    response.current_streak = 0
    response.best_streak = 0
    response.completed_today = False
    response.completion_rate = 0.0
    return response


@router.get("/", response_model=list[HabitResponse])
async def get_habits(
    local_date: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        user_date = datetime.strptime(local_date, "%Y-%m-%d").date() if local_date else date.today()
    except Exception:
        user_date = date.today()

    result = await db.execute(
        select(Habit).where(Habit.user_id == current_user.id, Habit.is_active == True)
    )
    habits = result.scalars().all()

    responses = []
    for habit in habits:
        resp = HabitResponse.model_validate(habit)
        resp.current_streak = await _compute_streak(db, habit.id, habit.cooldown_days)
        resp.best_streak = await _compute_best_streak(db, habit.id, habit.cooldown_days)
        completions = await _today_completions(db, habit.id, user_date)
        resp.today_completions = completions
        resp.completed_today = completions >= habit.daily_target
        resp.completion_rate = await _completion_rate(db, habit.id)
        responses.append(resp)
    return responses


@router.get("/{habit_id}", response_model=HabitResponse)
async def get_habit(
    habit_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Habit).where(Habit.id == habit_id, Habit.user_id == current_user.id)
    )
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    resp = HabitResponse.model_validate(habit)
    resp.current_streak = await _compute_streak(db, habit.id, habit.cooldown_days)
    resp.best_streak = await _compute_best_streak(db, habit.id, habit.cooldown_days)
    completions = await _today_completions(db, habit.id)
    resp.today_completions = completions
    resp.completed_today = completions >= habit.daily_target
    resp.completion_rate = await _completion_rate(db, habit.id)
    return resp


@router.put("/{habit_id}", response_model=HabitResponse)
async def update_habit(
    habit_id: int,
    habit_data: HabitUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Habit).where(Habit.id == habit_id, Habit.user_id == current_user.id)
    )
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    update_data = habit_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(habit, field, value)

    await db.commit()
    await db.refresh(habit)

    resp = HabitResponse.model_validate(habit)
    resp.current_streak = await _compute_streak(db, habit.id, habit.cooldown_days)
    resp.best_streak = await _compute_best_streak(db, habit.id, habit.cooldown_days)
    completions = await _today_completions(db, habit.id)
    resp.today_completions = completions
    resp.completed_today = completions >= habit.daily_target
    resp.completion_rate = await _completion_rate(db, habit.id)
    return resp


@router.delete("/{habit_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_habit(
    habit_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Habit).where(Habit.id == habit_id, Habit.user_id == current_user.id)
    )
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    await db.delete(habit)
    await db.commit()


# --- Habit Logs ---

@router.post("/log", response_model=HabitLogResponse, status_code=status.HTTP_201_CREATED)
async def log_habit(
    log_data: HabitLogCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Verify habit belongs to user
    result = await db.execute(
        select(Habit).where(Habit.id == log_data.habit_id, Habit.user_id == current_user.id)
    )
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    # For multi-completion habits (daily_target > 1), always create new log if not at target
    if habit.daily_target > 1 and log_data.completed:
        completions = await _today_completions(db, habit.id, log_data.date)
        if completions >= habit.daily_target:
            raise HTTPException(status_code=400, detail="Daily target already reached")
        log = HabitLog(
            **log_data.model_dump(),
            completed_at=datetime.now(timezone.utc),
        )
        db.add(log)
        await db.commit()
        await db.refresh(log)
        await _recalculate_active_challenges(db, current_user.id, log_data.date)
        await check_and_unlock(db, current_user.id)
        await db.commit()
        return log

    # Check for duplicate log (single-completion habits)
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id == log_data.habit_id,
            HabitLog.date == log_data.date,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        # Update existing log
        existing.completed = log_data.completed
        existing.note = log_data.note
        existing.skipped_reason = log_data.skipped_reason
        if log_data.completed:
            existing.completed_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(existing)

        await _recalculate_active_challenges(db, current_user.id, log_data.date)
        # Check achievements after log update
        await check_and_unlock(db, current_user.id)
        await db.commit()

        return existing

    log = HabitLog(
        **log_data.model_dump(),
        completed_at=datetime.now(timezone.utc) if log_data.completed else None,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)

    await _recalculate_active_challenges(db, current_user.id, log_data.date)
    # Check achievements after logging
    await check_and_unlock(db, current_user.id)
    await db.commit()

    return log


@router.get("/{habit_id}/logs", response_model=list[HabitLogResponse])
async def get_habit_logs(
    habit_id: int,
    days: int = 30,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Verify habit belongs to user
    result = await db.execute(
        select(Habit).where(Habit.id == habit_id, Habit.user_id == current_user.id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Habit not found")

    since = date.today() - timedelta(days=days)
    result = await db.execute(
        select(HabitLog)
        .where(HabitLog.habit_id == habit_id, HabitLog.date >= since)
        .order_by(HabitLog.date.desc())
    )
    return result.scalars().all()
