"""Factory that instantiates the correct LLM provider based on configuration."""

from app.llm.base import LLMProvider
from app.config import settings


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

        case "hf":
            from app.llm.hf import HuggingFaceLLMProvider

            return HuggingFaceLLMProvider(
                base_url=settings.llm_base_url,
                api_token=settings.hf_api_token,
            )

        case "midm_local":
            from app.llm.midm_local import MiDMLocalProvider

            return MiDMLocalProvider(base_url=settings.llm_base_url)

        case _:
            raise ValueError(
                f"Unknown LLM provider: {name!r}. "
                f"Valid options: mock, hf, midm_local"
            )
