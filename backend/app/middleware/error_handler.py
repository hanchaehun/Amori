import traceback
import uuid

import httpx
from fastapi import Request
from fastapi.responses import JSONResponse


async def error_handler_middleware(request: Request, call_next):
    """Catch unhandled exceptions and return standard error format."""
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    request.state.request_id = request_id
    try:
        response = await call_next(request)
        return response
    except httpx.TimeoutException:
        return JSONResponse(
            status_code=504,
            content={
                "error_code": "LLM_TIMEOUT",
                "message": "LLM 서버 응답 시간이 초과되었습니다.",
                "request_id": request_id,
            },
        )
    except httpx.ConnectError:
        return JSONResponse(
            status_code=503,
            content={
                "error_code": "LLM_UNAVAILABLE",
                "message": "LLM 서버에 연결할 수 없습니다.",
                "request_id": request_id,
            },
        )
    except Exception:
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "error_code": "INTERNAL_ERROR",
                "message": "내부 서버 오류가 발생했습니다.",
                "request_id": request_id,
            },
        )
