from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # LLM — 외부 API 직접 호출 (별도 LLM 서비스 없음)
    llm_provider: str = "mock"  # mock | gemini | modoo
    gemini_api_key: str = ""
    gemini_chat_model: str = "gemini-2.5-flash"
    gemini_embedding_model: str = "gemini-embedding-001"
    embedding_dim: int = 1024  # shared/schemas 계약 — 변경 시 pgvector 인덱스도 재생성

    # DevDive(모두의창업) — 채팅(페르소나·시뮬·리포트·스타터) 담당. 임베딩은 Gemini 유지.
    # 따라서 LLM_PROVIDER=modoo 여도 GEMINI_API_KEY(임베딩용)가 필요하다.
    modoo_api_key: str = ""
    modoo_base_url: str = "https://modoo.devdive.me"
    modoo_chat_model: str = "modoo-text-pro"

    # Database
    database_url: str = "postgresql+asyncpg://amori:amori_dev@localhost:5432/amori"

    # Firebase
    firebase_project_id: str = "amori-260523"

    # Rate limits
    daily_simulation_limit: int = 3
    daily_meet_request_limit: int = 1

    # 에이전트 자동 소개팅 — 하루 24시간 중 랜덤 N회, 서버가 알아서 돌린다.
    # (제품 설계: 질문지 직후 즉시 시뮬 X. 클라이언트는 페르소나 생성까지만.)
    # 주의: 켜면 페르소나 보유 유저 전원이 대상 — 실 Gemini 무료 쿼터(20 RPD)로는
    # 유저 1명 × 1회(~10콜)도 빠듯하니 mock이 아니면 신중히 켤 것.
    auto_sim_enabled: bool = False
    auto_sim_per_day: int = 3

    # 시차 송출(라이브 관전) — auto_sim이 한 번에 생성한 대화를 즉시 전부 공개하지
    # 않고, 글자 수에 비례한 간격으로 천천히 흘린다. 조회 시점에 visible_at<=now 인
    # 턴만 노출하고, 송출이 끝나기 전까지는 약속·리포트·게이트 분류를 가린다.
    # (제품 설계: "공장 컨베이어벨트처럼" 에이전트가 실시간으로 대화하는 느낌.)
    # 데모 때는 .env로 간격을 줄여 빠르게 돌려볼 수 있다. 끄면 즉시 전부 공개.
    reveal_enabled: bool = True
    reveal_first_delay_seconds: float = 8.0  # 첫 턴까지 도입 딜레이
    reveal_char_seconds: float = 1.6  # 글자당 추가 대기(읽기+타이핑 체감)
    reveal_min_gap_seconds: float = 18.0  # 턴 간 최소 간격(지터 폭도 겸함)
    reveal_max_gap_seconds: float = 180.0  # 턴 간 최대 간격(가끔 긴 공백)

    # 케미 리포트 게이트 — 미만이면 '진행 실패(닿지 않은 인연)'로 분류,
    # TTL이 지나면 GET /matches 목록에서 자연 소멸한다 (행은 보존)
    report_pass_score: int = 75
    failed_match_ttl_days: int = 3

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True

    model_config = ConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
