import re
from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime


# --- Auth ---
class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 3 or len(v) > 30:
            raise ValueError("Имя пользователя должно содержать от 3 до 30 символов")
        if not re.match(r"^[a-zA-Z0-9_]+$", v):
            raise ValueError("Имя пользователя может содержать только буквы, цифры и _")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Пароль должен содержать минимум 8 символов")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Пароль должен содержать хотя бы одну заглавную букву")
        if not re.search(r"[a-z]", v):
            raise ValueError("Пароль должен содержать хотя бы одну строчную букву")
        if not re.search(r"\d", v):
            raise ValueError("Пароль должен содержать хотя бы одну цифру")
        return v


class UserUpdate(BaseModel):
    username: str | None = None
    email: str | None = None
    timezone: str | None = None


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
    is_email_verified: bool
    is_admin: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: int | None = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Пароль должен содержать минимум 8 символов")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Пароль должен содержать хотя бы одну заглавную букву")
        if not re.search(r"[a-z]", v):
            raise ValueError("Пароль должен содержать хотя бы одну строчную букву")
        if not re.search(r"\d", v):
            raise ValueError("Пароль должен содержать хотя бы одну цифру")
        return v


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class DeviceTokenRegisterRequest(BaseModel):
    token: str
    platform: str = "unknown"

