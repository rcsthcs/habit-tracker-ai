"""
MoodLog — журнал настроения пользователя.
Привязывается к дате, содержит числовую оценку (1-5), заметку и теги.
Используется для корреляции настроения с выполнением привычек.
"""
from datetime import datetime, date, timezone
from sqlalchemy import Integer, String, DateTime, Date, ForeignKey, Float
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base


class MoodLog(Base):
    __tablename__ = "mood_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    score: Mapped[float] = mapped_column(Float, nullable=False)  # 1.0-5.0
    note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    tags: Mapped[str | None] = mapped_column(String(500), nullable=True)  # comma-separated: "tired,stressed"
    energy_level: Mapped[float | None] = mapped_column(Float, nullable=True)  # 1.0-5.0
    stress_level: Mapped[float | None] = mapped_column(Float, nullable=True)  # 1.0-5.0
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    user = relationship("User", back_populates="mood_logs")
