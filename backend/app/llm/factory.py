"""Factory that instantiates the correct LLM provider based on configuration."""

from app.config import settings
from app.llm.base import LLMProvider


def create_llm_provider(provider_name: str | None = None) -> LLMProvider:
    """Return an :class:`LLMProvider` instance for the given *provider_name*.

    When *provider_name* is ``None`` the value of the ``LLM_PROVIDER``
    environment variable (via ``settings.llm_provider``) is used.  Defaults to
    ``"mock"``.
    """
    name = provider_name or settings.llm_provider

    match name:
        case "mock":
            from app.llm.mock import MockLLMProvider

            return MockLLMProvider()

        case "gemini":
            from app.llm.gemini import GeminiProvider

            return GeminiProvider(
                api_key=settings.gemini_api_key,
                chat_model=settings.gemini_chat_model,
                embedding_model=settings.gemini_embedding_model,
                embedding_dim=settings.embedding_dim,
            )

        case _:
            raise ValueError(
                f"Unknown LLM provider: {name!r}. Valid options: mock, gemini"
            )
