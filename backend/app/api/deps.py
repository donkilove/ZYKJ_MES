from collections.abc import Callable
from threading import RLock
import time
from typing import Protocol

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import TokenPayload
from app.services.online_status_service import touch_user
from app.services.authz_service import (
    get_user_permission_codes,
    validate_permission_code,
)
from app.services.session_service import touch_session_by_token_id
from app.services.user_service import get_user_for_auth


oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.api_v1_prefix}/auth/login")
_AUTH_USER_CACHE_LOCK = RLock()
_AUTH_USER_CACHE: dict[str, tuple[float, User]] = {}
_AUTH_USER_CACHE_TTL_SECONDS = 10
_PERMISSION_DECISION_CACHE_LOCK = RLock()
_PERMISSION_DECISION_CACHE: dict[str, tuple[float, bool]] = {}
_PERMISSION_DECISION_CACHE_TTL_SECONDS = 10
_SESSION_PERMISSION_DECISION_CACHE_LOCK = RLock()
_SESSION_PERMISSION_DECISION_CACHE: dict[str, tuple[float, bool]] = {}
_SESSION_PERMISSION_DECISION_CACHE_TTL_SECONDS = 20


class _FastPermissionDependency(Protocol):
    def __call__(
        self,
        token: str = ..., 
        request: Request = ..., 
        db: Session = ...,
    ) -> None: ...


class _FastPermissionUserDependency(Protocol):
    def __call__(
        self,
        token: str = ..., 
        request: Request = ..., 
        db: Session = ...,
    ) -> User: ...


class _FastPermissionUserIdDependency(Protocol):
    def __call__(
        self,
        token: str = ..., 
        request: Request = ..., 
        db: Session = ...,
    ) -> int: ...

def _allow_auth_user_cache(request: Request, session_token_id: str | None) -> bool:
    if not session_token_id:
        return False
    if request.method.upper() not in {"GET", "HEAD"}:
        return False
    path = request.url.path
    if path == "/api/v1/ui/page-catalog":
        return True
    return path.startswith(
        (
            "/api/v1/authz/",
            "/api/v1/equipment/",
            "/api/v1/messages",
            "/api/v1/me/session",
            "/api/v1/users/export-tasks",
        )
    )


def _get_cached_auth_user(
    *,
    session_token_id: str,
    expected_user_id: int,
) -> User | None:
    with _AUTH_USER_CACHE_LOCK:
        cached = _AUTH_USER_CACHE.get(session_token_id)
        if cached is None:
            return None
        expire_at, user = cached
        if expire_at <= time.monotonic():
            _AUTH_USER_CACHE.pop(session_token_id, None)
            return None
        if user.id != expected_user_id or user.is_deleted or not user.is_active:
            _AUTH_USER_CACHE.pop(session_token_id, None)
            return None
        return user


def _set_cached_auth_user(*, session_token_id: str, user: User) -> None:
    with _AUTH_USER_CACHE_LOCK:
        _AUTH_USER_CACHE[session_token_id] = (
            time.monotonic() + _AUTH_USER_CACHE_TTL_SECONDS,
            user,
        )


def _forget_cached_auth_user(session_token_id: str | None) -> None:
    if not session_token_id:
        return
    with _AUTH_USER_CACHE_LOCK:
        _AUTH_USER_CACHE.pop(session_token_id, None)


def _session_permission_cache_key(
    *, session_token_id: str, permission_code: str
) -> str:
    return f"{session_token_id}|{permission_code}"


def _get_cached_session_permission_decision(cache_key: str) -> bool | None:
    with _SESSION_PERMISSION_DECISION_CACHE_LOCK:
        cached = _SESSION_PERMISSION_DECISION_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, result = cached
        if expire_at <= time.monotonic():
            _SESSION_PERMISSION_DECISION_CACHE.pop(cache_key, None)
            return None
        return result


def _set_cached_session_permission_decision(cache_key: str, result: bool) -> None:
    with _SESSION_PERMISSION_DECISION_CACHE_LOCK:
        _SESSION_PERMISSION_DECISION_CACHE[cache_key] = (
            time.monotonic() + _SESSION_PERMISSION_DECISION_CACHE_TTL_SECONDS,
            result,
        )


def _forget_cached_session_permission_decision(session_token_id: str | None) -> None:
    if not session_token_id:
        return
    key_prefix = f"{session_token_id}|"
    with _SESSION_PERMISSION_DECISION_CACHE_LOCK:
        keys = [
            key
            for key in _SESSION_PERMISSION_DECISION_CACHE.keys()
            if key.startswith(key_prefix)
        ]
        for key in keys:
            _SESSION_PERMISSION_DECISION_CACHE.pop(key, None)


def _role_code_key(user: User) -> str:
    role_codes = sorted(
        {
            str(role.code).strip()
            for role in getattr(user, "roles", [])
            if getattr(role, "is_enabled", True)
        }
    )
    return ",".join(code for code in role_codes if code)


def _permission_decision_cache_key(*, role_key: str, permission_key: str) -> str:
    return f"{role_key}|{permission_key}"


def _get_cached_permission_decision(cache_key: str) -> bool | None:
    with _PERMISSION_DECISION_CACHE_LOCK:
        cached = _PERMISSION_DECISION_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, result = cached
        if expire_at <= time.monotonic():
            _PERMISSION_DECISION_CACHE.pop(cache_key, None)
            return None
        return result


def _set_cached_permission_decision(cache_key: str, result: bool) -> None:
    with _PERMISSION_DECISION_CACHE_LOCK:
        _PERMISSION_DECISION_CACHE[cache_key] = (
            time.monotonic() + _PERMISSION_DECISION_CACHE_TTL_SECONDS,
            result,
        )


def _credentials_error() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid authentication credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )


def _decode_user_and_session_from_token(token: str) -> tuple[int, str | None]:
    credentials_error = _credentials_error()
    try:
        payload = decode_access_token(token)
        token_data = TokenPayload(sub=payload.get("sub", ""))
        session_token_id = str(payload.get("sid") or "").strip() or None
    except ValueError:
        raise credentials_error
    if not token_data.sub:
        raise credentials_error
    try:
        user_id = int(token_data.sub)
    except ValueError:
        raise credentials_error
    return user_id, session_token_id


def _validate_active_session(
    db: Session,
    *,
    user_id: int,
    session_token_id: str | None,
) -> str:
    credentials_error = _credentials_error()
    if not session_token_id:
        raise credentials_error
    session_row, session_touched = touch_session_by_token_id(
        db,
        session_token_id,
        allow_cached_active=True,
    )
    if session_touched:
        db.commit()
    session_user_id = getattr(session_row, "user_id", None) if session_row else None
    if (
        session_row is None
        or session_row.status != "active"
        or (session_user_id is not None and session_user_id != user_id)
    ):
        _forget_cached_auth_user(session_token_id)
        _forget_cached_session_permission_decision(session_token_id)
        raise credentials_error
    return session_token_id


def _load_valid_user_for_request(
    db: Session,
    *,
    user_id: int,
    session_token_id: str,
    request: Request | None,
) -> User:
    credentials_error = _credentials_error()
    user: User | None = None
    if request and _allow_auth_user_cache(request, session_token_id):
        user = _get_cached_auth_user(
            session_token_id=session_token_id,
            expected_user_id=user_id,
        )
    if user is None:
        user = get_user_for_auth(db, user_id)
    if not user or user.is_deleted or not user.is_active:
        _forget_cached_auth_user(session_token_id)
        _forget_cached_session_permission_decision(session_token_id)
        raise credentials_error
    if request and _allow_auth_user_cache(request, session_token_id):
        _set_cached_auth_user(session_token_id=session_token_id, user=user)
    return user


def _authorize_permission_fast(
    *,
    permission_code: str,
    token: str,
    request: Request | None,
    db: Session,
    return_user: bool,
) -> tuple[int, User | None]:
    user_id, session_token_id = _decode_user_and_session_from_token(token)
    sid = _validate_active_session(
        db,
        user_id=user_id,
        session_token_id=session_token_id,
    )
    session_permission_cache_key = _session_permission_cache_key(
        session_token_id=sid,
        permission_code=permission_code,
    )
    session_decision = _get_cached_session_permission_decision(
        session_permission_cache_key
    )
    if session_decision is not None:
        if not session_decision:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
            )
        if return_user:
            user = _load_valid_user_for_request(
                db,
                user_id=user_id,
                session_token_id=sid,
                request=request,
            )
            touch_user(user.id)
            return user.id, user
        touch_user(user_id)
        return user_id, None

    user = _load_valid_user_for_request(
        db,
        user_id=user_id,
        session_token_id=sid,
        request=request,
    )
    role_key = _role_code_key(user)
    decision_cache_key = _permission_decision_cache_key(
        role_key=role_key,
        permission_key=permission_code,
    )
    decision = _get_cached_permission_decision(decision_cache_key)
    if decision is None:
        effective_codes = get_user_permission_codes(db, user=user)
        decision = permission_code in effective_codes
        _set_cached_permission_decision(decision_cache_key, decision)
    _set_cached_session_permission_decision(session_permission_cache_key, decision)
    if not decision:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )
    touch_user(user.id)
    if return_user:
        return user.id, user
    return user.id, None


def get_current_user(
    token: str = Depends(oauth2_scheme),
    request: Request = None,
    db: Session = Depends(get_db),
) -> User:
    user_id, session_token_id = _decode_user_and_session_from_token(token)
    sid = _validate_active_session(
        db,
        user_id=user_id,
        session_token_id=session_token_id,
    )
    user = _load_valid_user_for_request(
        db,
        user_id=user_id,
        session_token_id=sid,
        request=request,
    )
    touch_user(user.id)
    return user


def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    return current_user


def require_role_codes(allowed_role_codes: list[str]) -> Callable[[User], User]:
    def dependency(current_user: User = Depends(get_current_active_user)) -> User:
        user_role_codes = {role.code for role in current_user.roles}
        if not user_role_codes.intersection(set(allowed_role_codes)):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
            )
        return current_user

    return dependency


def require_permission(permission_code: str) -> Callable[[User, Session], User]:
    validate_permission_code(permission_code)

    def dependency(
        current_user: User = Depends(get_current_active_user),
        db: Session = Depends(get_db),
    ) -> User:
        role_key = _role_code_key(current_user)
        cache_key = _permission_decision_cache_key(
            role_key=role_key,
            permission_key=permission_code,
        )
        decision = _get_cached_permission_decision(cache_key)
        if decision is None:
            effective_codes = get_user_permission_codes(db, user=current_user)
            decision = permission_code in effective_codes
            _set_cached_permission_decision(cache_key, decision)
        if not decision:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
            )
        return current_user

    return dependency


def require_any_permission(
    permission_codes: list[str],
) -> Callable[[User, Session], User]:
    normalized_codes = [code for code in permission_codes if code]
    if not normalized_codes:
        raise ValueError("permission_codes is required")
    for code in normalized_codes:
        validate_permission_code(code)
    normalized_code_set = set(normalized_codes)

    def dependency(
        current_user: User = Depends(get_current_active_user),
        db: Session = Depends(get_db),
    ) -> User:
        role_key = _role_code_key(current_user)
        permission_key = ",".join(sorted(normalized_code_set))
        cache_key = _permission_decision_cache_key(
            role_key=role_key,
            permission_key=permission_key,
        )
        decision = _get_cached_permission_decision(cache_key)
        if decision is None:
            effective_codes = get_user_permission_codes(db, user=current_user)
            decision = bool(normalized_code_set.intersection(effective_codes))
            _set_cached_permission_decision(cache_key, decision)
        if not decision:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
            )
        return current_user

    return dependency


def _authorize_any_permission_fast(
    *,
    permission_codes: set[str],
    permission_key: str,
    token: str,
    request: Request | None,
    db: Session,
) -> int:
    user_id, session_token_id = _decode_user_and_session_from_token(token)
    sid = _validate_active_session(
        db,
        user_id=user_id,
        session_token_id=session_token_id,
    )
    session_permission_cache_key = _session_permission_cache_key(
        session_token_id=sid,
        permission_code=permission_key,
    )
    session_decision = _get_cached_session_permission_decision(
        session_permission_cache_key
    )
    if session_decision is not None:
        if not session_decision:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
            )
        touch_user(user_id)
        return user_id

    user = _load_valid_user_for_request(
        db,
        user_id=user_id,
        session_token_id=sid,
        request=request,
    )
    role_key = _role_code_key(user)
    decision_cache_key = _permission_decision_cache_key(
        role_key=role_key,
        permission_key=permission_key,
    )
    decision = _get_cached_permission_decision(decision_cache_key)
    if decision is None:
        effective_codes = get_user_permission_codes(db, user=user)
        decision = bool(permission_codes.intersection(effective_codes))
        _set_cached_permission_decision(decision_cache_key, decision)
    _set_cached_session_permission_decision(session_permission_cache_key, decision)
    if not decision:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )
    touch_user(user.id)
    return user.id


def require_any_permission_fast(
    permission_codes: list[str],
) -> _FastPermissionDependency:
    normalized_codes = [code for code in permission_codes if code]
    if not normalized_codes:
        raise ValueError("permission_codes is required")
    for code in normalized_codes:
        validate_permission_code(code)
    normalized_code_set = set(normalized_codes)
    permission_key = ",".join(sorted(normalized_code_set))

    def dependency(
        token: str = Depends(oauth2_scheme),
        request: Request = None,
        db: Session = Depends(get_db),
    ) -> None:
        _authorize_any_permission_fast(
            permission_codes=normalized_code_set,
            permission_key=permission_key,
            token=token,
            request=request,
            db=db,
        )

    return dependency


def require_permission_fast(
    permission_code: str,
) -> _FastPermissionDependency:
    validate_permission_code(permission_code)

    def dependency(
        token: str = Depends(oauth2_scheme),
        request: Request = None,
        db: Session = Depends(get_db),
    ) -> None:
        _authorize_permission_fast(
            permission_code=permission_code,
            token=token,
            request=request,
            db=db,
            return_user=False,
        )

    return dependency


def require_permission_fast_user(
    permission_code: str,
) -> _FastPermissionUserDependency:
    validate_permission_code(permission_code)

    def dependency(
        token: str = Depends(oauth2_scheme),
        request: Request = None,
        db: Session = Depends(get_db),
    ) -> User:
        _user_id, user = _authorize_permission_fast(
            permission_code=permission_code,
            token=token,
            request=request,
            db=db,
            return_user=True,
        )
        if user is None:
            raise _credentials_error()
        return user

    return dependency


def require_permission_fast_user_id(
    permission_code: str,
) -> _FastPermissionUserIdDependency:
    validate_permission_code(permission_code)

    def dependency(
        token: str = Depends(oauth2_scheme),
        request: Request = None,
        db: Session = Depends(get_db),
    ) -> int:
        user_id, _user = _authorize_permission_fast(
            permission_code=permission_code,
            token=token,
            request=request,
            db=db,
            return_user=False,
        )
        return user_id

    return dependency
