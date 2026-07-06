"""주관식(말투 샘플) 답변 → sample_bank·voice_stats 배선.

수집 형식(폼/미연시/채팅형 온보딩)이 무엇이든 답변은
``{code, category, question, answer_letter, answer_text}`` 계약으로 도착한다 —
이 모듈은 그 계약만 보므로 온보딩 UI 결정과 무관하게 유효하다.

원칙 (docs/persona_fidelity_design.md §4):
- voice_stats는 사용자가 직접 쓴 문장(user_written)에서만 계산한다.
  LLM이 창작한 sample_messages(llm_seed)로 통계를 내면 추측이 측정으로 둔갑한다.
- 실측 샘플이 하나라도 있으면 sample_messages를 뱅크 파생(최신 3개)으로 교체한다 —
  LLM 창작 샘플은 부트스트랩 임시값이라는 지위가 여기서 실현된다.
"""

from datetime import date

from app.llm.voice_features import extract_voice_stats, voice_confidence

# 주관식 판별 기준 — prompts/persona.py의 [말투 샘플] 분리 조건과 동일해야 한다.
_FREE_TEXT_LETTER = "주관식"
_FREE_TEXT_CATEGORY = "말투 샘플"
# 정답지 판별 기준 — "이 상황에서 어떤 답장을 받고 싶은가" 문항.
# prompts/persona.py도 같은 기준으로 이 답변을 페르소나 생성 프롬프트에서 제외한다.
_PREFERENCE_LETTER = "정답지"
_PREFERENCE_CATEGORY = "정답지"


def _is_preference(answer: dict) -> bool:
    letter = answer.get("answer_letter") or answer.get("answerLetter") or ""
    return letter == _PREFERENCE_LETTER or answer.get("category") == _PREFERENCE_CATEGORY


def free_text_answers(answers: list[dict] | None) -> list[dict]:
    """답변 목록에서 주관식(말투 샘플)만 {code, text}로 추출한다 (빈 텍스트 제외).

    정답지는 '내가 받고 싶은 상대의 말'이라 내 말투 표본이 아니다 — 제외한다.
    """
    out: list[dict] = []
    for answer in answers or []:
        if _is_preference(answer):
            continue
        letter = answer.get("answer_letter") or answer.get("answerLetter") or ""
        category = answer.get("category") or ""
        text = (answer.get("answer_text") or answer.get("answerText") or "").strip()
        if text and (letter == _FREE_TEXT_LETTER or category == _FREE_TEXT_CATEGORY):
            out.append({"code": str(answer.get("code") or ""), "text": text})
    return out


def merge_response_preferences(existing: list | None, answers: list[dict] | None) -> list[dict]:
    """정답지 답변을 기존 목록에 병합한다 (desired_reply 기준 중복 제거)."""
    prefs = [dict(item) for item in (existing or [])]
    seen = {item.get("desired_reply") for item in prefs}
    for answer in answers or []:
        if not _is_preference(answer):
            continue
        text = (answer.get("answer_text") or answer.get("answerText") or "").strip()
        if not text or text in seen:
            continue
        prefs.append(
            {
                "code": str(answer.get("code") or ""),
                "situation": answer.get("question") or "",
                "desired_reply": text,
                "collected_at": date.today().isoformat(),
            }
        )
        seen.add(text)
    return prefs


def merge_sample_bank(existing: list | None, answers: list[dict] | None) -> list[dict]:
    """기존 뱅크에 새 주관식 답변을 병합한다 (text 기준 중복 제거, 순서 보존)."""
    bank = [dict(item) for item in (existing or [])]
    seen = {item.get("text") for item in bank}
    for entry in free_text_answers(answers):
        if entry["text"] in seen:
            continue
        bank.append(
            {
                "text": entry["text"],
                "register": entry["code"],
                "source": "user_written",
                "collected_at": date.today().isoformat(),
            }
        )
        seen.add(entry["text"])
    return bank


def apply_voice_profile(persona, answers: list[dict] | None) -> None:
    """Persona 행에 sample_bank → voice_stats → voice_confidence를 갱신한다.

    LLM 결과 반영(_apply_result) *뒤에* 불러야 한다 — 실측 샘플이 있으면
    LLM이 넣은 sample_messages를 실문장으로 덮어쓰기 때문.
    """
    bank = merge_sample_bank(persona.sample_bank, answers)
    persona.sample_bank = bank
    measured = [item["text"] for item in bank if item.get("source") != "llm_seed"]
    stats = extract_voice_stats(measured)
    persona.voice_stats = stats
    persona.voice_confidence = voice_confidence(stats)
    if measured:
        persona.sample_messages = measured[-3:]
    persona.response_preferences = merge_response_preferences(
        persona.response_preferences, answers
    )
