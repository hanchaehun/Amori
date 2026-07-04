"""LLM 구조화 출력 스키마 (채팅 provider 공용).

Gemini는 responseSchema로 이 형태를 강제하지만, DevDive(modoo)는 함수호출/스키마
강제를 지원하지 않는다. 그래서 modoo는 프롬프트로 JSON을 유도한 뒤 이 Pydantic
모델로 파싱·검증한다. 두 경로 모두 shared/schemas/*.json 계약을 만족해야 하므로
검증 스키마를 한 곳에 둔다.

주의: gemini.py는 verify/smoke 스크립트가 내부 심볼(_ConvTurn 등)을 직접
import하므로 자체 정의를 유지한다 — 필드/제약은 이 모듈과 동일하게 맞춘다.
"""

from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.persona import PersonaTrait, SpeechStyle
from app.schemas.report import Finding, Place, Warning


class PersonaOutput(BaseModel):
    traits: list[PersonaTrait] = Field(min_length=8, max_length=8)
    communication_style: str
    humor_style: str
    value_keywords: list[str] = Field(min_length=3, max_length=7)
    speech_style: SpeechStyle
    sample_messages: list[str] = Field(min_length=1, max_length=3)


class ConvTurn(BaseModel):
    # 원샷 대화의 한 메시지. partner_read·strategy는 내부 분석용(리포트 신호),
    # text만 사용자에게 노출된다. 약속 조율은 시뮬에서 하지 않는다(2026-07-04 제품 결정)
    # — 만남은 리포트를 본 두 사용자가 수락한 뒤 직접 채팅에서 잡는다.
    speaker: Literal["me", "them"]
    text: str
    strategy: Literal["알아가기", "마무리"]
    partner_read: Literal["긍정적", "중립", "미온적"] = "긍정적"


class ConversationOutput(BaseModel):
    turns: list[ConvTurn] = Field(min_length=6, max_length=24)


class ReportOutput(BaseModel):
    score: int = Field(ge=0, le=100)
    findings: list[Finding] = Field(min_length=2, max_length=5)
    warnings: list[Warning] = Field(min_length=1, max_length=2)
    places: list[Place] = Field(min_length=2, max_length=4)
    starters: list[str] = Field(min_length=2, max_length=5)
    tip: str = ""
