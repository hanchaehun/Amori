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


class LaughStats(BaseModel):
    token: str = ""  # 'ㅋ' | 'ㅎ' | ''(웃음 안 씀)
    avg_run: float = 0.0  # 평균 연속 길이 (ㅋㅋㅋ=3)
    per_msg: float = 0.0  # 웃음이 있는 메시지 비율


class EmojiStats(BaseModel):
    per_msg: float = 0.0
    inventory: list[str] = Field(default_factory=list)  # 실제 쓰는 이모지만


class LenChars(BaseModel):
    p25: int = 0
    p50: int = 0
    p75: int = 0


class VoiceStats(BaseModel):
    """코드가 계산한 말투 측정값 (voice_features.extract_voice_stats).

    LLM 추측 금지 — speech_style(LLM 추론 요약)과 달리 이 값은 실측 발화에서만
    나온다. 시뮬 프롬프트의 수치 지시(_speech_block v2)가 이걸 소비한다.
    """

    sample_count: int  # 실측 발화 수 = 신뢰도의 근거
    formality_ratio: dict[str, float]  # {"존댓말": .., "반말": ..} — 합 0이면 근거 없음
    len_chars: LenChars
    laugh: LaughStats
    emoji: EmojiStats
    punct_per_msg: dict[str, float] = Field(default_factory=dict)  # ~/!!/…/ㅠㅠ 등
    question_ratio: float = 0.0
    interjections: list[str] = Field(default_factory=list)


class SampleBankItem(BaseModel):
    """실측 발화 한 건 — 출처(provenance)를 기록해 낮은 등급을 자동 대체한다."""

    text: str
    # 'register'는 ABCMeta.register를 가려 pydantic이 부팅 시 경고 1회를 내지만
    # 동작엔 문제없다(검증 완료). 필드명은 shared/schemas 계약(설계 §4)과 동일하게 유지.
    register: str = ""  # v1: 문항 코드(9-1 등). 레지스터 라벨 매핑은 P1(10-x 뱅크)에서
    source: Literal["user_written", "kakao", "llm_seed"] = "user_written"
    collected_at: str = ""  # ISO 날짜


class ResponsePreference(BaseModel):
    """정답지 한 건 — "이 상황에서 나는 어떤 답장을 받고 싶은가".

    평가 전용 축: 리포트 채점(반응성 매칭)에만 쓴다. 시뮬 프롬프트에 넣으면
    상대 에이전트가 정답지에 맞춰 발화해 정직한 시뮬이 무너지고, 매칭 하드필터로
    쓰면 문헌 근거가 없다(명시적 선호 ≠ 실제 끌림 — Eastwick&Finkel, Joel 2017).
    """

    code: str = ""  # 유발 문항 코드
    situation: str = ""  # 상황 설명 (문항 텍스트)
    desired_reply: str  # 받고 싶은 답장 (사용자가 직접 작성 — 말투 표본 겸용)
    collected_at: str = ""


class PersonaResponse(BaseModel):
    user_id: str
    traits: list[PersonaTrait] = Field(min_length=8, max_length=8)
    communication_style: str
    humor_style: str
    value_keywords: list[str] = Field(min_length=3, max_length=7)
    speech_style: SpeechStyle
    sample_messages: list[str] = Field(min_length=1, max_length=3)
    voice_stats: VoiceStats | None = None
    sample_bank: list[SampleBankItem] = Field(default_factory=list)
    voice_confidence: float | None = None
    response_preferences: list[ResponsePreference] = Field(default_factory=list)
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
