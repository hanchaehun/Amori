"""LLM provider abstraction layer.

Usage::

    from app.llm import create_llm_provider

    llm = create_llm_provider()          # reads LLM_PROVIDER env var
    persona = await llm.build_persona(uid, answers)
"""

from app.llm.base import LLMProvider
from app.llm.factory import create_llm_provider

__all__ = ["LLMProvider", "create_llm_provider"]
