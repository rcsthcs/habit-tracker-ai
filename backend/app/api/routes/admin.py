"""
Admin routes — platform management endpoints.
All routes require admin privileges.
"""
from datetime import datetime, date, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, delete
from app.db.database import get_db
from app.api.auth_utils import get_current_admin
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.chat_message import ChatMessage
from app.schemas.admin import (
    AdminUserResponse,
    AdminHabitResponse,
    PlatformAnalyticsResponse,
    AdminChatMessage,
    PaginatedResponse,
)

router = APIRouter(prefix="/admin", tags=["admin"])


# ─── Pydantic models for admin actions ───

class AdminEditLog(BaseModel):
    """Edit/create a habit log for testing purposes."""
    habit_id: int
    date: str  # YYYY-MM-DD
    completed: bool = True
    note: str | None = None


class AdminBulkGenerateLogs(BaseModel):
    """Generate N days of logs for testing."""
    habit_id: int
    days: int = 30
    completion_percent: int = 80  # % of days marked completed


class AdminEditHabit(BaseModel):
    """Admin can edit any habit's properties."""
    name: str | None = None
    cooldown_days: int | None = None
    target_time: str | None = None
    reminder_time: str | None = None
    is_active: bool | None = None


# ─── Users ───

@router.get("/users", response_model=PaginatedResponse)
async def get_all_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str = Query("", description="Search by username or email"),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Get all users with pagination and search."""
    query = select(User)
    count_query = select(func.count(User.id))

    if search:
        search_filter = f"%{search}%"
        query = query.where(
            (User.username.ilike(search_filter)) | (User.email.ilike(search_filter))
        )
        count_query = count_query.where(
            (User.username.ilike(search_filter)) | (User.email.ilike(search_filter))
        )

    total_result = await db.execute(count_query)
    total = total_result.scalar()

    result = await db.execute(
        query.order_by(User.created_at.desc()).offset(skip).limit(limit)
    )
    users = result.scalars().all()

    items = []
    for user in users:
        habit_count_result = await db.execute(
            select(func.count(Habit.id)).where(Habit.user_id == user.id)
        )
        habits_count = habit_count_result.scalar() or 0
        items.append(
            AdminUserResponse(
                id=user.id,
                username=user.username,
                email=user.email,
                timezone=user.timezone,
                is_active=user.is_active,
                is_admin=user.is_admin,
                created_at=user.created_at,
                habits_count=habits_count,
            )
        )

    return PaginatedResponse(items=items, total=total, skip=skip, limit=limit)


@router.patch("/users/{user_id}/block")
async def block_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Block a user."""
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    await db.commit()
    return {"message": f"User '{user.username}' blocked"}


@router.patch("/users/{user_id}/unblock")
async def unblock_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Unblock a user."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = True
    await db.commit()
    return {"message": f"User '{user.username}' unblocked"}


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Delete a user and all their data."""
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    await db.delete(user)
    await db.commit()
    return {"message": f"User '{user.username}' deleted"}


@router.patch("/users/{user_id}/toggle-admin")
async def toggle_admin(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Toggle admin status for a user."""
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot change your own admin status")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_admin = not user.is_admin
    await db.commit()
    return {"message": f"User '{user.username}' admin={'yes' if user.is_admin else 'no'}"}


# ─── Habits ───

@router.get("/habits", response_model=PaginatedResponse)
async def get_all_habits(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user_id: int | None = Query(None, description="Filter by user ID"),
    search: str = Query("", description="Search by habit name"),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Get all habits across the platform."""
    query = select(Habit, User.username).join(User, Habit.user_id == User.id)
    count_query = select(func.count(Habit.id))

    if user_id:
        query = query.where(Habit.user_id == user_id)
        count_query = count_query.where(Habit.user_id == user_id)
    if search:
        search_filter = f"%{search}%"
        query = query.where(Habit.name.ilike(search_filter))
        count_query = count_query.where(Habit.name.ilike(search_filter))

    total_result = await db.execute(count_query)
    total = total_result.scalar()

    result = await db.execute(
        query.order_by(Habit.created_at.desc()).offset(skip).limit(limit)
    )
    rows = result.all()

    items = []
    for habit, username in rows:
        # Count logs
        log_count_res = await db.execute(
            select(func.count(HabitLog.id)).where(HabitLog.habit_id == habit.id)
        )
        logs_count = log_count_res.scalar() or 0
        completed_res = await db.execute(
            select(func.count(HabitLog.id)).where(
                HabitLog.habit_id == habit.id, HabitLog.completed == True
            )
        )
        completed_count = completed_res.scalar() or 0
        rate = round(completed_count / logs_count * 100, 1) if logs_count > 0 else 0.0

        items.append(AdminHabitResponse(
            id=habit.id,
            user_id=habit.user_id,
            username=username,
            name=habit.name,
            description=habit.description,
            category=habit.category,
            frequency=habit.frequency,
            cooldown_days=habit.cooldown_days,
            target_time=habit.target_time,
            reminder_time=habit.reminder_time,
            is_active=habit.is_active,
            created_at=habit.created_at,
            logs_count=logs_count,
            completion_rate=rate,
        ))

    return PaginatedResponse(items=items, total=total, skip=skip, limit=limit)


@router.patch("/habits/{habit_id}")
async def admin_edit_habit(
    habit_id: int,
    data: AdminEditHabit,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Admin: edit any habit (name, cooldown, times, active status)."""
    result = await db.execute(select(Habit).where(Habit.id == habit_id))
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(habit, field, value)
    await db.commit()
    return {"message": f"Habit '{habit.name}' updated"}


@router.delete("/habits/{habit_id}")
async def admin_delete_habit(
    habit_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Admin: delete any habit."""
    result = await db.execute(select(Habit).where(Habit.id == habit_id))
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")
    await db.delete(habit)
    await db.commit()
    return {"message": f"Habit '{habit.name}' deleted"}


# ─── Logs management (for testing) ───

@router.post("/logs/edit")
async def admin_edit_log(
    data: AdminEditLog,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Admin: create or update a habit log for any date (for testing)."""
    log_date = date.fromisoformat(data.date)
    result = await db.execute(
        select(HabitLog).where(
            HabitLog.habit_id == data.habit_id,
            HabitLog.date == log_date,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        existing.completed = data.completed
        existing.note = data.note
        if data.completed:
            existing.completed_at = datetime.now(timezone.utc)
        await db.commit()
        return {"message": f"Log updated for {data.date}", "action": "updated"}
    else:
        log = HabitLog(
            habit_id=data.habit_id,
            date=log_date,
            completed=data.completed,
            completed_at=datetime.now(timezone.utc) if data.completed else None,
            note=data.note,
        )
        db.add(log)
        await db.commit()
        return {"message": f"Log created for {data.date}", "action": "created"}


@router.post("/logs/generate")
async def admin_generate_logs(
    data: AdminBulkGenerateLogs,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Admin: bulk-generate test logs for a habit over N days."""
    result = await db.execute(select(Habit).where(Habit.id == data.habit_id))
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    import random
    today = date.today()
    created = 0
    for i in range(data.days):
        log_date = today - timedelta(days=i)
        # Check if log already exists
        existing = await db.execute(
            select(HabitLog).where(
                HabitLog.habit_id == data.habit_id,
                HabitLog.date == log_date,
            )
        )
        if existing.scalar_one_or_none():
            continue
        completed = random.randint(1, 100) <= data.completion_percent
        log = HabitLog(
            habit_id=data.habit_id,
            date=log_date,
            completed=completed,
            completed_at=datetime.now(timezone.utc) if completed else None,
            note="Auto-generated for testing",
        )
        db.add(log)
        created += 1

    await db.commit()
    return {"message": f"Generated {created} logs for habit '{habit.name}' over {data.days} days"}


@router.delete("/logs/{log_id}")
async def admin_delete_log(
    log_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Admin: delete a specific habit log."""
    result = await db.execute(select(HabitLog).where(HabitLog.id == log_id))
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=404, detail="Log not found")
    await db.delete(log)
    await db.commit()
    return {"message": "Log deleted"}


@router.get("/habits/{habit_id}/logs")
async def admin_get_habit_logs(
    habit_id: int,
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Admin: view logs for any habit."""
    since = date.today() - timedelta(days=days)
    result = await db.execute(
        select(HabitLog)
        .where(HabitLog.habit_id == habit_id, HabitLog.date >= since)
        .order_by(HabitLog.date.desc())
    )
    logs = result.scalars().all()
    return [
        {
            "id": l.id,
            "date": l.date.isoformat(),
            "completed": l.completed,
            "note": l.note,
            "completed_at": l.completed_at.isoformat() if l.completed_at else None,
        }
        for l in logs
    ]


# ─── Analytics ───

@router.get("/analytics", response_model=PlatformAnalyticsResponse)
async def get_platform_analytics(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Get platform-wide analytics."""
    now = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)

    total_users = (await db.execute(select(func.count(User.id)))).scalar()
    active_users = (
        await db.execute(select(func.count(User.id)).where(User.is_active == True))
    ).scalar()
    new_users_7d = (
        await db.execute(
            select(func.count(User.id)).where(User.created_at >= week_ago)
        )
    ).scalar()

    total_habits = (await db.execute(select(func.count(Habit.id)))).scalar()
    active_habits = (
        await db.execute(
            select(func.count(Habit.id)).where(Habit.is_active == True)
        )
    ).scalar()
    new_habits_7d = (
        await db.execute(
            select(func.count(Habit.id)).where(Habit.created_at >= week_ago)
        )
    ).scalar()

    total_logs = (await db.execute(select(func.count(HabitLog.id)))).scalar()
    completed_logs = (
        await db.execute(
            select(func.count(HabitLog.id)).where(HabitLog.completed == True)
        )
    ).scalar()
    completion_rate = round((completed_logs / total_logs * 100) if total_logs > 0 else 0, 1)

    cat_result = await db.execute(
        select(Habit.category, func.count(Habit.id).label("count"))
        .group_by(Habit.category)
        .order_by(func.count(Habit.id).desc())
        .limit(5)
    )
    top_categories = [
        {"category": cat, "count": count} for cat, count in cat_result.all()
    ]

    return PlatformAnalyticsResponse(
        total_users=total_users,
        active_users=active_users,
        total_habits=total_habits,
        active_habits=active_habits,
        total_logs=total_logs,
        completion_rate=completion_rate,
        new_users_7d=new_users_7d,
        new_habits_7d=new_habits_7d,
        top_categories=top_categories,
    )


# ─── Chat logs ───

@router.get("/chats", response_model=PaginatedResponse)
async def get_chat_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    user_id: int | None = Query(None, description="Filter by user ID"),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Get chat messages across the platform."""
    query = select(ChatMessage, User.username).join(User, ChatMessage.user_id == User.id)
    count_query = select(func.count(ChatMessage.id))

    if user_id:
        query = query.where(ChatMessage.user_id == user_id)
        count_query = count_query.where(ChatMessage.user_id == user_id)

    total_result = await db.execute(count_query)
    total = total_result.scalar()

    result = await db.execute(
        query.order_by(ChatMessage.timestamp.desc()).offset(skip).limit(limit)
    )
    rows = result.all()

    items = [
        AdminChatMessage(
            id=msg.id,
            user_id=msg.user_id,
            username=username,
            role=msg.role,
            content=msg.content,
            timestamp=msg.timestamp,
        )
        for msg, username in rows
    ]

    return PaginatedResponse(items=items, total=total, skip=skip, limit=limit)

