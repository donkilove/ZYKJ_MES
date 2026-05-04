"""app/services/login_ratelimit_service.py

Redis-backed login brute-force rate limiter.

Key design
──────────
• Key pattern :  "mes:login:fail:{username}"
  Value        :  integer failure count
  TTL          :  15 minutes (auto-reset after window expires)

• Threshold   :  5 consecutive failures → account locked for the full TTL window
• On success  :  DEL the key immediately (counter reset)
• Graceful    :  if Redis is unavailable, allow requests through (fail-open)
"""
from __future__ import annotations

import logging
import time

try:
    from redis import Redis
    from redis.exceptions import RedisError
except Exception:  # pragma: no cover - graceful fallback
    Redis = None  # type: ignore[assignment]
    RedisError = Exception  # type: ignore[misc, assignment]

from app.core.config import settings

logger = logging.getLogger(__name__)

# ── Constants ──────────────────────────────────────────────────────────────────

_LOGIN_FAIL_KEY_PREFIX = "mes:login:fail"
_LOGIN_FAIL_MAX_ATTEMPTS = 5
_LOGIN_FAIL_WINDOW_SECONDS = 15 * 60   # 15 minutes

# ── Module-level Redis client (lazy, global) ───────────────────────────────────

_LOGIN_RATELIMIT_REDIS_CLIENT: Redis | None = None
_LOGIN_RATELIMIT_REDIS_INIT = False
_LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL = 0.0
_LOGIN_RATELIMIT_REDIS_BACKOFF_SECONDS = 30.0


# ─────────────────────────────────────────────────────────────────────────────
# Redis client helpers
# ─────────────────────────────────────────────────────────────────────────────

def _get_login_ratelimit_redis_client() -> Redis | None:
    """Return the shared Redis client, or None if unavailable / disabled."""
    global _LOGIN_RATELIMIT_REDIS_CLIENT, _LOGIN_RATELIMIT_REDIS_INIT, _LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL

    if _LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL > time.monotonic():
        return None
    if _LOGIN_RATELIMIT_REDIS_INIT:
        return _LOGIN_RATELIMIT_REDIS_CLIENT
    _LOGIN_RATELIMIT_REDIS_INIT = True

    if Redis is None:
        logger.warning("[LOGIN-RATELIMIT] redis 依赖不可用，登录防暴破将不生效。")
        return None

    try:
        _LOGIN_RATELIMIT_REDIS_CLIENT = Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            db=settings.redis_db,
            password=settings.redis_password or None,
            ssl=settings.redis_ssl,
            decode_responses=True,
            socket_timeout=max(0.05, settings.redis_socket_timeout_seconds),
            socket_connect_timeout=max(0.05, settings.redis_connect_timeout_seconds),
        )
        _LOGIN_RATELIMIT_REDIS_CLIENT.ping()
        logger.info("[LOGIN-RATELIMIT] Redis 连接已建立。")
    except Exception:
        _LOGIN_RATELIMIT_REDIS_CLIENT = None
        _LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL = (
            time.monotonic() + _LOGIN_RATELIMIT_REDIS_BACKOFF_SECONDS
        )
        logger.warning(
            "[LOGIN-RATELIMIT] Redis 连接失败，登录防暴破暂时禁用（backoff %ds）。",
            _LOGIN_RATELIMIT_REDIS_BACKOFF_SECONDS,
            exc_info=True,
        )
    return _LOGIN_RATELIMIT_REDIS_CLIENT


def _mark_login_ratelimit_redis_unavailable() -> None:
    global _LOGIN_RATELIMIT_REDIS_CLIENT, _LOGIN_RATELIMIT_REDIS_INIT, _LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL
    _LOGIN_RATELIMIT_REDIS_CLIENT = None
    _LOGIN_RATELIMIT_REDIS_INIT = False
    _LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL = (
        time.monotonic() + _LOGIN_RATELIMIT_REDIS_BACKOFF_SECONDS
    )


# ─────────────────────────────────────────────────────────────────────────────
# Redis key helpers
# ─────────────────────────────────────────────────────────────────────────────

def _login_fail_key(*, username: str) -> str:
    """Redis key for tracking failed login attempts."""
    return f"{_LOGIN_FAIL_KEY_PREFIX}:{username.strip()}"


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

def is_account_locked(*, username: str) -> tuple[bool, int | None]:
    """Check if the account is currently locked due to too many failures.

    Returns
    -------
    (is_locked, remaining_seconds)
        is_locked          : True if the account is locked
        remaining_seconds  : TTL seconds left on the lock (None if not locked)
    """
    redis_client = _get_login_ratelimit_redis_client()
    if redis_client is None:
        return False, None

    key = _login_fail_key(username=username)
    try:
        count_str = redis_client.get(key)
        if count_str is None:
            return False, None
        count = int(count_str)
        if count < _LOGIN_FAIL_MAX_ATTEMPTS:
            return False, None
        ttl = redis_client.ttl(key)
        if ttl < 0:
            return False, None
        return True, ttl
    except (RedisError, ValueError):
        _mark_login_ratelimit_redis_unavailable()
        return False, None


def record_failed_login(*, username: str) -> int:
    """Record a failed login attempt and return the current failure count.

    If the count reaches _LOGIN_FAIL_MAX_ATTEMPTS, the account is locked.
    TTL is set/refreshed on every increment so the window slides.
    Returns the new failure count (capped at _LOGIN_FAIL_MAX_ATTEMPTS for display).
    """
    redis_client = _get_login_ratelimit_redis_client()
    if redis_client is None:
        return 0

    key = _login_fail_key(username=username)
    try:
        pipe = redis_client.pipeline()
        pipe.incr(key)
        pipe.expire(key, _LOGIN_FAIL_WINDOW_SECONDS)
        results = pipe.execute()
        new_count = int(results[0])
        return min(new_count, _LOGIN_FAIL_MAX_ATTEMPTS)
    except RedisError:
        _mark_login_ratelimit_redis_unavailable()
        return 0


def clear_login_failures(*, username: str) -> None:
    """Clear all failure records for the account on successful login."""
    redis_client = _get_login_ratelimit_redis_client()
    if redis_client is None:
        return

    key = _login_fail_key(username=username)
    try:
        redis_client.delete(key)
    except RedisError:
        pass  # best-effort; login already succeeded
