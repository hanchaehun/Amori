from pydantic import BaseModel, Field
from typing import Literal


class SimulationTurn(BaseModel):
    turn_index: int = Field(ge=0)
    speaker: Literal["me", "them", "system"]
    text: str
    signal: str | None = None
    ai_generated: Literal[True] = True


class SimulationRunRequest(BaseModel):
    target_user_id: str  # the other user to simulate with
    max_turns: int = Field(default=20, ge=1, le=30)


class SimulationJobResponse(BaseModel):
    job_id: str
    match_id: str
    status: str
