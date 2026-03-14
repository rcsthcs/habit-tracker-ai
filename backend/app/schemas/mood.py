"""Schemas for mood tracking."""
from pydantic import BaseModel, Field
from datetime import date, datetime


class MoodLogCreate(BaseModel):
    date: date
    score: float = Field(ge=1.0, le=5.0, description="Mood score 1-5")
    note: str | None = None
    tags: str | None = None
    energy_level: float | None = Field(None, ge=1.0, le=5.0)
    stress_level: float | None = Field(None, ge=1.0, le=5.0)


class MoodLogResponse(BaseModel):
    id: int
    user_id: int
    date: date
    score: float
    note: str | None
    tags: str | None
    energy_level: float | None
    stress_level: float | None
    created_at: datetime

    model_config = {"from_attributes": True}


class MoodHabitCorrelation(BaseModel):
    habit_id: int
    habit_name: str
    correlation: float  # -1 to 1
    interpretation: str  # "positive", "negative", "neutral"
    description: str


class MoodAnalytics(BaseModel):
    avg_mood_7d: float | None
    avg_mood_30d: float | None
    mood_trend: str  # "improving", "declining", "stable"
    best_day: str | None  # day of week
    worst_day: str | None
    correlations: list[MoodHabitCorrelation]
    mood_history: list[MoodLogResponse]
    ai_insight: str | None = None
