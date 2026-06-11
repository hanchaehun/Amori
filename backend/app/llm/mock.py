from __future__ import annotations

import asyncio
import math
import random
from typing import AsyncIterator

from app.llm.base import LLMProvider


def _random_embedding(dim: int = 1024) -> list[float]:
    raw = [random.gauss(0, 1) for _ in range(dim)]
    norm = math.sqrt(sum(x * x for x in raw))
    return [round(x / norm, 6) for x in raw]


class MockLLMProvider(LLMProvider):

    async def build_persona(self, user_id: str, answers: list[dict]) -> dict:
        return {
            "user_id": user_id,
            "ai_generated": True,
            "traits": [
                {
                    "category": "연락 템포",
                    "summary": "답장은 천천히, 하지만 진심을 담아요",
                    "keywords": ["느긋", "진심", "깊은 대화"],
                },
                {
                    "category": "유머",
                    "summary": "잔잔한 드라이 유머를 좋아해요",
                    "keywords": ["드라이", "잔잔", "센스"],
                },
                {
                    "category": "갈등",
                    "summary": "대화로 풀되, 시간이 좀 필요해요",
                    "keywords": ["대화", "냉각기", "이해"],
                },
                {
                    "category": "데이트",
                    "summary": "소소한 일상 데이트를 선호해요",
                    "keywords": ["산책", "카페", "일상"],
                },
                {
                    "category": "돈·시간",
                    "summary": "각자 편하게, 가끔은 서프라이즈",
                    "keywords": ["더치페이", "서프라이즈", "균형"],
                },
                {
                    "category": "관계 속도",
                    "summary": "천천히 알아가는 걸 좋아해요",
                    "keywords": ["천천히", "자연스럽게", "신중"],
                },
                {
                    "category": "경계선",
                    "summary": "개인 시간은 꼭 필요해요",
                    "keywords": ["독립", "존중", "개인시간"],
                },
                {
                    "category": "위로",
                    "summary": "말보다 함께 있어주는 게 좋아요",
                    "keywords": ["함께", "공감", "조용한 위로"],
                },
            ],
            "communication_style": "사려깊은 경청형",
            "humor_style": "잔잔한 드라이 유머",
            "value_keywords": ["진정성", "개인 존중", "일상의 소소함", "솔직한 소통", "느긋한 사랑"],
            "speech_style": {
                "formality": "존댓말",
                "emoji_usage": "가끔",
                "laugh_style": "ㅎㅎ",
                "sentence_length": "보통",
                "tone_keywords": ["담백", "차분", "다정"],
                "verbal_habits": "'~인 것 같아요' 처럼 부드럽게 의견을 냄",
            },
            "sample_messages": [
                "오늘 하루 어떻게 보내셨어요? ㅎㅎ",
                "저는 주말엔 보통 동네 산책하면서 쉬는 편이에요.",
                "그 얘기 들으니까 왠지 좀 더 궁금해지는데요?",
            ],
            "embedding": _random_embedding(),
        }

    async def run_simulation(
        self,
        my_persona: dict,
        their_persona: dict,
        max_turns: int = 20,
    ) -> AsyncIterator[dict]:
        # 눈치 흐름 데모: 알아가기 → 긍정 신호 → 약속 제안 → 약속 수락 → 마무리.
        # partner_read·strategy는 내부 분석용(사용자 비노출). 약속 수락이 나오면
        # appointment_ready가 켜진다.
        turns = [
            {
                "speaker": "me",
                "text": "안녕하세요! 프로필에서 여행을 좋아하신다고 봤는데, 최근에 어디 다녀오셨어요?",
                "partner_read": "중립",
                "strategy": "알아가기",
            },
            {
                "speaker": "them",
                "text": "안녕하세요~ 저 얼마 전에 제주도 다녀왔어요! 혹시 여행 좋아하세요?",
                "partner_read": "긍정적",
                "strategy": "알아가기",
            },
            {
                "speaker": "me",
                "text": "저도 여행 엄청 좋아해요! 작년에 올레길 걸었는데 진짜 힐링이었어요. 제주도에서 뭐가 제일 좋았어요?",
                "partner_read": "긍정적",
                "strategy": "알아가기",
            },
            {
                "speaker": "them",
                "text": "성산일출봉 일출이 최고였어요. 혹시 인디 음악도 좋아하세요? 소규모 공연장 분위기 좋아하거든요.",
                "partner_read": "긍정적",
                "strategy": "알아가기",
            },
            {
                "speaker": "me",
                "text": "저 완전 좋아해요 ㅎㅎ 이렇게 취향이 잘 맞는 것 같은데, 혹시 이번 주말에 홍대 쪽에서 공연 같이 보실래요?",
                "partner_read": "긍정적",
                "strategy": "약속 제안",
            },
            {
                "speaker": "them",
                "text": "오 좋아요! 토요일 저녁 어떠세요? 홍대 라이브 클럽 제가 아는 데 있어요 ㅎㅎ",
                "partner_read": "긍정적",
                "strategy": "약속 수락",
            },
            {
                "speaker": "me",
                "text": "토요일 저녁 좋아요! 그럼 그때 봬요 ㅎㅎ 기대할게요!",
                "partner_read": "긍정적",
                "strategy": "마무리",
            },
        ]

        for i, turn in enumerate(turns):
            if i >= max_turns:
                break
            yield {
                "turn_index": i,
                "speaker": turn["speaker"],
                "text": turn["text"],
                "partner_read": turn["partner_read"],
                "strategy": turn["strategy"],
                "ai_generated": True,
            }
            await asyncio.sleep(0.3)

    async def generate_report(
        self,
        my_persona: dict,
        their_persona: dict,
        simulation_log: list[dict],
    ) -> dict:
        return {
            "score": 82,
            "findings": [
                {
                    "emoji": "✈️",
                    "title": "여행 스타일 궁합",
                    "sub": "둘 다 자연 속 힐링 여행을 선호하고, 제주도·올레길에서 공통 관심사가 발견되었어요.",
                },
                {
                    "emoji": "🎵",
                    "title": "음악 취향 교집합",
                    "sub": "인디 밴드와 소규모 공연장을 함께 즐길 수 있는 궁합이에요.",
                },
                {
                    "emoji": "💬",
                    "title": "대화 스타일 일치",
                    "sub": "서로 질문을 주고받으며 관심을 표현하는 균형 잡힌 소통 패턴이에요.",
                },
                {
                    "emoji": "📍",
                    "title": "생활권 공유",
                    "sub": "홍대·마포 지역에 대한 공통 관심이 있어 만남 장소 설정이 자연스러워요.",
                },
            ],
            "warnings": [
                {
                    "title": "깊은 가치관 대화 필요",
                    "body": "아직 갈등 해결 방식이나 관계 속도에 대한 대화는 나누지 않았어요. 자연스럽게 알아가 보세요.",
                },
            ],
            "places": [
                {
                    "emoji": "☕",
                    "title": "연남동 카페 거리",
                    "sub": "카페와 산책을 좋아하는 두 분에게 딱이에요",
                },
                {
                    "emoji": "🎶",
                    "title": "문화비축기지",
                    "sub": "소규모 공연과 야외 산책을 함께 즐길 수 있어요",
                },
                {
                    "emoji": "🍝",
                    "title": "이태원 경리단길",
                    "sub": "다양한 음식과 분위기 있는 카페를 탐험할 수 있어요",
                },
            ],
            "starters": [
                "혹시 이번 주말에 연남동 카페 탐방 같이 하실래요?",
                "좋아하는 인디 밴드 공연 있으면 같이 가봐요!",
                "제주도 맛집 리스트 공유해 드릴까요? 저도 얼마 전에 갔거든요 ㅎㅎ",
            ],
            "tip": "첫 만남은 카페처럼 편한 공간에서 시작하면 대화가 더 자연스러워요.",
            "ai_generated": True,
        }

    async def generate_starters(
        self,
        my_persona: dict,
        their_persona: dict,
        recent_history: list[dict] | None = None,
    ) -> dict:
        if recent_history:
            return {
                "starters": [
                    {"label": "💬 이전 대화", "message": "저번에 얘기한 카페 가봤어요? 후기가 궁금해요!"},
                    {"label": "🌤️ 만남 제안", "message": "오늘 날씨가 산책하기 딱 좋은데, 혹시 시간 되세요?"},
                    {"label": "😊 호기심", "message": "요즘 재밌는 거 발견했는데 같이 해볼래요? ㅎㅎ"},
                ],
                "ai_generated": True,
            }
        return {
            "starters": [
                {"label": "✈️ 여행 토크", "message": "최근에 제일 기억에 남는 여행지가 어디예요?"},
                {"label": "☕ 카페 탐방", "message": "혹시 주말에 카페 가시는 거 좋아하세요? 요즘 분위기 좋은 곳 발견해서요"},
                {"label": "📸 프로필 칭찬", "message": "프로필 사진이 되게 좋은 곳에서 찍으셨더라고요~ 어디예요?"},
            ],
            "ai_generated": True,
        }
