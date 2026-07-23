"""실패 매치 마무리 인사 — 게이트 미달 대화에 '말뿐인 마무리'를 덧붙인다.

제품 설계 (2026-07-19, 한채훈): 케미 점수가 게이트(80점) 미만인 대화는
'닿지 않은 인연'에서 열람할 수 있는데, 대화 원문이 화기애애하게 끝나 있으면
낮은 점수와 모순돼 보인다. 그래서 리포트가 실패로 확정되는 시점에
서로 예의만 차리고 끝내는 마무리 인사 2턴을 대화 끝에 덧붙인다 —
"다음에 볼 수 있으면 봐요" 같은, 잘 된 소개팅이라면 하지 않을 인사.

LLM을 쓰지 않는다 — 결정적 풀에서 뽑는다. 실패가 확정된 시점엔 이미
시뮬+리포트로 LLM 비용을 다 쓴 뒤라 더 태울 이유가 없고, 문구가 통제돼
스타일 게이트도 필요 없다. 각 발화는 화자 페르소나의 말투(존댓말/반말)에
맞는 변형을 고른다.
"""

import random
from datetime import datetime, timezone

from app.services.reveal import plan_reveal_schedule

# (첫 화자 발화, 상대 답변) — polite/casual은 같은 내용의 존댓말/반말 변형.
# 첫 발화가 자리를 정리하고, 답변이 덕담으로 받아 끝낸다.
FAREWELL_PAIRS: list[dict[str, tuple[str, str]]] = [
    {
        "polite": (
            "오늘 이야기 즐거웠어요. 다음에 볼 수 있으면 봐요.",
            "네, 시간 내 주셔서 감사했어요. 좋은 하루 보내세요!",
        ),
        "casual": (
            "오늘 얘기 재밌었어. 다음에 기회 되면 또 보자.",
            "그래, 오늘 고마웠어. 좋은 하루 보내!",
        ),
    },
    {
        "polite": (
            "얘기해 보니 저랑은 가치관이 조금 다르신 것 같아요. 그래도 대화는 즐거웠어요.",
            "그러게요, 서로 더 잘 맞는 인연 만나면 좋겠네요.",
        ),
        "casual": (
            "얘기해 보니까 나랑은 가치관이 좀 다른 것 같아. 그래도 대화는 재밌었어.",
            "그러게, 서로 더 잘 맞는 사람 만나면 좋겠다.",
        ),
    },
    {
        "polite": (
            "슬슬 마무리해야 할 것 같아요. 오늘 시간 감사했어요.",
            "네네, 좋으신 분 만나실 거예요. 들어가세요!",
        ),
        "casual": (
            "슬슬 마무리해야 할 것 같아. 오늘 시간 고마웠어.",
            "응응, 좋은 사람 만날 거야. 들어가!",
        ),
    },
    {
        "polite": (
            "저희는 연인보다는 친구가 더 어울릴 것 같아요 ㅎㅎ",
            "하하 그런 것 같기도 하네요. 그래도 오늘 즐거웠어요.",
        ),
        "casual": (
            "우리는 연인보다는 친구가 더 어울리는 것 같아 ㅎㅎ",
            "ㅋㅋ 그런 것 같기도 하다. 그래도 오늘 즐거웠어.",
        ),
    },
    {
        "polite": (
            "오늘 나눈 이야기 좋았어요. 인연이 닿으면 또 뵈어요.",
            "네, 응원할게요. 건강하세요!",
        ),
        "casual": (
            "오늘 나눈 얘기 좋았어. 인연이 닿으면 또 보자.",
            "응, 응원할게. 잘 지내!",
        ),
    },
]


def _parse(visible_at: str) -> datetime:
    """ISO 문자열 → aware UTC datetime. naive면 UTC로 간주(reveal과 동일 방어)."""
    dt = datetime.fromisoformat(visible_at)
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def persona_formality(persona) -> str:
    """페르소나의 말투 격식 문자열('존댓말'|'혼용'|'반말'|''). 없으면 존댓말 취급."""
    if persona is None:
        return ""
    return ((persona.speech_style or {}).get("formality") or "")


def _variant(formality: str) -> str:
    return "casual" if "반말" in formality else "polite"


def farewell_turns(
    last_speaker: str,
    me_formality: str = "",
    them_formality: str = "",
    rng: random.Random | None = None,
) -> list[dict]:
    """마무리 인사 2턴. 마지막 화자의 상대가 먼저 자리를 정리한다.

    turns의 speaker(me|them)는 잡 요청자 기준 원본 값 그대로 쓴다.
    farewell=True 마커는 멱등 방어와 클라이언트 구분용.
    """
    r = rng or random
    pair = r.choice(FAREWELL_PAIRS)
    first = "them" if last_speaker == "me" else "me"
    second = "me" if first == "them" else "them"

    def _line(speaker: str, idx: int) -> str:
        formality = me_formality if speaker == "me" else them_formality
        return pair[_variant(formality)][idx]

    return [
        {"speaker": first, "text": _line(first, 0), "farewell": True},
        {"speaker": second, "text": _line(second, 1), "farewell": True},
    ]


def append_farewell(
    turns: list[dict] | None,
    settings,
    me_formality: str = "",
    them_formality: str = "",
    rng: random.Random | None = None,
) -> list[dict]:
    """실패 확정 시점에 호출 — 마무리 인사가 덧붙은 새 turns 리스트를 반환한다.

    - 멱등: 이미 farewell 턴이 있으면 원본 그대로.
    - 빈 대화(0턴)엔 덧붙이지 않는다 — 인사할 맥락이 없다.
    - 시차 송출 대화(visible_at 보유)는 마지막 공개 시각 뒤로 이어 스케줄해
      관전 중인 사용자에게 마무리 인사도 라이브로 흐른다.
    """
    turns = list(turns or [])
    if not turns or any(t.get("farewell") for t in turns):
        return turns
    extra = farewell_turns(
        turns[-1].get("speaker", "me"), me_formality, them_formality, rng=rng
    )
    stamps = [t["visible_at"] for t in turns if t.get("visible_at")]
    if stamps:
        start = max(_parse(s) for s in stamps)
        extra = plan_reveal_schedule(extra, start, settings, rng=rng)
    return [*turns, *extra]
