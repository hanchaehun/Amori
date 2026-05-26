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
