"""
Notifications routes — персистентные уведомления из БД.
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update, delete
from app.db.database import get_db
from app.models.user import User
from app.models.notification import Notification
from app.models.device_token import DeviceToken
from app.schemas.analytics import NotificationResponse
from app.schemas.user import DeviceTokenRegisterRequest
from app.api.auth_utils import get_current_user

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("/device-token")
async def register_device_token(
    data: DeviceTokenRegisterRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    token = data.token.strip()
    if not token:
        return {"message": "Token is empty"}

    existing = await db.execute(select(DeviceToken).where(DeviceToken.token == token))
    token_row = existing.scalar_one_or_none()
    if token_row:
        token_row.user_id = current_user.id
        token_row.platform = data.platform or token_row.platform
    else:
        token_row = DeviceToken(
            user_id=current_user.id,
            token=token,
            platform=data.platform or "unknown",
        )
        db.add(token_row)

    await db.commit()
    return {"message": "Device token registered"}


@router.get("/", response_model=list[NotificationResponse])
async def get_notifications(
    limit: int = Query(50, ge=1, le=200),
    unread_only: bool = Query(False),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get notifications for the current user."""
    query = select(Notification).where(Notification.user_id == current_user.id)
    if unread_only:
        query = query.where(Notification.is_read == False)
    query = query.order_by(Notification.created_at.desc()).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


@router.get("/unread-count")
async def get_unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get count of unread notifications."""
    result = await db.execute(
        select(func.count(Notification.id)).where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
        )
    )
    count = result.scalar() or 0
    return {"unread_count": count}


@router.patch("/{notification_id}/read")
async def mark_as_read(
    notification_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark a notification as read."""
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        return {"message": "Notification not found"}

    notification.is_read = True
    await db.commit()
    return {"message": "Marked as read"}


@router.patch("/read-all")
async def mark_all_as_read(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark all notifications as read."""
    await db.execute(
        update(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
        )
        .values(is_read=True)
    )
    await db.commit()
    return {"message": "All notifications marked as read"}


@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a single notification."""
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        return {"message": "Notification not found"}

    await db.delete(notification)
    await db.commit()
    return {"message": "Notification deleted"}


@router.delete("/")
async def clear_all_notifications(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete all notifications for the current user."""
    await db.execute(
        delete(Notification).where(Notification.user_id == current_user.id)
    )
    await db.commit()
    return {"message": "All notifications cleared"}


