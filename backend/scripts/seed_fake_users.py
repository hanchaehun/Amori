"""개발용 가짜 계정 100명 시드 — 실 가입자가 매칭될 상대 풀.

mock provider 없이 "실제 사용 가능한" 상태를 만든다: 실제 사람이 회원가입하고
페르소나를 만들면 GET /matches/find(pgvector 코사인 top-K)가 이 시드 계정들을
후보로 돌려준다.

- 이름 오른쪽에 "(개발용)" 표기 — 제품 요구(실 유저와 구분).
- 페르소나는 코드에서 합성(아키타입 20종 × 카테고리별 성향 변형 × 말투 풀)하되,
  임베딩은 프로덕션 경로 그대로 실제 Gemini embedding-001(1024차원, 정규화)로
  생성한다 — 시드끼리/실 유저와의 유사도가 의미적으로 진짜다.
- 성별 50:50, 관심 성별(이성 위주 + both/동성 소수), 나이·일정 다양화 —
  어떤 실 유저가 와도 상호 성별 필터를 통과하는 후보가 존재한다.
- 시뮬레이션·리포트는 깔지 않는다 — 가입 후 자연 흐름(auto_sim/수동)에 맡긴다.

재실행 멱등 — 이미 있는 시드 계정(seed_dev_*)은 건너뛴다. --force 로 재생성.

실행: .venv/Scripts/python.exe -X utf8 scripts/seed_fake_users.py [--count 100] [--force]
필요: .env 의 GEMINI_API_KEY(임베딩), DATABASE_URL 접속 가능
"""

import argparse
import asyncio
import os
import random
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.chdir(Path(__file__).resolve().parents[1])  # settings 의 env_file=".env" 해석 기준

from sqlalchemy import delete, select

from app.config import settings
from app.db.session import async_session_factory, engine
from app.llm.embedding import GeminiEmbedder
from app.llm.prompts.persona import persona_embedding_text
from app.models.database import Base, Persona, User
from app.routers.persona import DAILY_SCENARIO_CODES

SEED_PREFIX = "seed_dev_"

# ---- 다양성 풀 -------------------------------------------------------------

SURNAMES = ["김", "이", "박", "최", "정", "강", "조", "윤", "장", "임", "한", "오", "서", "신", "권"]
FEMALE_NAMES = [
    "서연", "지우", "하은", "수아", "지민", "예린", "채원", "유나", "다인", "소율",
    "가은", "민서", "윤아", "시은", "나연", "주하", "예나", "지안", "혜원", "다현",
    "세아", "은채", "수빈", "아린", "보라", "슬기", "미소", "현서", "규리", "온유",
]
MALE_NAMES = [
    "민준", "도윤", "시우", "주원", "지호", "준서", "건우", "현우", "우진", "선우",
    "연우", "정우", "승현", "태윤", "은찬", "재윤", "시온", "하람", "경민", "규현",
    "동혁", "성진", "찬영", "범준", "해성", "윤재", "태오", "진우", "석현", "라온",
]

# 관심사 아키타입 — (가치관 키워드 풀, 대화 스타일 후보, 유머 스타일 후보, 말투 샘플)
ARCHETYPES: list[dict] = [
    {"keywords": ["새로운 경험", "즉흥 여행", "낯선 골목", "사진", "자유"],
     "comm": ["여행 이야기로 마음을 여는 호기심형", "떠나온 이야기가 많은 탐험형"],
     "humor": ["엉뚱한 여행 에피소드 유머", "길치 셀프디스 유머"],
     "samples": ["얼마 전에 제주도 한 바퀴 돌고 왔어요!", "다음 여행지 고르는 게 취미예요 ㅎㅎ", "낯선 도시 골목 걷는 거 좋아해요"]},
    {"keywords": ["맛집 탐방", "집밥", "요리", "취향 공유", "함께 먹기"],
     "comm": ["맛집·요리로 친해지는 다정형", "먹는 얘기부터 시작하는 미식형"],
     "humor": ["먹을 때 진지해지는 반전 유머", "레시피 실패담 유머"],
     "samples": ["요즘 빠진 파스타집이 있어요 ㅋㅋ", "주말엔 장 봐서 직접 해 먹어요", "같이 먹으면 두 배로 맛있죠"]},
    {"keywords": ["영화관", "OTT 정주행", "여운", "취향 토론", "감성"],
     "comm": ["영화·드라마로 깊어지는 사색형", "엔딩 해석을 나누고 싶은 감상형"],
     "humor": ["명대사 패러디 유머", "스포 참기 실패 유머"],
     "samples": ["최근에 본 영화 여운이 길게 남았어요", "주말엔 한 편씩 정주행해요", "엔딩 해석 얘기하는 거 좋아해요"]},
    {"keywords": ["러닝", "헬스", "건강한 루틴", "성취감", "아침형"],
     "comm": ["운동으로 에너지를 나누는 활동형", "기록 인증이 즐거운 러너형"],
     "humor": ["근육통 셀프디스 유머", "치팅데이 합리화 유머"],
     "samples": ["아침마다 한강 러닝해요!", "오늘도 운동 인증 완료 ㅋㅋ", "같이 뛰면 금방 친해져요"]},
    {"keywords": ["등산", "캠핑", "자연", "일출", "아웃도어"],
     "comm": ["산과 캠핑장에서 충전하는 자연형", "주말마다 밖으로 나가는 야외형"],
     "humor": ["하산 후 다리 풀림 유머", "장비병 자백 유머"],
     "samples": ["지난 주말엔 북한산 다녀왔어요", "캠핑 장비가 자꾸 늘어나요 ㅋㅋ", "정상에서 먹는 김밥은 못 참죠"]},
    {"keywords": ["독립서점", "필사", "조용한 카페", "사유", "느린 대화"],
     "comm": ["책과 글로 천천히 스며드는 내향형", "좋은 문장을 모으는 기록형"],
     "humor": ["은근한 말장난 유머", "책 사놓고 안 읽는 자백 유머"],
     "samples": ["요즘 산문집 한 권을 천천히 읽고 있어요", "독립서점 구경하는 걸 좋아해요", "좋은 문장은 적어두는 편이에요"]},
    {"keywords": ["인디밴드", "소규모 공연", "플레이리스트", "라이브", "분위기"],
     "comm": ["음악·공연으로 통하는 감성형", "플레이리스트로 말을 거는 큐레이터형"],
     "humor": ["노래 가사 인용 유머", "노래방 열창 유머"],
     "samples": ["요즘 듣는 플레이리스트 공유하고 싶어요 ㅎㅎ", "소규모 공연장 분위기를 좋아해요", "라이브는 직접 가야 제맛이죠"]},
    {"keywords": ["강아지", "고양이", "산책", "교감", "소소한 행복"],
     "comm": ["반려동물 이야기로 무장해제되는 온화형", "산책 메이트가 있는 다정형"],
     "humor": ["반려동물 자랑 폭주 유머", "집사 서열 최하위 유머"],
     "samples": ["저희 강아지 자랑 시작하면 끝이 없어요 ㅎㅎ", "매일 저녁 산책이 하루의 낙이에요", "동물 좋아하는 분이면 좋겠어요"]},
    {"keywords": ["카페 투어", "디저트", "여유", "공간 취향", "수다"],
     "comm": ["카페·디저트로 여유를 나누는 느긋형", "공간 분위기를 아끼는 취향형"],
     "humor": ["디저트 앞에서 무너지는 유머", "카페인 과다 자백 유머"],
     "samples": ["분위기 좋은 카페 찾아다니는 게 취미예요", "주말엔 디저트 투어를 해요 ㅋㅋ", "느긋하게 수다 떠는 시간이 좋아요"]},
    {"keywords": ["전시", "미술관", "영감", "취향", "여운"],
     "comm": ["전시·미술로 영감을 나누는 감각형", "작품 앞에 오래 서 있는 관찰형"],
     "humor": ["작품 앞에서 진지한 척 농담", "도슨트급 아는 척 유머"],
     "samples": ["요즘 전시 보러 다니는 재미에 빠졌어요", "그림 앞에 오래 서 있는 편이에요", "여운 남는 작품 만나면 행복해요"]},
    {"keywords": ["필름카메라", "산책 스냅", "기록", "골목", "빛"],
     "comm": ["사진으로 순간을 모으는 기록형", "좋은 빛을 쫓아다니는 산책형"],
     "humor": ["어색한 셀카 자폭 유머", "필름값 통장 잔고 유머"],
     "samples": ["요즘 필름카메라로 산책 스냅 찍어요 ㅎㅎ", "좋은 빛을 만나면 꼭 담아둬요", "골목 사진 모으는 걸 좋아해요"]},
    {"keywords": ["도자기", "원데이클래스", "손맛", "집중", "성취"],
     "comm": ["만들기로 가까워지는 손재주형", "새 클래스에 도전하는 체험형"],
     "humor": ["완성품 기대와 현실의 갭 유머", "본드 손에 붙은 날 유머"],
     "samples": ["지난주엔 도자기 클래스 다녀왔어요 ㅋㅋ", "손으로 만드는 시간이 좋아요", "같이 하면 더 재밌는 것들이 많아요"]},
    {"keywords": ["보드게임", "콘솔 게임", "협동 플레이", "승부욕", "웃음"],
     "comm": ["게임으로 텐션을 맞추는 플레이형", "승부욕과 웃음이 공존하는 오락형"],
     "humor": ["패배 인정 못 하는 유머", "튜토리얼부터 헤매는 유머"],
     "samples": ["요즘 보드게임 카페에 자주 가요", "협동 게임하면 성격 다 나와요 ㅋㅋ", "이기면 기분 좋잖아요 솔직히"]},
    {"keywords": ["식물", "가드닝", "홈카페", "루틴", "차분함"],
     "comm": ["식물을 돌보며 안정을 찾는 차분형", "아침 루틴이 단단한 생활형"],
     "humor": ["식물 이름 다 까먹는 유머", "선인장도 말려 죽인 과거 유머"],
     "samples": ["창가에 화분이 하나둘 늘고 있어요", "아침에 물 주는 시간이 좋아요", "집에서 커피 내려 마시는 게 낙이에요"]},
    {"keywords": ["와인", "위스키", "분위기 있는 바", "대화", "취향 탐구"],
     "comm": ["한 잔과 긴 대화를 좋아하는 무드형", "취향을 탐구하는 애호가형"],
     "humor": ["시음 노트 허세 유머", "다음날 후회 유머"],
     "samples": ["조용한 바에서 얘기하는 거 좋아해요", "요즘 위스키 입문했어요 ㅎㅎ", "안주 조합 연구하는 재미가 있어요"]},
    {"keywords": ["봉사", "커뮤니티", "따뜻함", "사람", "나눔"],
     "comm": ["사람들과 온기를 나누는 참여형", "동네 커뮤니티가 익숙한 친화형"],
     "humor": ["오지랖 셀프디스 유머", "모임 총무 전담 유머"],
     "samples": ["주말에 유기견 봉사 다녀왔어요", "사람들 만나는 데서 에너지를 얻어요", "좋은 일은 같이 하면 더 좋더라고요"]},
    {"keywords": ["커리어", "자기계발", "사이드 프로젝트", "성장", "계획"],
     "comm": ["성장 이야기를 나누고 싶은 목표형", "계획 세우는 게 즐거운 실행형"],
     "humor": ["갓생 3일 만에 실패 유머", "새벽 기상 알람 5개 유머"],
     "samples": ["요즘 사이드 프로젝트 하나 하고 있어요", "계획 세우는 것 자체가 재밌어요", "성장하는 얘기 나누는 거 좋아해요"]},
    {"keywords": ["드라이브", "야경", "플레이리스트", "근교", "바람"],
     "comm": ["드라이브와 야경으로 여는 낭만형", "근교 명소를 꿰고 있는 안내자형"],
     "humor": ["주차 실력 자백 유머", "톨게이트 지나쳐버린 유머"],
     "samples": ["밤 드라이브하면서 노래 듣는 거 좋아해요", "근교 뷰 맛집 많이 알아요 ㅎㅎ", "바람 쐬러 훌쩍 나가는 편이에요"]},
    {"keywords": ["요가", "명상", "균형", "마음챙김", "느린 아침"],
     "comm": ["요가와 명상으로 균형을 찾는 안정형", "마음의 여백을 아끼는 평온형"],
     "humor": ["요가 자세 무너지는 유머", "명상하다 잠드는 유머"],
     "samples": ["아침 요가로 하루를 시작해요", "마음이 복잡할 땐 걷거나 명상해요", "천천히 사는 연습을 하고 있어요"]},
    {"keywords": ["야구", "축구 직관", "응원", "치맥", "열정"],
     "comm": ["직관과 응원으로 뜨거워지는 열정형", "스포츠 얘기가 끊이지 않는 팬심형"],
     "humor": ["연패 팀 부심 유머", "중계 보다 소리 지르는 유머"],
     "samples": ["주말에 야구 직관 다녀왔어요!", "응원가는 다 외우고 있어요 ㅋㅋ", "직관 치맥은 못 참죠"]},
    {"keywords": ["빈티지", "패션", "플리마켓", "취향", "스타일"],
     "comm": ["빈티지와 스타일로 말하는 감각형", "플리마켓 보물찾기가 취미인 수집형"],
     "humor": ["옷장 포화 상태 유머", "산 옷 또 사는 유머"],
     "samples": ["주말엔 플리마켓 구경 다녀요", "빈티지샵에서 보물 찾는 재미가 있어요", "스타일 얘기 나누는 거 좋아해요"]},
]

# 8개 trait 카테고리별 성향 변형 — 카테고리 순서는 페르소나 계약과 동일하게 고정
TRAIT_VARIANTS: dict[str, list[dict]] = {
    "연락 템포": [
        {"summary": "답장이 빠르고 자주 연락하는 걸 좋아해요", "keywords": ["빠른 답장", "수시 연락", "티키타카"]},
        {"summary": "답장은 천천히, 하지만 진심을 담아요", "keywords": ["느긋", "진심", "깊은 대화"]},
        {"summary": "바쁠 땐 몰아서, 대신 통화로 풀어요", "keywords": ["몰아서 답장", "통화 선호", "효율"]},
        {"summary": "일정한 리듬으로 꾸준히 연락해요", "keywords": ["꾸준함", "일정한 템포", "안정"]},
    ],
    "유머": [
        {"summary": "잔잔한 드라이 유머를 좋아해요", "keywords": ["드라이", "잔잔", "센스"]},
        {"summary": "티키타카 티격태격 유머가 편해요", "keywords": ["티키타카", "장난", "텐션"]},
        {"summary": "밈과 유행어로 웃기는 걸 좋아해요", "keywords": ["밈", "유행어", "가벼움"]},
        {"summary": "리액션이 커서 같이 웃게 돼요", "keywords": ["리액션", "웃음", "호응"]},
    ],
    "갈등": [
        {"summary": "서운한 건 바로 말하고 풀어요", "keywords": ["즉시 대화", "솔직", "직진"]},
        {"summary": "대화로 풀되, 시간이 좀 필요해요", "keywords": ["대화", "냉각기", "이해"]},
        {"summary": "감정이 가라앉은 뒤 차분히 얘기해요", "keywords": ["차분", "정리 후 대화", "신중"]},
    ],
    "데이트": [
        {"summary": "소소한 일상 데이트를 선호해요", "keywords": ["산책", "카페", "일상"]},
        {"summary": "새로운 곳을 찾아다니는 데이트가 좋아요", "keywords": ["탐방", "새로움", "액티비티"]},
        {"summary": "집이나 조용한 공간에서 쉬는 게 좋아요", "keywords": ["휴식", "홈데이트", "조용함"]},
        {"summary": "계획을 꽉 채운 알찬 데이트가 좋아요", "keywords": ["계획형", "알찬 일정", "코스"]},
    ],
    "돈·시간": [
        {"summary": "각자 편하게, 가끔은 서프라이즈", "keywords": ["더치페이", "서프라이즈", "균형"]},
        {"summary": "번갈아 내는 게 자연스러워요", "keywords": ["번갈아", "자연스러움", "배려"]},
        {"summary": "시간 약속은 꼭 지키는 편이에요", "keywords": ["시간 엄수", "신뢰", "계획"]},
    ],
    "관계 속도": [
        {"summary": "천천히 알아가는 걸 좋아해요", "keywords": ["천천히", "자연스럽게", "신중"]},
        {"summary": "호감이 생기면 표현이 빠른 편이에요", "keywords": ["빠른 표현", "솔직", "직진"]},
        {"summary": "말보다 행동으로 확인하고 싶어요", "keywords": ["행동", "확인", "꾸준함"]},
    ],
    "경계선": [
        {"summary": "개인 시간은 꼭 필요해요", "keywords": ["독립", "존중", "개인시간"]},
        {"summary": "웬만하면 많이 공유하는 게 좋아요", "keywords": ["공유", "함께", "개방"]},
        {"summary": "서로 합의한 선을 중요하게 생각해요", "keywords": ["합의", "선", "신뢰"]},
    ],
    "위로": [
        {"summary": "말보다 함께 있어주는 게 좋아요", "keywords": ["함께", "공감", "조용한 위로"]},
        {"summary": "먼저 공감해주고 나서 해결을 찾아요", "keywords": ["공감 우선", "경청", "해결"]},
        {"summary": "기분 전환을 시켜주는 위로가 좋아요", "keywords": ["기분 전환", "유쾌", "환기"]},
        {"summary": "혼자 회복할 시간을 존중받고 싶어요", "keywords": ["혼자 회복", "존중", "여백"]},
    ],
}

FORMALITY = ["존댓말", "존댓말", "혼용", "반말"]  # 존댓말 비중 높게(초면 컨텍스트)
EMOJI = ["거의 안 씀", "가끔", "자주"]
LAUGH = ["ㅋㅋ", "ㅎㅎ", "ㅋㅋㅋ", "안 씀"]
SENTENCE = ["짧고 간결", "보통", "길게 풀어 씀"]
TONES = ["담백", "다정", "활기", "차분", "장난스러움", "설렘", "잔잔", "솔직", "포근", "섬세"]
VERBAL_HABITS = ["", "", "'~더라고요'를 자주 씀", "'헐/대박' 감탄사", "'아 맞다'로 화제 전환", "'그쵸?'로 동의 구함"]
PUNCT_HABITS = ["", "", "!! 자주", "ㅠㅠ 자주", "~ 로 부드럽게", "… 여운"]
REACTION = ["공감형", "공감형", "논리형", "중간"]


def _confidence(count: int) -> str:
    if count >= 18:
        return "high"
    if count >= 8:
        return "medium"
    return "low"


def compose_profiles(count: int, rng: random.Random) -> list[dict]:
    """서로 다른 시드 프로필 count개를 합성한다 (임베딩 제외)."""
    # 이름: 성×이름 조합에서 중복 없이 뽑는다
    fem = [(s, n) for s in SURNAMES for n in FEMALE_NAMES]
    mal = [(s, n) for s in SURNAMES for n in MALE_NAMES]
    rng.shuffle(fem)
    rng.shuffle(mal)

    profiles: list[dict] = []
    today = date.today()
    for i in range(count):
        gender = "female" if i % 2 == 0 else "male"
        surname, given = (fem if gender == "female" else mal).pop()
        # 관심 성별: 이성 위주 + both/동성 소수 — 어떤 실 유저와도 상호 필터가 열린다
        r = rng.random()
        if r < 0.78:
            interest = "male" if gender == "female" else "female"
        elif r < 0.93:
            interest = "both"
        else:
            interest = gender

        arche = ARCHETYPES[i % len(ARCHETYPES)]
        traits = [
            {"category": cat, **rng.choice(variants)}
            for cat, variants in TRAIT_VARIANTS.items()
        ]
        keywords = rng.sample(arche["keywords"], k=rng.randint(4, 5))

        speech = {
            "formality": rng.choice(FORMALITY),
            "emoji_usage": rng.choice(EMOJI),
            "laugh_style": rng.choice(LAUGH),
            "sentence_length": rng.choice(SENTENCE),
            "tone_keywords": rng.sample(TONES, k=rng.randint(2, 3)),
            "verbal_habits": rng.choice(VERBAL_HABITS),
            "punctuation_habits": rng.choice(PUNCT_HABITS),
            "reaction_style": rng.choice(REACTION),
        }

        # 가능 일정: 앞으로 2주 내 0~5칸 (일부는 일정 없음 — 의향만 합의 폴백도 커버)
        slots = []
        if rng.random() > 0.15:
            days = rng.sample(range(1, 15), k=rng.randint(2, 5))
            slots = [
                {"date": (today + timedelta(days=d)).isoformat(),
                 "time": rng.choice(["점심", "저녁"])}
                for d in sorted(days)
            ]

        answered = rng.sample(DAILY_SCENARIO_CODES, k=rng.randint(5, len(DAILY_SCENARIO_CODES)))
        birth = date(rng.randint(1994, 2004), rng.randint(1, 12), rng.randint(1, 28))

        profiles.append({
            "uid": f"{SEED_PREFIX}{i + 1:03d}",
            "display_name": f"{surname}{given}(개발용)",
            "gender": gender,
            "interest_gender": interest,
            "birth_date": birth,
            "available_slots": slots,
            "persona": {
                "traits": traits,
                "communication_style": rng.choice(arche["comm"]),
                "humor_style": rng.choice(arche["humor"]),
                "value_keywords": keywords,
                "speech_style": speech,
                "sample_messages": arche["samples"],
            },
            "answered_codes": answered,
        })
    return profiles


async def embed_with_retry(embedder: GeminiEmbedder, text: str) -> list[float]:
    last: Exception | None = None
    for attempt in range(3):
        try:
            return await embedder.embed(text)
        except Exception as exc:  # 429/일시 오류 — 백오프 후 재시도
            last = exc
            await asyncio.sleep(2.0 * (attempt + 1))
    raise last


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--force", action="store_true", help="기존 시드 계정을 지우고 재생성")
    parser.add_argument("--seed", type=int, default=42, help="프로필 합성 RNG 시드(재현성)")
    args = parser.parse_args()

    if not settings.gemini_api_key:
        print("GEMINI_API_KEY 가 없습니다 — 임베딩을 만들 수 없어 중단합니다.")
        return 1

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    embedder = GeminiEmbedder(
        settings.gemini_api_key, settings.gemini_embedding_model, settings.embedding_dim
    )
    profiles = compose_profiles(args.count, random.Random(args.seed))

    async with async_session_factory() as db:
        if args.force:
            await db.execute(delete(User).where(User.id.like(f"{SEED_PREFIX}%")))
            await db.commit()
            print(f"--force: 기존 {SEED_PREFIX}* 계정 삭제")

        existing = set(
            (await db.execute(
                select(User.id).where(User.id.like(f"{SEED_PREFIX}%"))
            )).scalars().all()
        )

        created = skipped = 0
        for p in profiles:
            if p["uid"] in existing:
                skipped += 1
                continue
            embedding = await embed_with_retry(
                embedder, persona_embedding_text(p["persona"])
            )
            db.add(User(
                id=p["uid"],
                email=f"{p['uid']}@dev.local",
                display_name=p["display_name"],
                birth_date=p["birth_date"],
                gender=p["gender"],
                interest_gender=p["interest_gender"],
                available_slots=p["available_slots"],
            ))
            db.add(Persona(
                user_id=p["uid"],
                traits=p["persona"]["traits"],
                communication_style=p["persona"]["communication_style"],
                humor_style=p["persona"]["humor_style"],
                value_keywords=p["persona"]["value_keywords"],
                speech_style=p["persona"]["speech_style"],
                sample_messages=p["persona"]["sample_messages"],
                embedding=embedding,
                answer_count=len(p["answered_codes"]),
                answered_codes=p["answered_codes"],
                persona_revision=1,
                persona_confidence=_confidence(len(p["answered_codes"])),
            ))
            created += 1
            if created % 10 == 0:
                await db.commit()
                print(f"  … {created}/{args.count - skipped} 생성 (임베딩 실호출)")
            await asyncio.sleep(0.3)  # 임베딩 RPM 완충
        await db.commit()
        print(f"시드 완료 — 생성 {created}, 스킵(기존) {skipped}")

        # 검증: 시드 한 명의 임베딩으로 실제 매칭 쿼리(pgvector 코사인)를 돌려본다
        sample = (await db.execute(
            select(Persona).join(User, User.id == Persona.user_id)
            .where(User.id.like(f"{SEED_PREFIX}%")).limit(1)
        )).scalar_one_or_none()
        if sample is not None:
            from app.matching import find_candidates

            me = (await db.execute(select(User).where(User.id == sample.user_id))).scalar_one()
            cands = await find_candidates(
                db, sample.embedding, exclude_user_id=sample.user_id, top_k=5,
                my_gender=me.gender, my_interest_gender=me.interest_gender,
            )
            print(f"\n매칭 검증 — {me.display_name}({me.gender}→{me.interest_gender}) top-5:")
            for c in cands:
                print(f"   · {c.display_name}  score={c.score}")
            assert cands, "매칭 후보가 비어 있음 — 임베딩/필터 확인 필요"
            assert all("(개발용)" in (c.display_name or "") for c in cands)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
