from pydantic import BaseModel, Field
from typing import Literal


class PersonaTrait(BaseModel):
    category: str
    summary: str
    keywords: list[str]


class PersonaResponse(BaseModel):
    user_id: str
    traits: list[PersonaTrait] = Field(min_length=8, max_length=8)
    communication_style: str
    humor_style: str
    value_keywords: list[str] = Field(min_length=3, max_length=7)
    embedding: list[float] | None = None
    ai_generated: Literal[True] = True


class PersonaBuildRequest(BaseModel):
    answers: list[dict]  # 24 question answers from Flutter
