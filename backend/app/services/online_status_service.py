from __future__ import annotations

import logging
import time
from datetime import UTC, datetime, timedelta

try:
    from redis import Redis
    from redis.exceptions import RedisError
except Exception:  # pragma: no cover - graceful fallback
    Redis = None  # type: ignore[assignment]
    RedisError = Exception  # type: ignore[misc, assignment]

from app.core.config import settings

logger = logging.getLogger(__name__)

# ── Module-level Redis client (lazy, global) ───────────────────────────────────

_ONLINE_REDIS_CLIENT: Redis | None = None
_ONLINE_REDIS_INIT = False
_ONLINE_REDIS_DISABLED_UNTIL = 0.0
_ONLINE_REDIS_BACKOFF_SECONDS = 30.0

# Redis key prefix: "mes:online:{user_id}" → value = last_seen timestamp (int)
_ONLINE_KEY_PREFIX = "mes:online"


# ─────────────────────────────────────────────────────────────────────────────
# Redis client helpers
# ─────────────────────────────────────────────────────────────────────────────

def _get_online_redis_client() -> Redis | None:
    """Return the shared Redis client, or None if unavailable / disabled."""
    global _ONLINE_REDIS_CLIENT, _ONLINE_REDIS_INIT, _ONLINE_REDIS_DISABLED_UNTIL

    if _ONLINE_REDIS_DISABLED_UNTIL > time.monotonic():
        return None
    if _ONLINE_REDIS_INIT:
        return _ONLINE_REDIS_CLIENT
    _ONLINE_REDIS_INIT = True

    if Redis is None:
        logger.warning("[ONLINE] redis 依赖不可用，在线状态缓存将不生效。")
        return None

    try:
        _ONLINE_REDIS_CLIENT = Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            db=settings.redis_db,
            password=settings.redis_password or None,
            ssl=settings.redis_ssl,
            decode_responses=True,
            socket_timeout=max(0.05, settings.redis_socket_timeout_seconds),
            socket_connect_timeout=max(0.05, settings.redis_connect_timeout_seconds),
        )
        _ONLINE_REDIS_CLIENT.ping()
        logger.info("[ONLINE] Redis 连接已建立。")
    except Exception:
        _ONLINE_REDIS_CLIENT = None
        _ONLINE_REDIS_DISABLED_UNTIL = (
            time.monotonic() + _ONLINE_REDIS_BACKOFF_SECONDS
        )
        logger.warning(
            "[ONLINE] Redis 连接失败，在线状态缓存暂时禁用（backoff %ds）。",
            _ONLINE_REDIS_BACKOFF_SECONDS,
            exc_info=True,
        )
    return _ONLINE_REDIS_CLIENT


def _mark_online_redis_unavailable() -> None:
    global _ONLINE_REDIS_CLIENT, _ONLINE_REDIS_INIT, _ONLINE_REDIS_DISABLED_UNTIL
    _ONLINE_REDIS_CLIENT = None
    _ONLINE_REDIS_INIT = False
    _ONLINE_REDIS_DISABLED_UNTIL = (
        time.monotonic() + _ONLINE_REDIS_BACKOFF_SECONDS
    )


# ─────────────────────────────────────────────────────────────────────────────
# Redis key helpers
# ─────────────────────────────────────────────────────────────────────────────

def _online_key(user_id: int) -> str:
    return f"{_ONLINE_KEY_PREFIX}:{user_id}"


# ─────────────────────────────────────────────────────────────────────────────
# Online status API
# ─────────────────────────────────────────────────────────────────────────────

def touch_user(user_id: int) -> None:
    """Refresh the user's online TTL in Redis (TTL = online_status_ttl_seconds).

    Redis automatically expires the key after TTL with no heartbeat needed.
    """
    if user_id <= 0:
        return
    redis_client = _get_online_redis_client()
    if redis_client is None:
        return
    key = _online_key(user_id)
    try:
        redis_client.setex(key, settings.online_status_ttl_seconds, str(int(time.time())))
    except RedisError:
        _mark_online_redis_unavailable()


def clear_user(user_id: int) -> None:
    """Force-remove the user from the online set (e.g., on logout)."""
    if user_id <= 0:
        return
    redis_client = _get_online_redis_client()
    if redis_client is None:
        return
    key = _online_key(user_id)
    try:
        redis_client.delete(key)
    except RedisError:
        pass  # best-effort; DB state is authoritative


def get_user_online_snapshot(user_id: int) -> tuple[bool, datetime | None]:
    """
    Check if a user is currently online.

    Returns (is_online, last_seen_datetime).  Redis TTL auto-expiry is the
    source of truth — no in-process prune loop is needed.
    """
    redis_client = _get_online_redis_client()
    if redis_client is None:
        return False, None
    key = _online_key(user_id)
    try:
        value = redis_client.get(key)
        if value is None:
            return False, None
        ts = int(value)
        return True, datetime.fromtimestamp(ts, tz=UTC)
    except (RedisError, ValueError):
        _mark_online_redis_unavailable()
        return False, None


def list_online_user_ids(candidate_user_ids: list[int] | None = None) -> set[int]:
    """
    Return the set of online user IDs.

    With Redis TTL, a key's absence means the user is offline — no manual
    timestamp comparison needed.  This function queries Redis directly.
    """
    redis_client = _get_online_redis_client()
    if redis_client is None:
        return set()

    if candidate_user_ids is None:
        # Scan all mes:online:* keys
        pattern = f"{_ONLINE_KEY_PREFIX}:*"
        try:
            keys = redis_client.keys(pattern)
            result: set[int] = set()
            prefix_len = len(f"{_ONLINE_KEY_PREFIX}:")
            for key in keys:
                try:
                    uid = int(key[prefix_len:])
                    if uid > 0:
                        result.add(uid)
                except (ValueError, IndexError):
                    pass
            return result
        except RedisError:
            _mark_online_redis_unavailable()
            return set()
    else:
        # Batch-check only requested user IDs
        pipe = redis_client.pipeline()
        for uid in candidate_user_ids:
            if uid > 0:
                pipe.exists(_online_key(uid))
        try:
            exists_list = pipe.execute()
            return {
                uid
                for uid, exists in zip(candidate_user_ids, exists_list, strict=False)
                if exists and uid > 0
            }
        except RedisError:
            _mark_online_redis_unavailable()
            return set()
