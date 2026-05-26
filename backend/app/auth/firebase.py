import uuid

from fastapi import Request
from fastapi.exceptions import HTTPException
from firebase_admin import auth


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
