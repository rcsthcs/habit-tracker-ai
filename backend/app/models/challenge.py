"""
Challenge — AI-генерируемые челленджи для пользователей.
Типы: daily (дневной), weekly (недельный), streak_recovery (восстановление серии).
"""
from datetime import datetime, date, timezone
from sqlalchemy import Integer, String, DateTime, Date, ForeignKey, Boolean, Enum as SAEnum, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base
import enum


class ChallengeType(str, enum.Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    STREAK_RECOVERY = "streak_recovery"
    CATEGORY_FOCUS = "category_focus"
    IMPROVEMENT = "improvement"


class ChallengeStatus(str, enum.Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    FAILED = "failed"
    EXPIRED = "expired"


class Challenge(Base):
    __tablename__ = "challenges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    type: Mapped[str] = mapped_column(SAEnum(ChallengeType), nullable=False)
    status: Mapped[str] = mapped_column(SAEnum(ChallengeStatus), default=ChallengeStatus.ACTIVE)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    target_habit_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("habits.id"), nullable=True)
    target_count: Mapped[int] = mapped_column(Integer, default=1)  # e.g., complete 5 times
    current_count: Mapped[int] = mapped_column(Integer, default=0)
    reward_text: Mapped[str] = mapped_column(String(300), default="")
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    user = relationship("User", back_populates="challenges")
    target_habit = relationship("Habit", foreign_keys=[target_habit_id])


class WeeklyReport(Base):
    __tablename__ = "weekly_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    week_start: Mapped[date] = mapped_column(Date, nullable=False)
    week_end: Mapped[date] = mapped_column(Date, nullable=False)
    total_habits: Mapped[int] = mapped_column(Integer, default=0)
    completed_count: Mapped[int] = mapped_column(Integer, default=0)
    completion_rate: Mapped[float] = mapped_column(Integer, default=0.0)
    best_habit: Mapped[str | None] = mapped_column(String(200), nullable=True)
    worst_habit: Mapped[str | None] = mapped_column(String(200), nullable=True)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    mood_avg: Mapped[float | None] = mapped_column(Integer, nullable=True)
    ai_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_tips: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON string list
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    user = relationship("User", back_populates="weekly_reports")
