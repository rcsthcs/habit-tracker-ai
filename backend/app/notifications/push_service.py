import logging
from typing import Iterable

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.device_token import DeviceToken

logger = logging.getLogger(__name__)

_firebase_ready = False
_firebase_init_attempted = False


def _init_firebase() -> bool:
    global _firebase_ready, _firebase_init_attempted
    if _firebase_init_attempted:
        return _firebase_ready

    _firebase_init_attempted = True
    settings = get_settings()
    if not settings.FIREBASE_SERVICE_ACCOUNT_FILE:
        logger.warning("FIREBASE_SERVICE_ACCOUNT_FILE is not configured")
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_FILE)
        firebase_admin.initialize_app(cred)
        _firebase_ready = True
        logger.info("Firebase Admin initialized")
    except Exception as exc:
        logger.error("Failed to initialize Firebase Admin: %s", exc)
        _firebase_ready = False

    return _firebase_ready


async def _get_user_tokens(db: AsyncSession, user_id: int) -> list[str]:
    result = await db.execute(
        select(DeviceToken.token).where(DeviceToken.user_id == user_id)
    )
    return [row[0] for row in result.all() if row and row[0]]


async def send_push_to_user(
    db: AsyncSession,
    user_id: int,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    if not _init_firebase():
        return 0

    tokens = await _get_user_tokens(db, user_id)
    if not tokens:
        return 0

    import firebase_admin
    from firebase_admin import messaging

    successes = 0
    invalid_tokens: list[str] = []

    for token in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                token=token,
                data=data or {},
            )
            messaging.send(message, app=firebase_admin.get_app())
            successes += 1
        except Exception as exc:
            err_text = str(exc).lower()
            if "registration-token-not-registered" in err_text or "invalid-argument" in err_text:
                invalid_tokens.append(token)

    if invalid_tokens:
        await _remove_invalid_tokens(db, invalid_tokens)

    return successes


async def _remove_invalid_tokens(db: AsyncSession, tokens: Iterable[str]) -> None:
    tokens = [token for token in tokens if token]
    if not tokens:
        return

    result = await db.execute(
        select(DeviceToken).where(DeviceToken.token.in_(tokens))
    )
    entities = result.scalars().all()
    for entity in entities:
        await db.delete(entity)
    await db.flush()