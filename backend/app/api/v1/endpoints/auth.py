from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, require_role_codes
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.core.config import settings
from app.core.security import create_access_token, verify_password
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
)
from app.schemas.common import ApiResponse, success_response
from app.services.online_status_service import touch_user
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


@router.post("/login", response_model=ApiResponse[LoginResult])
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
) -> ApiResponse[LoginResult]:
    user = get_user_by_username(db, form_data.username)
    if not user:
        pending_request = get_registration_request_by_account(db, form_data.username.strip())
        if pending_request:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is pending approval",
            )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    if not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    touch_user(user.id)
    token = create_access_token(subject=str(user.id))
    return success_response(
        LoginResult(
            access_token=token,
            token_type="bearer",
            expires_in=settings.jwt_expire_minutes * 60,
        )
    )


@router.post("/register", response_model=ApiResponse[RegisterResult], status_code=status.HTTP_202_ACCEPTED)
def register(
    payload: RegisterRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[RegisterResult]:
    request, error_message = submit_registration_request(db, payload.account, payload.password)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not request:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to submit registration request")
    return success_response(
        RegisterResult(
            account=request.account,
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


def _to_registration_item(request: RegistrationRequest) -> RegistrationRequestItem:
    return RegistrationRequestItem(
        id=request.id,
        account=request.account,
        created_at=request.created_at,
    )


@router.get("/register-requests", response_model=ApiResponse[RegistrationRequestListResult])
def get_registration_requests(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[RegistrationRequestListResult]:
    total, items = list_registration_requests(db, page=page, page_size=page_size, keyword=keyword)
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
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[RegistrationActionResult]:
    request = get_registration_request_by_id(db, request_id)
    if not request:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registration request not found")

    account = request.account
    user, error_message = approve_registration_request(
        db,
        request,
        account=payload.account,
        role_codes=payload.role_codes,
        process_codes=payload.process_codes,
    )
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not user:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to approve registration request")

    return success_response(
        RegistrationActionResult(
            request_id=request_id,
            account=account,
            final_account=user.username,
            approved=True,
            user_id=user.id,
            role_codes=sorted(role.code for role in user.roles),
            process_codes=sorted(process.code for process in user.processes),
        ),
        message="approved",
    )


@router.post("/register-requests/{request_id}/reject", response_model=ApiResponse[RegistrationActionResult])
def reject_registration(
    request_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[RegistrationActionResult]:
    request = get_registration_request_by_id(db, request_id)
    if not request:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registration request not found")

    account = request.account
    reject_registration_request(db, request)
    return success_response(
        RegistrationActionResult(
            request_id=request_id,
            account=account,
            final_account=None,
            approved=False,
            user_id=None,
            role_codes=[],
            process_codes=[],
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
            role_codes=sorted(role.code for role in current_user.roles),
            role_names=sorted(role.name for role in current_user.roles),
            process_codes=sorted(process.code for process in current_user.processes),
            process_names=sorted(process.name for process in current_user.processes),
        )
    )
