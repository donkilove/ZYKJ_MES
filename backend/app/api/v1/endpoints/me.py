from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, oauth2_scheme
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.me import ChangePasswordRequest, CurrentSessionResult, ProfileResult
from app.services.audit_service import write_audit_log
from app.services.session_service import get_user_current_session, mark_session_logout
from app.services.user_service import change_user_password


router = APIRouter()


@router.get("/profile", response_model=ApiResponse[ProfileResult])
def get_my_profile(
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[ProfileResult]:
    return success_response(
        ProfileResult(
            id=current_user.id,
            username=current_user.username,
            full_name=current_user.full_name,
            role_codes=sorted(role.code for role in current_user.roles),
            role_names=sorted(role.name for role in current_user.roles),
            stage_name=current_user.stage.name if current_user.stage else None,
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
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="New password and confirm password do not match")
    ok, error = change_user_password(
        db,
        user=current_user,
        old_password=payload.old_password,
        new_password=payload.new_password,
        confirm_password=payload.confirm_password,
    )
    if not ok:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error or "Failed to change password")

    sid = None
    try:
        payload_token = decode_access_token(token)
        sid = str(payload_token.get("sid") or "").strip() or None
    except Exception:
        sid = None
    if sid:
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
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[CurrentSessionResult]:
    sid = None
    try:
        payload_token = decode_access_token(token)
        sid = str(payload_token.get("sid") or "").strip() or None
    except Exception:
        sid = None
    if not sid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Current session not found")

    row = get_user_current_session(db, session_token_id=sid)
    if not row or row.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Current session not found")
    remaining = max(0, int((row.expires_at - datetime.now(UTC)).total_seconds()))
    return success_response(
        CurrentSessionResult(
            session_token_id=row.session_token_id,
            login_time=row.login_time,
            last_active_at=row.last_active_at,
            expires_at=row.expires_at,
            status=row.status,
            remaining_seconds=remaining,
        )
    )
