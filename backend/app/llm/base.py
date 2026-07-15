"""Abstract base class for LLM providers."""

from abc import ABC, abstractmethod
from typing import AsyncIterator


class LLMProvider(ABC):
    """Interface that every LLM provider must implement.

    The BFF calls an external LLM module via HTTP.  The provider can be
    switched at runtime through the ``LLM_PROVIDER`` environment variable.
    """

    @abstractmethod
    async def build_persona(
        self, user_id: str, answers: list[dict]
    ) -> dict:
        """Create the first persona snapshot from onboarding answers.

        Parameters
        ----------
        user_id:
            Firebase UID of the user.
        answers:
            List of survey answer dicts (question_id, value, …).

        Returns
        -------
        dict
            Full persona dict including 1024-dim embedding vector.
        """
        ...

    @abstractmethod
    async def update_persona(
        self, user_id: str, current_persona: dict, answer: dict
    ) -> dict:
        """Update an existing persona snapshot with one daily answer.

        The provider returns a full persona dict so persistence can keep using
        the same schema as initial persona creation.
        """
        ...

    @abstractmethod
    async def run_simulation(
        self,
        my_persona: dict,
        their_persona: dict,
        max_turns: int = 20,
    ) -> AsyncIterator[dict]:
        """Generate the agent-to-agent conversation, one turn dict at a time.

        시뮬은 '알아가기 대화'만 한다 — 약속 조율은 하지 않는다(2026-07-04 결정).
        만남은 리포트를 본 두 사용자가 수락한 뒤 직접 채팅에서 잡는다.

        Parameters
        ----------
        my_persona:
            The requesting user's persona.
        their_persona:
            The matched user's persona.
        max_turns:
            Maximum number of conversation turns to generate.

        Yields
        ------
        dict
            Individual simulation turn (speaker, text, partner_read, strategy).
        """
        ...

    async def preview_utterances(self, persona: dict) -> list[dict]:
        """페르소나 미리보기 발화 3개 생성 (P0-C) — [{"register", "text"}].

        abstractmethod가 아닌 이유: 구 provider 구현이 깨지지 않게 점진 도입.
        """
        raise NotImplementedError(f"{type(self).__name__}는 preview를 지원하지 않습니다.")

    async def embed_persona(self, persona: dict) -> list[float] | None:
        """페르소나 텍스트 임베딩 재계산 (PATCH로 traits가 바뀌었을 때). None=미지원."""
        return None

    @abstractmethod
    async def generate_report(
        self,
        my_persona: dict,
        their_persona: dict,
        simulation_log: list[dict],
    ) -> dict:
        """Call ``POST /llm/report``.

        Parameters
        ----------
        my_persona:
            The requesting user's persona.
        their_persona:
            The matched user's persona.
        simulation_log:
            Full list of simulation turns produced by ``run_simulation``.

        Returns
        -------
        dict
            Chemistry report with score, findings, warnings, etc.
        """
        ...
