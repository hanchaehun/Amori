from pydantic import BaseModel, Field
from typing import Literal


class Finding(BaseModel):
    emoji: str
    title: str
    sub: str


class Warning(BaseModel):
    title: str
    body: str


class Place(BaseModel):
    emoji: str
    title: str
    sub: str


class ReportResponse(BaseModel):
    match_id: str
    score: int = Field(ge=0, le=100)
    findings: list[Finding] = Field(min_length=2, max_length=5)
    warnings: list[Warning]
    places: list[Place] = Field(min_length=2, max_length=4)
    starters: list[str] = Field(min_length=2, max_length=5)
    tip: str | None = None
    ai_generated: Literal[True] = True
