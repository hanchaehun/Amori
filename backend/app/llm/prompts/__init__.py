"""한국어 프롬프트 템플릿 패키지.

구 ``llm/`` 모듈(KT Mi:dm 셀프호스팅 계획)의 프롬프트 엔지니어링 책임이
이 패키지로 이관되었다. Flutter 클라이언트에 있던 검증된 한국어 프롬프트를
시드로 가져왔으며, 출력 형태는 ``shared/schemas/`` 계약을 따른다.

담당: 이현정 — LLM 품질 작업은 이 디렉토리 안에서만 이루어진다.
"""

from app.llm.prompts.persona import (
    PERSONA_SYSTEM_PROMPT,
    build_persona_update_user_message,
    build_persona_user_message,
)
from app.llm.prompts.report import REPORT_SYSTEM_PROMPT, build_report_user_message
from app.llm.prompts.simulation import (
    build_agent_system_prompt,
    build_oneshot_simulation_prompt,
)
from app.llm.prompts.starters import STARTERS_SYSTEM_PROMPT, build_starters_user_message

__all__ = [
    "PERSONA_SYSTEM_PROMPT",
    "build_persona_update_user_message",
    "build_persona_user_message",
    "REPORT_SYSTEM_PROMPT",
    "build_report_user_message",
    "build_agent_system_prompt",
    "build_oneshot_simulation_prompt",
    "STARTERS_SYSTEM_PROMPT",
    "build_starters_user_message",
]
