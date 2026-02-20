from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, date, timezone, timedelta
from app.db.database import get_db
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.schemas.habit import (
    HabitCreate, HabitUpdate, HabitResponse,
    HabitLogCreate, HabitLogResponse,
)
from app.api.auth_utils import get_current_user

router = APIRouter(prefix="/habits", tags=["habits"])


async def _compute_streak(db: AsyncSession, habit_id: int) -> int:
    """Compute current consecutive days streak for a habit."""
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
        if log.date == expected_date:
            streak += 1
            expected_date -= timedelta(days=1)
        elif log.date == expected_date - timedelta(days=1):
            # Allow checking from yesterday if today not logged yet
            if streak == 0:
                expected_date = log.date
                streak = 1
                expected_date -= timedelta(days=1)
            else:
                break
        else:
            break
    return streak


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

    response = HabitResponse.model_validate(habit)
    response.current_streak = 0
    response.completion_rate = 0.0
    return response


@router.get("/", response_model=list[HabitResponse])
async def get_habits(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Habit).where(Habit.user_id == current_user.id, Habit.is_active == True)
    )
    habits = result.scalars().all()

    responses = []
    for habit in habits:
        resp = HabitResponse.model_validate(habit)
        resp.current_streak = await _compute_streak(db, habit.id)
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
    resp.current_streak = await _compute_streak(db, habit.id)
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
    resp.current_streak = await _compute_streak(db, habit.id)
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
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Habit not found")

    # Check for duplicate log
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
        return existing

    log = HabitLog(
        **log_data.model_dump(),
        completed_at=datetime.now(timezone.utc) if log_data.completed else None,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
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

