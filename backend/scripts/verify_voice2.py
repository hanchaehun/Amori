"""voice 2차 검증 — 실 Gemini가 말투 샘플에서 speech_style을 '추출'하는지.

특징적인 말투(헉/ㅠㅠ/!!/ㅋㅋㅋ/반존대 혼용)를 주관식 샘플로 주고,
- speech_style이 그 특징을 그대로 잡는지 (지어내는 게 아니라)
- sample_messages가 사용자 문장을 거의 그대로 쓰는지
확인한다. 실행: .venv/Scripts/python.exe -X utf8 scripts/verify_voice2.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import settings
from app.llm.gemini import GeminiProvider

ANSWERS = [
    {"code": "2-1", "category": "유머 / 대화 코드", "question": "농담이 과하면?", "answer_letter": "A", "answer_text": "분위기를 편하게 만들려는 점이 좋다"},
    {"code": "6-1", "category": "관계 속도", "question": "관계 진전 속도는?", "answer_letter": "A", "answer_text": "끌리면 빠르게 가까워지는 편이다"},
    {"code": "9-1", "category": "말투 샘플", "question": "카페 휴무를 알리는 메시지", "answer_letter": "주관식", "answer_text": "헉 대박ㅠㅠ 우리 가기로한 카페 오늘 쉬는날이래요!! 어떡해 ㅋㅋㅋ 근데 저 근처에 봐둔데 있긴해요 거기 갈래요??"},
    {"code": "9-2", "category": "말투 샘플", "question": "스트레스 푸는 법 질문에 답하기", "answer_letter": "주관식", "answer_text": "저는 무조건 집이죠 ㅋㅋㅋ 이불속에서 넷플 정주행하는게 최고예요!! 근데 왠지 OO님은 밖에서 노는 파일거같은데 맞죠??"},
    {"code": "9-3", "category": "말투 샘플", "question": "칭찬에 답하기", "answer_letter": "주관식", "answer_text": "헐 감사해요ㅠㅠ 저도 오늘 진짜 재밌었어요!! 다음엔 더 웃겨드릴게요 ㅋㅋㅋ"},
]


async def main() -> int:
    provider = GeminiProvider(
        api_key=settings.gemini_api_key, chat_model=settings.gemini_chat_model
    )
    result = await provider.build_persona("voice2_test", ANSWERS)
    ss = result["speech_style"]
    print(f"formality: {ss['formality']} | emoji: {ss['emoji_usage']} | laugh: {ss['laugh_style']}")
    print(f"tone: {ss['tone_keywords']} | habits: {ss['verbal_habits']}")
    print("--- sample_messages (사용자 문장 그대로인가?) ---")
    for m in result["sample_messages"]:
        print(" ·", m)
    # 추출 판정: 샘플의 특징 표지가 살아있는지
    joined = " ".join(result["sample_messages"])
    markers = [m for m in ("ㅋㅋ", "ㅠㅠ", "헉", "!!") if m in joined]
    print(f"\n살아남은 말투 표지: {markers}")
    print("추출 검증 통과" if len(markers) >= 2 else "WARN: 사용자 말투가 희석됨 — 프롬프트 보강 필요")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
