from pydantic import BaseModel, Field
from typing import Literal


class PersonaTrait(BaseModel):
    category: str
    summary: str
    keywords: list[str]


class SpeechStyle(BaseModel):
    """말투. 에이전트 발화 충실도의 핵심.

    주관식 [말투 샘플](9-x 문항)이 있으면 LLM이 샘플에서 *추출*하고,
    없으면 객관식 성향에서 추론한다. 샘플에서 못 뽑는 항목은 기본값
    (중간/빈 문자열)으로 둔다 — 과잉 추측보다 무난한 기본이 낫다.
    """

    formality: Literal["반말", "존댓말", "혼용"]
    emoji_usage: Literal["거의 안 씀", "가끔", "자주"]
    laugh_style: str  # 'ㅋㅋ' | 'ㅎㅎ' | '안 씀' 등
    sentence_length: Literal["짧고 간결", "보통", "길게 풀어 씀"]
    tone_keywords: list[str] = Field(min_length=2, max_length=4)
    verbal_habits: str = ""  # 감탄사·말버릇 (헉/헐/아 맞다 등)
    punctuation_habits: str = ""  # 부호·감정 표지 습관 (ㅠㅠ/!!/…/~ 등)
    reaction_style: Literal["공감형", "논리형", "중간"] = "중간"


class PersonaResponse(BaseModel):
    user_id: str
    traits: list[PersonaTrait] = Field(min_length=8, max_length=8)
    communication_style: str
    humor_style: str
    value_keywords: list[str] = Field(min_length=3, max_length=7)
    speech_style: SpeechStyle
    sample_messages: list[str] = Field(min_length=1, max_length=3)
    embedding: list[float] | None = None
    ai_generated: Literal[True] = True
    answer_count: int | None = None
    answered_codes: list[str] = Field(default_factory=list)
    persona_revision: int = 1
    persona_confidence: Literal["low", "medium", "high"] = "low"
    last_answered_on: str | None = None


class PersonaBuildRequest(BaseModel):
    # Initial persona setup answers from Flutter. The first-run UX sends 5 answers;
    # legacy/dev flows may still send more.
    answers: list[dict]


class PersonaUpdateRequest(BaseModel):
    # One daily answer used to update the existing persona snapshot.
    answer: dict


class PersonaDailyStatusResponse(BaseModel):
    completed_today: bool
    scenario_code: str | None = None
    answer_count: int | None = None
    answered_codes: list[str] = Field(default_factory=list)
    persona_revision: int = 1
