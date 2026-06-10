from pydantic import BaseModel, Field
from typing import Literal


class PersonaTrait(BaseModel):
    category: str
    summary: str
    keywords: list[str]


class SpeechStyle(BaseModel):
    """말투. 에이전트 발화 충실도의 핵심.

    객관식 24답변에서는 말투가 드러나지 않아 현재는 LLM이 추론한다.
    자유 텍스트 입력(자기소개·평소 메시지)이 추가되면 추론 대신 그 텍스트에서
    직접 추출하도록 build_persona를 바꾸면 된다 — 이 스키마는 그대로 (voice-ready).
    """

    formality: Literal["반말", "존댓말", "혼용"]
    emoji_usage: Literal["거의 안 씀", "가끔", "자주"]
    laugh_style: str  # 'ㅋㅋ' | 'ㅎㅎ' | '안 씀' 등
    sentence_length: Literal["짧고 간결", "보통", "길게 풀어 씀"]
    tone_keywords: list[str] = Field(min_length=2, max_length=4)
    verbal_habits: str = ""


class PersonaResponse(BaseModel):
    user_id: str
    traits: list[PersonaTrait] = Field(min_length=8, max_length=8)
    communication_style: str
    humor_style: str
    value_keywords: list[str] = Field(min_length=3, max_length=7)
    speech_style: SpeechStyle
    sample_messages: list[str] = Field(min_length=3, max_length=3)
    embedding: list[float] | None = None
    ai_generated: Literal[True] = True


class PersonaBuildRequest(BaseModel):
    answers: list[dict]  # 24 question answers from Flutter
