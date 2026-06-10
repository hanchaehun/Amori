from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # LLM — 외부 API 직접 호출 (별도 LLM 서비스 없음)
    llm_provider: str = "mock"  # mock | gemini
    gemini_api_key: str = ""
    gemini_chat_model: str = "gemini-2.5-flash"
    gemini_embedding_model: str = "gemini-embedding-001"
    embedding_dim: int = 1024  # shared/schemas 계약 — 변경 시 pgvector 인덱스도 재생성

    # Database
    database_url: str = "postgresql+asyncpg://amori:amori_dev@localhost:5432/amori"

    # Firebase
    firebase_project_id: str = "amori-260523"

    # Rate limits
    daily_simulation_limit: int = 5
    daily_meet_request_limit: int = 1

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True

    model_config = ConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
