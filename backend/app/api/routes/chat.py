from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func
from app.db.database import get_db
from app.models.user import User
from app.models.chat_session import ChatSession
from app.models.chat_message import ChatMessage
from app.schemas.analytics import (
    ChatMessageCreate,
    ChatMessageResponse,
    ChatSessionResponse,
)
from app.api.auth_utils import get_current_user
from app.nlp.chatbot import HabitChatbot

router = APIRouter(prefix="/chat", tags=["chat"])

chatbot = HabitChatbot()


async def _get_session_or_404(
    db: AsyncSession,
    current_user: User,
    session_id: str,
) -> ChatSession:
    result = await db.execute(
        select(ChatSession).where(
            ChatSession.id == session_id,
            ChatSession.user_id == current_user.id,
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Chat session not found")
    return session


def _build_session_preview(messages: list[ChatMessage]) -> str | None:
    if not messages:
        return None
    content = (messages[-1].content or "").strip().replace("\n", " ")
    return content[:80] if content else None


def _build_session_title(messages: list[ChatMessage]) -> str:
    if not messages:
        return "Новый чат"
    first_user = next((m for m in messages if m.role == "user"), None)
    content = ((first_user.content if first_user else messages[0].content) or "").strip()
    return content[:40] if content else "Новый чат"


async def _serialize_sessions(
    db: AsyncSession,
    current_user: User,
) -> list[ChatSessionResponse]:
    result = await db.execute(
        select(ChatSession)
        .where(ChatSession.user_id == current_user.id)
        .order_by(ChatSession.updated_at.desc(), ChatSession.created_at.desc())
    )
    sessions = result.scalars().all()

    serialized = []
    for session in sessions:
        msg_result = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session.id)
            .order_by(ChatMessage.timestamp.asc())
        )
        messages = msg_result.scalars().all()
        serialized.append(
            ChatSessionResponse(
                id=session.id,
                title=session.title,
                created_at=session.created_at,
                updated_at=session.updated_at,
                message_count=len(messages),
                preview=_build_session_preview(messages),
            )
        )
    return serialized


@router.get("/sessions", response_model=list[ChatSessionResponse])
async def get_chat_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await _serialize_sessions(db, current_user)


@router.post("/sessions", response_model=ChatSessionResponse)
async def create_chat_session(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = ChatSession(user_id=current_user.id, title="Новый чат")
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return ChatSessionResponse(
        id=session.id,
        title=session.title,
        created_at=session.created_at,
        updated_at=session.updated_at,
        message_count=0,
        preview=None,
    )


@router.post("/", response_model=ChatMessageResponse)
async def send_message(
    msg: ChatMessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = await _get_session_or_404(db, current_user, msg.session_id)

    # Save user message
    user_msg = ChatMessage(
        user_id=current_user.id,
        session_id=session.id,
        role="user",
        content=msg.content,
        suggested_habits=[],
        suggested_bundle_name=None,
    )
    db.add(user_msg)
    session.updated_at = datetime.now(timezone.utc)
    await db.commit()

    # Generate AI response
    try:
        response_payload = await chatbot.process_message(
            db,
            current_user,
            session.id,
            msg.content,
            context_hints=msg.context_hints or {},
        )
    except Exception:
        response_payload = {
            "message": "Я получил сообщение, но не смог обработать ответ AI. Давай попробуем ещё раз или переформулируем запрос.",
            "habits": [],
            "folder_name": None,
        }

    if not isinstance(response_payload, dict):
        response_payload = {
            "message": str(response_payload),
            "habits": [],
            "folder_name": None,
        }

    ai_msg = ChatMessage(
        user_id=current_user.id,
        session_id=session.id,
        role="assistant",
        content=(response_payload.get("message") or "Не удалось получить ответ AI.").strip(),
        suggested_habits=response_payload.get("habits") or [],
        suggested_bundle_name=response_payload.get("folder_name"),
    )
    db.add(ai_msg)
    session.title = (
        _build_session_title([user_msg, ai_msg])
        if session.title == "Новый чат"
        else session.title
    )
    session.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(ai_msg)

    return ai_msg


@router.get("/history", response_model=list[ChatMessageResponse])
async def get_chat_history(
    session_id: str,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _get_session_or_404(db, current_user, session_id)
    result = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.session_id == session_id,
        )
        .order_by(ChatMessage.timestamp.desc())
        .limit(limit)
    )
    messages = result.scalars().all()
    messages.reverse()
    return messages


@router.delete("/")
async def clear_chat_history(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _get_session_or_404(db, current_user, session_id)
    await db.execute(
        delete(ChatMessage).where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.session_id == session_id,
        )
    )
    await db.commit()
    return {"status": "ok"}


@router.delete("/sessions/{session_id}")
async def delete_chat_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a chat session and all its messages."""
    session = await _get_session_or_404(db, current_user, session_id)
    await db.execute(
        delete(ChatMessage).where(ChatMessage.session_id == session.id)
    )
    await db.delete(session)
    await db.commit()
    return {"status": "ok"}


