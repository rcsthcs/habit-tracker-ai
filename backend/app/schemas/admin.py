from pydantic import BaseModel
from datetime import datetime


class AdminUserResponse(BaseModel):
    id: int
    username: str
    email: str
    timezone: str
    is_active: bool
    is_admin: bool
    created_at: datetime
    habits_count: int = 0

    model_config = {"from_attributes": True}


class AdminHabitResponse(BaseModel):
    id: int
    user_id: int
    username: str
    name: str
    description: str
    category: str
    frequency: str
    cooldown_days: int = 1
    target_time: str | None = None
    reminder_time: str | None = None
    is_active: bool
    created_at: datetime
    logs_count: int = 0
    completion_rate: float = 0.0

    model_config = {"from_attributes": True}


class PlatformAnalyticsResponse(BaseModel):
    total_users: int
    active_users: int
    total_habits: int
    active_habits: int
    total_logs: int
    completion_rate: float
    new_users_7d: int
    new_habits_7d: int
    top_categories: list[dict]  # [{category, count}]


class AdminChatMessage(BaseModel):
    id: int
    user_id: int
    username: str
    role: str
    content: str
    timestamp: datetime

    model_config = {"from_attributes": True}


class PaginatedResponse(BaseModel):
    items: list
    total: int
    skip: int
    limit: int
