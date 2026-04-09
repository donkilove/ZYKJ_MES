import json
import time
from datetime import UTC, datetime
from threading import RLock

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, oauth2_scheme
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.process_stage import ProcessStage
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.me import ChangePasswordRequest, CurrentSessionResult, ProfileResult
from app.services.audit_service import write_audit_log
from app.services.session_service import get_current_session_projection, mark_session_logout
from app.services.user_service import change_user_password


router = APIRouter()
_ME_SESSION_RESPONSE_CACHE: dict[str, tuple[float, bytes]] = {}
_ME_SESSION_RESPONSE_CACHE_LOCK = RLock()
_ME_SESSION_RESPONSE_CACHE_TTL_SECONDS = 10


def _my_session_response_cache_key(*, user_id: int, session_token_id: str) -> str:
    return f"me_session:{user_id}:{session_token_id}"


def _get_my_session_response_bytes(cache_key: str) -> bytes | None:
    with _ME_SESSION_RESPONSE_CACHE_LOCK:
        cached = _ME_SESSION_RESPONSE_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, payload_bytes = cached
        if expire_at <= time.monotonic():
            _ME_SESSION_RESPONSE_CACHE.pop(cache_key, None)
            return None
        return payload_bytes


def _set_my_session_response_bytes(cache_key: str, payload: dict[str, object]) -> bytes:
    payload_bytes = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    with _ME_SESSION_RESPONSE_CACHE_LOCK:
        _ME_SESSION_RESPONSE_CACHE[cache_key] = (
            time.monotonic() + _ME_SESSION_RESPONSE_CACHE_TTL_SECONDS,
            payload_bytes,
        )
    return payload_bytes


def _invalidate_my_session_response_cache_by_session_token_id(session_token_id: str) -> None:
    key_suffix = f":{session_token_id}"
    with _ME_SESSION_RESPONSE_CACHE_LOCK:
        expired_keys = [
            key
            for key in _ME_SESSION_RESPONSE_CACHE
            if key.endswith(key_suffix)
        ]
        for key in expired_keys:
            _ME_SESSION_RESPONSE_CACHE.pop(key, None)


@router.get("/profile", response_model=ApiResponse[ProfileResult])
def get_my_profile(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
) -> ApiResponse[ProfileResult]:
    stage_name = None
    if current_user.stage_id is not None:
        stage_name = (
            db.execute(
                select(ProcessStage.name).where(ProcessStage.id == current_user.stage_id)
            ).scalar_one_or_none()
        )
    return success_response(
        ProfileResult(
            id=current_user.id,
            username=current_user.username,
            full_name=current_user.full_name,
            role_code=current_user.roles[0].code if current_user.roles else None,
            role_name=current_user.roles[0].name if current_user.roles else None,
            stage_id=current_user.stage_id,
            stage_name=stage_name,
            is_active=current_user.is_active,
            created_at=current_user.created_at,
            last_login_at=current_user.last_login_at,
            last_login_ip=current_user.last_login_ip,
            password_changed_at=current_user.password_changed_at,
        )
    )


@router.post("/password", response_model=ApiResponse[dict[str, bool]])
def change_my_password(
    payload: ChangePasswordRequest,
    request: Request,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[dict[str, bool]]:
    if payload.new_password != payload.confirm_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="新密码与确认密码不一致"
        )
    ok, error = change_user_password(
        db,
        user=current_user,
        old_password=payload.old_password,
        new_password=payload.new_password,
        confirm_password=payload.confirm_password,
    )
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=error or "修改密码失败"
        )

    sid = None
    try:
        payload_token = decode_access_token(token)
        sid = str(payload_token.get("sid") or "").strip() or None
    except Exception:
        sid = None
    if sid:
        _invalidate_my_session_response_cache_by_session_token_id(sid)
        mark_session_logout(db, session_token_id=sid, forced_offline=False)

    write_audit_log(
        db,
        action_code="me.change_password",
        action_name="修改本人密码",
        target_type="user",
        target_id=str(current_user.id),
        target_name=current_user.username,
        operator=current_user,
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    return success_response({"changed": True}, message="password_changed")


@router.get("/session", response_model=ApiResponse[CurrentSessionResult])
def get_my_session(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> ApiResponse[CurrentSessionResult] | Response:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid authentication credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload_token = decode_access_token(token)
        sid = str(payload_token.get("sid") or "").strip() or None
        user_id = int(str(payload_token.get("sub") or "").strip())
    except Exception:
        raise credentials_error
    if not sid:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Current session not found"
        )
    cache_key = _my_session_response_cache_key(
        user_id=user_id,
        session_token_id=sid,
    )
    cached_payload = _get_my_session_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")

    row = get_current_session_projection(db, session_token_id=sid)
    if (
        not row
        or row.user_id != user_id
        or row.status != "active"
        or row.expires_at <= datetime.now(UTC)
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Current session not found"
        )
    remaining = max(0, int((row.expires_at - datetime.now(UTC)).total_seconds()))
    response_payload = success_response(
        CurrentSessionResult(
            session_token_id=row.session_token_id,
            login_time=row.login_time,
            last_active_at=row.last_active_at,
            expires_at=row.expires_at,
            status=row.status,
            remaining_seconds=remaining,
        )
    ).model_dump(mode="json")
    payload_bytes = _set_my_session_response_bytes(cache_key, response_payload)
    return Response(content=payload_bytes, media_type="application/json")
