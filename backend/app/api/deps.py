from collections.abc import Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import TokenPayload
from app.services.online_status_service import touch_user
from app.services.authz_service import has_permission, validate_permission_code
from app.services.session_service import touch_session_by_token_id
from app.services.user_service import get_user_by_id


oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.api_v1_prefix}/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid authentication credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_access_token(token)
        token_data = TokenPayload(sub=payload.get("sub", ""))
        session_token_id = str(payload.get("sid") or "").strip() or None
    except Exception:
        raise credentials_error

    if not token_data.sub:
        raise credentials_error

    try:
        user_id = int(token_data.sub)
    except ValueError:
        raise credentials_error

    user = get_user_by_id(db, user_id)
    if not user:
        raise credentials_error
    if user.is_deleted or not user.is_active:
        raise credentials_error
    if session_token_id:
        session_row = touch_session_by_token_id(db, session_token_id)
        if session_row is None or session_row.status != "active":
            raise credentials_error
        db.commit()
    touch_user(user.id)
    return user


def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    return current_user


def require_role_codes(allowed_role_codes: list[str]) -> Callable[[User], User]:
    def dependency(current_user: User = Depends(get_current_active_user)) -> User:
        user_role_codes = {role.code for role in current_user.roles}
        if not user_role_codes.intersection(set(allowed_role_codes)):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
        return current_user

    return dependency


def require_permission(permission_code: str) -> Callable[[User, Session], User]:
    validate_permission_code(permission_code)

    def dependency(
        current_user: User = Depends(get_current_active_user),
        db: Session = Depends(get_db),
    ) -> User:
        if not has_permission(db, user=current_user, permission_code=permission_code):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
        return current_user

    return dependency


def require_any_permission(permission_codes: list[str]) -> Callable[[User, Session], User]:
    normalized_codes = [code for code in permission_codes if code]
    if not normalized_codes:
        raise ValueError("permission_codes is required")
    for code in normalized_codes:
        validate_permission_code(code)

    def dependency(
        current_user: User = Depends(get_current_active_user),
        db: Session = Depends(get_db),
    ) -> User:
        if not any(
            has_permission(db, user=current_user, permission_code=code)
            for code in normalized_codes
        ):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
        return current_user

    return dependency
