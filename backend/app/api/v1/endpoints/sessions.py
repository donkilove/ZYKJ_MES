from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.db.session import get_db
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
from app.services.session_service import delete_expired_login_logs, force_offline_sessions, list_login_logs, list_online_sessions


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
    delete_expired_login_logs(db)
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
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.sessions.online.list")),
) -> ApiResponse[OnlineSessionListResult]:
    total, rows = list_online_sessions(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
    )
    items = []
    for session_row, user in rows:
        items.append(
            OnlineSessionItem(
                id=session_row.id,
                session_token_id=session_row.session_token_id,
                user_id=user.id,
                username=user.username,
                role_codes=sorted(role.code for role in user.roles),
                role_names=sorted(role.name for role in user.roles),
                stage_name=user.stage.name if user.stage else None,
                login_time=session_row.login_time,
                last_active_at=session_row.last_active_at,
                expires_at=session_row.expires_at,
                ip_address=session_row.login_ip,
                terminal_info=session_row.terminal_info,
                status=session_row.status,
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
    return success_response(ForceOfflineResult(affected=affected))
