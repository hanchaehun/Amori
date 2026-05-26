from pydantic_settings import BaseSettings
from pydantic import ConfigDict


class Settings(BaseSettings):
    # LLM
    llm_provider: str = "mock"  # mock | hf | midm_local
    llm_base_url: str = "http://localhost:8001"
    hf_api_token: str = ""

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

    model_config = ConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
