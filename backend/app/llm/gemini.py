"""Gemini provider — 외부 LLM API SDK 직접 호출 (리팩토링 결정 1·4).

별도 LLM HTTP 서비스 없이 google-genai SDK를 직접 사용한다.
- 채팅: gemini-2.5-flash + responseSchema(structured output) → SCHEMA_VIOLATION 소멸
- 임베딩: gemini-embedding 계열, output_dimensionality=1024 (shared 계약 차원 유지)
- 시뮬레이션: 원샷 — 양쪽 페르소나·일정을 한 번에 주고 대화 전체를 1콜로 생성
  (구 턴별 1콜 방식 대비 쿼터·지연 대폭 감소, 모델이 대화 아크를 통째로 설계)
"""

import asyncio
import math
from typing import AsyncIterator

from pydantic import BaseModel

from app.llm.base import LLMProvider
from app.llm.oneshot import iter_finalized_turns
from app.llm.output_schemas import (
    ConversationOutput,
    PersonaOutput,
    ReportOutput,
)
from app.llm.prompts import (
    PERSONA_SYSTEM_PROMPT,
    REPORT_SYSTEM_PROMPT,
    build_oneshot_simulation_prompt,
    build_persona_update_user_message,
    build_persona_user_message,
    build_report_user_message,
)
from app.llm.prompts.persona import persona_embedding_text


def _quota_retry_delay(exc: Exception) -> float | None:
    """429 응답의 RetryInfo retryDelay(예: '11s')를 초 단위로 꺼낸다.

    무료 티어 RPM 쿼터는 분 단위 윈도우라 고정 백오프(1.5s)로는 못 넘는다 —
    서버가 알려준 대기 시간을 그대로 따라야 시뮬레이션 턴 루프가 안 끊긴다.
    """
    if getattr(exc, "code", None) != 429:
        return None
    details = getattr(exc, "details", None)
    if not isinstance(details, dict):
        return None
    for item in details.get("error", {}).get("details", []):
        if item.get("@type", "").endswith("RetryInfo"):
            delay = item.get("retryDelay", "")
            try:
                return float(delay.rstrip("s"))
            except ValueError:
                return None
    return None


# LLM structured output 스키마는 output_schemas 모듈(채팅 provider 공용)을 그대로 쓴다.


class GeminiProvider(LLMProvider):
    """채팅과 임베딩을 단일 키·단일 provider로 처리한다."""

    def __init__(
        self,
        api_key: str,
        chat_model: str = "gemini-2.5-flash",
        embedding_model: str = "gemini-embedding-001",
        embedding_dim: int = 1024,
        max_retries: int = 2,
    ):
        # 지연 임포트 — mock provider만 쓰는 환경에서 SDK 미설치를 허용
        from google import genai

        if not api_key:
            raise ValueError("GEMINI_API_KEY 가 설정되지 않았습니다.")
        self._client = genai.Client(api_key=api_key)
        self._chat_model = chat_model
        self._embedding_model = embedding_model
        self._embedding_dim = embedding_dim
        self._max_retries = max_retries

    # ---- 저수준 호출 -------------------------------------------------------

    async def _generate(
        self,
        system_prompt: str,
        contents,
        schema: type[BaseModel],
        temperature: float = 0.8,
    ) -> BaseModel:
        from google.genai import types

        config = types.GenerateContentConfig(
            system_instruction=system_prompt,
            response_mime_type="application/json",
            response_schema=schema,
            temperature=temperature,
        )
        last_error: Exception | None = None
        for attempt in range(self._max_retries + 1):
            try:
                response = await self._client.aio.models.generate_content(
                    model=self._chat_model,
                    contents=contents,
                    config=config,
                )
                parsed = response.parsed
                if parsed is None:
                    parsed = schema.model_validate_json(response.text)
                return parsed
            except Exception as exc:  # 일시 오류(429/5xx)·파싱 실패 재시도
                last_error = exc
                if attempt < self._max_retries:
                    quota_delay = _quota_retry_delay(exc)
                    delay = quota_delay + 1.0 if quota_delay is not None else 1.5 * (attempt + 1)
                    await asyncio.sleep(delay)
        raise last_error

    @staticmethod
    def _to_contents(history: list[dict]):
        from google.genai import types

        return [
            types.Content(role=item["role"], parts=[types.Part(text=item["text"])])
            for item in history
        ]

    async def _embed(self, text: str) -> list[float]:
        from google.genai import types

        response = await self._client.aio.models.embed_content(
            model=self._embedding_model,
            contents=text,
            config=types.EmbedContentConfig(
                output_dimensionality=self._embedding_dim,
                task_type="SEMANTIC_SIMILARITY",
            ),
        )
        values = list(response.embeddings[0].values)
        # 3072차원이 아닌 출력은 정규화되어 있지 않음 — 코사인 검색을 위해 정규화
        norm = math.sqrt(sum(v * v for v in values)) or 1.0
        return [v / norm for v in values]

    # ---- LLMProvider 도메인 메서드 ----------------------------------------

    async def build_persona(self, user_id: str, answers: list[dict]) -> dict:
        output = await self._generate(
            PERSONA_SYSTEM_PROMPT,
            build_persona_user_message(answers),
            PersonaOutput,
            temperature=0.6,
        )
        persona = output.model_dump()
        persona["user_id"] = user_id
        persona["ai_generated"] = True
        persona["embedding"] = await self._embed(persona_embedding_text(persona))
        return persona

    async def update_persona(
        self, user_id: str, current_persona: dict, answer: dict
    ) -> dict:
        output = await self._generate(
            PERSONA_SYSTEM_PROMPT,
            build_persona_update_user_message(current_persona, answer),
            PersonaOutput,
            temperature=0.45,
        )
        persona = output.model_dump()
        persona["user_id"] = user_id
        persona["ai_generated"] = True
        persona["embedding"] = await self._embed(persona_embedding_text(persona))
        return persona

    async def run_simulation(
        self,
        my_persona: dict,
        their_persona: dict,
        max_turns: int = 20,
    ) -> AsyncIterator[dict]:
        """원샷 — 양쪽 정보를 한 번에 주고 대화 전체를 1콜로 생성한다.

        턴마다 호출하던 구조(15콜+)를 1콜로 줄여 쿼터·지연을 크게 낮추고, 모델이
        대화 아크를 통째로 설계하게 해 더 사람다운 멀티토픽 대화를 얻는다.
        약속 조율은 하지 않는다(만남은 수락 후 직접 채팅에서).
        """
        system_prompt, user_message = build_oneshot_simulation_prompt(
            my_persona, their_persona, max_turns=max_turns,
        )
        output = await self._generate(
            system_prompt, user_message, ConversationOutput, temperature=0.95,
        )
        for turn in iter_finalized_turns(output.turns, max_turns):
            yield turn

    async def generate_report(
        self,
        my_persona: dict,
        their_persona: dict,
        simulation_log: list[dict],
    ) -> dict:
        output = await self._generate(
            REPORT_SYSTEM_PROMPT,
            build_report_user_message(my_persona, their_persona, simulation_log),
            ReportOutput,
            temperature=0.5,
        )
        report = output.model_dump()
        report["ai_generated"] = True
        return report
