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
        """Call ``POST /llm/persona``.

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
    async def run_simulation(
        self,
        my_persona: dict,
        their_persona: dict,
        max_turns: int = 20,
        my_slots: list[dict] | None = None,
        their_slots: list[dict] | None = None,
    ) -> AsyncIterator[dict]:
        """Call ``POST /llm/simulate``.

        Yields simulation turn dicts streamed via SSE from the LLM module.

        Parameters
        ----------
        my_persona:
            The requesting user's persona.
        their_persona:
            The matched user's persona.
        max_turns:
            Maximum number of conversation turns to generate.
        my_slots / their_slots:
            Each user's available meeting slots
            ([{"date": "YYYY-MM-DD", "time": "점심"|"저녁"}]).  When both are
            non-empty the agents negotiate a concrete slot in conversation;
            otherwise they only agree on the intent to meet.

        Yields
        ------
        dict
            Individual simulation turn (speaker, content, signals, …).
        """
        ...

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

    @abstractmethod
    async def generate_starters(
        self,
        my_persona: dict,
        their_persona: dict,
        recent_history: list[dict] | None = None,
    ) -> dict:
        """Call ``POST /llm/starters``.

        Parameters
        ----------
        my_persona:
            The requesting user's persona.
        their_persona:
            The matched user's persona.
        recent_history:
            Optional recent chat messages for context continuity.

        Returns
        -------
        dict
            Chat starters dict with suggested opening messages.
        """
        ...
