<<<<<<< HEAD
=======
import logging
>>>>>>> 1f4677efd502e60c9e3637dc833cfd3b7dd9e418
import uuid

from fastapi import Request
from fastapi.exceptions import HTTPException
from firebase_admin import auth
<<<<<<< HEAD

from app.config import settings

=======
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.config import settings

logger = logging.getLogger(__name__)

>>>>>>> 1f4677efd502e60c9e3637dc833cfd3b7dd9e418
# 로컬 개발용 인증 우회 — Firebase 서비스 계정 키 없이 앱을 백엔드에 붙인다.
# DEBUG=true에서만 살아있는 경로이므로 운영 배포 시 반드시 DEBUG=false.
_DEV_TOKEN_PREFIX = "dev:"

<<<<<<< HEAD
=======
# google-auth 폴백 검증용 인증서 요청 세션 — 프로세스당 1개면 충분.
_cert_request = google_requests.Request()


def _unauthorized(message: str) -> HTTPException:
    return HTTPException(
        status_code=401,
        detail={
            "error_code": "UNAUTHORIZED",
            "message": message,
            "request_id": str(uuid.uuid4()),
        },
    )


def _decoded_to_user(decoded: dict) -> dict:
    # firebase_admin은 "uid", google-auth 폴백은 "sub"/"user_id"에 uid가 담긴다.
    uid = decoded.get("uid") or decoded.get("sub") or decoded.get("user_id")
    if not uid:
        raise _unauthorized("유효하지 않은 인증 토큰입니다.")
    return {
        "uid": uid,
        "email": decoded.get("email"),
        "name": decoded.get("name"),
    }

>>>>>>> 1f4677efd502e60c9e3637dc833cfd3b7dd9e418

async def get_current_user(request: Request) -> dict:
    """Extract and verify Firebase ID token from Authorization header.
    Returns dict with uid and other token claims."""
    authorization = request.headers.get("Authorization")
    if not authorization or not authorization.startswith("Bearer "):
<<<<<<< HEAD
        raise HTTPException(
            status_code=401,
            detail={
                "error_code": "UNAUTHORIZED",
                "message": "인증 토큰이 필요합니다.",
                "request_id": str(uuid.uuid4()),
            },
        )
=======
        raise _unauthorized("인증 토큰이 필요합니다.")
>>>>>>> 1f4677efd502e60c9e3637dc833cfd3b7dd9e418
    token = authorization.split("Bearer ")[1]
    if settings.debug and token.startswith(_DEV_TOKEN_PREFIX):
        dev_uid = token[len(_DEV_TOKEN_PREFIX):].strip()
        if dev_uid:
            return {
                "uid": dev_uid,
                "email": f"{dev_uid}@dev.local",
                "name": dev_uid,
                "is_dev": True,
            }
    try:
<<<<<<< HEAD
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
=======
        return _decoded_to_user(auth.verify_id_token(token))
    except auth.ExpiredIdTokenError:
        raise _unauthorized("인증 토큰이 만료되었습니다.")
    except auth.InvalidIdTokenError as error:
        # 토큰 자체의 문제(위조·형식 오류 등) — 폴백해도 결과는 같다.
        logger.warning("Firebase 토큰 검증 실패: %s", error)
        raise _unauthorized("유효하지 않은 인증 토큰입니다.")
    except HTTPException:
        raise
    except Exception as error:
        # 토큰이 아니라 서버 환경의 문제 — 대표적으로 서비스계정 키 부재
        # (DefaultCredentialsError). firebase_admin은 자격증명 없이는 어떤
        # 토큰도 검증하지 못하므로, 서비스계정 키가 필요 없는 google-auth
        # 공개 인증서 검증으로 폴백한다 (서명·aud·만료를 동일하게 확인).
        logger.warning(
            "firebase_admin 검증 불가(%s: %s) — google-auth 공개 인증서 검증으로 폴백",
            type(error).__name__,
            error,
        )
        try:
            decoded = google_id_token.verify_firebase_token(
                token, _cert_request, audience=settings.firebase_project_id
            )
        except Exception as fallback_error:
            logger.warning("google-auth 폴백 검증 실패: %s", fallback_error)
            if "expired" in str(fallback_error).lower():
                raise _unauthorized("인증 토큰이 만료되었습니다.")
            raise _unauthorized("유효하지 않은 인증 토큰입니다.")
        return _decoded_to_user(decoded)
>>>>>>> 1f4677efd502e60c9e3637dc833cfd3b7dd9e418
