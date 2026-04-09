import hashlib
import time
from datetime import datetime, timedelta, timezone
from threading import RLock
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
_PASSWORD_VERIFY_LOCAL_CACHE: dict[str, float] = {}
_PASSWORD_VERIFY_LOCAL_CACHE_LOCK = RLock()
_PASSWORD_VERIFY_CACHE_TTL_SECONDS = 60


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


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
    return verified


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(subject: str, extra_claims: dict[str, Any] | None = None) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload: dict[str, Any] = {"sub": subject, "exp": expires_at}
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except JWTError as exc:  # pragma: no cover - propagated for API error handling
        raise ValueError("Invalid or expired token") from exc
