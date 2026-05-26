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
            "embedding": _random_embedding(),
        }

    async def run_simulation(
        self,
        my_persona: dict,
        their_persona: dict,
        max_turns: int = 20,
    ) -> AsyncIterator[dict]:
        turns = [
            {
                "turn_index": 0,
                "speaker": "me",
                "text": "안녕하세요! 프로필에서 여행을 좋아하신다고 봤는데, 최근에 어디 다녀오셨어요?",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 1,
                "speaker": "them",
                "text": "안녕하세요~ 저 얼마 전에 제주도 다녀왔어요! 혹시 여행 좋아하세요?",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 2,
                "speaker": "system",
                "text": "🔍 공통 관심사 발견: 여행",
                "signal": "여행 시그널",
                "ai_generated": True,
            },
            {
                "turn_index": 3,
                "speaker": "me",
                "text": "저도 여행 엄청 좋아해요! 제주도 좋죠~ 저는 작년에 올레길 걸었는데 진짜 힐링이었어요. 제주도에서 뭐가 제일 좋았어요?",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 4,
                "speaker": "them",
                "text": "저는 성산일출봉에서 본 일출이 진짜 좋았어요. 새벽에 힘들었지만 올라가고 나니까 감동이더라고요. 혹시 음악도 좋아하세요?",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 5,
                "speaker": "me",
                "text": "맞아요 ㅎㅎ 인디 밴드 공연 보는 거 좋아해요. 조용한 소규모 공연장에서 듣는 거 특히 좋아하는데, 혹시 음악 취향이 어떻게 되세요?",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 6,
                "speaker": "system",
                "text": "🔍 공통 관심사 발견: 음악 (인디/소규모 공연)",
                "signal": "음악 취향 +18%",
                "ai_generated": True,
            },
            {
                "turn_index": 7,
                "speaker": "them",
                "text": "오 저도 인디 좋아해요! 혁오나 잔나비 같은 거 자주 듣고요, 소규모 공연장 분위기 진짜 좋죠. 마포구 쪽에 괜찮은 데 많던데 혹시 아세요?",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 8,
                "speaker": "me",
                "text": "홍대 근처 라이브 클럽 몇 군데 가봤어요! 맛집도 많고 분위기도 좋아서 자주 가는 편이에요. 그런데 평소에는 주로 뭐 하면서 시간 보내세요?",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 9,
                "speaker": "them",
                "text": "저는 카페에서 책 읽는 거 좋아해요. 요즘은 에세이를 많이 읽고 있어요. 그리고 요리도 좋아해서 주말에는 새로운 레시피 도전해 봐요 ㅎㅎ",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 10,
                "speaker": "me",
                "text": "카페에서 책 읽기 저도 좋아하는데! 요리도 하시는구나, 어떤 요리 잘하세요? 저는 파스타를 좋아하는데 만들면 항상 좀 아쉬워요 ㅋㅋ",
                "signal": None,
                "ai_generated": True,
            },
            {
                "turn_index": 11,
                "speaker": "system",
                "text": "💬 대화 스타일 궁합: 서로 질문을 주고받으며 관심을 표현하는 패턴",
                "signal": "대화 템포 일치",
                "ai_generated": True,
            },
        ]

        for turn in turns:
            if turn["turn_index"] >= max_turns:
                break
            yield turn
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
