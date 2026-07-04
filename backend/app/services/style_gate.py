"""스타일 게이트 — 시뮬 발화의 말투 위반을 실측(voice_stats) 기준으로 후편집.

원샷 생성의 구조적 리스크(persona drift·style bleed)에 대한 '생성 후 검증' 레이어
(docs/persona_fidelity_design.md §5-4). 재생성 호출 없이 결정적으로 고칠 수 있는
위반만 고친다 — 사용자가 안 쓰는 습관(이모지·부호·웃음)의 누출이 "나 같지 않음"의
최대 원인이므로 제거 편집이 핵심이다. 격식(존/반말) 위반은 결정적으로 고칠 수 없어
위반 목록에만 기록한다(로깅 → 추후 재생성 트리거의 근거 데이터).

voice_stats가 없으면(실측 표본 0) 아무것도 하지 않는다 — 게이트는 실측이 있을 때만.
"""

import logging
import re

from app.llm.voice_features import (
    EMOJI_RE,
    LAUGH_H_RE,
    LAUGH_K_RE,
    classify_formality,
)

logger = logging.getLogger(__name__)

_TILDE_RE = re.compile(r"~+")
_TEARS_RE = re.compile(r"[ㅠㅜ]+")
_MULTI_EXCLAIM_RE = re.compile(r"!{2,}")
_CARET_RE = re.compile(r"\^{2,}")
_SEMI_RE = re.compile(r";{2,}")
_ELLIPSIS_RE = re.compile(r"…+|\.{4,}")
_MULTI_SPACE_RE = re.compile(r" {2,}")


def _strip_foreign_emoji(text: str, emoji_stats: dict) -> tuple[str, bool]:
    """실측 인벤토리에 없는 이모지를 제거한다. 인벤토리가 비면 전부 제거."""
    allowed = set(emoji_stats.get("inventory") or []) if emoji_stats.get("per_msg") else set()
    out = []
    removed = False
    for ch in text:
        if EMOJI_RE.match(ch) and ch not in allowed:
            removed = True
            continue
        out.append(ch)
    return "".join(out), removed


def _fix_laugh(text: str, laugh_stats: dict) -> tuple[str, bool]:
    """웃음 습관 교정 — 안 쓰면 제거, 다른 토큰이면 실측 토큰으로 치환."""
    token = laugh_stats.get("token") or ""
    if not token:
        fixed = LAUGH_K_RE.sub("", text)
        fixed = LAUGH_H_RE.sub("", fixed)
        return fixed, fixed != text
    wrong_re = LAUGH_H_RE if token == "ㅋ" else LAUGH_K_RE
    fixed = wrong_re.sub(lambda m: token * len(m.group()), text)
    return fixed, fixed != text


def sanitize_text(text: str, stats: dict) -> tuple[str, list[str]]:
    """발화 하나를 실측 통계에 맞게 후편집한다. (편집된 텍스트, 위반 라벨) 반환."""
    violations: list[str] = []
    fixed = text

    fixed, removed = _strip_foreign_emoji(fixed, stats.get("emoji") or {})
    if removed:
        violations.append("emoji")

    fixed, changed = _fix_laugh(fixed, stats.get("laugh") or {})
    if changed:
        violations.append("laugh")

    # 실측에 없는 부호 습관 제거. 실제로 쓰는 습관(punct_per_msg에 키 존재)은 보존.
    punct = stats.get("punct_per_msg") or {}
    edits = (
        ("~", _TILDE_RE, ""),
        ("ㅠㅠ", _TEARS_RE, ""),
        ("!!", _MULTI_EXCLAIM_RE, "!"),
        ("^^", _CARET_RE, ""),
        (";;", _SEMI_RE, ""),
        ("…", _ELLIPSIS_RE, "."),
    )
    for key, pattern, replacement in edits:
        if key not in punct:
            new = pattern.sub(replacement, fixed)
            if new != fixed:
                violations.append(f"punct:{key}")
                fixed = new

    # 격식 위반 — 결정적 교정 불가, 기록만 (실측 근거가 뚜렷할 때만 판정).
    fr = stats.get("formality_ratio") or {}
    dominant = max(fr, key=fr.get) if any(fr.values()) else None
    if dominant and fr[dominant] >= 0.9:
        spoken = classify_formality(fixed)
        if spoken and spoken != dominant:
            violations.append(f"formality:{spoken}")

    fixed = _MULTI_SPACE_RE.sub(" ", fixed).strip()
    return fixed, violations


def gate_turn(turn: dict, stats: dict | None) -> dict:
    """시뮬 턴 하나에 게이트를 적용한다. 실측이 없으면 원본 그대로."""
    if not stats or not stats.get("sample_count"):
        return turn
    fixed, violations = sanitize_text(turn.get("text", ""), stats)
    if violations:
        logger.info(
            "style-gate: turn=%s speaker=%s violations=%s",
            turn.get("turn_index"), turn.get("speaker"), violations,
        )
    if fixed == turn.get("text"):
        return turn
    return {**turn, "text": fixed}
