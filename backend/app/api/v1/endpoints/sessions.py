from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
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


@router.get("/login-logs", response_model=ApiResponse[LoginLogListResult])
def get_login_logs(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    username: str | None = Query(default=None),
    success: bool | None = Query(default=None),
    start_time: datetime | None = Query(default=None),
    end_time: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.sessions.login_logs.list")),
) -> ApiResponse[LoginLogListResult]:
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
    return success_response(
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
    )


@router.get("/online", response_model=ApiResponse[OnlineSessionListResult])
def get_online_sessions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    keyword: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.sessions.online.list")),
) -> ApiResponse[OnlineSessionListResult]:
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
    return success_response(OnlineSessionListResult(total=total, items=items))


@router.post("/force-offline", response_model=ApiResponse[ForceOfflineResult])
def force_offline(
    payload: ForceOfflineRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.sessions.force_offline")),
) -> ApiResponse[ForceOfflineResult]:
    role_codes = {role.code for role in current_user.roles}
    if ROLE_SYSTEM_ADMIN not in role_codes:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="仅系统管理员可执行强制下线")
    target_session = db.execute(
        select(UserSession).where(UserSession.session_token_id == payload.session_token_id)
    ).scalar_one_or_none()
    affected = force_offline_sessions(db, session_token_ids=[payload.session_token_id])
    if affected < 1:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Online session not found")
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
    current_user: User = Depends(require_permission("user.sessions.force_offline.batch")),
) -> ApiResponse[ForceOfflineResult]:
    role_codes = {role.code for role in current_user.roles}
    if ROLE_SYSTEM_ADMIN not in role_codes:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="仅系统管理员可执行批量强制下线")
    target_sessions = db.execute(
        select(UserSession).where(UserSession.session_token_id.in_(payload.session_token_ids))
    ).scalars().all()
    affected = force_offline_sessions(db, session_token_ids=payload.session_token_ids)
    write_audit_log(
        db,
        action_code="session.force_offline.batch",
        action_name="批量强制下线",
        target_type="session",
        operator=current_user,
        after_data={"session_token_ids": payload.session_token_ids, "affected": affected},
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
