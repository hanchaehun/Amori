from pydantic import BaseModel, Field
from typing import Literal


class Starter(BaseModel):
    label: str
    message: str


class StartersResponse(BaseModel):
    starters: list[Starter] = Field(min_length=3, max_length=3)
    ai_generated: Literal[True] = True
