"""SQLAlchemy 모델 — Postgres 단일 데이터 원천 (리팩토링 결정 3).

8개 테이블: users, personas, matches, simulation_jobs, reports,
meet_requests, feedback, llm_call_logs.

페르소나 임베딩은 1024차원 pgvector 컬럼이며 HNSW 코사인 인덱스를 사용한다.
``Base.metadata`` 의 ``before_create`` 리스너가 vector 익스텐션을 먼저 설치한다.
"""

import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    DDL,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    event,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

EMBEDDING_DIM = 1024


class Base(DeclarativeBase):
    pass


event.listen(
    Base.metadata,
    "before_create",
    DDL("CREATE EXTENSION IF NOT EXISTS vector"),
)


class User(Base):
    """Firebase Auth 사용자의 도메인 프로필. id = Firebase UID."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    email: Mapped[str | None] = mapped_column(String(255))
    display_name: Mapped[str | None] = mapped_column(String(100))
    birth_date: Mapped[datetime | None] = mapped_column(Date)
    gender: Mapped[str | None] = mapped_column(String(20))
    interest_gender: Mapped[str | None] = mapped_column(String(20))
    photo_url: Mapped[str | None] = mapped_column(Text)
    fcm_token: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class Persona(Base):
    __tablename__ = "personas"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    traits: Mapped[list] = mapped_column(JSONB)  # 8 카테고리 {category, summary, keywords}
    communication_style: Mapped[str] = mapped_column(String(200))
    humor_style: Mapped[str] = mapped_column(String(200))
    value_keywords: Mapped[list] = mapped_column(JSONB)  # 3~7개 문자열
    speech_style: Mapped[dict] = mapped_column(JSONB)  # 말투 — 에이전트 발화 충실도의 핵심
    sample_messages: Mapped[list] = mapped_column(JSONB)  # few-shot 발화 앵커 3개
    embedding = mapped_column(Vector(EMBEDDING_DIM), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    __table_args__ = (
        Index(
            "ix_personas_embedding_hnsw",
            "embedding",
            postgresql_using="hnsw",
            postgresql_with={"m": 16, "ef_construction": 64},
            postgresql_ops={"embedding": "vector_cosine_ops"},
        ),
    )


class Match(Base):
    __tablename__ = "matches"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    participant_ids: Mapped[list[str]] = mapped_column(ARRAY(String(128)))
    status: Mapped[str] = mapped_column(
        String(20), default="candidate"
    )  # candidate | simulated | scheduled | met
    score: Mapped[float | None] = mapped_column(Float)
    # 시뮬레이션 중 두 에이전트가 약속을 잡았는가(눈치 strategy="약속 수락").
    # True면 '진행 중'에서 맨 위로 + 테두리 강조, 사용자가 수락을 누를 수 있음.
    appointment_ready: Mapped[bool] = mapped_column(Boolean, default=False)
    # 만남을 수락한 사용자 uid 목록. 양쪽 다 차면 status를 'scheduled'로 올린다.
    accepted_by: Mapped[list[str]] = mapped_column(
        ARRAY(String(128)), default=list, server_default="{}"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    __table_args__ = (
        Index(
            "ix_matches_participant_ids",
            "participant_ids",
            postgresql_using="gin",
        ),
    )


class SimulationJob(Base):
    __tablename__ = "simulation_jobs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    match_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), index=True
    )
    requested_by: Mapped[str] = mapped_column(String(128), index=True)
    status: Mapped[str] = mapped_column(
        String(20), default="running"
    )  # running | completed | failed
    turns: Mapped[list | None] = mapped_column(JSONB)  # simulation_turn.schema.json[]
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    match_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), unique=True, index=True
    )
    score: Mapped[int] = mapped_column(Integer)
    findings: Mapped[list] = mapped_column(JSONB)
    warnings: Mapped[list] = mapped_column(JSONB)
    places: Mapped[list] = mapped_column(JSONB)
    starters: Mapped[list] = mapped_column(JSONB)
    tip: Mapped[str | None] = mapped_column(Text)
    ai_generated: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class MeetRequest(Base):
    __tablename__ = "meet_requests"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    match_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), index=True
    )
    requester_id: Mapped[str] = mapped_column(String(128), index=True)
    receiver_id: Mapped[str] = mapped_column(String(128), index=True)
    message: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(
        String(20), default="pending"
    )  # pending | accepted | declined | expired
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class Feedback(Base):
    """만남 후 피드백 — 매칭 알고리즘 학습 루프의 입력."""

    __tablename__ = "feedback"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    match_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[str] = mapped_column(String(128), index=True)
    impression: Mapped[str] = mapped_column(String(20))  # good | ok | bad
    accuracy: Mapped[float] = mapped_column(Float)  # 0~1, 리포트 정확도 체감
    next_step: Mapped[str] = mapped_column(String(50))
    note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class LLMCallLog(Base):
    """LLM 호출 감사 로그 — 비용 추적·AI 기본법 대응 근거 자료."""

    __tablename__ = "llm_call_logs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    endpoint: Mapped[str] = mapped_column(String(100))
    provider: Mapped[str] = mapped_column(String(50))
    request_body: Mapped[dict | None] = mapped_column(JSONB)
    response_status: Mapped[int] = mapped_column(Integer)
    response_time_ms: Mapped[int] = mapped_column(Integer)
    user_id: Mapped[str | None] = mapped_column(String(128), index=True)
    request_id: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
