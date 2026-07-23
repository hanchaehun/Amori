"""원샷 시뮬레이션 프롬프트 — 양쪽 페르소나·일정을 한 번에 주고 대화 전체를 1콜 생성.

style bleed(말투 수렴)는 "각자의 말투를 끝까지 다르게 유지하라"는 시스템 지시와
페르소나별 말투 블록(_speech_block — voice_stats 실측 카드 + 금지 규칙)으로 막는다.
구 2-에이전트 턴 루프 프롬프트(build_agent_system_prompt)는 원샷 전환으로 제거됨(git 이력 참조).

소개팅 시뮬은 전원 존댓말이다(처음 만난 사이). formality 지시는 시스템 규칙이 소유하고,
말투 카드에는 반말 신호(반말 어미 표지·반말 발화 예시)를 아예 넣지 않는다(_speech_block
drop_formality + _is_polite 필터). preview는 실제 말투를 보여야 하므로 예외.
"""

import re


_POLITE_ENDINGS = ("요", "죠", "쵸", "니다", "습니다", "니까", "세요", "데요", "대요", "예요", "에요")


def _is_polite(msg: str) -> bool:
    """소개팅 시뮬 예시로 쓸 수 있는(존댓말로 끝나는) 발화인지.

    반말 발화 예시가 few-shot으로 들어가면 시스템의 '전원 존댓말' 규칙을 뚫고 그대로
    복제된다(2026-07 실사용 확인 — '무조건 함', '가보자고'). 시뮬 카드에는 존댓말 예시만 남긴다.
    """
    core = msg.strip()
    core = re.sub(r"[\s?!.,…~ㄱ-ㅎ☀-➿\U0001f000-\U0001faff\d]+$", "", core)
    return core.endswith(_POLITE_ENDINGS)


def _habit_polite_safe(habit: str) -> bool:
    """말버릇 설명에 반말 인용('가보자고' 등)이 없으면 True — 시뮬 카드에 그대로 넣어도 안전.

    인용이 없으면(순수 설명) 안전. 존댓말 인용('~더라고요')은 통과, 반말 인용은 걸러 카드에서 뺀다.
    """
    quoted = re.findall(r"['\"]([^'\"]+)['\"]", habit)
    return all(_is_polite(q) for q in quoted)


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


def _voice_stats_lines(stats: dict, style: dict, *, drop_formality: bool = False) -> list[str]:
    """실측 카드 — voice_features가 계산한 통계를 수치 지시로 변환한다.

    enum 카드("이모지 가끔")보다 강한 재현 지시("메시지당 0.5개, 😊만")가 되고,
    실측에 *없는* 습관은 네거티브로 명시한다 — 안 쓰는 습관의 누출(이모지·~)이
    '나 같지 않음'의 최대 원인이기 때문(설계 §5).
    """
    parts: list[str] = []
    banned: list[str] = []

    # 소개팅 시뮬은 무조건 존댓말(drop_formality) — formality 지시를 아예 빼서
    # 시스템 규칙("서로 존댓말")과 충돌하지 않게 한다. preview는 실제 말투를 보여야 하므로 유지.
    if not drop_formality:
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


def _speech_block(persona: dict, *, drop_formality: bool = False) -> str:
    """말투 지시 + 발화 예시(few-shot). 에이전트가 '이 사람처럼' 말하게 하는 앵커.

    매 턴 시스템 프롬프트로 재전송되는 핫패스 — 한 줄 key:value로 압축한다.
    빈 값(말버릇·부호 습관 없음, reaction_style 중간)은 줄 자체를 생략해 토큰을 아낀다.
    voice_stats(실측 통계)가 있으면 수치 카드가 enum 카드를 대체한다.
    drop_formality=True면 존댓말/반말 지시를 뺀다 — 소개팅 시뮬은 전원 존댓말이라
    시스템 규칙이 formality를 소유한다(preview는 실제 말투를 보여야 하므로 기본 False).
    """
    style = persona.get("speech_style") or {}
    stats = persona.get("voice_stats") or {}
    samples = persona.get("sample_messages") or []
    lines = []
    if stats.get("sample_count"):
        lines.extend(_voice_stats_lines(stats, style, drop_formality=drop_formality))
    elif style:
        parts = [
            f"이모지 {style.get('emoji_usage', '가끔')}",
            f"웃음 {style.get('laugh_style', 'ㅎㅎ')}",
            f"문장 {style.get('sentence_length', '보통')}",
        ]
        if not drop_formality:
            parts.insert(0, style.get("formality", "존댓말"))
        tones = style.get("tone_keywords") or []
        if tones:
            parts.append(f"톤 {','.join(tones)}")
        if style.get("verbal_habits") and (not drop_formality or _habit_polite_safe(style["verbal_habits"])):
            parts.append(f"말버릇 {style['verbal_habits']}")
        if style.get("punctuation_habits"):
            parts.append(f"부호 습관 {style['punctuation_habits']}")
        if style.get("reaction_style") and style["reaction_style"] != "중간":
            parts.append(f"반응 {style['reaction_style']}")
        lines.append("말투(일관 유지): " + " | ".join(parts))
    if drop_formality:
        samples = [s for s in samples if _is_polite(s)]  # 반말 예시는 카드에서 제외
    if samples:
        example_lines = "\n".join(f'  · "{s}"' for s in samples)
        if drop_formality:
            lines.append(f"발화 예시 — 어휘·이모지·웃음·표기 습관만 참고(말끝은 존댓말):\n{example_lines}")
            lines.append(
                "위 예시에서 어휘 색·이모지/웃음 빈도·비표준 표기(의도적 오타·줄임·늘여쓰기)만"
                " 흉내 내고, 말끝은 반드시 존댓말입니다. 모든 문장에 욱여넣으면 흉내가 아니라 과장입니다."
            )
        else:
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
    speech = _speech_block(persona, drop_formality=True)
    speech_part = f"\n{speech}" if speech else ""
    behavior = _behavior_block(persona)
    behavior_part = f"\n{behavior}" if behavior else ""
    return f"[사람 {label}] {name_part}— 출력에서 speaker는 \"{speaker_tag}\"\n{_persona_block(persona)}{speech_part}{behavior_part}"


# 연애 리얼리티(하트시그널·나는솔로·72시간 소개팅 등)의 '첫 대면 소개팅'에서 반복 관찰되는
# 대화 역학을 패턴으로 추출한 것. 대사 자체가 아니라 '리듬·행동'만 데이터화했다(방송 대본은
# 저작물 — 복제 회피). 아래 few-shot(_SOSGAETING_FEWSHOT)이 이 패턴을 형태로 보여준다.
_DATE_DYNAMICS = [
    "길이가 들쭉날쭉하다 — 한두 마디 리액션('헐 진짜요?', '아 그건 좀 ㅋㅋ')만으로 한 턴이"
    " 끝나기도 하고, 가끔만 길게 푼다. 매 턴 한 문단씩 쓰면 두 에세이스트가 글 쓰는 것처럼 가짜다.",
    "처음엔 가볍고 실무적이다 — 어떻게 신청했는지, 사는 동네, 주말에 뭐 하는지, 무슨 일 하는지처럼"
    " 실제로 궁금한 걸 먼저 묻는다. 깊은 취향·가치관·인생관은 대화가 데워진 뒤에 천천히 나온다.",
    "온도가 항상 같지 않다 — 한쪽이 살짝 더 들이대고 다른 쪽은 재기도, 한 화제가 안 먹혀 어색하게"
    " 끊겼다가 다른 사람이 다시 살리기도 한다. 모든 턴이 '긍정적'이면 가짜다.",
    "가벼운 장난·되받아치기가 있다 — 상대 말을 살짝 놀리거나 츤데레처럼 받아친다. 과하지 않게.",
    "자기 관계를 해설하지 않는다 — '우리 결이 비슷하네요', '대화가 잘 통하네요', '이런 분이면'"
    " 같은 메타 코멘트로 궁합을 요약하지 않는다. 호감은 요약이 아니라 더 묻고 더 웃는 걸로 드러난다.",
    "말이 문어체가 아니다 — 소설 문장·아포리즘('~하는 느낌이랄까요', '~라도 붙잡아두는') 금지."
    " 말하다 끊고, 줄임말 쓰고, 어순이 구어체다.",
]


# 형식·호흡 앵커. 실제 방송 대사가 아니라 위 역학을 보여주려고 직접 지은 예시다.
# '내용·화제·이름 복사 금지'를 명시해 content bleed(예시 주제를 그대로 베끼는 것)를 막는다.
_SOSGAETING_FEWSHOT = """[대화 리듬 예시 — 호흡·길이 변화만 참고하세요. 화제·표현·이름은 절대 그대로 쓰지 마세요]
가: 안녕하세요 ㅎㅎ 생각보다 안 떨리시네요?
나: 아 저 지금 엄청 떨고 있는데요 ㅋㅋㅋ 티 안 났으면 다행이네요
가: ㅋㅋㅋ 여유로워 보였어요. 이런 거 자주 하세요?
나: 아뇨 처음이에요. 친구가 등 떠밀어서.. 님은요?
가: 저도 거의 처음이에요. 주말엔 보통 뭐 하세요?
나: 음 저는 집에 있는 거 좋아해서 넷플 아니면 동네 카페? 재미없죠 ㅋㅋ
가: 아니 그거 저랑 똑같은데요. 카페 어디 다니세요?
나: 그건 좀 비밀인데.. 나중에 알려드릴게요 ㅋㅋ
가: 헐 벌써 밀당 들어오네요
나: ㅋㅋㅋㅋ 아니 그런 거 아니고요"""


_DYNAMICS_BLOCK = "\n".join(f"- {d}" for d in _DATE_DYNAMICS)


ONESHOT_SYSTEM_PROMPT = f"""당신은 소개팅 앱의 대화 시뮬레이터입니다. 이 앱은 두 사람이 직접 만나기 전에
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

[말투 — 두 사람 다 존댓말]
오늘 처음 만난 사이이니 서로 존댓말을 씁니다. 반말·혼용은 절대 쓰지 마세요. 단, 딱딱한 격식체가
아니라 "~해요/~거든요/~더라고요" 같은 편한 구어체 높임말입니다. 서로 이름으로 부르세요(예:
"유진씨", "지은님"). "A님"·"B님" 호칭은 절대 금지. 각자의 말버릇·이모지·웃음·부호 습관은 끝까지
다르게 유지하세요 — 화제·에너지는 수렴해도 되지만 말투가 섞이면 실패입니다.

[진짜 소개팅처럼 — 가장 흔한 실패는 '두 에세이스트가 번갈아 글 쓰는' 대화입니다]
실제 카카오톡 대화처럼 하세요. 정중하고 매끄러운 AI 말투 금지. 매끄럽게 쓰려는 본능을 누르고
아래 역학을 지키세요.
{_DYNAMICS_BLOCK}
- 상대 말에 먼저 리액션(ㅋㅋ/오/헐/음…)하고 자기 얘기를 더하되, 매 메시지를 질문으로 끝내지 마세요.
- 막연한 동조("저도 좋아해요") 대신 구체적 일화로. 모든 것에 맞장구치지 말고 다른 점은 솔직히 드러내세요.
- 전체 중 최소 3~4개 턴은 한 문장 이하의 짧은 리액션으로만 채우세요("아 진짜요? ㅋㅋ", "헐 대박",
  "오 그건 몰랐어요"). 매 턴을 문단으로 쓰면 실패입니다.
- 프로필·외모 칭찬으로 시작하지 말고, 가벼운 인사나 관심사로 자연스럽게 여세요.

{_SOSGAETING_FEWSHOT}

[대화 흐름]
- 최소 3가지 이상 서로 다른 주제(취미·일상·취향·음식·가치관 등)를 오가며 충분히 알아가세요.
- 한 번에 한 사람씩 번갈아 말합니다(A, B, A, B...).

[마무리 — 약속은 잡지 않습니다]
- 이 대화에서 구체적인 날짜·시간 약속은 절대 잡지 마세요. 만남 성사는 두 사용자가
  리포트를 보고 직접 결정하고, 약속은 그 후 직접 대화에서 잡습니다.
- 정말 잘 맞았다면 "직접 만나서 얘기하고 싶다"는 호감을 분명히 표현하며 마무리하세요.
- 안 맞거나 미지근하면 예의는 지키되 호감을 연기하지 마세요. "언제 한번 봐요" 같은
  빈말 없이 담백하게 마무리하는 것도 정당하고 중요한 결과입니다.
- 마무리에서 "우리 결이 비슷하네요 / 잘 통하는 것 같아요 / 스타일이 잘 섞일 것 같아요" 같은
  궁합 요약·관계 총평은 하지 마세요 — 그건 리포트가 할 일이지 당사자가 대놓고 말하는 게 아닙니다.
  호감은 "직접 만나서 더 얘기해보고 싶다" 정도로만 담백하게 드러내세요.

[각 메시지(턴)에 표시할 것]
- speaker: "me"(=사람 A) 또는 "them"(=사람 B)
- partner_read: 직전 상대 반응 — 긍정적 | 중립 | 미온적
- strategy: 알아가기 | 마무리
- text: 실제 발화

금지: 외모·재산·학력 평가, 차별적 표현, 과도한 신체 묘사.
출력은 JSON {{"turns": [...]}} 형식으로만 반환합니다."""


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
