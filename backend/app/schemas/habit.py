from pydantic import BaseModel
from datetime import datetime, date
from app.models.habit import HabitCategory, HabitFrequency


# --- Habit ---
class HabitCreate(BaseModel):
    name: str
    description: str = ""
    category: HabitCategory = HabitCategory.OTHER
    frequency: HabitFrequency = HabitFrequency.DAILY
    cooldown_days: int = 1  # 1=каждый день, 2=через день...
    target_time: str | None = None  # HH:MM — когда выполнять
    reminder_time: str | None = None  # HH:MM — когда push
    color: str = "#4CAF50"
    icon: str = "check_circle"


class HabitUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    category: HabitCategory | None = None
    frequency: HabitFrequency | None = None
    cooldown_days: int | None = None
    target_time: str | None = None
    reminder_time: str | None = None
    color: str | None = None
    icon: str | None = None
    is_active: bool | None = None


class HabitResponse(BaseModel):
    id: int
    user_id: int
    name: str
    description: str
    category: HabitCategory
    frequency: HabitFrequency
    cooldown_days: int = 1
    target_time: str | None
    reminder_time: str | None
    color: str
    icon: str
    is_active: bool
    created_at: datetime
    current_streak: int = 0
    completion_rate: float = 0.0

    model_config = {"from_attributes": True}


# --- Habit Log ---
class HabitLogCreate(BaseModel):
    habit_id: int
    date: date
    completed: bool = True
    note: str | None = None
    skipped_reason: str | None = None


class HabitLogResponse(BaseModel):
    id: int
    habit_id: int
    date: date
    completed: bool
    completed_at: datetime | None
    note: str | None
    skipped_reason: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
