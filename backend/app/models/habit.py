from datetime import datetime, timezone
from sqlalchemy import Integer, String, DateTime, Boolean, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base
import enum


class HabitCategory(str, enum.Enum):
    HEALTH = "health"
    FITNESS = "fitness"
    NUTRITION = "nutrition"
    MINDFULNESS = "mindfulness"
    PRODUCTIVITY = "productivity"
    LEARNING = "learning"
    SOCIAL = "social"
    SLEEP = "sleep"
    FINANCE = "finance"
    OTHER = "other"


class HabitFrequency(str, enum.Enum):
    DAILY = "daily"
    WEEKDAYS = "weekdays"
    WEEKENDS = "weekends"
    WEEKLY = "weekly"
    CUSTOM = "custom"


class Habit(Base):
    __tablename__ = "habits"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(String(500), default="")
    category: Mapped[str] = mapped_column(
        SAEnum(HabitCategory), default=HabitCategory.OTHER
    )
    frequency: Mapped[str] = mapped_column(
        SAEnum(HabitFrequency), default=HabitFrequency.DAILY
    )
    target_time: Mapped[str] = mapped_column(String(5), nullable=True)  # HH:MM format
    color: Mapped[str] = mapped_column(String(7), default="#4CAF50")  # Hex color
    icon: Mapped[str] = mapped_column(String(50), default="check_circle")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    user = relationship("User", back_populates="habits")
    logs = relationship("HabitLog", back_populates="habit", cascade="all, delete-orphan")

