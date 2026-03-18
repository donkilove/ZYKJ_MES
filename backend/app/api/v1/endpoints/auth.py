from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, oauth2_scheme, require_permission
from app.core.config import settings
from app.core.security import create_access_token, decode_access_token, verify_password
from app.db.session import get_db
from app.models.registration_request import RegistrationRequest
from app.models.user import User
from app.schemas.auth import (
    AccountListResult,
    ApproveRegistrationRequest,
    BootstrapAdminResult,
    CurrentUserResult,
    LoginResult,
    RegistrationActionResult,
    RegistrationRequestItem,
    RegistrationRequestListResult,
    RegisterRequest,
    RegisterResult,
    RejectRegistrationRequest,
)
from app.schemas.common import ApiResponse, success_response
from app.services.audit_service import write_audit_log
from app.services.message_service import create_message_for_users
from app.services.online_status_service import clear_user, touch_user
from app.services.session_service import (
    create_login_log,
    create_user_session,
    delete_expired_login_logs,
    mark_session_logout,
)
from app.services.user_service import (
    approve_registration_request,
    ensure_admin_account,
    get_registration_request_by_account,
    get_registration_request_by_id,
    get_user_by_username,
    list_all_usernames,
    list_registration_requests,
    normalize_users_to_single_role,
    reject_registration_request,
    submit_registration_request,
)


router = APIRouter()


def _to_registration_item(request: RegistrationRequest) -> RegistrationRequestItem:
    return RegistrationRequestItem(
        id=request.id,
        account=request.account,
        status=request.status,
        rejected_reason=request.rejected_reason,
        reviewed_by_user_id=request.reviewed_by_user_id,
        reviewed_at=request.reviewed_at,
        created_at=request.created_at,
    )


@router.post("/login", response_model=ApiResponse[LoginResult])
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    request: Request = None,
    db: Session = Depends(get_db),
) -> ApiResponse[LoginResult]:
    username = form_data.username.strip()
    ip_address = request.client.host if request and request.client else None
    terminal_info = request.headers.get("user-agent") if request else None

    user = get_user_by_username(db, username)
    if not user:
        pending_request = get_registration_request_by_account(db, username, pending_only=True)
        reason = "Account is pending approval" if pending_request else "Incorrect username or password"
        create_login_log(
            db,
            username=username,
            user_id=None,
            success=False,
            ip_address=ip_address,
            terminal_info=terminal_info,
            failure_reason=reason,
        )
        db.commit()
        if pending_request:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=reason)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=reason)

    if not user.is_active or user.is_deleted:
        reason = "Account is disabled"
        create_login_log(
            db,
            username=username,
            user_id=user.id,
            success=False,
            ip_address=ip_address,
            terminal_info=terminal_info,
            failure_reason=reason,
        )
        db.commit()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=reason)

    if not verify_password(form_data.password, user.password_hash):
        create_login_log(
            db,
            username=username,
            user_id=user.id,
            success=False,
            ip_address=ip_address,
            terminal_info=terminal_info,
            failure_reason="Incorrect username or password",
        )
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")

    session_row = create_user_session(
        db,
        user=user,
        ip_address=ip_address,
        terminal_info=terminal_info,
    )
    create_login_log(
        db,
        username=username,
        user_id=user.id,
        success=True,
        ip_address=ip_address,
        terminal_info=terminal_info,
        session_token_id=session_row.session_token_id,
    )
    user.last_login_at = session_row.login_time
    user.last_login_ip = ip_address
    user.last_login_terminal = terminal_info
    delete_expired_login_logs(db)
    db.commit()

    touch_user(user.id)
    token = create_access_token(
        subject=str(user.id),
        extra_claims={"sid": session_row.session_token_id},
    )
    return success_response(
        LoginResult(
            access_token=token,
            token_type="bearer",
            expires_in=settings.jwt_expire_minutes * 60,
            must_change_password=user.must_change_password,
        )
    )


@router.post("/logout", response_model=ApiResponse[dict[str, bool]])
def logout(
    token: str = Depends(oauth2_scheme),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
) -> ApiResponse[dict[str, bool]]:
    sid = None
    try:
        payload = decode_access_token(token)
        sid = str(payload.get("sid") or "").strip() or None
    except Exception:
        sid = None

    if sid:
        mark_session_logout(db, session_token_id=sid, forced_offline=False)
    write_audit_log(
        db,
        action_code="auth.logout",
        action_name="主动退出登录",
        target_type="session",
        target_id=sid,
        operator=current_user,
    )
    db.commit()
    clear_user(current_user.id)
    return success_response({"logged_out": True}, message="logged_out")


@router.post("/register", response_model=ApiResponse[RegisterResult], status_code=status.HTTP_202_ACCEPTED)
def register(
    payload: RegisterRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[RegisterResult]:
    request_row, error_message = submit_registration_request(
        db,
        account=payload.account,
        password=payload.password,
    )
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not request_row:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to submit registration request")
    return success_response(
        RegisterResult(
            account=request_row.account,
            status="pending_approval",
        ),
        message="submitted",
    )


@router.post("/bootstrap-admin", response_model=ApiResponse[BootstrapAdminResult])
def bootstrap_admin_account(
    db: Session = Depends(get_db),
) -> ApiResponse[BootstrapAdminResult]:
    try:
        user, created, role_repaired = ensure_admin_account(
            db,
            password=settings.bootstrap_admin_password,
            repair_role=True,
        )
        normalized_users_count = normalize_users_to_single_role(db)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(error))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to bootstrap admin")

    return success_response(
        BootstrapAdminResult(
            username=user.username,
            created=created,
            role_repaired=role_repaired,
            normalized_users_count=normalized_users_count,
        ),
        message="bootstrapped",
    )


@router.get("/accounts", response_model=ApiResponse[AccountListResult])
def list_accounts(
    db: Session = Depends(get_db),
) -> ApiResponse[AccountListResult]:
    accounts = list_all_usernames(db)
    return success_response(AccountListResult(accounts=accounts))


@router.get("/register-requests/{request_id}", response_model=ApiResponse[RegistrationRequestItem])
def get_registration_request(
    request_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.registration_requests.list")),
) -> ApiResponse[RegistrationRequestItem]:
    request_row = get_registration_request_by_id(db, request_id)
    if not request_row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registration request not found")
    return success_response(_to_registration_item(request_row))


@router.get("/register-requests", response_model=ApiResponse[RegistrationRequestListResult])
def get_registration_requests(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    keyword: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.registration_requests.list")),
) -> ApiResponse[RegistrationRequestListResult]:
    total, items = list_registration_requests(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        status=status_filter,
    )
    return success_response(
        RegistrationRequestListResult(
            total=total,
            items=[_to_registration_item(item) for item in items],
        )
    )


@router.post("/register-requests/{request_id}/approve", response_model=ApiResponse[RegistrationActionResult])
def approve_registration(
    request_id: int,
    payload: ApproveRegistrationRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.registration_requests.approve")),
) -> ApiResponse[RegistrationActionResult]:
    request_row = get_registration_request_by_id(db, request_id)
    if not request_row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registration request not found")

    account = request_row.account
    user, error_message = approve_registration_request(
        db,
        request=request_row,
        account=payload.account,
        password=payload.password,
        role_code=payload.role_code,
        stage_id=payload.stage_id,
        reviewer=current_user,
    )
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not user:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to approve registration request")

    write_audit_log(
        db,
        action_code="registration.approve",
        action_name="审批通过",
        target_type="registration_request",
        target_id=str(request_id),
        target_name=account,
        operator=current_user,
        after_data={
            "final_account": user.username,
            "role_code": user.roles[0].code if user.roles else None,
            "stage_id": user.stage_id,
        },
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    # 通知申请人：注册审批通过
    create_message_for_users(
        db,
        message_type="notice",
        priority="important",
        title="您的注册申请已通过审批",
        summary=f"账号 {user.username} 已创建，您现在可以登录系统。",
        source_module="user",
        source_type="registration_request",
        source_id=str(request_id),
        source_code=account,
        recipient_user_ids=[user.id],
        dedupe_key=f"reg_approved_{request_id}",
    )
    return success_response(
        RegistrationActionResult(
            request_id=request_id,
            account=account,
            status=request_row.status,
            rejected_reason=request_row.rejected_reason,
            final_account=user.username,
            approved=True,
            user_id=user.id,
            role_code=user.roles[0].code if user.roles else None,
        ),
        message="approved",
    )


@router.post("/register-requests/{request_id}/reject", response_model=ApiResponse[RegistrationActionResult])
def reject_registration(
    request_id: int,
    payload: RejectRegistrationRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.registration_requests.reject")),
) -> ApiResponse[RegistrationActionResult]:
    request_row = get_registration_request_by_id(db, request_id)
    if not request_row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registration request not found")

    account = request_row.account
    updated = reject_registration_request(
        db,
        request=request_row,
        reason=payload.reason,
        reviewer=current_user,
    )
    write_audit_log(
        db,
        action_code="registration.reject",
        action_name="审批驳回",
        target_type="registration_request",
        target_id=str(request_id),
        target_name=account,
        operator=current_user,
        after_data={"status": updated.status, "rejected_reason": updated.rejected_reason},
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    return success_response(
        RegistrationActionResult(
            request_id=request_id,
            account=account,
            status=updated.status,
            rejected_reason=updated.rejected_reason,
            final_account=None,
            approved=False,
            user_id=None,
            role_code=None,
        ),
        message="rejected",
    )


@router.get("/me", response_model=ApiResponse[CurrentUserResult])
def get_current_login_user(
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[CurrentUserResult]:
    return success_response(
        CurrentUserResult(
            id=current_user.id,
            username=current_user.username,
            full_name=current_user.full_name,
            role_code=current_user.roles[0].code if current_user.roles else None,
            role_name=current_user.roles[0].name if current_user.roles else None,
            stage_id=current_user.stage_id,
            stage_name=current_user.stage.name if current_user.stage else None,
        )
    )
