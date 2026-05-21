from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://bonuscard_user:bonuscard_pass@db:5432/bonuscard_db"
    REDIS_URL: str = "redis://redis:6379"
    SECRET_KEY: str = "your-secret-key-here-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    POS_API_KEY: str = "pos-api-key-12345"
    BONUS_CACHE_TTL: int = 300

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()