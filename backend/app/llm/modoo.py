"""ModooProvider — DevDive(모두의창업) AI API를 LLM 백엔드로 사용한다.

- 채팅(페르소나 생성/보정·시뮬레이션·리포트·스타터): DevDive ``POST /v1/chat/completions``.
  DevDive는 함수호출/responseSchema를 지원하지 않으므로, 프롬프트로 JSON을 유도하고
  응답을 여기서 파싱·검증한다(어긋나면 재생성 재시도).
- 임베딩: Gemini embedding-001 유지(shared 계약 1024차원). build_persona·update_persona가
  공통으로 GeminiEmbedder에 의존한다 — JSON 모드 + 재임베딩 패턴.

DevDive 응답은 평평한 ``{"content", "usage", "cost"}`` 형태다(OpenAI choices 구조 아님).
에러는 ``{"error": {code, message, type}}`` — 429/5xx/upstream_error는 백오프 재시도한다.
"""

from __future__ import annotations

import asyncio
import json
from typing import AsyncIterator

import httpx
from pydantic import BaseModel, ValidationError

from app.llm.base import LLMProvider
from app.llm.embedding import GeminiEmbedder
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

# 재시도 대상 — 일시적 오류. daily_quota_exceeded/invalid_* 등은 재시도하지 않는다.
_RETRYABLE_STATUS = {429, 500, 502, 503, 504}
_RETRYABLE_CODES = {"rate_limited", "upstream_error"}

# 스키마 강제가 없으므로 매 요청에 JSON-only를 명시한다.
_JSON_ONLY = (
    "\n\n반드시 유효한 JSON 하나만 출력하세요. 코드펜스(```)나 JSON 밖의 설명 문장을 붙이지 마세요."
)

# 페르소나는 프롬프트에 스키마 골격이 없어 키를 명시해준다(리포트·스타터는 프롬프트에 이미 있음).
_PERSONA_JSON_HINT = """

출력 JSON 키를 정확히 지키세요:
{"traits":[{"category":"연락 템포","summary":"한 문장","keywords":["..",".."]}, ...총 8개, 순서: 연락 템포·유머·갈등·데이트·돈·시간·관계 속도·경계선·위로],
 "communication_style":"명사구","humor_style":"명사구","value_keywords":["..3~7개"],
 "speech_style":{"formality":"반말|존댓말|혼용","emoji_usage":"거의 안 씀|가끔|자주","laugh_style":"ㅋㅋ 등","sentence_length":"짧고 간결|보통|길게 풀어 씀","tone_keywords":["..2~4개"],"verbal_habits":"","punctuation_habits":"","reaction_style":"공감형|논리형|중간"},
 "sample_messages":["..1~3개"]}

[말투 샘플]이 없으면 sample_messages를 빈 배열로 두지 말고, 추론한 speech_style에
맞는 자연스러운 메신저 문장 1~3개를 직접 만들어 넣으세요(초기 온보딩은 객관식만 있음)."""

_SIMULATION_JSON_HINT = """

출력 JSON 형식:
{"turns":[{"speaker":"me|them","text":"발화","strategy":"알아가기|마무리","partner_read":"긍정적|중립|미온적"}]}"""


class ModooError(Exception):
    """DevDive 호출 실패. code/status로 재시도 여부를 판단한다."""

    def __init__(self, message: str, *, code: str | None = None, status: int | None = None):
        super().__init__(message)
        self.code = code
        self.status = status

    @property
    def retryable(self) -> bool:
        return self.status in _RETRYABLE_STATUS or self.code in _RETRYABLE_CODES


def _extract_json(text: str) -> dict:
    """응답 문자열에서 JSON 객체 하나를 뽑는다(코드펜스·서두 설명 방어)."""
    s = (text or "").strip()
    if s.startswith("```"):
        s = s.strip("`")
        if s[:4].lower() == "json":
            s = s[4:]
        s = s.strip()
    start, end = s.find("{"), s.rfind("}")
    if start != -1 and end > start:
        s = s[start : end + 1]
    return json.loads(s)


class ModooProvider(LLMProvider):
    """DevDive 채팅 + Gemini 임베딩으로 LLMProvider 계약을 구현한다."""

    def __init__(
        self,
        api_key: str,
        base_url: str = "https://modoo.devdive.me",
        chat_model: str = "modoo-text-pro",
        *,
        gemini_api_key: str,
        embedding_model: str = "gemini-embedding-001",
        embedding_dim: int = 1024,
        max_retries: int = 2,
        timeout: float = 120.0,
    ):
        if not api_key:
            raise ValueError("MODOO_API_KEY 가 설정되지 않았습니다.")
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._chat_model = chat_model
        # 임베딩(Gemini)은 build_persona·update_persona에서만 필요하다 — 지연 생성해
        # 채팅 전용 경로(시뮬/리포트/스타터)는 Gemini 키 없이도 동작하게 한다.
        self._gemini_api_key = gemini_api_key
        self._embedding_model = embedding_model
        self._embedding_dim = embedding_dim
        self._embedder: GeminiEmbedder | None = None
        self._max_retries = max_retries
        self._timeout = timeout
        self._http: httpx.AsyncClient | None = None

    def _get_embedder(self) -> GeminiEmbedder:
        """build_persona·update_persona가 공유하는 임베딩 의존 (재임베딩 패턴)."""
        if self._embedder is None:
            self._embedder = GeminiEmbedder(
                self._gemini_api_key, self._embedding_model, self._embedding_dim
            )
        return self._embedder

    # ---- 저수준 호출 -------------------------------------------------------

    async def _chat(
        self, system_prompt: str, user_message: str, temperature: float, max_tokens: int
    ) -> str:
        if self._http is None:
            # provider가 DI 싱글턴이라 앱 수명 동안 커넥션 풀을 재사용한다
            self._http = httpx.AsyncClient(
                base_url=self._base_url,
                timeout=self._timeout,
                headers={"Authorization": f"Bearer {self._api_key}"},
            )
        payload = {
            "model": self._chat_model,
            "system_prompt": system_prompt,
            "prompt": user_message,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        try:
            resp = await self._http.post("/v1/chat/completions", json=payload)
        except httpx.RequestError as exc:  # 네트워크/타임아웃 — 일시적 취급
            raise ModooError(f"DevDive 연결 실패: {exc}", status=503) from exc

        try:
            data = resp.json()
        except ValueError:
            data = None

        if resp.status_code >= 400 or (isinstance(data, dict) and "error" in data):
            err = data.get("error", {}) if isinstance(data, dict) else {}
            raise ModooError(
                err.get("message") or f"DevDive 오류 (HTTP {resp.status_code})",
                code=err.get("code"),
                status=resp.status_code,
            )

        content = data.get("content") if isinstance(data, dict) else None
        if not content:
            raise ModooError("DevDive 응답에 content가 없습니다.", status=502)
        return content

    async def _chat_json(
        self,
        system_prompt: str,
        user_message: str,
        schema: type[BaseModel],
        temperature: float,
        max_tokens: int,
    ) -> BaseModel:
        """채팅 후 JSON을 파싱·검증한다. 일시 오류는 백오프, 스키마 위반은 재생성."""
        last_error: Exception | None = None
        for attempt in range(self._max_retries + 1):
            try:
                content = await self._chat(
                    system_prompt, user_message + _JSON_ONLY, temperature, max_tokens
                )
            except ModooError as exc:
                last_error = exc
                if exc.retryable and attempt < self._max_retries:
                    await asyncio.sleep(1.5 * (attempt + 1))
                    continue
                raise
            try:
                return schema.model_validate(_extract_json(content))
            except (ValidationError, json.JSONDecodeError, ValueError) as exc:
                last_error = exc  # JSON이 계약과 어긋남 — 다음 시도에서 다시 생성
        raise last_error

    # ---- LLMProvider 도메인 메서드 ----------------------------------------

    async def build_persona(self, user_id: str, answers: list[dict]) -> dict:
        output = await self._chat_json(
            PERSONA_SYSTEM_PROMPT + _PERSONA_JSON_HINT,
            build_persona_user_message(answers),
            PersonaOutput,
            temperature=0.6,
            max_tokens=2000,
        )
        persona = output.model_dump()
        persona["user_id"] = user_id
        persona["ai_generated"] = True
        persona["embedding"] = await self._get_embedder().embed(persona_embedding_text(persona))
        return persona

    async def update_persona(
        self, user_id: str, current_persona: dict, answer: dict
    ) -> dict:
        output = await self._chat_json(
            PERSONA_SYSTEM_PROMPT + _PERSONA_JSON_HINT,
            build_persona_update_user_message(current_persona, answer),
            PersonaOutput,
            temperature=0.45,
            max_tokens=2000,
        )
        persona = output.model_dump()
        persona["user_id"] = user_id
        persona["ai_generated"] = True
        persona["embedding"] = await self._get_embedder().embed(persona_embedding_text(persona))
        return persona

    async def run_simulation(
        self,
        my_persona: dict,
        their_persona: dict,
        max_turns: int = 20,
    ) -> AsyncIterator[dict]:
        """원샷 — 양쪽 정보를 한 번에 주고 대화 전체를 1콜로 생성한다."""
        system_prompt, user_message = build_oneshot_simulation_prompt(
            my_persona, their_persona, max_turns=max_turns,
        )
        output = await self._chat_json(
            system_prompt + _SIMULATION_JSON_HINT,
            user_message,
            ConversationOutput,
            temperature=0.95,
            max_tokens=4000,
        )
        for turn in iter_finalized_turns(output.turns, max_turns):
            yield turn

    async def generate_report(
        self,
        my_persona: dict,
        their_persona: dict,
        simulation_log: list[dict],
    ) -> dict:
        output = await self._chat_json(
            REPORT_SYSTEM_PROMPT,
            build_report_user_message(my_persona, their_persona, simulation_log),
            ReportOutput,
            temperature=0.5,
            max_tokens=2000,
        )
        report = output.model_dump()
        report["ai_generated"] = True
        return report
