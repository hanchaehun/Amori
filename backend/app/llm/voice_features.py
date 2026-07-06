"""말투 측정 모듈 — 자유 발화에서 voice_stats를 *코드로* 계산한다.

페르소나 충실도 설계(docs/persona_fidelity_design.md §4)의 "말투는 추측하지 말고
측정한다" 원칙의 구현체. 순수 함수 + 정규식/카운팅이라 LLM·외부 의존이 없다.
build/update_persona가 주관식(말투 샘플) 답변을 여기 통과시키고, 결과는
personas.voice_stats에 저장돼 시뮬 프롬프트(_speech_block)의 수치 지시가 된다.

v1 정확도 등급 (형태소 분석기 없이 정규식만 — Kiwi 도입은 P1 검토):
- 정확: len_chars, laugh, emoji, punct_per_msg
- 근사: formality_ratio(어미 표지가 있는 메시지만 분모 — "ㅇㅇ" 같은 단편은 판정 불가),
        question_ratio('?' + 일부 의문 어미. '?' 없는 "뭐해"류 질문은 놓친다)
- 제외: spacing(띄어쓰기 뭉갬 판정은 교정 모델 없이 불가능해 v1 스키마에서 뺐다)

표본 2~3개(온보딩 직후)의 통계는 통계가 아니라 '앵커'다 — 이 모듈의 역할은
정밀 측정이 아니라 LLM 창작을 실측으로 규율하는 것. 신뢰도는 voice_confidence로
따로 노출한다.
"""

from __future__ import annotations

import math
import re

# ── 토큰 정규식 ──────────────────────────────────────────────────────────────

LAUGH_K_RE = re.compile(r"ㅋ+")
LAUGH_H_RE = re.compile(r"ㅎ+")

# 이모지 본체 블록. ㅠㅠ/^^/~ 같은 텍스트 감정 표지는 이모지가 아니라 punct로 센다.
EMOJI_RE = re.compile(
    "["
    "\U0001f1e6-\U0001f1ff"  # 국기
    "\U0001f300-\U0001faff"  # 그림문자 본체 (misc/supplemental/extended-A 포함)
    "☀-➿"  # 기호·딩벳 (☀❤✨ 등)
    "⬀-⯿"  # ⭐ 등
    "]"
)

# 부호 습관 — 설계 문서 punct_per_msg 키와 동일한 표기를 쓴다.
_PUNCT_PATTERNS: dict[str, re.Pattern[str]] = {
    "~": re.compile(r"~"),
    "!!": re.compile(r"!{2,}"),
    "…": re.compile(r"…|\.{3,}"),
    "ㅠㅠ": re.compile(r"[ㅠㅜ]+"),
    "^^": re.compile(r"\^{2,}"),
    ";;": re.compile(r";{2,}"),
}

# 어미 판정 전에 문미의 웃음·이모지·부호·공백을 벗겨낸다.
_TRAILING_NOISE_RE = re.compile(
    "(?:[ㅋㅎ]+|[\\s~!?.,…;^]+|[ㅠㅜ]+|"
    "[\U0001f1e6-\U0001f1ff\U0001f300-\U0001faff☀-➿⬀-⯿️])+$"
)

# 존댓말 어미 — '요'가 세요/네요/어요/까요/죠 대부분을 덮는다. 반말보다 먼저 검사해
# '니다'가 반말 '다'로 오분류되는 것을 막는다.
_POLITE_ENDINGS = ("요", "죠", "니다", "습니까", "십니까")
# 반말(해체·해라체·음슬체) 어미. '어/아/해'가 해체 대부분을 덮는다.
_BANMAL_ENDINGS = (
    "야", "자", "지", "냐", "래", "게", "다", "어", "아", "해",
    "함", "음", "셈", "걸", "줘", "봐", "라", "네", "든",
)
# 단독 토큰 판정 사전 — 어미 규칙이 못 다루는 초단문 관용 답.
_POLITE_TOKENS = {"네", "넵", "넹", "예", "옙"}
_BANMAL_TOKENS = {"응", "웅", "엉", "ㅇㅇ", "ㅇㅋ", "ㄴㄴ", "노", "ㄱㄱ"}

# 의문 어미('?' 없는 질문의 보조 신호). 짧은 어미('까','니')는 오탐이 커서 제외.
_QUESTION_ENDINGS = ("냐", "나요", "가요", "까요", "을까", "ㄹ까", "는지")

# 감탄사 사전 — 단독 토큰으로만 매칭해 단어 일부 오탐을 막는다.
_INTERJECTIONS = (
    "헉", "헐", "대박", "엥", "어머", "우와", "와우", "오잉",
    "아이고", "아이구", "앗", "어라", "오호", "맙소사", "세상에",
)
_INTERJECTION_PHRASES = ("아 맞다", "아맞다")

_TOKEN_STRIP_RE = re.compile(r"^[\W_ㅋㅎㅠㅜ]+|[\W_ㅋㅎㅠㅜ]+$")


def _percentile(sorted_vals: list[int], q: float) -> int:
    """inclusive 선형 보간 백분위 — 표본 1~2개에서도 죽지 않는다."""
    if not sorted_vals:
        return 0
    pos = (len(sorted_vals) - 1) * q
    lo = math.floor(pos)
    hi = math.ceil(pos)
    if lo == hi:
        return sorted_vals[lo]
    frac = pos - lo
    return round(sorted_vals[lo] * (1 - frac) + sorted_vals[hi] * frac)


def _strip_trailing_noise(text: str) -> str:
    return _TRAILING_NOISE_RE.sub("", text).strip()


def classify_formality(text: str) -> str | None:
    """메시지 하나의 존/반말 판정. 표지가 없으면 None(분모 제외)."""
    core = _strip_trailing_noise(text)
    if not core:
        return None
    if core in _POLITE_TOKENS:
        return "존댓말"
    if core in _BANMAL_TOKENS:
        return "반말"
    if core.endswith(_POLITE_ENDINGS):
        return "존댓말"
    if core.endswith(_BANMAL_ENDINGS):
        return "반말"
    return None


def _is_question(text: str) -> bool:
    if "?" in text:
        return True
    core = _strip_trailing_noise(text)
    return core.endswith(_QUESTION_ENDINGS)


def _laugh_stats(texts: list[str]) -> dict:
    k_runs = [len(m) for t in texts for m in LAUGH_K_RE.findall(t)]
    h_runs = [len(m) for t in texts for m in LAUGH_H_RE.findall(t)]
    if not k_runs and not h_runs:
        return {"token": "", "avg_run": 0.0, "per_msg": 0.0}
    token, runs = ("ㅋ", k_runs) if sum(k_runs) >= sum(h_runs) else ("ㅎ", h_runs)
    with_laugh = sum(1 for t in texts if LAUGH_K_RE.search(t) or LAUGH_H_RE.search(t))
    return {
        "token": token,
        "avg_run": round(sum(runs) / len(runs), 1),
        "per_msg": round(with_laugh / len(texts), 2),
    }


def _emoji_stats(texts: list[str]) -> dict:
    counts: dict[str, int] = {}
    total = 0
    for t in texts:
        for ch in EMOJI_RE.findall(t):
            counts[ch] = counts.get(ch, 0) + 1
            total += 1
    inventory = sorted(counts, key=counts.get, reverse=True)[:10]
    return {"per_msg": round(total / len(texts), 2), "inventory": inventory}


def _punct_stats(texts: list[str]) -> dict[str, float]:
    out: dict[str, float] = {}
    for key, pattern in _PUNCT_PATTERNS.items():
        total = sum(len(pattern.findall(t)) for t in texts)
        if total:
            out[key] = round(total / len(texts), 2)
    return out


def _interjections(texts: list[str]) -> list[str]:
    counts: dict[str, int] = {}
    for t in texts:
        for phrase in _INTERJECTION_PHRASES:
            if phrase in t:
                counts["아 맞다"] = counts.get("아 맞다", 0) + 1
        for raw in t.split():
            token = _TOKEN_STRIP_RE.sub("", raw)
            if token in _INTERJECTIONS:
                counts[token] = counts.get(token, 0) + 1
    return sorted(counts, key=counts.get, reverse=True)[:5]


def extract_voice_stats(texts: list[str]) -> dict | None:
    """자유 발화 목록 → voice_stats. 쓸 수 있는 텍스트가 없으면 None.

    반환 형태는 shared/schemas/persona.schema.json의 voice_stats와 동일하다.
    """
    msgs = [t.strip() for t in (texts or []) if t and t.strip()]
    if not msgs:
        return None

    lengths = sorted(len(t) for t in msgs)
    verdicts = [v for v in (classify_formality(t) for t in msgs) if v]
    polite = verdicts.count("존댓말")
    formality = (
        {
            "존댓말": round(polite / len(verdicts), 2),
            "반말": round((len(verdicts) - polite) / len(verdicts), 2),
        }
        if verdicts
        # 표지 있는 메시지가 하나도 없으면 0/0 — 소비자는 합이 0이면 근거 없음으로 취급
        else {"존댓말": 0.0, "반말": 0.0}
    )

    return {
        "sample_count": len(msgs),
        "formality_ratio": formality,
        "len_chars": {
            "p25": _percentile(lengths, 0.25),
            "p50": _percentile(lengths, 0.50),
            "p75": _percentile(lengths, 0.75),
        },
        "laugh": _laugh_stats(msgs),
        "emoji": _emoji_stats(msgs),
        "punct_per_msg": _punct_stats(msgs),
        "question_ratio": round(sum(1 for t in msgs if _is_question(t)) / len(msgs), 2),
        "interjections": _interjections(msgs),
    }


def voice_confidence(stats: dict | None) -> float:
    """실측 표본 수 → 신뢰도 [0, 0.9].

    1 - exp(-n/7): 3개≈0.35(격식·웃음 잡힘), 10개≈0.76(통계 안정).
    상한 0.9는 카톡 import·레지스터 커버리지(P1) 몫으로 남겨둔다.
    """
    n = (stats or {}).get("sample_count", 0)
    if n <= 0:
        return 0.0
    return min(0.9, round(1 - math.exp(-n / 7), 2))
