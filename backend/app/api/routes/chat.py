from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.database import get_db
from app.models.user import User
from app.models.chat_message import ChatMessage
from app.schemas.analytics import ChatMessageCreate, ChatMessageResponse
from app.api.auth_utils import get_current_user
from app.nlp.chatbot import HabitChatbot

router = APIRouter(prefix="/chat", tags=["chat"])

chatbot = HabitChatbot()


@router.post("/", response_model=ChatMessageResponse)
async def send_message(
    msg: ChatMessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Save user message
    user_msg = ChatMessage(
        user_id=current_user.id,
        role="user",
        content=msg.content,
    )
    db.add(user_msg)
    await db.commit()

    # Generate AI response
    response_text = await chatbot.process_message(db, current_user, msg.content)

    # Save AI response
    ai_msg = ChatMessage(
        user_id=current_user.id,
        role="assistant",
        content=response_text,
    )
    db.add(ai_msg)
    await db.commit()
    await db.refresh(ai_msg)

    return ai_msg


@router.get("/history", response_model=list[ChatMessageResponse])
async def get_chat_history(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == current_user.id)
        .order_by(ChatMessage.timestamp.desc())
        .limit(limit)
    )
    messages = result.scalars().all()
    messages.reverse()  # Return in chronological order
    return messages

