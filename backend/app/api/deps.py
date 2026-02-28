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
