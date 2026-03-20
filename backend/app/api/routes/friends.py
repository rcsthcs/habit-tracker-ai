"""
Friends routes — система друзей.
Запросы дружбы, принятие, список друзей, прогресс друзей.
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from datetime import date
from app.db.database import get_db
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.friendship import Friendship, FriendshipStatus
from app.models.notification import Notification
from app.notifications.push_service import send_push_to_user
from app.schemas.friends import FriendProgressResponse
from app.api.auth_utils import get_current_user
from app.api.routes.habits import _compute_streak, _completion_rate

router = APIRouter(prefix="/friends", tags=["friends"])


@router.get("/search")
async def search_users(
    q: str = Query("", min_length=1, description="Search by username"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Search for users to add as friends."""
    if len(q) < 2:
        return []
    result = await db.execute(
        select(User)
        .where(
            User.username.ilike(f"%{q}%"),
            User.id != current_user.id,
            User.is_active == True,
        )
        .limit(20)
    )
    users = result.scalars().all()

    # Get existing friendship statuses
    friend_ids = [u.id for u in users]
    existing_res = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.user_id == current_user.id, Friendship.friend_id.in_(friend_ids)),
                and_(Friendship.friend_id == current_user.id, Friendship.user_id.in_(friend_ids)),
            )
        )
    )
    existing = existing_res.scalars().all()
    status_map = {}
    friendship_id_map = {}
    for f in existing:
        other_id = f.friend_id if f.user_id == current_user.id else f.user_id
        status_map[other_id] = f.status
        friendship_id_map[other_id] = f.id

    return [
        {
            "id": u.id,
            "username": u.username,
            "avatar_url": u.avatar_url,
            "friendship_status": status_map.get(u.id),
            "friendship_id": friendship_id_map.get(u.id),
        }
        for u in users
    ]


@router.post("/request/{friend_id}")
async def send_friend_request(
    friend_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Send a friend request."""
    if friend_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself as a friend")

    # Check friend exists
    result = await db.execute(select(User).where(User.id == friend_id))
    friend = result.scalar_one_or_none()
    if not friend:
        raise HTTPException(status_code=404, detail="User not found")

    # Check if friendship already exists (in either direction)
    result = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.user_id == current_user.id, Friendship.friend_id == friend_id),
                and_(Friendship.user_id == friend_id, Friendship.friend_id == current_user.id),
            )
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        if existing.status == FriendshipStatus.ACCEPTED:
            raise HTTPException(status_code=400, detail="Already friends")
        if existing.status == FriendshipStatus.PENDING:
            raise HTTPException(status_code=400, detail="Request already pending")
        if existing.status == FriendshipStatus.REJECTED:
            # Re-send: update to pending
            existing.status = FriendshipStatus.PENDING
            existing.user_id = current_user.id
            existing.friend_id = friend_id
            await db.commit()
            return {"message": "Friend request re-sent"}

    friendship = Friendship(
        user_id=current_user.id,
        friend_id=friend_id,
        status=FriendshipStatus.PENDING,
    )
    db.add(friendship)

    # Notification for recipient
    notification = Notification(
        user_id=friend_id,
        type="friend_request",
        title="Новый запрос дружбы",
        body=f"{current_user.username} хочет добавить тебя в друзья",
    )
    db.add(notification)
    await db.flush()
    await send_push_to_user(
        db=db,
        user_id=friend_id,
        title=notification.title,
        body=notification.body,
        data={"type": notification.type, "notification_id": str(notification.id)},
    )

    await db.commit()
    return {"message": f"Friend request sent to {friend.username}"}


@router.delete("/request/{friendship_id}")
async def cancel_friend_request(
    friendship_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cancel a pending friend request that the current user sent."""
    result = await db.execute(
        select(Friendship).where(
            Friendship.id == friendship_id,
            Friendship.user_id == current_user.id,
            Friendship.status == FriendshipStatus.PENDING,
        )
    )
    friendship = result.scalar_one_or_none()
    if not friendship:
        raise HTTPException(status_code=404, detail="Friend request not found")

    await db.delete(friendship)
    await db.commit()
    return {"message": "Friend request cancelled"}


@router.post("/accept/{friendship_id}")
async def accept_friend_request(
    friendship_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Accept a friend request."""
    result = await db.execute(
        select(Friendship).where(
            Friendship.id == friendship_id,
            Friendship.friend_id == current_user.id,
            Friendship.status == FriendshipStatus.PENDING,
        )
    )
    friendship = result.scalar_one_or_none()
    if not friendship:
        raise HTTPException(status_code=404, detail="Friend request not found")

    friendship.status = FriendshipStatus.ACCEPTED

    # Notification for sender
    notification = Notification(
        user_id=friendship.user_id,
        type="friend_accepted",
        title="Запрос принят!",
        body=f"{current_user.username} принял(а) твой запрос дружбы",
    )
    db.add(notification)
    await db.flush()
    await send_push_to_user(
        db=db,
        user_id=friendship.user_id,
        title=notification.title,
        body=notification.body,
        data={"type": notification.type, "notification_id": str(notification.id)},
    )

    await db.commit()
    return {"message": "Friend request accepted"}


@router.post("/reject/{friendship_id}")
async def reject_friend_request(
    friendship_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Reject a friend request."""
    result = await db.execute(
        select(Friendship).where(
            Friendship.id == friendship_id,
            Friendship.friend_id == current_user.id,
            Friendship.status == FriendshipStatus.PENDING,
        )
    )
    friendship = result.scalar_one_or_none()
    if not friendship:
        raise HTTPException(status_code=404, detail="Friend request not found")

    friendship.status = FriendshipStatus.REJECTED
    await db.commit()
    return {"message": "Friend request rejected"}


@router.delete("/{friend_id}")
async def remove_friend(
    friend_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Remove a friend."""
    result = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.user_id == current_user.id, Friendship.friend_id == friend_id),
                and_(Friendship.user_id == friend_id, Friendship.friend_id == current_user.id),
            ),
            Friendship.status == FriendshipStatus.ACCEPTED,
        )
    )
    friendship = result.scalar_one_or_none()
    if not friendship:
        raise HTTPException(status_code=404, detail="Friendship not found")

    await db.delete(friendship)
    await db.commit()
    return {"message": "Friend removed"}


@router.get("/")
async def get_friends(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get list of accepted friends."""
    result = await db.execute(
        select(Friendship).where(
            or_(
                Friendship.user_id == current_user.id,
                Friendship.friend_id == current_user.id,
            ),
            Friendship.status == FriendshipStatus.ACCEPTED,
        )
    )
    friendships = result.scalars().all()

    friends = []
    for f in friendships:
        other_id = f.friend_id if f.user_id == current_user.id else f.user_id
        user_res = await db.execute(select(User).where(User.id == other_id))
        user = user_res.scalar_one_or_none()
        if user:
            friends.append({
                "friendship_id": f.id,
                "user_id": user.id,
                "username": user.username,
                "avatar_url": user.avatar_url,
                "created_at": f.created_at.isoformat(),
            })

    return friends


@router.get("/requests")
async def get_friend_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get incoming friend requests."""
    result = await db.execute(
        select(Friendship, User.username, User.avatar_url)
        .join(User, Friendship.user_id == User.id)
        .where(
            Friendship.friend_id == current_user.id,
            Friendship.status == FriendshipStatus.PENDING,
        )
        .order_by(Friendship.created_at.desc())
    )
    rows = result.all()

    return [
        {
            "friendship_id": f.id,
            "user_id": f.user_id,
            "username": username,
            "avatar_url": avatar_url,
            "created_at": f.created_at.isoformat(),
        }
        for f, username, avatar_url in rows
    ]


@router.get("/sent-requests")
async def get_sent_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get outgoing pending friend requests sent by current user."""
    result = await db.execute(
        select(Friendship, User.username, User.avatar_url)
        .join(User, Friendship.friend_id == User.id)
        .where(
            Friendship.user_id == current_user.id,
            Friendship.status == FriendshipStatus.PENDING,
        )
        .order_by(Friendship.created_at.desc())
    )
    rows = result.all()

    return [
        {
            "friendship_id": f.id,
            "user_id": f.friend_id,
            "username": username,
            "avatar_url": avatar_url,
            "created_at": f.created_at.isoformat(),
        }
        for f, username, avatar_url in rows
    ]


@router.get("/{friend_id}/progress", response_model=FriendProgressResponse)
async def get_friend_progress(
    friend_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get friend's aggregated progress (no habit names for privacy)."""
    # Verify they are friends
    result = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.user_id == current_user.id, Friendship.friend_id == friend_id),
                and_(Friendship.user_id == friend_id, Friendship.friend_id == current_user.id),
            ),
            Friendship.status == FriendshipStatus.ACCEPTED,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not friends")

    # Get friend data
    result = await db.execute(select(User).where(User.id == friend_id))
    friend = result.scalar_one_or_none()
    if not friend:
        raise HTTPException(status_code=404, detail="User not found")

    # Habits
    result = await db.execute(select(Habit).where(Habit.user_id == friend_id))
    all_habits = result.scalars().all()
    active_habits = [h for h in all_habits if h.is_active]

    # Best streak
    best_streak = 0
    for h in active_habits:
        s = await _compute_streak(db, h.id, h.cooldown_days)
        if s > best_streak:
            best_streak = s

    # Overall completion rate
    rates = []
    for h in active_habits:
        r = await _completion_rate(db, h.id)
        rates.append(r)
    overall_rate = round(sum(rates) / len(rates), 1) if rates else 0.0

    # Today
    today = date.today()
    today_completed = 0
    for h in active_habits:
        res = await db.execute(
            select(HabitLog).where(
                HabitLog.habit_id == h.id,
                HabitLog.date == today,
                HabitLog.completed == True,
            )
        )
        if res.scalar_one_or_none():
            today_completed += 1

    return FriendProgressResponse(
        user_id=friend.id,
        username=friend.username,
        avatar_url=friend.avatar_url,
        total_habits=len(all_habits),
        active_habits=len(active_habits),
        best_streak=best_streak,
        overall_completion_rate=overall_rate,
        today_completed=today_completed,
        today_total=len(active_habits),
    )



