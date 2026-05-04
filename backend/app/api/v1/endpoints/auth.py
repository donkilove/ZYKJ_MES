import json
import os
from datetime import UTC, datetime, timedelta, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, oauth2_scheme, require_permission
from app.core.config import settings
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.core.security import (
    create_access_token,
    decode_access_token,
    rehash_password_if_needed,
    verify_password_cached,
)
from app.db.session import get_db
from app.models.process_stage import ProcessStage
from app.models.registration_request import RegistrationRequest
from app.models.user_session import UserSession
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
    RenewTokenRequest,
    RenewTokenResult,
)
from app.schemas.common import ApiResponse, success_response
from app.services.audit_service import write_audit_log
from app.services.home_dashboard_service import invalidate_home_dashboard_cache
from app.services.login_ratelimit_service import (
    clear_login_failures,
    is_account_locked,
    record_failed_login,
)
from app.services.message_service import (
    close_registration_request_pending_messages,
    create_message_for_users,
)
from app.services.online_status_service import clear_user, touch_user
from app.services.session_service import (
    cleanup_expired_login_logs_if_due,
    create_login_log,
    create_or_reuse_user_session,
    force_offline_user_sessions_except,
    forget_active_session_token,
    get_session_by_token_id,
    mark_session_logout,
    normalize_terminal_info,
    remember_active_session_token,
    renew_session,
    should_record_success_login,
)
from app.services.user_service import (
    approve_registration_request,
    ensure_admin_account,
    get_active_user_ids_by_role,
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


def _build_login_success_response(
    *,
    user: User,
    session_row: object,
    expires_minutes: int,
    login_type: str = "web",
) -> ApiResponse[LoginResult]:
    token = create_access_token(
        subject=str(user.id),
        extra_claims={"sid": session_row.session_token_id, "login_type": login_type},
        expires_minutes=expires_minutes,
    )
    return success_response(
        LoginResult(
            access_token=token,
            token_type="bearer",
            expires_in=expires_minutes * 60,
            must_change_password=user.must_change_password,
        )
    )


def _login_with_expiry(
    *,
    form_data: OAuth2PasswordRequestForm = Depends(),
    request: Request | None,
    db: Session,
    expires_minutes: int,
    login_type: str = "web",
) -> ApiResponse[LoginResult]:
    username = form_data.username.strip()
    ip_address = request.client.host if request and request.client else None
    terminal_info = normalize_terminal_info(
        request.headers.get("user-agent") if request else None
    )

    # ── 隐患 M 修复：检查账号是否因多次失败被锁定 ────────────────────────
    locked, remaining_seconds = is_account_locked(username=username)
    if locked:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                f"登录失败次数过多，账户已被暂时锁定。"
                f"请 {remaining_seconds} 秒后重试。"
            ),
        )

    user = get_user_by_username(
        db,
        username,
        include_deleted=True,
        load_roles=False,
        load_processes=False,
        load_stage=False,
    )
    if not user:
        detail = "Incorrect username or password"
        status_code = status.HTTP_401_UNAUTHORIZED
        reason = detail
        latest_request = get_registration_request_by_account(db, username)
        if latest_request and latest_request.status == "pending":
            detail = "Account is pending approval"
            status_code = status.HTTP_403_FORBIDDEN
            reason = detail
        elif latest_request and latest_request.status == "rejected":
            detail = "Registration request was rejected"
            status_code = status.HTTP_403_FORBIDDEN
            rejected_reason = (latest_request.rejected_reason or "").strip()
            reason = (
                f"{detail}: {rejected_reason}" if rejected_reason else detail
            )
        create_login_log(
            db,
            username=username,
            user_id=None,
            success=False,
            ip_address=ip_address,
            terminal_info=terminal_info,
            failure_reason=reason,
        )
        record_failed_login(username=username)
        db.commit()
        raise HTTPException(status_code=status_code, detail=detail)

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
        record_failed_login(username=username)
        db.commit()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=reason)

    if not verify_password_cached(
        form_data.password,
        user.password_hash,
        cache_scope=f"user:{user.id}",
    ):
        create_login_log(
            db,
            username=username,
            user_id=user.id,
            success=False,
            ip_address=ip_address,
            terminal_info=terminal_info,
            failure_reason="Incorrect username or password",
        )
        record_failed_login(username=username)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    new_hash = rehash_password_if_needed(form_data.password, user.password_hash)
    if new_hash is not None:
        user.password_hash = new_hash

    session_row = create_or_reuse_user_session(
        db,
        user=user,
        ip_address=ip_address,
        terminal_info=terminal_info,
        login_type=login_type,
    )

    # 单会话并发控制：web登录时强制下线该用户所有其他web会话（移动端会话保留）
    if login_type == "web":
        force_offline_user_sessions_except(
            db,
            user_id=user.id,
            exclude_session_token_id=session_row.session_token_id,
            login_type="web",
        )

    if should_record_success_login(
        user_id=user.id,
        ip_address=ip_address,
        terminal_info=terminal_info,
    ):
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
    cleanup_expired_login_logs_if_due(db)
    clear_login_failures(username=username)
    db.commit()
    remember_active_session_token(
        session_row.session_token_id,
        user_id=user.id,
        expires_at=session_row.expires_at,
    )

    touch_user(user.id)
    return _build_login_success_response(
        user=user,
        session_row=session_row,
        expires_minutes=expires_minutes,
        login_type=login_type,
    )


@router.post("/login", response_model=ApiResponse[LoginResult])
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    request: Request = None,
    db: Session = Depends(get_db),
) -> ApiResponse[LoginResult]:
    return _login_with_expiry(
        form_data=form_data,
        request=request,
        db=db,
        expires_minutes=settings.jwt_expire_minutes,
        login_type="web",
    )


@router.post("/mobile-scan-review-login", response_model=ApiResponse[LoginResult])
def mobile_scan_review_login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    request: Request = None,
    db: Session = Depends(get_db),
) -> ApiResponse[LoginResult]:
    return _login_with_expiry(
        form_data=form_data,
        request=request,
        db=db,
        expires_minutes=settings.mobile_scan_review_jwt_expire_minutes,
        login_type="mobile_scan",
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


@router.post("/renew-token", response_model=ApiResponse[RenewTokenResult])
def renew_token(
    payload: RenewTokenRequest,
    request: Request,
    token: str = Depends(oauth2_scheme),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
) -> ApiResponse[RenewTokenResult]:
    if not verify_password_cached(
        payload.password,
        current_user.password_hash,
        cache_scope=f"user:{current_user.id}",
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="密码错误",
        )

    try:
        token_payload = decode_access_token(token)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token无效",
        )

    old_session_token_id = str(token_payload.get("sid") or "").strip() or None
    if not old_session_token_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token中缺少会话信息",
        )

    # 测试模式：MES_TEST_SKIP_RENEW_AGE_CHECK=1 跳过 1h gate（仅用于自动化测试）
    iat = token_payload.get("iat")
    if iat is not None and not (
        os.environ.get("MES_TEST_SKIP_RENEW_AGE_CHECK") == "1"
    ):
        iat_dt = datetime.fromtimestamp(iat, tz=timezone.utc)
        token_age_seconds = (datetime.now(timezone.utc) - iat_dt).total_seconds()
        if token_age_seconds < 3600:
            remaining = int(3600 - token_age_seconds)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Token使用时长不足1小时，还需等待{remaining}秒后才能续期",
            )

    # ── 隐患 A：校验会话归属 ───────────────────────────────────────────────
    existing_session = get_session_by_token_id(db, old_session_token_id)
    if not existing_session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="会话已失效，请重新登录",
        )
    if existing_session.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="会话与用户不匹配",
        )
    if existing_session.status != "active":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="会话状态无效",
        )

    # ── 隐患 B：轮转 Session ───────────────────────────────────────────────
    new_session_token_id = uuid4().hex
    login_type = str(token_payload.get("login_type") or "web")

    # 立刻从 Redis 删除旧会话，确保证中信令失效
    forget_active_session_token(old_session_token_id)

    # 旧会话标记为 logout（已不再使用）
    mark_session_logout(db, session_token_id=old_session_token_id, forced_offline=False)

    # 创建新会话
    now_utc = datetime.now(timezone.utc)
    extend_seconds = 3600
    new_expires_at = now_utc + timedelta(seconds=extend_seconds)
    new_session_row = UserSession(
        session_token_id=new_session_token_id,
        user_id=current_user.id,
        status="active",
        is_forced_offline=False,
        login_time=existing_session.login_time,
        last_active_at=now_utc,
        expires_at=new_expires_at,
        logout_time=None,
        login_ip=existing_session.login_ip,
        terminal_info=existing_session.terminal_info,
    )
    db.add(new_session_row)
    db.flush()

    # ── 隐患 C：移动端 Token 续期保持 10080 分钟 ──────────────────────────
    if login_type == "mobile_scan":
        new_expires_minutes = settings.mobile_scan_review_jwt_expire_minutes + (extend_seconds // 60)
    else:
        new_expires_minutes = settings.jwt_expire_minutes + (extend_seconds // 60)

    new_token = create_access_token(
        subject=str(current_user.id),
        extra_claims={"sid": new_session_token_id, "login_type": login_type},
        expires_minutes=new_expires_minutes,
    )

    # 将新会话写入 Redis 并登记到用户缓存
    remember_active_session_token(
        new_session_token_id,
        user_id=current_user.id,
        expires_at=new_expires_at,
    )

    # 清除旧 token 在用户侧缓存中的记录
    clear_user(current_user.id)

    write_audit_log(
        db,
        action_code="auth.renew_token",
        action_name="续期Token",
        target_type="session",
        target_id=new_session_token_id,
        operator=current_user,
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()

    return success_response(
        RenewTokenResult(
            access_token=new_token,
            token_type="bearer",
            expires_in=new_expires_minutes * 60,
        ),
        message="renewed",
    )


@router.post(
    "/register",
    response_model=ApiResponse[RegisterResult],
    status_code=status.HTTP_202_ACCEPTED,
)
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=error_message
        )
    if not request_row:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to submit registration request",
        )
    approver_user_ids = get_active_user_ids_by_role(db, ROLE_SYSTEM_ADMIN)
    if approver_user_ids:
        create_message_for_users(
            db,
            message_type="todo",
            priority="important",
            title=f"注册审批待处理：{request_row.account}",
            summary=f"账号 {request_row.account} 已提交注册申请，请进入注册审批页面处理。",
            source_module="user",
            source_type="registration_request",
            source_id=str(request_row.id),
            source_code=request_row.account,
            target_page_code="user",
            target_tab_code="registration_approval",
            target_route_payload_json=json.dumps(
                {"action": "detail", "request_id": request_row.id},
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            recipient_user_ids=approver_user_ids,
            dedupe_key=f"registration_request_pending_{request_row.id}",
        )
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(error)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to bootstrap admin",
        )

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


@router.get(
    "/register-requests/{request_id}",
    response_model=ApiResponse[RegistrationRequestItem],
)
def get_registration_request(
    request_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.registration_requests.list")),
) -> ApiResponse[RegistrationRequestItem]:
    request_row = get_registration_request_by_id(db, request_id)
    if not request_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Registration request not found",
        )
    return success_response(_to_registration_item(request_row))


@router.get(
    "/register-requests", response_model=ApiResponse[RegistrationRequestListResult]
)
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


@router.post(
    "/register-requests/{request_id}/approve",
    response_model=ApiResponse[RegistrationActionResult],
)
def approve_registration(
    request_id: int,
    payload: ApproveRegistrationRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("user.registration_requests.approve")
    ),
) -> ApiResponse[RegistrationActionResult]:
    request_row = get_registration_request_by_id(db, request_id)
    if not request_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Registration request not found",
        )

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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=error_message
        )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to approve registration request",
        )

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
    close_registration_request_pending_messages(
        db,
        request_id=request_id,
        reason="registration_request_approved",
    )
    invalidate_home_dashboard_cache(user_ids={current_user.id})
    db.commit()
    # 通知申请人：注册审批通过
    create_message_for_users(
        db,
        message_type="notice",
        priority="important",
        title="您的注册申请已通过审批",
        summary=(
            f"账号 {user.username} 已创建，请使用初始密码登录；"
            "首次登录后系统将要求修改密码。"
        ),
        source_module="user",
        source_type="registration_request",
        source_id=str(request_id),
        source_code=account,
        target_page_code="user",
        target_tab_code="account_settings",
        target_route_payload_json=json.dumps({"action": "change_password"}),
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


@router.post(
    "/register-requests/{request_id}/reject",
    response_model=ApiResponse[RegistrationActionResult],
)
def reject_registration(
    request_id: int,
    payload: RejectRegistrationRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("user.registration_requests.reject")
    ),
) -> ApiResponse[RegistrationActionResult]:
    request_row = get_registration_request_by_id(db, request_id)
    if not request_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Registration request not found",
        )

    account = request_row.account
    updated, error_message = reject_registration_request(
        db,
        request=request_row,
        reason=payload.reason,
        reviewer=current_user,
    )
    if error_message:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message,
        )
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to reject registration request",
        )
    write_audit_log(
        db,
        action_code="registration.reject",
        action_name="审批驳回",
        target_type="registration_request",
        target_id=str(request_id),
        target_name=account,
        operator=current_user,
        after_data={
            "status": updated.status,
            "rejected_reason": updated.rejected_reason,
        },
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    close_registration_request_pending_messages(
        db,
        request_id=request_id,
        reason="registration_request_rejected",
    )
    invalidate_home_dashboard_cache(user_ids={current_user.id})
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
    db: Session = Depends(get_db),
) -> ApiResponse[CurrentUserResult]:
    stage_name = None
    if current_user.stage_id is not None:
        stage_name = (
            db.execute(
                select(ProcessStage.name).where(ProcessStage.id == current_user.stage_id)
            ).scalar_one_or_none()
        )
    return success_response(
        CurrentUserResult(
            id=current_user.id,
            username=current_user.username,
            full_name=current_user.full_name,
            role_code=current_user.roles[0].code if current_user.roles else None,
            role_name=current_user.roles[0].name if current_user.roles else None,
            stage_id=current_user.stage_id,
            stage_name=stage_name,
        )
    )
