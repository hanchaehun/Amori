"""문항 → 심리 축 매핑 (결정적, LLM 무관).

설계 근거: docs/persona_science_rationale.md (관점 분리 원칙, 애착 매핑).
refatodo P0-F(F-1) 구현 — P0-B에서 애착·conversation_policy 매핑이 추가된다.

MEASURES — 문항이 무엇을 재는가:
- "behavior": 나의 행동·취향·가치관 서술 (trait evidence 허용)
- "preference": 상대·관계에서 내가 원하는 것 (trait 근거 금지 —
  리포트 반응성·정답지 축으로만. preference 답변으로 만든 trait은 추측이다.)

주관식(9-x)은 실발화라 behavior. 분류는 v1 판정 — 문항 텍스트가 바뀌면 재검토
(문항 텍스트 자체는 팀 결정 영역).
"""

MEASURES: dict[str, str] = {
    # 온보딩 R-x
    "R-1": "behavior",  # 내 관계 목적
    "R-2": "preference",  # 원하는 연락 템포 (애착-불안 신호 겸용, P0-B)
    "R-3": "behavior",  # 서운함에 대한 내 대처
    "R-4": "preference",  # 받고 싶은 위로 → 정답지 축
    "R-5": "behavior",  # 내 가치관 우선순위
    # 1. 연락 / 대화 템포
    "1-1": "preference",
    "1-2": "preference",
    "1-3": "behavior",  # 상대 요구에 내가 어떻게 반응하나
    # 2. 유머 — 전부 상대 유머 수용도. 내 유머는 주관식·10-9 행동 표본에서만.
    "2-1": "preference",
    "2-2": "preference",
    "2-3": "preference",
    # 3. 갈등 / 감정 표현
    "3-1": "behavior",
    "3-2": "preference",  # 사과에서 내가 필요로 하는 것
    "3-3": "behavior",
    # 4. 데이트 취향 — 내 취향 서술
    "4-1": "behavior",
    "4-2": "behavior",
    "4-3": "behavior",
    # 5. 돈 / 시간 / 약속
    "5-1": "behavior",  # 내 계산 행동
    "5-2": "preference",  # 지각 수용도
    "5-3": "behavior",  # 기념일에 대한 내 태도
    # 6. 관계 속도 / 호감 표현
    "6-1": "preference",
    "6-2": "preference",  # 애정표현 수신 선호
    "6-3": "behavior",  # 관계 정의를 내가 어떻게 다루나
    # 7. 경계선 / 프라이버시
    "7-1": "preference",
    "7-2": "behavior",  # 내 공개 성향
    "7-3": "behavior",  # 내 사생활 경계
    # 8. 위로 / 안정감 / 애착
    "8-1": "preference",
    "8-2": "behavior",  # 내 회복 방식
    "8-3": "behavior",  # 관계 불안 시 내 대처 (애착 축 핵심 문항)
    # 9. 말투 샘플 (주관식 실발화)
    "9-1": "behavior",
    "9-2": "behavior",
    "9-3": "behavior",
}


def measures(code: str) -> str:
    """문항 코드의 측정 관점. 미등록 코드(신규 10-x 등)는 보수적으로 preference."""
    return MEASURES.get(str(code or "").strip(), "preference")


# ═══════════════════════════════════════════════════════════════════════════
# P0-B — 결정적 심리 매핑 (LLM 무관, 근거: rationale §5·6)
#
# 답변의 (code, letter) 신호를 psych_profile / conversation_policy로 변환한다.
# raw 답변 전문은 저장하지 않는 정책이므로, 축 계산에 쓰는 신호만
# psych_profile["signals"] = {code: letter}로 누적하고 매번 재계산한다(멱등).
# ═══════════════════════════════════════════════════════════════════════════

# 애착-불안 신호 — "관계 확인·재확인 추구" 강도 (0=무신호, 1=약, 2=강)
_ANXIETY_SIGNALS: dict[tuple[str, str], int] = {
    ("R-2", "B"): 1,  # 짧게라도 자주 연락하고 싶다
    ("8-3", "C"): 2,  # 마음이 달라졌는지 확인하고 싶다
    ("8-3", "D"): 2,  # 혼자 생각이 많아진다
    ("8-3", "B"): 0,  # 가볍게 물어본다 — 안정 신호
    ("1-1", "C"): 2,  # 관심이 낮아 보여 신경 쓰인다
    ("1-1", "B"): 1,
    ("1-2", "C"): 2,  # 관심 없는 것처럼 느껴진다
    ("1-2", "B"): 1,
    ("6-3", "D"): 1,  # 불명확한 관계가 오래가면 힘들다
}

# 애착-회피 신호 — "감정 표현·접근의 회피" 강도
_AVOIDANCE_SIGNALS: dict[tuple[str, str], int] = {
    ("R-3", "C"): 1,  # 상대가 먼저 알아차리길 기다린다
    ("R-3", "D"): 2,  # 혼자 정리하고 넘어간다
    ("3-1", "C"): 1,
    ("3-1", "D"): 2,
    ("3-3", "C"): 1,  # 감정 정리될 때까지 시간
    ("3-3", "D"): 1,  # 압박하면 더 말하기 어려움
    ("8-2", "C"): 1,  # 혼자 회복하는 시간이 꼭 필요
    ("8-2", "D"): 1,
}

# 갈등 대처 모드 — R-3(온보딩)이 1순위, 3-x가 보정
_CONFLICT_MODE: dict[tuple[str, str], str] = {
    ("R-3", "A"): "즉시형",
    ("R-3", "B"): "지연-정리형",
    ("R-3", "C"): "회피형",
    ("R-3", "D"): "회피형",
    ("3-1", "A"): "즉시형",
    ("3-1", "B"): "지연-정리형",
    ("3-1", "C"): "회피형",
    ("3-1", "D"): "회피형",
    ("3-3", "A"): "즉시형",
    ("3-3", "B"): "지연-정리형",
    ("3-3", "C"): "지연-정리형",
    ("3-3", "D"): "회피형",
}

# 자기개방 속도 (사회침투 이론) — behavior 문항만
_DISCLOSURE_PACE: dict[tuple[str, str], str] = {
    ("R-1", "A"): "보통",
    ("R-1", "B"): "느림",  # 천천히 확인하고 싶다
    ("R-1", "C"): "보통",
    ("R-1", "D"): "보통",
    ("R-1", "E"): "느림",
    ("6-3", "A"): "느림",  # 흐름을 본다
    ("6-3", "C"): "빠름",  # 관계를 확인하고 싶다
    ("6-3", "D"): "빠름",
}

# 심리 축 계산에 쓰는 문항 — 이 코드들의 답변 letter만 signals로 누적한다.
PSYCH_SIGNAL_CODES: frozenset[str] = frozenset(
    {code for code, _ in _ANXIETY_SIGNALS}
    | {code for code, _ in _AVOIDANCE_SIGNALS}
    | {code for code, _ in _CONFLICT_MODE}
    | {code for code, _ in _DISCLOSURE_PACE}
)

# MBTI 4축 → Big Five 약한 prior (McCrae & Costa 1989 상관 — rationale §9).
# 유형 궁합·매칭엔 절대 쓰지 않는다. 축당 ±0.15, confidence 0.2 고정.
_MBTI_TYPES = {
    f"{ei}{sn}{tf}{jp}"
    for ei in "EI"
    for sn in "SN"
    for tf in "TF"
    for jp in "JP"
}


def valid_mbti(value: str | None) -> str | None:
    """대문자 정규화 후 16유형이면 반환, 아니면 None."""
    if not value:
        return None
    upper = value.strip().upper()
    return upper if upper in _MBTI_TYPES else None


def mbti_big_five_prior(mbti: str | None) -> dict | None:
    """MBTI → Big Five 초기값. 실답변 증거가 쌓이면 합성에서 자연 희석된다."""
    mbti = valid_mbti(mbti)
    if not mbti:
        return None
    delta = 0.15
    return {
        "E": 0.5 + (delta if mbti[0] == "E" else -delta),
        "O": 0.5 + (delta if mbti[1] == "N" else -delta),
        "A": 0.5 + (delta if mbti[2] == "F" else -delta),
        "C": 0.5 + (delta if mbti[3] == "J" else -delta),
        "N": 0.5,  # MBTI에는 신경성 축이 없다
        "evidence": ["mbti_prior"],
        "confidence": 0.2,
    }


def collect_signals(existing: dict | None, answers: list[dict] | None) -> dict:
    """답변 목록에서 심리 신호(code→letter)를 기존 신호에 병합한다 (최신 답변 우선)."""
    signals = dict(existing or {})
    for answer in answers or []:
        code = str(answer.get("code") or "").strip()
        letter = str(
            answer.get("answer_letter") or answer.get("answerLetter") or ""
        ).strip()
        if code in PSYCH_SIGNAL_CODES and letter and letter not in ("주관식", "정답지"):
            signals[code] = letter
    return signals


def _axis_score(signals: dict, table: dict[tuple[str, str], int]) -> float | None:
    """신호 강도 합 / 최대 가능치 → 0~1. 해당 축 문항에 답이 없으면 None."""
    answered = [code for code in {c for c, _ in table} if code in signals]
    if not answered:
        return None
    got = sum(table.get((code, signals[code]), 0) for code in answered)
    top = sum(max(v for (c, _), v in table.items() if c == code) for code in answered)
    return round(got / top, 2) if top else 0.0


def _attachment_hint(anxiety: float | None, avoidance: float | None) -> str:
    """hint 어투만 — 단정 진단 금지 (rationale §5·11)."""
    if anxiety is None and avoidance is None:
        return ""
    anx = anxiety or 0.0
    avo = avoidance or 0.0
    if anx >= 0.5 and avo >= 0.5:
        return "확인도 필요하고 혼자만의 시간도 필요한 편 같아요"
    if anx >= 0.5:
        return "상대의 마음을 자주 확인하고 싶어지는 편 같아요"
    if avo >= 0.5:
        return "감정을 혼자 정리하는 시간이 필요한 편 같아요"
    return "안정형에 가까워 보여요"


def compute_psych_profile(
    signals: dict,
    mbti: str | None,
    llm_big_five: dict | None,
    previous: dict | None = None,
) -> dict:
    """psych_profile 계산 — 애착은 결정적 매핑, big_five는 LLM 추정+MBTI prior 합성."""
    anxiety = _axis_score(signals, _ANXIETY_SIGNALS)
    avoidance = _axis_score(signals, _AVOIDANCE_SIGNALS)

    prior = mbti_big_five_prior(mbti)
    big_five = None
    if llm_big_five and prior:
        # 증거 수 가중 합성 — 실답변 근거가 쌓일수록 prior 영향이 줄어든다.
        evidence = [e for e in (llm_big_five.get("evidence") or []) if e]
        weight = min(0.9, 0.3 + 0.15 * len(evidence))  # LLM 추정 쪽 가중
        big_five = {
            axis: round(
                weight * float(llm_big_five.get(axis, 0.5))
                + (1 - weight) * float(prior[axis]),
                2,
            )
            for axis in "EACNO"
        }
        big_five["evidence"] = evidence + ["mbti_prior"]
        big_five["confidence"] = round(min(0.7, 0.2 + 0.1 * len(evidence)), 2)
    elif llm_big_five:
        big_five = dict(llm_big_five)
        big_five.setdefault("confidence", 0.3)
    elif prior:
        big_five = prior

    return {
        "signals": signals,
        "attachment_anxiety": anxiety,
        "attachment_avoidance": avoidance,
        "attachment_hint": _attachment_hint(anxiety, avoidance),
        "big_five": big_five,
        # 사용자 공개·숨김권 (rationale §11) — PATCH psych_edits로 토글.
        "user_visible": (previous or {}).get("user_visible", True),
    }


def _mode_from(signals: dict, table: dict[tuple[str, str], str], priority: list[str]) -> str | None:
    for code in priority:
        letter = signals.get(code)
        if letter and (code, letter) in table:
            return table[(code, letter)]
    return None


def compute_conversation_policy(signals: dict, voice_stats: dict | None) -> dict:
    """conversation_policy — 2층 화용 행동. 전부 코드 산출 (LLM 추측 금지)."""
    stats = voice_stats or {}
    laugh = (stats.get("laugh") or {}).get("per_msg", 0.0) or 0.0
    emoji = (stats.get("emoji") or {}).get("per_msg", 0.0) or 0.0
    punct = sum((stats.get("punct_per_msg") or {}).values())
    interjection_bonus = 0.5 if stats.get("interjections") else 0.0
    amplitude_score = laugh + emoji + min(1.0, punct) + interjection_bonus
    if not stats.get("sample_count"):
        amplitude = None
    elif amplitude_score >= 1.2:
        amplitude = "큼"
    elif amplitude_score >= 0.5:
        amplitude = "중간"
    else:
        amplitude = "담백"

    anxiety = _axis_score(signals, _ANXIETY_SIGNALS)
    reassurance = None
    if anxiety is not None:
        reassurance = "높음" if anxiety >= 0.5 else ("중간" if anxiety >= 0.25 else "낮음")

    return {
        "question_ratio": stats.get("question_ratio"),
        "reaction_amplitude": amplitude,
        "conflict_mode": _mode_from(signals, _CONFLICT_MODE, ["3-3", "3-1", "R-3"]),
        "reassurance_seeking": reassurance,
        "self_disclosure_pace": _mode_from(signals, _DISCLOSURE_PACE, ["6-3", "R-1"]),
    }
