"""Gemini 임베딩 전용 헬퍼 — 채팅 provider와 무관하게 재사용한다.

modoo provider는 채팅을 DevDive로 보내지만 임베딩 벡터는 계속 Gemini
embedding-001(shared 계약 1024차원, 정규화)로 만든다. build_persona·update_persona가
공통으로 이 임베더에 의존한다(JSON 모드 + 재임베딩 패턴).
"""

import math


class GeminiEmbedder:
    """Gemini embedding 모델을 감싼 얇은 비동기 임베더."""

    def __init__(
        self,
        api_key: str,
        model: str = "gemini-embedding-001",
        dim: int = 1024,
    ):
        # 지연 임포트 — SDK 미설치 환경(순수 mock 등)에서도 모듈 로드를 허용
        from google import genai

        if not api_key:
            raise ValueError("GEMINI_API_KEY 가 설정되지 않았습니다 (임베딩에 필요).")
        self._client = genai.Client(api_key=api_key)
        self._model = model
        self._dim = dim

    async def embed(self, text: str) -> list[float]:
        from google.genai import types

        response = await self._client.aio.models.embed_content(
            model=self._model,
            contents=text,
            config=types.EmbedContentConfig(
                output_dimensionality=self._dim,
                task_type="SEMANTIC_SIMILARITY",
            ),
        )
        values = list(response.embeddings[0].values)
        # 3072차원이 아닌 출력은 정규화되어 있지 않음 — 코사인 검색을 위해 정규화
        norm = math.sqrt(sum(v * v for v in values)) or 1.0
        return [v / norm for v in values]
