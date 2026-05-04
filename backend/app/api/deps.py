from collections.abc import Callable
from threading import RLock
import time

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import TokenPayload
from app.services import authz_cache_service
from app.services.online_status_service import touch_user
from app.services.authz_service import get_user_permission_codes, validate_permission_code
from app.services.session_service import (
    get_session_by_token_id,
    normalize_terminal_info,
    touch_session_by_token_id,
)
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
_AUTHZ_CACHE_GENERATION = 0


def _allow_auth_user_cache(request: Request, session_token_id: str | None) -> bool:
    if not session_token_id:
        return False
    if request.method.upper() not in {"GET", "HEAD"}:
        return False
    path = request.url.path
    if not path.startswith("/api/v1/"):
        return False
    if path.startswith("/api/v1/equipment/"):
        return False
    if path.startswith("/api/v1/production/my-orders"):
        return False
    return True


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


def _session_permission_cache_key(*, session_token_id: str, permission_code: str) -> str:
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


def _sync_permission_decision_caches_with_generation() -> None:
    global _AUTHZ_CACHE_GENERATION
    generation = authz_cache_service._authz_cache_generation_value()
    if generation <= _AUTHZ_CACHE_GENERATION:
        return
    _AUTHZ_CACHE_GENERATION = generation
    with _PERMISSION_DECISION_CACHE_LOCK:
        _PERMISSION_DECISION_CACHE.clear()
    with _SESSION_PERMISSION_DECISION_CACHE_LOCK:
        _SESSION_PERMISSION_DECISION_CACHE.clear()


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


def get_current_user(
    token: str = Depends(oauth2_scheme),
    request: Request = None,
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
        login_type = str(payload.get("login_type") or "web").strip() or "web"
    except Exception:
        raise credentials_error

    if not token_data.sub:
        raise credentials_error

    try:
        user_id = int(token_data.sub)
    except ValueError:
        raise credentials_error

    if session_token_id:
        session_row, session_touched = touch_session_by_token_id(
            db,
            session_token_id,
            require_user_id=user_id,
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

        # ── 隐患 F 修复：设备指纹绑定校验 ─────────────────────────────────────
        # session_row 可能是一个轻量级 SessionStatusSnapshot（无 login_ip/UA），
        # 也可能是完整的 UserSession（有 login_ip/UA）。
        # 为安全起见，强制从 DB 获取完整会话信息用于指纹比对；
        # 同时确保 force-offline 操作作用在完整的 DB 记录上。
        #
        # 安全策略：
        #   • web Token：严格校验 IP + User-Agent（跨设备使用必须拒绝）
        #   • mobile_scan Token：仅校验 IP（移动端 UA 随请求变化，不适合作为指纹）
        current_ip: str | None = (
            request.client.host if request and request.client else None
        )
        current_ua: str | None = (
            normalize_terminal_info(
                request.headers.get("user-agent") if request else None
            )
            if request else None
        )
        stored_ip = getattr(session_row, "login_ip", None)
        stored_ua = getattr(session_row, "terminal_info", None)
        if stored_ip is None or stored_ua is None:
            full_session = get_session_by_token_id(db, session_token_id)
        else:
            full_session = session_row if hasattr(session_row, "login_ip") else None
        if full_session is not None:
            stored_ip = full_session.login_ip
            stored_ua = full_session.terminal_info

        def _fingerprint_mismatch(a: str | None, b: str | None) -> bool:
            if a is None and b is None:
                return False
            if a is None or b is None:
                return True
            return a.strip() != b.strip()

        # IP 检查：所有登录类型都必须校验（跨网段使用 Token 视为可疑）
        ip_mismatch = _fingerprint_mismatch(current_ip, stored_ip)
        # UA 检查：仅 web Token 需要，移动端 UA 随请求动态变化
        ua_mismatch = (
            (login_type == "web") and _fingerprint_mismatch(current_ua, stored_ua)
        )

        if ip_mismatch or ua_mismatch:
            # Token 疑似被跨设备盗用 → 强制注销并要求重新登录
            if full_session is not None:
                from app.services.session_service import mark_session_logout

                mark_session_logout(
                    db, session_token_id=session_token_id, forced_offline=True
                )
                db.commit()
            _forget_cached_auth_user(session_token_id)
            _forget_cached_session_permission_decision(session_token_id)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="会话设备指纹校验失败（IP或User-Agent与登录时不一致），"
                "请重新登录。如需在新设备使用，请注销后重新登录。",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if request and _allow_auth_user_cache(request, session_token_id):
            cached_user = _get_cached_auth_user(
                session_token_id=session_token_id,
                expected_user_id=user_id,
            )
            if cached_user is not None:
                touch_user(cached_user.id)
                return cached_user
    user = get_user_for_auth(db, user_id)
    if not user:
        _forget_cached_auth_user(session_token_id)
        _forget_cached_session_permission_decision(session_token_id)
        raise credentials_error
    if user.is_deleted or not user.is_active:
        _forget_cached_auth_user(session_token_id)
        _forget_cached_session_permission_decision(session_token_id)
        raise credentials_error
    if request and _allow_auth_user_cache(request, session_token_id):
        _set_cached_auth_user(session_token_id=session_token_id, user=user)
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
        _sync_permission_decision_caches_with_generation()
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
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
        return current_user

    return dependency


def require_any_permission(permission_codes: list[str]) -> Callable[[User, Session], User]:
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
        _sync_permission_decision_caches_with_generation()
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
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
        return current_user

    return dependency


def require_permission_fast(permission_code: str) -> Callable[[str, Request, Session], None]:
    validate_permission_code(permission_code)

    def dependency(
        token: str = Depends(oauth2_scheme),
        request: Request = None,
        db: Session = Depends(get_db),
    ) -> None:
        _sync_permission_decision_caches_with_generation()
        credentials_error = HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
        try:
            payload = decode_access_token(token)
            token_data = TokenPayload(sub=payload.get("sub", ""))
            session_token_id = str(payload.get("sid") or "").strip() or None
            login_type = str(payload.get("login_type") or "web").strip() or "web"
        except Exception:
            raise credentials_error
        if not token_data.sub:
            raise credentials_error
        try:
            user_id = int(token_data.sub)
        except ValueError:
            raise credentials_error

        if not session_token_id:
            raise credentials_error
        session_row, session_touched = touch_session_by_token_id(
            db,
            session_token_id,
            require_user_id=user_id,
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

        # ── 隐患 F 修复：设备指纹绑定校验（require_permission_fast 路径）──────────
        current_ip: str | None = (
            request.client.host if request and request.client else None
        )
        current_ua: str | None = (
            normalize_terminal_info(
                request.headers.get("user-agent") if request else None
            )
            if request else None
        )
        stored_ip = getattr(session_row, "login_ip", None)
        stored_ua = getattr(session_row, "terminal_info", None)
        if stored_ip is None or stored_ua is None:
            full_session = get_session_by_token_id(db, session_token_id)
        else:
            full_session = session_row if hasattr(session_row, "login_ip") else None
        if full_session is not None:
            stored_ip = full_session.login_ip
            stored_ua = full_session.terminal_info

        def _fp_mismatch(a: str | None, b: str | None) -> bool:
            if a is None and b is None:
                return False
            if a is None or b is None:
                return True
            return a.strip() != b.strip()

        # IP 检查：所有登录类型都必须校验
        ip_mismatch = _fp_mismatch(current_ip, stored_ip)
        # UA 检查：仅 web Token 需要，移动端 UA 随请求动态变化
        ua_mismatch = (
            (login_type == "web") and _fp_mismatch(current_ua, stored_ua)
        )

        if ip_mismatch or ua_mismatch:
            if full_session is not None:
                from app.services.session_service import mark_session_logout

                mark_session_logout(
                    db, session_token_id=session_token_id, forced_offline=True
                )
                db.commit()
            _forget_cached_auth_user(session_token_id)
            _forget_cached_session_permission_decision(session_token_id)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="会话设备指纹校验失败（IP或User-Agent与登录时不一致），"
                "请重新登录。如需在新设备使用，请注销后重新登录。",
                headers={"WWW-Authenticate": "Bearer"},
            )

        session_permission_cache_key = _session_permission_cache_key(
            session_token_id=session_token_id,
            permission_code=permission_code,
        )
        session_decision = _get_cached_session_permission_decision(
            session_permission_cache_key
        )
        if session_decision is not None:
            if not session_decision:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied",
                )
            touch_user(user_id)
            return

        cached_user = None
        if request and _allow_auth_user_cache(request, session_token_id):
            cached_user = _get_cached_auth_user(
                session_token_id=session_token_id,
                expected_user_id=user_id,
            )
        user = cached_user or get_user_for_auth(db, user_id)
        if not user or user.is_deleted or not user.is_active:
            _forget_cached_auth_user(session_token_id)
            _forget_cached_session_permission_decision(session_token_id)
            raise credentials_error

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
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

        if request and _allow_auth_user_cache(request, session_token_id):
            _set_cached_auth_user(session_token_id=session_token_id, user=user)
        touch_user(user.id)

    return dependency
