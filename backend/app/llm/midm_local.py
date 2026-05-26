"""Self-hosted MiDM (local) LLM provider."""

from __future__ import annotations

import json
import logging
from typing import AsyncIterator

import httpx

from app.llm.base import LLMProvider

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(connect=10.0, read=120.0, write=10.0, pool=10.0)


class MiDMLocalProvider(LLMProvider):
    """Calls a self-hosted LLM module (no authentication required).

    Parameters
    ----------
    base_url:
        Root URL of the local LLM server (e.g. ``http://localhost:8001``).
    """

    def __init__(self, base_url: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._headers = {"Content-Type": "application/json"}

    # ----- helpers -----

    def _url(self, path: str) -> str:
        return f"{self._base_url}{path}"

    async def _post_json(self, path: str, payload: dict) -> dict:
        """POST *payload* and return the parsed JSON response."""
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            try:
                resp = await client.post(
                    self._url(path),
                    json=payload,
                    headers=self._headers,
                )
                resp.raise_for_status()
                return resp.json()
            except httpx.TimeoutException as exc:
                logger.error("LLM request timed out: %s %s", path, exc)
                raise RuntimeError(f"LLM request timed out: {path}") from exc
            except httpx.ConnectError as exc:
                logger.error("Cannot connect to local LLM server: %s", exc)
                raise RuntimeError(
                    f"Cannot connect to local LLM server at {self._base_url}"
                ) from exc
            except httpx.HTTPStatusError as exc:
                logger.error(
                    "Local LLM server returned %s for %s: %s",
                    exc.response.status_code,
                    path,
                    exc.response.text[:500],
                )
                raise RuntimeError(
                    f"Local LLM server error {exc.response.status_code} on {path}"
                ) from exc

    # ----- interface -----

    async def build_persona(
        self, user_id: str, answers: list[dict]
    ) -> dict:
        return await self._post_json(
            "/llm/persona",
            {"user_id": user_id, "answers": answers},
        )

    async def run_simulation(
        self,
        my_persona: dict,
        their_persona: dict,
        max_turns: int = 20,
    ) -> AsyncIterator[dict]:
        payload = {
            "my_persona": my_persona,
            "their_persona": their_persona,
            "max_turns": max_turns,
        }
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            try:
                async with client.stream(
                    "POST",
                    self._url("/llm/simulate"),
                    json=payload,
                    headers=self._headers,
                ) as resp:
                    resp.raise_for_status()
                    buffer = ""
                    async for chunk in resp.aiter_text():
                        buffer += chunk
                        while "\n\n" in buffer:
                            frame, buffer = buffer.split("\n\n", 1)
                            for line in frame.splitlines():
                                if line.startswith("data:"):
                                    data_str = line[len("data:"):].strip()
                                    if data_str == "[DONE]":
                                        return
                                    try:
                                        yield json.loads(data_str)
                                    except json.JSONDecodeError:
                                        logger.warning(
                                            "Ignoring malformed SSE data: %s",
                                            data_str[:200],
                                        )
            except httpx.TimeoutException as exc:
                logger.error("Simulation stream timed out: %s", exc)
                raise RuntimeError("Simulation stream timed out") from exc
            except httpx.ConnectError as exc:
                logger.error("Cannot connect to local LLM server: %s", exc)
                raise RuntimeError(
                    f"Cannot connect to local LLM server at {self._base_url}"
                ) from exc
            except httpx.HTTPStatusError as exc:
                logger.error(
                    "Simulation stream returned %s: %s",
                    exc.response.status_code,
                    exc.response.text[:500],
                )
                raise RuntimeError(
                    f"Simulation stream error {exc.response.status_code}"
                ) from exc

    async def generate_report(
        self,
        my_persona: dict,
        their_persona: dict,
        simulation_log: list[dict],
    ) -> dict:
        return await self._post_json(
            "/llm/report",
            {
                "my_persona": my_persona,
                "their_persona": their_persona,
                "simulation_log": simulation_log,
            },
        )

    async def generate_starters(
        self,
        my_persona: dict,
        their_persona: dict,
        recent_history: list[dict] | None = None,
    ) -> dict:
        return await self._post_json(
            "/llm/starters",
            {
                "my_persona": my_persona,
                "their_persona": their_persona,
                "recent_history": recent_history or [],
            },
        )
