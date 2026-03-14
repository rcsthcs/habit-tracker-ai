"""Schemas for challenges and weekly reports."""
from pydantic import BaseModel
from datetime import date, datetime
from app.models.challenge import ChallengeType, ChallengeStatus


class ChallengeResponse(BaseModel):
    id: int
    user_id: int
    type: ChallengeType
    status: ChallengeStatus
    title: str
    description: str
    target_habit_id: int | None
    target_count: int
    current_count: int
    reward_text: str
    start_date: date
    end_date: date
    completed_at: datetime | None
    created_at: datetime
    progress_pct: float = 0.0

    model_config = {"from_attributes": True}


class ChallengeAccept(BaseModel):
    challenge_id: int


class WeeklyReportResponse(BaseModel):
    id: int
    user_id: int
    week_start: date
    week_end: date
    total_habits: int
    completed_count: int
    completion_rate: float
    best_habit: str | None
    worst_habit: str | None
    longest_streak: int
    mood_avg: float | None
    ai_summary: str | None
    ai_tips: list[str] = []
    created_at: datetime

    model_config = {"from_attributes": True}


class StreakRecoveryResponse(BaseModel):
    habit_id: int
    habit_name: str
    lost_streak: int
    recovery_message: str
    challenge: ChallengeResponse | None = None
