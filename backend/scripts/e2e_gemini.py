"""실 Gemini E2E — persona/build → matches/find → simulation/run(SSE) → report.

실행: cd backend && .venv/Scripts/python.exe -X utf8 scripts/e2e_gemini.py
전제: docker-compose up -d db, alembic upgrade head, .env에 LLM_PROVIDER=gemini + GEMINI_API_KEY

인증만 dependency_overrides로 대체(프로덕션 코드 무변경), LLM·DB는 실물.
대조적인 두 페르소나(존댓말 신중형 vs 반말 장난형)를 만들어
시뮬레이션 대화에서 두 에이전트의 말투가 실제로 구분되는지 본다.
결과는 콘솔 + scripts/e2e_result.md 에 기록.
"""

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx

from app.main import app
from app.auth.firebase import get_current_user

RESULT_PATH = Path(__file__).parent / "e2e_result.md"

# ---- 인증 모킹: 요청마다 이 전역을 바꿔 사용자 전환 ----------------------
CURRENT_USER = {"uid": "e2e_user_a", "email": "a@e2e.test", "name": "지우"}


async def fake_current_user() -> dict:
    return dict(CURRENT_USER)


app.dependency_overrides[get_current_user] = fake_current_user


def switch_user(uid: str, name: str) -> None:
    CURRENT_USER["uid"] = uid
    CURRENT_USER["email"] = f"{uid}@e2e.test"
    CURRENT_USER["name"] = name


# ---- 대조적인 답변 세트 (scenarios.dart 8 카테고리 기준) -----------------
# A: 신중·배려·존댓말로 추론될 성향 / B: 장난기·직진·반말로 추론될 성향
ANSWERS_A = [
    {"code": "1-1", "category": "연락 / 대화 템포", "question": "하루 한두 번 답장하는 상대의 연락 템포를 어떻게 느끼나요?", "answer_letter": "A", "answer_text": "만나기 전이라 이 정도면 괜찮다"},
    {"code": "1-3", "category": "연락 / 대화 템포", "question": "상대가 '연락이 조금 느린 것 같아'라고 말하면?", "answer_letter": "A", "answer_text": "상대가 불안하지 않게 조금 더 신경 쓴다"},
    {"code": "2-1", "category": "유머 / 대화 코드", "question": "상대의 농담이 조금 과하게 느껴지면?", "answer_letter": "C", "answer_text": "진지한 대화도 함께 있어야 호감이 간다"},
    {"code": "3-1", "category": "갈등", "question": "의견이 부딪히면 어떻게 하나요?", "answer_letter": "B", "answer_text": "감정이 가라앉은 뒤에 차분히 이야기한다"},
    {"code": "4-1", "category": "데이트", "question": "선호하는 데이트는?", "answer_letter": "A", "answer_text": "조용한 카페에서 깊은 대화를 나누는 데이트"},
    {"code": "5-1", "category": "돈·시간", "question": "데이트 비용은 어떻게 생각하나요?", "answer_letter": "B", "answer_text": "부담되지 않게 번갈아 내는 것이 좋다"},
    {"code": "6-1", "category": "관계 속도", "question": "관계 진전 속도는?", "answer_letter": "C", "answer_text": "서로를 충분히 알아간 뒤에 천천히 진전되길 원한다"},
    {"code": "7-1", "category": "경계선", "question": "연인의 사생활은?", "answer_letter": "A", "answer_text": "각자의 시간과 공간을 존중해야 한다"},
    {"code": "8-1", "category": "위로", "question": "상대가 힘들어할 때 당신은?", "answer_letter": "B", "answer_text": "조용히 곁에서 이야기를 들어준다"},
]

ANSWERS_B = [
    {"code": "1-1", "category": "연락 / 대화 템포", "question": "하루 한두 번 답장하는 상대의 연락 템포를 어떻게 느끼나요?", "answer_letter": "C", "answer_text": "관심이 낮아 보여서 신경 쓰인다"},
    {"code": "1-2", "category": "연락 / 대화 템포", "question": "대화 주도권이 늘 나에게 있다면?", "answer_letter": "A", "answer_text": "내가 주도하는 것도 괜찮다"},
    {"code": "2-1", "category": "유머 / 대화 코드", "question": "상대의 농담이 조금 과하게 느껴지면?", "answer_letter": "A", "answer_text": "분위기를 편하게 만들려는 점이 좋다"},
    {"code": "2-2", "category": "유머 / 대화 코드", "question": "상대가 '너 은근 허당이네' 같은 가벼운 놀림을 하면?", "answer_letter": "A", "answer_text": "친근하게 느껴져서 괜찮다"},
    {"code": "3-1", "category": "갈등", "question": "의견이 부딪히면 어떻게 하나요?", "answer_letter": "A", "answer_text": "그 자리에서 바로 풀어버린다"},
    {"code": "4-1", "category": "데이트", "question": "선호하는 데이트는?", "answer_letter": "C", "answer_text": "즉흥적으로 떠나는 액티비티 데이트"},
    {"code": "5-1", "category": "돈·시간", "question": "데이트 비용은 어떻게 생각하나요?", "answer_letter": "A", "answer_text": "그때그때 기분 내키는 사람이 내면 된다"},
    {"code": "6-1", "category": "관계 속도", "question": "관계 진전 속도는?", "answer_letter": "A", "answer_text": "끌리면 빠르게 가까워지는 편이다"},
    {"code": "8-1", "category": "위로", "question": "상대가 힘들어할 때 당신은?", "answer_letter": "A", "answer_text": "웃긴 얘기로 기분을 풀어준다"},
]

out_lines: list[str] = []


def emit(line: str = "") -> None:
    print(line, flush=True)
    out_lines.append(line)


def show_persona(label: str, p: dict) -> None:
    ss = p["speech_style"]
    emit(f"### {label}")
    emit(f"- communication_style: {p['communication_style']}")
    emit(f"- humor_style: {p['humor_style']}")
    emit(f"- value_keywords: {', '.join(p['value_keywords'])}")
    emit(f"- speech_style: {ss['formality']} / 이모지 {ss['emoji_usage']} / 웃음 '{ss['laugh_style']}' / 문장 {ss['sentence_length']}")
    emit(f"  - tone: {', '.join(ss['tone_keywords'])} | 말버릇: '{ss.get('verbal_habits', '')}'")
    emit("- sample_messages:")
    for m in p["sample_messages"]:
        emit(f"  - {m}")
    dims = len(p["embedding"]) if p.get("embedding") else 0
    emit(f"- embedding: {dims}차원")
    emit()


async def main() -> int:
    skip_persona = "--skip-persona" in sys.argv  # 무료 티어 RPD 절약 — DB의 기존 페르소나 재사용

    transport = httpx.ASGITransport(app=app)
    timeout = httpx.Timeout(600.0)
    async with httpx.AsyncClient(transport=transport, base_url="http://e2e", timeout=timeout) as client:
        emit("# 실 Gemini E2E 결과")
        emit()

        if skip_persona:
            emit("## 1·2. 페르소나 생성 생략 (--skip-persona) — DB의 기존 페르소나 재사용")
            for uid, name, label in [("e2e_user_a", "지우", "A 페르소나"), ("e2e_user_b", "하준", "B 페르소나")]:
                switch_user(uid, name)
                r = await client.get("/persona/me")
                if r.status_code != 200:
                    emit(f"FAIL {r.status_code}: {r.text[:500]}")
                    return 1
                show_persona(label, r.json())
        else:
            # 1. 페르소나 A
            emit("## 1. POST /persona/build — A(지우, 신중·존댓말 성향 답변)")
            switch_user("e2e_user_a", "지우")
            r = await client.post("/persona/build", json={"answers": ANSWERS_A})
            if r.status_code != 200:
                emit(f"FAIL {r.status_code}: {r.text[:500]}")
                return 1
            show_persona("A 페르소나", r.json())

            # 2. 페르소나 B
            emit("## 2. POST /persona/build — B(하준, 장난기·반말 성향 답변)")
            switch_user("e2e_user_b", "하준")
            r = await client.post("/persona/build", json={"answers": ANSWERS_B})
            if r.status_code != 200:
                emit(f"FAIL {r.status_code}: {r.text[:500]}")
                return 1
            show_persona("B 페르소나", r.json())

        # 3. 매칭 (A 시점) — 임베딩 코사인 랭킹 + match_id 획득
        emit("## 3. GET /matches/find — A의 임베딩 매칭")
        switch_user("e2e_user_a", "지우")
        r = await client.get("/matches/find")
        if r.status_code != 200:
            emit(f"FAIL {r.status_code}: {r.text[:500]}")
            return 1
        matches = r.json()
        target = next((m for m in matches if m.get("user_id") == "e2e_user_b"), None)
        if not target:
            emit(f"FAIL: B가 매칭 후보에 없음 — {json.dumps(matches, ensure_ascii=False)[:300]}")
            return 1
        match_id = target["match_id"]
        emit(f"- B 발견: match_id={match_id}, score={target.get('score')}")
        emit()

        # 4. 시뮬레이션 SSE
        emit("## 4. POST /simulation/run — 2-에이전트 대화 (SSE)")
        sim_body = {"target_user_id": "e2e_user_b", "max_turns": 8}
        event_name = None
        turn_count = 0
        failed = False
        async with client.stream("POST", "/simulation/run", json=sim_body) as resp:
            if resp.status_code != 200:
                body = await resp.aread()
                emit(f"FAIL {resp.status_code}: {body.decode('utf-8', 'replace')[:500]}")
                return 1
            async for line in resp.aiter_lines():
                if line.startswith("event:"):
                    event_name = line.split(":", 1)[1].strip()
                elif line.startswith("data:"):
                    data = json.loads(line.split(":", 1)[1].strip())
                    if event_name == "turn":
                        turn_count += 1
                        speaker = {"me": "A(지우)", "them": "B(하준)"}.get(data["speaker"], data["speaker"])
                        emit(f"- [{data['turn_index']}] **{speaker}**: {data['text']}")
                        if data.get("signal"):
                            emit(f"  - 시그널: {data['signal']}")
                    elif event_name == "done":
                        emit(f"- done: {data}")
                    elif event_name == "error":
                        emit(f"- SSE error: {data}")
                        failed = True
        if failed or turn_count == 0:
            emit("FAIL: 시뮬레이션 턴 없음/에러")
            return 1
        emit()

        # 5. 리포트
        emit("## 5. GET /report/{match_id}")
        r = await client.get(f"/report/{match_id}")
        if r.status_code != 200:
            emit(f"FAIL {r.status_code}: {r.text[:500]}")
            return 1
        rep = r.json()
        emit(f"- score: {rep['score']}")
        emit(f"- findings: {json.dumps(rep['findings'], ensure_ascii=False)}")
        emit(f"- warnings: {json.dumps(rep['warnings'], ensure_ascii=False)}")
        emit(f"- places: {json.dumps(rep['places'], ensure_ascii=False)}")
        emit(f"- starters: {json.dumps(rep['starters'], ensure_ascii=False)}")
        emit(f"- tip: {rep.get('tip')}")
        emit()
        emit("**E2E PASS** — persona(voice 포함)→match→simulation(SSE)→report 전 구간 실 Gemini 통과")
    return 0


if __name__ == "__main__":
    code = asyncio.run(main())
    RESULT_PATH.write_text("\n".join(out_lines), encoding="utf-8")
    print(f"\n결과 저장: {RESULT_PATH}")
    sys.exit(code)
