from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://habits_user:habits_pass@localhost:5432/habits_db"

    # Auth
    SECRET_KEY: str = "super-secret-dev-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours

    # Google OAuth
    GOOGLE_CLIENT_ID: str = ""  # Set via env: GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com

    # LLM
    LLM_PROVIDER: str = "auto"  # auto | ollama | gemini | fallback
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3.2"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"

    # ML
    MODEL_STORE_PATH: str = "data/models"
    MIN_LOGS_FOR_ML: int = 30  # Minimum habit logs before ML kicks in
    MIN_USERS_FOR_COLLAB: int = 10  # Minimum users for collaborative filtering

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
