from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user
from app.core.config import settings
from app.core.security import create_access_token, verify_password
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    CurrentUserResult,
    LoginResult,
    RegisterRequest,
    RegisterResult,
)
from app.schemas.common import ApiResponse, success_response
from app.services.user_service import get_user_by_username, register_user


router = APIRouter()


@router.post("/login", response_model=ApiResponse[LoginResult])
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
) -> ApiResponse[LoginResult]:
    user = get_user_by_username(db, form_data.username)
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    token = create_access_token(subject=str(user.id))
    return success_response(
        LoginResult(
            access_token=token,
            token_type="bearer",
            expires_in=settings.jwt_expire_minutes * 60,
        )
    )


@router.post("/register", response_model=ApiResponse[RegisterResult], status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[RegisterResult]:
    user, error_message = register_user(db, payload.account, payload.password)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not user:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to register user")
    return success_response(
        RegisterResult(
            id=user.id,
            username=user.username,
            full_name=user.full_name or user.username,
        ),
        message="registered",
    )


@router.get("/me", response_model=ApiResponse[CurrentUserResult])
def get_current_login_user(
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[CurrentUserResult]:
    permission_codes = sorted(
        {
            permission.code
            for role in current_user.roles
            for permission in role.permissions
        }
    )
    return success_response(
        CurrentUserResult(
            id=current_user.id,
            username=current_user.username,
            full_name=current_user.full_name,
            role_codes=sorted(role.code for role in current_user.roles),
            role_names=sorted(role.name for role in current_user.roles),
            process_codes=sorted(process.code for process in current_user.processes),
            process_names=sorted(process.name for process in current_user.processes),
            permission_codes=permission_codes,
        )
    )
