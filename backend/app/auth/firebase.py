import uuid

from fastapi import Request
from fastapi.exceptions import HTTPException
from firebase_admin import auth

from app.config import settings

# 로컬 개발용 인증 우회 — Firebase 서비스 계정 키 없이 앱을 백엔드에 붙인다.
# DEBUG=true에서만 살아있는 경로이므로 운영 배포 시 반드시 DEBUG=false.
_DEV_TOKEN_PREFIX = "dev:"


async def get_current_user(request: Request) -> dict:
    """Extract and verify Firebase ID token from Authorization header.
    Returns dict with uid and other token claims."""
    authorization = request.headers.get("Authorization")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail={
                "error_code": "UNAUTHORIZED",
                "message": "인증 토큰이 필요합니다.",
                "request_id": str(uuid.uuid4()),
            },
        )
    token = authorization.split("Bearer ")[1]
    if settings.debug and token.startswith(_DEV_TOKEN_PREFIX):
        dev_uid = token[len(_DEV_TOKEN_PREFIX):].strip()
        if dev_uid:
            return {"uid": dev_uid, "email": f"{dev_uid}@dev.local", "name": dev_uid}
    try:
        decoded = auth.verify_id_token(token)
        return {
            "uid": decoded["uid"],
            "email": decoded.get("email"),
            "name": decoded.get("name"),
        }
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=401,
            detail={
                "error_code": "UNAUTHORIZED",
                "message": "인증 토큰이 만료되었습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )
    except Exception:
        raise HTTPException(
            status_code=401,
            detail={
                "error_code": "UNAUTHORIZED",
                "message": "유효하지 않은 인증 토큰입니다.",
                "request_id": str(uuid.uuid4()),
            },
        )
