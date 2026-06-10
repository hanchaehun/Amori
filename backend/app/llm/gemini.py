"""Gemini provider — 외부 LLM API SDK 직접 호출 (리팩토링 결정 1·4).

별도 LLM HTTP 서비스 없이 google-genai SDK를 직접 사용한다.
- 채팅: gemini-2.5-flash + responseSchema(structured output) → SCHEMA_VIOLATION 소멸
- 임베딩: gemini-embedding 계열, output_dimensionality=1024 (shared 계약 차원 유지)
- 시뮬레이션: services/simulation.py 의 2-에이전트 턴 루프에 콜백 주입
"""

import asyncio
import math
from typing import AsyncIterator

from pydantic import BaseModel, Field

from app.llm.base import LLMProvider
from app.llm.prompts import (
    ANALYSIS_SYSTEM_PROMPT,
    PERSONA_SYSTEM_PROMPT,
    REPORT_SYSTEM_PROMPT,
    STARTERS_SYSTEM_PROMPT,
    build_persona_user_message,
    build_report_user_message,
    build_starters_user_message,
)
from app.llm.prompts.persona import persona_embedding_text
from app.schemas.persona import PersonaTrait
from app.schemas.report import Finding, Place, Warning
from app.services.simulation import run_two_agent_simulation


# ---- LLM structured output 스키마 (Gemini responseSchema로 강제) ----------

class _PersonaOutput(BaseModel):
    traits: list[PersonaTrait] = Field(min_length=8, max_length=8)
    communication_style: str
    humor_style: str
    value_keywords: list[str] = Field(min_length=3, max_length=7)


class _SpeechOutput(BaseModel):
    text: str


class _AnalysisOutput(BaseModel):
    has_signal: bool
    system_text: str = ""
    signal: str = ""


class _ReportOutput(BaseModel):
    score: int = Field(ge=0, le=100)
    findings: list[Finding] = Field(min_length=2, max_length=5)
    warnings: list[Warning] = Field(min_length=1, max_length=2)
    places: list[Place] = Field(min_length=2, max_length=4)
    starters: list[str] = Field(min_length=2, max_length=5)
    tip: str = ""


class _Starter(BaseModel):
    label: str
    message: str


class _StartersOutput(BaseModel):
    starters: list[_Starter] = Field(min_length=3, max_length=3)


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
                    await asyncio.sleep(1.5 * (attempt + 1))
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
            _PersonaOutput,
            temperature=0.6,
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
        async def speak(system_prompt: str, history: list[dict]) -> str:
            output = await self._generate(
                system_prompt,
                self._to_contents(history),
                _SpeechOutput,
                temperature=0.9,
            )
            return output.text

        async def analyze(user_message: str) -> dict:
            output = await self._generate(
                ANALYSIS_SYSTEM_PROMPT,
                user_message,
                _AnalysisOutput,
                temperature=0.3,
            )
            return output.model_dump()

        async for turn in run_two_agent_simulation(
            speak, analyze, my_persona, their_persona, max_turns
        ):
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
            _ReportOutput,
            temperature=0.5,
        )
        report = output.model_dump()
        report["ai_generated"] = True
        return report

    async def generate_starters(
        self,
        my_persona: dict,
        their_persona: dict,
        recent_history: list[dict] | None = None,
    ) -> dict:
        output = await self._generate(
            STARTERS_SYSTEM_PROMPT,
            build_starters_user_message(my_persona, their_persona, recent_history),
            _StartersOutput,
            temperature=0.8,
        )
        result = output.model_dump()
        result["ai_generated"] = True
        return result
