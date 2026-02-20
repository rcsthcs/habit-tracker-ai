from pydantic import BaseModel
from datetime import datetime


class ChatMessageCreate(BaseModel):
    content: str


class ChatMessageResponse(BaseModel):
    id: int
    role: str
    content: str
    timestamp: datetime

    model_config = {"from_attributes": True}


class AnalyticsResponse(BaseModel):
    total_habits: int
    active_habits: int
    today_completed: int
    today_total: int
    overall_completion_rate: float
    longest_streak: int
    current_best_streak: int
    most_consistent_habit: str | None
    most_struggled_habit: str | None
    optimal_time: str | None
    weekly_completion: list[float]  # Last 7 days completion rates


class RecommendationResponse(BaseModel):
    recommendations: list[dict]  # [{type, title, description, reason}]
    tips: list[str]
    motivation_message: str

