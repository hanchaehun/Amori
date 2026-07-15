"""원샷 시뮬레이션 프롬프트 — 양쪽 페르소나·일정을 한 번에 주고 대화 전체를 1콜 생성.

style bleed(말투 수렴)는 "각자의 말투를 끝까지 다르게 유지하라"는 시스템 지시와
페르소나별 말투 블록(_speech_block — voice_stats 실측 카드 + 금지 규칙)으로 막는다.
구 2-에이전트 턴 루프 프롬프트(build_agent_system_prompt)는 원샷 전환으로 제거됨(git 이력 참조).
"""


def _persona_block(persona: dict) -> str:
    trait_lines = [
        f"- {t['category']}: {t['summary']} (키워드: {', '.join(t['keywords'])})"
        for t in persona.get("traits", [])
    ]
    return "\n".join(
        [
            f"대화 스타일: {persona.get('communication_style', '')}",
            f"유머 스타일: {persona.get('humor_style', '')}",
            f"가치관 키워드: {', '.join(persona.get('value_keywords', []))}",
            *trait_lines,
        ]
    )


def _shrunk_pct(p: float, n: int, *, prior: float = 0.4, k: int = 5) -> int:
    """소표본 비율 축소 → % 정수.

    표본 2~5개에서 나온 '웃음 80~100%'를 문자 그대로 지시하면 LLM이 모든
    문장에 기계적으로 붙인다(캐리커처 — 2026-07-15 실사용 확인). 베이지안
    축소(가상 표본 k개, prior 0.4)로 보수화한다 — 표본이 쌓이면 실측에 수렴.
    """
    return int(round((n * p + k * prior) / (n + k) * 100))


def _voice_stats_lines(stats: dict, style: dict) -> list[str]:
    """실측 카드 — voice_features가 계산한 통계를 수치 지시로 변환한다.

    enum 카드("이모지 가끔")보다 강한 재현 지시("메시지당 0.5개, 😊만")가 되고,
    실측에 *없는* 습관은 네거티브로 명시한다 — 안 쓰는 습관의 누출(이모지·~)이
    '나 같지 않음'의 최대 원인이기 때문(설계 §5).
    """
    parts: list[str] = []
    banned: list[str] = []

    fr = stats.get("formality_ratio") or {}
    if fr.get("존댓말", 0) + fr.get("반말", 0) > 0:
        dom = "존댓말" if fr.get("존댓말", 0) >= fr.get("반말", 0) else "반말"
        pct = int(round(fr[dom] * 100))
        parts.append(dom if pct >= 100 else f"{dom} {pct}%(가끔 {'반말' if dom == '존댓말' else '존댓말'} 섞음)")
    elif style.get("formality"):
        parts.append(style["formality"])  # 실측 표본에 어미 표지가 없으면 LLM 추론값으로

    lc = stats.get("len_chars") or {}
    if lc.get("p50"):
        parts.append(f"문장 {lc.get('p25', 0)}~{lc.get('p75', 0)}자(중앙 {lc['p50']}자)")

    sample_count = stats.get("sample_count") or 0
    laugh = stats.get("laugh") or {}
    if laugh.get("token"):
        per = _shrunk_pct(laugh.get("per_msg") or 0, sample_count)
        parts.append(
            f"웃음 {laugh['token']} {laugh.get('avg_run', 0):g}연속꼴"
            f"·대화 전체에서 메시지 {per}% 정도에만"
        )
    else:
        banned.append("ㅋㅋ/ㅎㅎ 등 웃음 표현")

    emoji = stats.get("emoji") or {}
    if emoji.get("per_msg"):
        inventory = "".join((emoji.get("inventory") or [])[:3])
        parts.append(f"이모지 메시지당 {emoji['per_msg']}개({inventory} 위주)")
    else:
        banned.append("이모지")

    punct = stats.get("punct_per_msg") or {}
    if punct:
        parts.append("부호 " + " ".join(f"{k} {v}회/메시지" for k, v in punct.items()))
    banned.extend(t for t in ("~", "ㅠㅠ", "!!") if t not in punct)

    if stats.get("question_ratio"):
        parts.append(f"질문 비율 {int(round(stats['question_ratio'] * 100))}%")
    if stats.get("interjections"):
        parts.append(f"감탄사 {'·'.join(stats['interjections'])}")

    tones = style.get("tone_keywords") or []
    if tones:
        parts.append(f"톤 {','.join(tones)}")  # 측정 불가 차원은 LLM 추론값으로 보충
    if style.get("reaction_style") and style["reaction_style"] != "중간":
        parts.append(f"반응 {style['reaction_style']}")

    lines = [
        f"말투(실측 {stats.get('sample_count', 0)}개 발화 통계 — 반드시 재현): "
        + " | ".join(parts)
    ]
    lines.append(
        "위 비율은 상한이지 규칙이 아닙니다 — 웃음·부호·이모지는 웃기거나 멋쩍거나"
        " 들뜬 맥락에서만 자연스럽게 쓰고, 매 문장 끝에 기계적으로 붙이거나 연속된"
        " 메시지에 똑같이 반복하지 마세요. 담백한 문장이 섞여야 진짜 사람입니다."
    )
    if banned:
        lines.append("절대 사용 금지(실측에 없는 습관 — 쓰면 그 사람이 아님): " + ", ".join(banned))
    return lines


def _speech_block(persona: dict) -> str:
    """말투 지시 + 발화 예시(few-shot). 에이전트가 '이 사람처럼' 말하게 하는 앵커.

    매 턴 시스템 프롬프트로 재전송되는 핫패스 — 한 줄 key:value로 압축한다.
    빈 값(말버릇·부호 습관 없음, reaction_style 중간)은 줄 자체를 생략해 토큰을 아낀다.
    voice_stats(실측 통계)가 있으면 수치 카드가 enum 카드를 대체한다.
    """
    style = persona.get("speech_style") or {}
    stats = persona.get("voice_stats") or {}
    samples = persona.get("sample_messages") or []
    lines = []
    if stats.get("sample_count"):
        lines.extend(_voice_stats_lines(stats, style))
    elif style:
        parts = [
            style.get("formality", "존댓말"),
            f"이모지 {style.get('emoji_usage', '가끔')}",
            f"웃음 {style.get('laugh_style', 'ㅎㅎ')}",
            f"문장 {style.get('sentence_length', '보통')}",
        ]
        tones = style.get("tone_keywords") or []
        if tones:
            parts.append(f"톤 {','.join(tones)}")
        if style.get("verbal_habits"):
            parts.append(f"말버릇 {style['verbal_habits']}")
        if style.get("punctuation_habits"):
            parts.append(f"부호 습관 {style['punctuation_habits']}")
        if style.get("reaction_style") and style["reaction_style"] != "중간":
            parts.append(f"반응 {style['reaction_style']}")
        lines.append("말투(일관 유지): " + " | ".join(parts))
    if samples:
        example_lines = "\n".join(f'  · "{s}"' for s in samples)
        lines.append(f"발화 예시 — 이 어투 그대로:\n{example_lines}")
        lines.append(
            "예시의 맞춤법·표기를 교정하지 마세요. 비표준 표기(의도적 오타·줄임·"
            "늘여쓰기)는 빈도까지 흉내 내세요 — 여러 예시에서 반복되는 표기는 습관이니"
            " 자주, 한 번만 보이는 표기는 가끔만. 모든 문장에 욱여넣으면 흉내가 아니라"
            " 과장입니다."
        )
    return "\n".join(lines)


# Big Five 축 → 대화 언어 마커 (트레이트→언어 변환은 반복 검증됨 — rationale §7).
# 극단값(≥0.65/≤0.35)만 지시해 어중간한 축의 과잉 연기를 막는다.
_BIG_FIVE_MARKERS: dict[tuple[str, bool], str] = {
    ("E", True): "말수가 많고 에너지가 겉으로 드러남",
    ("E", False): "말수가 적고 차분한 톤",
    ("A", True): "완화 표현·맞장구가 잦음",
    ("A", False): "직설적이고 돌려 말하지 않음",
    ("C", True): "약속·계획 얘기가 구체적",
    ("C", False): "즉흥적이고 느슨한 화법",
    ("N", True): "걱정·조심스러운 표현이 종종 섞임",
    ("N", False): "부정 정서 단어가 드묾",
    ("O", True): "새로운 화제·비유를 즐김",
    ("O", False): "익숙한 화제를 선호",
}


def _behavior_block(persona: dict) -> str:
    """대화 행동 지시 (2층 conversation_policy + 3층 big_five 마커) — P0-B.

    존댓말·ㅋㅋ가 같아도 '서운할 때 반응'이 다르면 남이다 — 행동 축이 이 블록에서
    발화 정책이 된다. 값이 없는 축은 줄을 생략한다(추측 지시 금지).
    """
    policy = persona.get("conversation_policy") or {}
    psych = persona.get("psych_profile") or {}
    parts: list[str] = []
    question_ratio = policy.get("question_ratio")
    if question_ratio:
        parts.append(f"메시지의 약 {int(question_ratio * 100)}%는 되묻기")
    if policy.get("reaction_amplitude"):
        parts.append(f"리액션 {policy['reaction_amplitude']}")
    if policy.get("conflict_mode"):
        parts.append(f"서운하거나 갈등이 생기면 {policy['conflict_mode']}")
    reassurance = policy.get("reassurance_seeking")
    if reassurance and reassurance != "낮음":
        parts.append(f"상대 마음 확인 욕구 {reassurance}")
    pace = policy.get("self_disclosure_pace")
    if pace and pace != "보통":
        parts.append(f"자기 이야기를 여는 속도 {pace}")

    lines: list[str] = []
    if parts:
        lines.append("대화 행동(일관 유지): " + " | ".join(parts))
    big_five = psych.get("big_five") or {}
    if (big_five.get("confidence") or 0) >= 0.3:
        markers = []
        for axis in "EACNO":
            value = big_five.get(axis)
            if value is None:
                continue
            if value >= 0.65:
                markers.append(_BIG_FIVE_MARKERS[(axis, True)])
            elif value <= 0.35:
                markers.append(_BIG_FIVE_MARKERS[(axis, False)])
        if markers:
            lines.append("성격 마커: " + ", ".join(markers))
    return "\n".join(lines)


def _person_block(persona: dict, label: str, speaker_tag: str) -> str:
    """원샷 프롬프트용 한 사람 소개 — 이름 + 페르소나 + 말투 + 행동 + 발화 예시."""
    name = persona.get("display_name")
    name_part = f"(이름: {name}) " if name else ""
    speech = _speech_block(persona)
    speech_part = f"\n{speech}" if speech else ""
    behavior = _behavior_block(persona)
    behavior_part = f"\n{behavior}" if behavior else ""
    return f"[사람 {label}] {name_part}— 출력에서 speaker는 \"{speaker_tag}\"\n{_persona_block(persona)}{speech_part}{behavior_part}"


ONESHOT_SYSTEM_PROMPT = """당신은 소개팅 앱의 대화 시뮬레이터입니다. 이 앱은 두 사람이 직접 만나기 전에
각자의 AI 에이전트가 먼저 대화해보고 '실제로 잘 맞는지'를 검증해줍니다. 그러니 당신의 역할은
두 사람을 무조건 잘 되게 만드는 게 아니라, 주어진 두 페르소나가 진짜로 만나면 어떻게 흘러갈지를
'정직하게' 시뮬레이션하는 것입니다. 두 사람은 서로의 취향·일상·일정을 모르는 상태에서 시작해
질문하며 알아갑니다.

[가장 중요 — 정직한 궁합 시뮬레이션]
두 사람의 가치관·유머 코드·생활 방식·대화 에너지·온도를 깊이 들여다보고, 그 둘의 '실제 궁합'에
따라 대화가 달라지게 하세요. 모든 대화가 잘 흘러가면 이 서비스는 의미가 없습니다.
- 결이 잘 맞으면: 대화에 점점 흥이 오르고, 서로 더 알고 싶어 하고, 직접 만나보고 싶다는
  호감이 분명해집니다.
- 어중간하면: 나쁘진 않지만 미지근합니다. 한쪽만 적극적이거나, 화제가 자꾸 끊길 수 있습니다.
- 안 맞으면: 대화가 겉돕니다. 가치관·취향이 부딪히고, 답이 점점 짧아지고, 관심이 식습니다.
  예의는 지키되 약속은 잡지 않고 자연스럽게 멀어집니다.
어느 쪽이 정답이 아니라, '이 두 사람의 궁합'이 결과를 정해야 합니다. 페르소나가 잘 안 맞으면
억지로 좋게 끌고 가지 마세요.

[진짜 사람처럼]
- 실제 카카오톡 대화처럼. 정중하고 매끄러운 AI 말투 금지.
- 상대 말에 먼저 리액션하고(ㅋㅋ/오/헐/음…) 자기 얘기를 더하세요. 매 메시지를 질문으로 끝내지 마세요.
- 막연한 동조("저도 좋아해요") 대신 구체적인 일화로. 모든 것에 맞장구치지 말고 다른 점은 솔직히 드러내세요.
- 두 사람은 서로 다른 사람입니다 — 화제와 대화 에너지는 상대에게 자연스럽게 수렴해도
  되지만, 각자의 어미·말버릇·이모지·부호 습관은 끝까지 다르게 유지하세요(섞이면 실패).
- 서로 통성명한 사이이니 이름으로 부르세요(예: "유진씨", "지은님"). "A님"·"B님" 같은 호칭은 절대 금지.
- 프로필·외모 칭찬으로 시작하지 말고, 가벼운 인사나 관심사로 자연스럽게 여세요.

[대화 흐름]
- 최소 3가지 이상 서로 다른 주제(취미·일상·취향·음식·가치관 등)를 오가며 충분히 알아가세요.
- 한 번에 한 사람씩 번갈아 말합니다(A, B, A, B...).

[마무리 — 약속은 잡지 않습니다]
- 이 대화에서 구체적인 날짜·시간 약속은 절대 잡지 마세요. 만남 성사는 두 사용자가
  리포트를 보고 직접 결정하고, 약속은 그 후 직접 대화에서 잡습니다.
- 정말 잘 맞았다면 "직접 만나서 얘기하고 싶다"는 호감을 분명히 표현하며 마무리하세요.
- 안 맞거나 미지근하면 예의는 지키되 호감을 연기하지 마세요. "언제 한번 봐요" 같은
  빈말 없이 담백하게 마무리하는 것도 정당하고 중요한 결과입니다.

[각 메시지(턴)에 표시할 것]
- speaker: "me"(=사람 A) 또는 "them"(=사람 B)
- partner_read: 직전 상대 반응 — 긍정적 | 중립 | 미온적
- strategy: 알아가기 | 마무리
- text: 실제 발화

금지: 외모·재산·학력 평가, 차별적 표현, 과도한 신체 묘사.
출력은 JSON {"turns": [...]} 형식으로만 반환합니다."""


def build_oneshot_simulation_prompt(
    my_persona: dict,
    their_persona: dict,
    min_turns: int = 14,
    max_turns: int = 20,
) -> tuple[str, str]:
    """원샷 시뮬레이션 — 양쪽 정보를 한 번에 주고 대화 전체를 1콜로 생성한다.

    두 사람을 '서로 모르는 상태에서 시작'한다고 지시해, LLM이 양쪽을 다 알면서도
    정보 비대칭을 *서사적으로* 재현하게 한다(질문하며 알아가기).

    반환: (system_prompt, user_message).
    """
    user_message = "\n\n".join(
        [
            _person_block(my_persona, "A", "me"),
            _person_block(their_persona, "B", "them"),
            f"위 두 사람의 소개팅 대화를 총 {min_turns}~{max_turns}개의 메시지로 생성하세요.",
        ]
    )
    return ONESHOT_SYSTEM_PROMPT, user_message
