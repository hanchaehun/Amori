from typing import Literal

from pydantic import BaseModel, Field


class ErrorResponse(BaseModel):
    error_code: str
    message: str
    request_id: str


class HealthResponse(BaseModel):
    status: str
    llm_provider: str
    database: str


class MeetRequestCreate(BaseModel):
    match_id: str
    receiver_id: str
    message: str = ""


class MeetRequestResponse(BaseModel):
    id: str
    match_id: str
    requester_id: str
    receiver_id: str
    message: str
    status: str
    expires_at: str
    created_at: str


class FeedbackCreate(BaseModel):
    match_id: str
    impression: str
    accuracy: float = Field(ge=0, le=1)
    next_step: str
    note: str | None = None


class MatchResponse(BaseModel):
    match_id: str
    user_id: str
    display_name: str | None = None
    score: float


class AppointmentSetRequest(BaseModel):
    """직접 채팅에서 합의한 약속 기록 — 약속의 주체는 사용자다 (시뮬은 약속을 잡지 않음)."""

    date: str  # YYYY-MM-DD
    time: Literal["점심", "저녁"]


class AppointmentSetResponse(BaseModel):
    match_id: str
    status: str
    appointment_slot: str  # 라벨 "6월 14일(토) 저녁"


class MatchAcceptResponse(BaseModel):
    match_id: str
    status: str  # simulated | scheduled
    # 07-04부터 의미 재정의: '수락 가능(리포트 게이트 통과)'. 시뮬은 약속을 잡지 않는다.
    appointment_ready: bool
    accepted_by: list[str]
    both_accepted: bool


class ChatMessageItem(BaseModel):
    """직접 채팅 메시지 한 건. kind="system"은 약속 취소 같은 안내문구."""

    id: str
    kind: str  # user | system
    is_me: bool = False  # system이면 항상 False
    text: str
    created_at: str


class AgentTurnItem(BaseModel):
    """에이전트 시뮬레이션 발화 — 요청자 시점의 speaker(me|them)와 text만."""

    speaker: str  # me | them
    text: str


class ChatSendRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class MatchConversationResponse(BaseModel):
    """대화방 화면 한 번에 — 에이전트 대화 + 직접 채팅 + 입력 가능 여부."""

    match_id: str
    partner_name: str | None = None
    status: str  # simulated | scheduled | met
    appointment_slot: str | None = None  # 사용자들이 직접 확정한 약속 라벨 (시뮬은 약속을 잡지 않음)
    chat_enabled: bool  # status == scheduled 일 때만 직접 채팅 가능
    # 에이전트 대화가 아직 시차 송출 중인가 — True면 다음 턴이 곧 도착한다(라이브 관전).
    # 클라이언트는 이 플래그로 타이핑 인디케이터·폴링 지속 여부를 정한다.
    agent_live: bool = False
    agent_turns: list[AgentTurnItem]
    messages: list[ChatMessageItem]


class MatchCancelResponse(BaseModel):
    match_id: str
    status: str  # 취소 후 simulated로 돌아간다
    notice: str  # 채팅방에 남은 시스템 안내문구


class MatchListItem(BaseModel):
    """연결(inbox) 화면의 대화 카드 한 장 — 시뮬레이션이 있었던 매치만."""

    match_id: str
    partner_id: str
    partner_name: str | None = None
    status: str  # simulated | scheduled | met
    score: float | None = None
    # 07-04부터 의미 재정의: '수락 가능(리포트 게이트 통과)'. 필드명은 Flutter 하위호환.
    appointment_ready: bool
    you_accepted: bool
    partner_accepted: bool
    last_message: str | None = None  # 지금까지 공개된 마지막 발화 text
    turn_count: int = 0  # 지금까지 공개된 턴 수(송출 중이면 전체보다 적다)
    updated_at: str
    # 에이전트 대화가 시차 송출 중 — True면 카드는 "에이전트 대화 중"으로 표시하고,
    # 약속·리포트·게이트 분류 결과는 송출이 끝날 때까지 숨긴다(스포일러 방지).
    agent_live: bool = False
    appointment_slot: str | None = None  # 사용자들이 직접 확정한 약속 라벨 "6월 14일(토) 저녁"
    report_score: int | None = None  # 케미 점수(리포트) — score는 벡터 매칭 점수
    failed: bool = False  # 케미 점수가 게이트 미만 — '닿지 않은 인연' 화면으로 분리
    failure_reason: str | None = None  # 리포트 warnings 첫 항목
    failed_expires_at: str | None = None  # 이 시각이 지나면 목록에서 사라진다
