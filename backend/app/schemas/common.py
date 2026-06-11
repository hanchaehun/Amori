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


class MatchAcceptResponse(BaseModel):
    match_id: str
    status: str  # simulated | scheduled
    appointment_ready: bool
    accepted_by: list[str]
    both_accepted: bool


class MatchListItem(BaseModel):
    """연결(inbox) 화면의 대화 카드 한 장 — 시뮬레이션이 있었던 매치만."""

    match_id: str
    partner_id: str
    partner_name: str | None = None
    status: str  # simulated | scheduled | met
    score: float | None = None
    appointment_ready: bool
    you_accepted: bool
    partner_accepted: bool
    last_message: str | None = None  # 최신 시뮬레이션의 마지막 발화 text
    turn_count: int = 0
    updated_at: str
