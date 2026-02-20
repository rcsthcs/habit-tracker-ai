from fastapi import APIRouter, Depends
from app.models.user import User
from app.api.auth_utils import get_current_user
from app.notifications.scheduler import get_user_notifications

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/")
async def get_notifications(current_user: User = Depends(get_current_user)):
    """Poll for pending notifications (local dev). In production, use push."""
    notifications = get_user_notifications(current_user.id)
    return {"notifications": notifications}

