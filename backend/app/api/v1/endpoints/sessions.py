import json
import time
from datetime import datetime
from threading import RLock

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission, require_permission_fast
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.db.session import get_db
from app.models.user_session import UserSession
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.session import (
    BatchForceOfflineRequest,
    ForceOfflineRequest,
    ForceOfflineResult,
    LoginLogItem,
    LoginLogListResult,
    OnlineSessionItem,
    OnlineSessionListResult,
)
from app.services.audit_service import write_audit_log
from app.services.message_service import create_message_for_users
from app.services.session_service import (
    cleanup_expired_login_logs_if_due,
    force_offline_sessions,
    list_login_logs,
    list_online_sessions,
)


router = APIRouter()
_SESSIONS_ONLINE_RESPONSE_CACHE: dict[str, tuple[float, bytes]] = {}
_SESSIONS_ONLINE_RESPONSE_CACHE_LOCK = RLock()
_SESSIONS_ONLINE_RESPONSE_CACHE_TTL_SECONDS = 2
_SESSIONS_LOGIN_LOGS_RESPONSE_CACHE: dict[str, tuple[float, bytes]] = {}
_SESSIONS_LOGIN_LOGS_RESPONSE_CACHE_LOCK = RLock()
_SESSIONS_LOGIN_LOGS_RESPONSE_CACHE_TTL_SECONDS = 2


def _sessions_online_response_cache_key(
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    status_filter: str | None,
) -> str:
    normalized_keyword = (keyword or "").strip().lower()
    normalized_status = (status_filter or "").strip().lower()
    return f"{page}|{page_size}|{normalized_keyword}|{normalized_status}"


def _sessions_login_logs_response_cache_key(
    *,
    page: int,
    page_size: int,
    username: str | None,
    success: bool | None,
    start_time: datetime | None,
    end_time: datetime | None,
) -> str:
    normalized_username = (username or "").strip().lower()
    normalized_success = ""
    if success:
        normalized_success = "1"
    elif success is False:
        normalized_success = "0"
    normalized_start_time = start_time.isoformat() if start_time else ""
    normalized_end_time = end_time.isoformat() if end_time else ""
    return (
        f"{page}|{page_size}|{normalized_username}|{normalized_success}|"
        f"{normalized_start_time}|{normalized_end_time}"
    )


def _get_cached_sessions_online_response(cache_key: str) -> bytes | None:
    now_monotonic = time.monotonic()
    with _SESSIONS_ONLINE_RESPONSE_CACHE_LOCK:
        cached = _SESSIONS_ONLINE_RESPONSE_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, payload_bytes = cached
        if expire_at <= now_monotonic:
            _SESSIONS_ONLINE_RESPONSE_CACHE.pop(cache_key, None)
            return None
        return payload_bytes


def _set_cached_sessions_online_response(
    cache_key: str, payload: dict[str, object]
) -> bytes:
    payload_bytes = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    with _SESSIONS_ONLINE_RESPONSE_CACHE_LOCK:
        _SESSIONS_ONLINE_RESPONSE_CACHE[cache_key] = (
            time.monotonic() + _SESSIONS_ONLINE_RESPONSE_CACHE_TTL_SECONDS,
            payload_bytes,
        )
    return payload_bytes


def _get_cached_sessions_login_logs_response(cache_key: str) -> bytes | None:
    now_monotonic = time.monotonic()
    with _SESSIONS_LOGIN_LOGS_RESPONSE_CACHE_LOCK:
        cached = _SESSIONS_LOGIN_LOGS_RESPONSE_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, payload_bytes = cached
        if expire_at <= now_monotonic:
            _SESSIONS_LOGIN_LOGS_RESPONSE_CACHE.pop(cache_key, None)
            return None
        return payload_bytes


def _set_cached_sessions_login_logs_response(
    cache_key: str, payload: dict[str, object]
) -> bytes:
    payload_bytes = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    with _SESSIONS_LOGIN_LOGS_RESPONSE_CACHE_LOCK:
        _SESSIONS_LOGIN_LOGS_RESPONSE_CACHE[cache_key] = (
            time.monotonic() + _SESSIONS_LOGIN_LOGS_RESPONSE_CACHE_TTL_SECONDS,
            payload_bytes,
        )
    return payload_bytes


def _invalidate_sessions_online_response_cache() -> None:
    with _SESSIONS_ONLINE_RESPONSE_CACHE_LOCK:
        _SESSIONS_ONLINE_RESPONSE_CACHE.clear()


@router.get("/login-logs", response_model=ApiResponse[LoginLogListResult])
def get_login_logs(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    username: str | None = Query(default=None),
    success: bool | None = Query(default=None),
    start_time: datetime | None = Query(default=None),
    end_time: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("user.sessions.login_logs.list")),
) -> ApiResponse[LoginLogListResult] | Response:
    cache_key = _sessions_login_logs_response_cache_key(
        page=page,
        page_size=page_size,
        username=username,
        success=success,
        start_time=start_time,
        end_time=end_time,
    )
    cached_payload = _get_cached_sessions_login_logs_response(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")

    cleanup_expired_login_logs_if_due(db)
    total, items = list_login_logs(
        db,
        page=page,
        page_size=page_size,
        username=username,
        success=success,
        start_time=start_time,
        end_time=end_time,
    )
    response_payload = success_response(
        LoginLogListResult(
            total=total,
            items=[
                LoginLogItem(
                    id=row.id,
                    login_time=row.login_time,
                    username=row.username,
                    success=row.success,
                    ip_address=row.ip_address,
                    terminal_info=row.terminal_info,
                    failure_reason=row.failure_reason,
                    session_token_id=row.session_token_id,
                )
                for row in items
            ],
        )
    ).model_dump(mode="json")
    payload_bytes = _set_cached_sessions_login_logs_response(
        cache_key, response_payload
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get("/online", response_model=ApiResponse[OnlineSessionListResult])
def get_online_sessions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    keyword: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("user.sessions.online.list")),
) -> ApiResponse[OnlineSessionListResult] | Response:
    cache_key = _sessions_online_response_cache_key(
        page=page,
        page_size=page_size,
        keyword=keyword,
        status_filter=status_filter,
    )
    cached_payload_bytes = _get_cached_sessions_online_response(cache_key)
    if cached_payload_bytes is not None:
        return Response(content=cached_payload_bytes, media_type="application/json")

    total, rows = list_online_sessions(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        status_filter=status_filter,
    )
    items = []
    for row in rows:
        items.append(
            OnlineSessionItem(
                id=row.id,
                session_token_id=row.session_token_id,
                user_id=row.user_id,
                username=row.username,
                role_code=row.role_code,
                role_name=row.role_name,
                stage_id=row.stage_id,
                stage_name=row.stage_name,
                login_time=row.login_time,
                last_active_at=row.last_active_at,
                expires_at=row.expires_at,
                ip_address=row.ip_address,
                terminal_info=row.terminal_info,
                status=row.status,
            )
        )
    response_payload = success_response(
        OnlineSessionListResult(total=total, items=items)
    ).model_dump(mode="json")
    payload_bytes = _set_cached_sessions_online_response(cache_key, response_payload)
    return Response(content=payload_bytes, media_type="application/json")


@router.post("/force-offline", response_model=ApiResponse[ForceOfflineResult])
def force_offline(
    payload: ForceOfflineRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.sessions.force_offline")),
) -> ApiResponse[ForceOfflineResult]:
    role_codes = {role.code for role in current_user.roles}
    if ROLE_SYSTEM_ADMIN not in role_codes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="仅系统管理员可执行强制下线"
        )
    target_session = db.execute(
        select(UserSession).where(
            UserSession.session_token_id == payload.session_token_id
        )
    ).scalar_one_or_none()
    affected = force_offline_sessions(db, session_token_ids=[payload.session_token_id])
    if affected < 1:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Online session not found"
        )
    _invalidate_sessions_online_response_cache()
    write_audit_log(
        db,
        action_code="session.force_offline",
        action_name="强制下线",
        target_type="session",
        target_id=payload.session_token_id,
        operator=current_user,
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    if target_session is not None:
        create_message_for_users(
            db,
            message_type="warning",
            priority="important",
            title="当前会话已被强制下线",
            summary="检测到管理员主动终止您的在线会话，请重新登录后继续操作。",
            content=(
                f"您的会话已被管理员 {current_user.username} 强制下线。"
                "如非本人预期操作，请联系系统管理员核实。"
            ),
            source_module="user",
            source_type="force_offline",
            source_id=payload.session_token_id,
            source_code=payload.session_token_id,
            target_page_code="user",
            target_tab_code="account_settings",
            recipient_user_ids=[target_session.user_id],
            dedupe_key=f"force_offline_{payload.session_token_id}",
            created_by_user_id=current_user.id,
        )
    return success_response(ForceOfflineResult(affected=affected))


@router.post("/force-offline/batch", response_model=ApiResponse[ForceOfflineResult])
def batch_force_offline(
    payload: BatchForceOfflineRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("user.sessions.force_offline.batch")
    ),
) -> ApiResponse[ForceOfflineResult]:
    role_codes = {role.code for role in current_user.roles}
    if ROLE_SYSTEM_ADMIN not in role_codes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="仅系统管理员可执行批量强制下线",
        )
    target_sessions = (
        db.execute(
            select(UserSession).where(
                UserSession.session_token_id.in_(payload.session_token_ids)
            )
        )
        .scalars()
        .all()
    )
    affected = force_offline_sessions(db, session_token_ids=payload.session_token_ids)
    _invalidate_sessions_online_response_cache()
    write_audit_log(
        db,
        action_code="session.force_offline.batch",
        action_name="批量强制下线",
        target_type="session",
        operator=current_user,
        after_data={
            "session_token_ids": payload.session_token_ids,
            "affected": affected,
        },
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    for session_row in target_sessions:
        create_message_for_users(
            db,
            message_type="warning",
            priority="important",
            title="当前会话已被强制下线",
            summary="检测到管理员主动终止您的在线会话，请重新登录后继续操作。",
            content=(
                f"您的会话已被管理员 {current_user.username} 强制下线。"
                "如非本人预期操作，请联系系统管理员核实。"
            ),
            source_module="user",
            source_type="force_offline",
            source_id=session_row.session_token_id,
            source_code=session_row.session_token_id,
            target_page_code="user",
            target_tab_code="account_settings",
            recipient_user_ids=[session_row.user_id],
            dedupe_key=f"force_offline_{session_row.session_token_id}",
            created_by_user_id=current_user.id,
        )
    return success_response(ForceOfflineResult(affected=affected))
