"""SQLAlchemy 모델 — Postgres 단일 데이터 원천 (리팩토링 결정 3).

8개 테이블: users, personas, matches, simulation_jobs, reports,
meet_requests, feedback, llm_call_logs.

페르소나 임베딩은 1024차원 pgvector 컬럼이며 HNSW 코사인 인덱스를 사용한다.
``Base.metadata`` 의 ``before_create`` 리스너가 vector 익스텐션을 먼저 설치한다.
"""

import uuid
from datetime import date, datetime

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
    # 소개팅 가능 일정 [{"date": "YYYY-MM-DD", "time": "점심"|"저녁"}, ...]
    # 에이전트는 시뮬레이션에서 이 시간 중에서만 약속을 제안·수락한다.
    available_slots: Mapped[list] = mapped_column(
        JSONB, default=list, server_default="[]"
    )
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
    sample_messages: Mapped[list] = mapped_column(JSONB)  # few-shot 발화 앵커 1~3개
    # voice v2 — 코드가 측정한 말투 (LLM 추측 금지). voice_features.extract_voice_stats 산출물.
    voice_stats: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    # 실측 발화 뱅크 {text, register, source(user_written|kakao|llm_seed), collected_at}
    sample_bank: Mapped[list] = mapped_column(JSONB, default=list, server_default="[]")
    voice_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    # 정답지 — "이 상황에서 나는 어떤 답장을 받고 싶은가" {code, situation, desired_reply, collected_at}.
    # 평가 전용 축: 리포트 채점에만 쓰고, 시뮬 프롬프트·매칭 하드필터엔 절대 넣지 않는다
    # (명시적 선호는 실제 끌림을 잘 예측하지 못한다 — Eastwick&Finkel 2008, Joel 2017).
    response_preferences: Mapped[list] = mapped_column(JSONB, default=list, server_default="[]")
    embedding = mapped_column(Vector(EMBEDDING_DIM), nullable=True)
    # 점진형 페르소나 보정 상태. raw answer 전문은 저장하지 않고 문항 코드만 보관한다.
    answer_count: Mapped[int | None] = mapped_column(Integer)
    answered_codes: Mapped[list] = mapped_column(JSONB, default=list, server_default="[]")
    persona_revision: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    persona_confidence: Mapped[str] = mapped_column(String(20), default="low", server_default="low")
    last_answered_on: Mapped[date | None] = mapped_column(Date)
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
    # [휴면 컬럼] 시뮬 약속 폐지(2026-07-04)로 아무도 쓰지 않는다 — API의
    # appointment_ready는 '리포트 게이트 통과'를 매번 계산해 내려보낸다(routers/matches.py).
    # 컬럼 제거는 후속 마이그레이션에서.
    appointment_ready: Mapped[bool] = mapped_column(Boolean, default=False)
    # 사용자들이 직접 채팅에서 확정한 약속 {"date": "YYYY-MM-DD", "time": "점심"|"저녁"}
    # (POST /matches/{id}/appointment). 시뮬은 약속을 잡지 않는다 — 주체는 사용자.
    # 일정 시트 잠금(booked_slots)·중복 약속 차단의 근거.
    appointment_slot: Mapped[dict | None] = mapped_column(JSONB)
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


class ChatMessage(Base):
    """만남이 확정된(scheduled) 두 사용자의 직접 대화 + 시스템 안내.

    에이전트 시뮬레이션 턴(SimulationJob.turns)과 별개로, 사용자가 직접 친
    메시지를 담는다. kind="system"은 약속 취소 같은 상태 변화 안내 — 채팅방
    가운데에 안내문구로 표시되고 sender_id가 없다.
    """

    __tablename__ = "chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    match_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), index=True
    )
    sender_id: Mapped[str | None] = mapped_column(String(128))  # system이면 None
    kind: Mapped[str] = mapped_column(String(20), default="user")  # user | system
    text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        Index("ix_chat_messages_match_created", "match_id", "created_at"),
    )


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
    """만남 후 피드백 — 매칭 품질 개선 신호."""

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
