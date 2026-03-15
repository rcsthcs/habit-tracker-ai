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
    ai_insight: str | None = None


class RecommendationResponse(BaseModel):
    recommendations: list[dict]  # [{type, title, description, reason}]
    tips: list[str]
    motivation_message: str


class CategoryStat(BaseModel):
    category: str
    count: int
    completion_rate: float


class HourStat(BaseModel):
    hour: int
    count: int


class DetailedAnalyticsResponse(BaseModel):
    """Расширенная аналитика с heatmap, категориями, часами и трендами."""
    # Месячный heatmap: {date_str: bool}
    heatmap: dict[str, bool | None]
    # Статистика по категориям
    category_stats: list[CategoryStat]
    # Распределение по часам
    hourly_distribution: list[HourStat]
    # Тренд за 90 дней (% выполнения по неделям)
    trend_90d: list[float]
    # Общая статистика
    total_completed: int
    total_logged: int
    days_active: int


class NotificationResponse(BaseModel):
    id: int
    type: str
    title: str
    body: str
    habit_id: int | None = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}



