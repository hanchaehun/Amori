import time
import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.config import settings
from app.dependencies import get_db, get_llm_provider
from app.llm.base import LLMProvider
from app.models.database import Persona
from app.routers.users import ensure_user
from app.schemas.persona import (
    PersonaBuildRequest,
    PersonaDailyStatusResponse,
    PersonaPatchRequest,
    PersonaPreviewResponse,
    PersonaResponse,
    PersonaUpdateRequest,
)
from app.llm.prompts.persona import PERSONA_TRAIT_CATEGORIES
from app.llm.psych_mapping import (
    collect_signals,
    compute_conversation_policy,
    compute_psych_profile,
)
from app.models.database import User
from app.services.llm_log import log_llm_call
from app.services.style_gate import sanitize_text
from app.services.voice import add_user_samples, apply_voice_profile

router = APIRouter()

# 데일리 큐 (P0-F 재배열) — 원칙: "축당 2문항 최속 달성" (근거: docs/persona_science_rationale.md).
# 온보딩(R-1·R-2·R-3·8-3·R-5·9-1·9-2)이 못 잡는 축을 첫 2주에 채운다:
# ① 9-3 = 주관식 3개째(voice_confidence 0.35) ② 미커버 축(데이트·경계선·돈·관계정의)의
# behavior 문항 ③ 각 축 2문항째 ④ preference 문항(정답지·리포트 축)은 후반.
# 중복쌍(1-1≈R-2, 3-1≈R-3, 8-1≈R-4)은 큐에서 제외 — 서빙은 answered_codes 미포함
# 첫 코드 선택이라 온보딩 미응답자도 안전하다.
DAILY_SCENARIO_CODES = [
    "9-3",  # 주관식 3개째 — 말투 통계 안정선
    "4-2",  # 데이트(즉흥) — 미커버 축
    "7-2",  # 경계선(공개 성향) — 미커버 축
    "5-1",  # 돈(계산 행동) — 미커버 축
    "6-3",  # 관계 속도(관계 정의 행동)
    "3-3",  # 갈등 2문항째
    "8-2",  # 위로/애착(회복 방식) 2문항째
    "1-3",  # 연락 2문항째 (행동)
    "4-3",  # 데이트 2문항째
    "7-3",  # 경계선 2문항째
    "5-3",  # 돈 2문항째
    "6-1",  # 관계 속도 2문항째 (선호)
    "2-2",  # 유머 수용도 (선호)
    "3-2",  # 사과 기준 (선호)
    "1-2",  # 대화 주도권 (선호)
    "2-1",  # 유머 수용도 (선호)
    "4-1",  # 데이트 에너지
    "5-2",  # 지각 수용도 (선호)
    "6-2",  # 애정표현 수신 (선호)
    "7-1",  # 이성 친구 (선호)
    "2-3",  # 밈 코드 (선호)
    "8-3",  # 온보딩 포함 — 미응답자(구계정) 안전망
    "9-1",  # 〃
    "9-2",  # 〃
]


def _answer_codes(answers: list[dict]) -> list[str]:
    return [str(a.get("code", "")).strip() for a in answers if a.get("code")]


def _merge_codes(existing: list | None, new_codes: list[str]) -> list[str]:
    merged = [str(code) for code in (existing or []) if code]
    for code in new_codes:
        if code and code not in merged:
            merged.append(code)
    return merged


def _confidence(answer_count: int | None, answered_codes: list[str]) -> str:
    count = answer_count or len(answered_codes)
    if count >= 18:
        return "high"
    if count >= 8:
        return "medium"
    return "low"


def _persona_dict(persona: Persona) -> dict:
    # LLM 프롬프트(update)용 — voice_stats/sample_bank은 코드 산출물이라 LLM에 주지 않는다
    # (프롬프트 토큰 낭비 + LLM이 측정값을 '수정'하는 사고 방지).
    return {
        "user_id": persona.user_id,
        "traits": persona.traits,
        "communication_style": persona.communication_style,
        "humor_style": persona.humor_style,
        "value_keywords": persona.value_keywords,
        "speech_style": persona.speech_style,
        "sample_messages": persona.sample_messages,
        "embedding": list(persona.embedding) if persona.embedding is not None else None,
        "ai_generated": True,
    }


def _sim_persona_dict(persona: Persona) -> dict:
    """미리보기/시뮬 컨디셔닝용 — LLM update용 _persona_dict와 달리 voice_stats
    (측정값 카드)와 심리 기저층까지 싣는다. 이게 빠지면 발화가 enum 카드로만 생성된다."""
    return {
        "traits": persona.traits,
        "communication_style": persona.communication_style,
        "humor_style": persona.humor_style,
        "value_keywords": persona.value_keywords,
        "speech_style": persona.speech_style,
        "sample_messages": persona.sample_messages,
        "voice_stats": persona.voice_stats,
        "conversation_policy": persona.conversation_policy,
        "psych_profile": persona.psych_profile,
    }


async def _refresh_psych(
    db: AsyncSession, persona: Persona, uid: str, answers: list[dict], result: dict
) -> None:
    """답변 신호 → psych_profile·conversation_policy 갱신 (P0-B, 결정적 매핑).

    apply_voice_profile *뒤에* 불러야 한다 — conversation_policy가 최신
    voice_stats(question_ratio·리액션 크기)를 소비하기 때문.
    """
    user_row = await db.get(User, uid)
    signals = collect_signals(
        (persona.psych_profile or {}).get("signals"), answers
    )
    persona.psych_profile = compute_psych_profile(
        signals,
        user_row.mbti if user_row else None,
        result.get("big_five"),
        persona.psych_profile,
    )
    persona.conversation_policy = compute_conversation_policy(
        signals, persona.voice_stats
    )


def _persona_response(persona: Persona) -> PersonaResponse:
    return PersonaResponse(
        **_persona_dict(persona),
        voice_stats=persona.voice_stats,
        sample_bank=persona.sample_bank or [],
        voice_confidence=persona.voice_confidence,
        psych_profile=persona.psych_profile,
        conversation_policy=persona.conversation_policy,
        response_preferences=persona.response_preferences or [],
        answer_count=persona.answer_count,
        answered_codes=persona.answered_codes or [],
        persona_revision=persona.persona_revision or 1,
        persona_confidence=persona.persona_confidence or "low",
        last_answered_on=(
            persona.last_answered_on.isoformat() if persona.last_answered_on else None
        ),
    )


def _daily_status_response(persona: Persona) -> PersonaDailyStatusResponse:
    completed_today = persona.last_answered_on == date.today()
    answered = persona.answered_codes or []
    scenario_code = None
    if not completed_today:
        scenario_code = next(
            (code for code in DAILY_SCENARIO_CODES if code not in answered),
            None,
        )
    return PersonaDailyStatusResponse(
        completed_today=completed_today,
        scenario_code=scenario_code,
        answer_count=persona.answer_count,
        answered_codes=answered,
        persona_revision=persona.persona_revision or 1,
    )


def _ensure_dev_user(user: dict) -> None:
    if settings.debug and user.get("is_dev"):
        return
    raise HTTPException(
        status_code=403,
        detail={
            "error_code": "DEV_ONLY",
            "message": "개발 모드에서만 사용할 수 있는 기능입니다.",
            "request_id": str(uuid.uuid4()),
        },
    )


_TRAIT_ORDER = {c: i for i, c in enumerate(PERSONA_TRAIT_CATEGORIES)}


def _finalize_traits(new_traits: list[dict], existing: list | None = None) -> list[dict]:
    """LLM trait 출력 정리 — 카테고리 검증·중복 제거·confidence 코드 산출 (P0-A).

    confidence는 LLM 자기보고를 믿지 않고 evidence(근거 답변 코드) 개수로 계산한다.
    user_edited trait은 LLM 출력과 무관하게 기존 것을 보존한다 — 프롬프트 지시의
    코드 레벨 보증 (P0-C).
    """
    protected = {
        t.get("category"): dict(t) for t in (existing or []) if t.get("user_edited")
    }
    out: list[dict] = []
    seen: set[str] = set()
    for raw in new_traits:
        trait = dict(raw)
        cat = trait.get("category")
        if cat not in _TRAIT_ORDER or cat in seen or cat in protected:
            continue
        seen.add(cat)
        evidence = trait.get("evidence") or []
        trait["confidence"] = round(min(0.9, 0.3 + 0.2 * len(evidence)), 2)
        trait.setdefault("user_edited", False)
        out.append(trait)
    out.extend(protected.values())
    if not out:
        # LLM이 카테고리명을 전부 벗어나게 쓴 극단 케이스 — 응답 계약(min 1)을 지키기
        # 위해 원본을 그대로 쓴다 (다음 업데이트에서 자연 교정).
        out = [dict(t) for t in new_traits[:8]]
    out.sort(key=lambda t: _TRAIT_ORDER.get(t.get("category"), 99))
    return out


def _apply_result(persona: Persona, result: dict) -> None:
    persona.traits = _finalize_traits(result["traits"], persona.traits)
    persona.communication_style = result["communication_style"]
    persona.humor_style = result["humor_style"]
    persona.value_keywords = result["value_keywords"]
    persona.speech_style = result["speech_style"]
    persona.sample_messages = result["sample_messages"]
    persona.embedding = result.get("embedding")


async def _get_persona(db: AsyncSession, user_id: str) -> Persona | None:
    result = await db.execute(select(Persona).where(Persona.user_id == user_id))
    return result.scalar_one_or_none()


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=404,
        detail={
            "error_code": "NOT_FOUND",
            "message": "페르소나가 아직 생성되지 않았습니다.",
            "request_id": str(uuid.uuid4()),
        },
    )


@router.post("/build", response_model=PersonaResponse)
async def build_persona(
    body: PersonaBuildRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    started = time.monotonic()
    result = await llm.build_persona(user["uid"], body.answers)
    elapsed_ms = int((time.monotonic() - started) * 1000)

    # FK 전제: User 행 보장 후 페르소나 upsert
    await ensure_user(db, user["uid"], user.get("email"))

    persona = await _get_persona(db, user["uid"])
    new_codes = _answer_codes(body.answers)
    if persona:
        _apply_result(persona, result)
        persona.persona_revision = (persona.persona_revision or 1) + 1
    else:
        persona = Persona(
            user_id=user["uid"],
            persona_revision=1,
            answer_count=0,
            answered_codes=[],
            persona_confidence="low",
        )
        _apply_result(persona, result)
        db.add(persona)
    # LLM 결과 반영 뒤에 — 주관식 실측이 있으면 sample_messages를 실문장으로 교체한다.
    apply_voice_profile(persona, body.answers)
    await _refresh_psych(db, persona, user["uid"], body.answers, result)
    persona.answered_codes = _merge_codes(persona.answered_codes, new_codes)
    persona.answer_count = len(persona.answered_codes)
    persona.persona_confidence = _confidence(persona.answer_count, persona.answered_codes)
    if new_codes:
        persona.last_answered_on = date.today()
    await db.commit()
    await db.refresh(persona)

    await log_llm_call(
        db,
        endpoint="persona/build",
        provider=settings.llm_provider,
        request_body={"answers_count": len(body.answers)},
        response_status=200,
        response_time_ms=elapsed_ms,
        user_id=user["uid"],
    )

    return _persona_response(persona)


@router.post("/preview", response_model=PersonaPreviewResponse)
async def preview_persona(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    """"당신의 에이전트는 이렇게 말해요" — 상황 3개 발화 (P0-C).

    시뮬과 동일하게 스타일 게이트를 통과시켜 반환한다 — 미리보기가 실제
    시뮬 발화와 다르면 수정 루프의 의미가 없다.
    """
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()

    started = time.monotonic()
    utterances = await llm.preview_utterances(_sim_persona_dict(persona))
    elapsed_ms = int((time.monotonic() - started) * 1000)

    stats = persona.voice_stats or {}
    gated = []
    for item in utterances:
        text = item.get("text") or ""
        if stats:
            text, _violations = sanitize_text(text, stats)
        gated.append({"register": item.get("register") or "", "text": text})

    await log_llm_call(
        db,
        endpoint="persona/preview",
        provider=settings.llm_provider,
        request_body={},
        response_status=200,
        response_time_ms=elapsed_ms,
        user_id=user["uid"],
    )
    return PersonaPreviewResponse(
        utterances=gated, voice_confidence=persona.voice_confidence
    )


@router.patch("/me", response_model=PersonaResponse)
async def patch_persona(
    body: PersonaPatchRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    """페르소나 부분 수정 (P0-C) — 사용자에게 수정권을 준다.

    - trait 수정/삭제: user_edited로 잠겨 이후 LLM 업데이트가 덮지 못한다.
    - 발화 수정문·자유입력: sample_bank(user_written) 추가 + 말투 통계 재계산.
    - traits가 바뀌면 매칭 임베딩을 재계산한다.
    """
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()

    traits_changed = False
    if body.trait_edits:
        traits = [dict(t) for t in (persona.traits or [])]
        by_category = {t.get("category"): t for t in traits}
        for edit in body.trait_edits:
            if edit.category not in _TRAIT_ORDER:
                continue  # 카테고리 canon 밖은 무시
            if edit.delete:
                if edit.category in by_category:
                    traits = [t for t in traits if t.get("category") != edit.category]
                    by_category.pop(edit.category, None)
                    traits_changed = True
                continue
            trait = by_category.get(edit.category)
            if trait is None:
                if not edit.summary:
                    continue
                trait = {"category": edit.category, "summary": "", "keywords": []}
                traits.append(trait)
                by_category[edit.category] = trait
            if edit.summary is not None:
                trait["summary"] = edit.summary
            if edit.keywords is not None:
                trait["keywords"] = edit.keywords
            trait["user_edited"] = True
            trait["evidence"] = trait.get("evidence") or ["user_edit"]
            trait["confidence"] = 0.95  # 본인 확인 = 최고 신뢰
            traits_changed = True
        if traits_changed:
            traits.sort(key=lambda t: _TRAIT_ORDER.get(t.get("category"), 99))
            persona.traits = traits

    samples = [
        {"register": item.register, "text": item.text} for item in body.utterance_fixes
    ]
    if body.speech_edits:
        samples.extend(
            {"register": "자유입력", "text": text}
            for text in body.speech_edits.free_samples
        )
    voice_changed = add_user_samples(persona, samples)

    if body.speech_edits and (
        body.speech_edits.verbal_habits is not None
        or body.speech_edits.punctuation_habits is not None
    ):
        style = dict(persona.speech_style or {})
        if body.speech_edits.verbal_habits is not None:
            style["verbal_habits"] = body.speech_edits.verbal_habits
        if body.speech_edits.punctuation_habits is not None:
            style["punctuation_habits"] = body.speech_edits.punctuation_habits
        persona.speech_style = style
        voice_changed = True

    psych_changed = False
    if voice_changed:
        # 새 실측 표본이 들어왔으면 정책의 실측 필드(question_ratio 등)를 재계산.
        signals = (persona.psych_profile or {}).get("signals") or {}
        persona.conversation_policy = compute_conversation_policy(
            signals, persona.voice_stats
        )
    if body.psych_edits and body.psych_edits.hide is not None:
        profile = dict(persona.psych_profile or {})
        profile["user_visible"] = not body.psych_edits.hide
        persona.psych_profile = profile
        psych_changed = True

    if traits_changed:
        embedding = await llm.embed_persona(_persona_dict(persona))
        if embedding is not None:
            persona.embedding = embedding
    if traits_changed or voice_changed or psych_changed:
        persona.persona_revision = (persona.persona_revision or 1) + 1
        await db.commit()
        await db.refresh(persona)
    return _persona_response(persona)


@router.get("/daily", response_model=PersonaDailyStatusResponse)
async def get_daily_persona_question(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    return _daily_status_response(persona)


@router.post("/dev/advance-day", response_model=PersonaDailyStatusResponse)
async def advance_persona_day_for_dev(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _ensure_dev_user(user)
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    persona.last_answered_on = date.today() - timedelta(days=1)
    await db.commit()
    await db.refresh(persona)
    return _daily_status_response(persona)


@router.post("/update", response_model=PersonaResponse)
async def update_persona(
    body: PersonaUpdateRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    if persona.last_answered_on == date.today():
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "ALREADY_UPDATED_TODAY",
                "message": "오늘의 페르소나 답변은 이미 반영되었습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )

    started = time.monotonic()
    result = await llm.update_persona(user["uid"], _persona_dict(persona), body.answer)
    elapsed_ms = int((time.monotonic() - started) * 1000)

    _apply_result(persona, result)
    apply_voice_profile(persona, [body.answer])
    await _refresh_psych(db, persona, user["uid"], [body.answer], result)
    new_codes = _answer_codes([body.answer])
    persona.answered_codes = _merge_codes(persona.answered_codes, new_codes)
    persona.answer_count = len(persona.answered_codes)
    persona.persona_revision = (persona.persona_revision or 1) + 1
    persona.persona_confidence = _confidence(persona.answer_count, persona.answered_codes)
    persona.last_answered_on = date.today()
    await db.commit()
    await db.refresh(persona)

    await log_llm_call(
        db,
        endpoint="persona/update",
        provider=settings.llm_provider,
        request_body={
            "answer_code": body.answer.get("code"),
            "category": body.answer.get("category"),
        },
        response_status=200,
        response_time_ms=elapsed_ms,
        user_id=user["uid"],
    )

    return _persona_response(persona)


@router.get("/me", response_model=PersonaResponse)
async def get_my_persona(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    return _persona_response(persona)
