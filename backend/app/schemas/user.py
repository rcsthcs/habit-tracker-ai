from pydantic import BaseModel, EmailStr
from datetime import datetime


# --- Auth ---
class UserCreate(BaseModel):
    username: str
    email: str
    password: str


class UserLogin(BaseModel):
    username: str
    password: str


class GoogleAuthRequest(BaseModel):
    """Google OAuth: frontend sends the id_token from Google Sign-In."""
    id_token: str


class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    avatar_url: str | None = None
    timezone: str
    is_active: bool
    is_admin: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: int | None = None
