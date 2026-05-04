import hashlib
import time
from datetime import datetime, timedelta, timezone
from threading import RLock
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import ensure_runtime_settings_secure, settings


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=10)
_PASSWORD_VERIFY_LOCAL_CACHE: dict[str, float] = {}
_PASSWORD_VERIFY_LOCAL_CACHE_LOCK = RLock()
_PASSWORD_VERIFY_CACHE_TTL_SECONDS = 60
_PASSWORD_VERIFY_USER_KEYS: dict[int, set[str]] = {}  # user_id → set of cache_keys


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def _extract_user_id_from_scope(cache_scope: str) -> int | None:
    """Extract user_id from cache_scope like 'user:123'."""
    if cache_scope.startswith("user:"):
        try:
            return int(cache_scope[5:])
        except ValueError:
            return None
    return None


def verify_password_cached(
    plain_password: str,
    hashed_password: str,
    *,
    cache_scope: str,
    ttl_seconds: int = _PASSWORD_VERIFY_CACHE_TTL_SECONDS,
) -> bool:
    cache_key = hashlib.sha256(
        f"{cache_scope}|{hashed_password}|{plain_password}".encode("utf-8")
    ).hexdigest()
    now_monotonic = time.monotonic()
    with _PASSWORD_VERIFY_LOCAL_CACHE_LOCK:
        expire_at = _PASSWORD_VERIFY_LOCAL_CACHE.get(cache_key)
        if expire_at is not None and expire_at > now_monotonic:
            return True
    verified = verify_password(plain_password, hashed_password)
    if verified:
        with _PASSWORD_VERIFY_LOCAL_CACHE_LOCK:
            _PASSWORD_VERIFY_LOCAL_CACHE[cache_key] = now_monotonic + max(1, ttl_seconds)
            user_id = _extract_user_id_from_scope(cache_scope)
            if user_id is not None:
                _PASSWORD_VERIFY_USER_KEYS.setdefault(user_id, set()).add(cache_key)
    return verified


def invalidate_password_cache(user_id: int) -> int:
    """Remove all cached password verification results for a specific user.

    Returns the number of cache entries removed.
    """
    with _PASSWORD_VERIFY_LOCAL_CACHE_LOCK:
        keys_to_remove = _PASSWORD_VERIFY_USER_KEYS.pop(user_id, set())
        for key in keys_to_remove:
            _PASSWORD_VERIFY_LOCAL_CACHE.pop(key, None)
        return len(keys_to_remove)


def rehash_password_if_needed(plain_password: str, hashed_password: str) -> str | None:
    if not pwd_context.needs_update(hashed_password):
        return None
    return pwd_context.hash(plain_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(
    subject: str,
    extra_claims: dict[str, Any] | None = None,
    *,
    expires_minutes: int | None = None,
) -> str:
    ensure_runtime_settings_secure()
    resolved_minutes = expires_minutes or settings.jwt_expire_minutes
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=resolved_minutes)
    payload: dict[str, Any] = {"sub": subject, "exp": expires_at, "iat": now}
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict[str, Any]:
    ensure_runtime_settings_secure()
    try:
        return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except JWTError as exc:  # pragma: no cover - propagated for API error handling
        raise ValueError("Invalid or expired token") from exc
