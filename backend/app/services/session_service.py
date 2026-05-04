from __future__ import annotations

import logging
import time
from datetime import UTC, datetime, timedelta
from dataclasses import dataclass
from threading import Lock
from uuid import uuid4

from sqlalchemy import and_, delete, func, select, update
from sqlalchemy.orm import Session

try:
    from redis import Redis
    from redis.exceptions import RedisError
except Exception:  # pragma: no cover - graceful fallback
    Redis = None  # type: ignore[assignment]
    RedisError = Exception  # type: ignore[misc, assignment]

from app.core.config import settings
from app.models.associations import user_roles
from app.models.login_log import LoginLog
from app.models.process_stage import ProcessStage
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession

logger = logging.getLogger(__name__)

# ── Module-level Redis client (lazy, global) ───────────────────────────────────

_SESSION_REDIS_CLIENT: Redis | None = None
_SESSION_REDIS_INIT = False
_SESSION_REDIS_DISABLED_UNTIL = 0.0
_SESSION_REDIS_BACKOFF_SECONDS = 30.0
_SESSION_REDIS_KEY_PREFIX = "mes:session:active"

# ── Module-level lock for login-log deduplication ──────────────────────────────

_LOGIN_LOG_CLEANUP_LOCK = Lock()
_LOGIN_LOG_CLEANUP_NEXT_AT = 0.0
_LOGIN_LOG_CLEANUP_MIN_INTERVAL_SECONDS = 300

# ── Module-level lock for session cleanup throttle ──────────────────────────────

_SESSION_CLEANUP_LOCK = Lock()
_SESSION_CLEANUP_NEXT_AT = 0.0
_SESSION_CLEANUP_MIN_INTERVAL_SECONDS = 30

# ── Login-log deduplication cache (process-local, short TTL) ──────────────────

_SUCCESS_LOGIN_LOG_LOCAL_CACHE: dict[str, float] = {}
_SUCCESS_LOGIN_LOG_LOCAL_CACHE_LOCK = Lock()
_SUCCESS_LOGIN_LOG_MIN_INTERVAL_SECONDS = 60

_TERMINAL_INFO_MAX_LENGTH = 255


# ─────────────────────────────────────────────────────────────────────────────
# Redis client helpers
# ─────────────────────────────────────────────────────────────────────────────

def _get_session_redis_client() -> Redis | None:
    """Return the shared Redis client, or None if unavailable / disabled."""
    global _SESSION_REDIS_CLIENT, _SESSION_REDIS_INIT, _SESSION_REDIS_DISABLED_UNTIL

    if _SESSION_REDIS_DISABLED_UNTIL > time.monotonic():
        return None
    if _SESSION_REDIS_INIT:
        return _SESSION_REDIS_CLIENT
    _SESSION_REDIS_INIT = True

    if Redis is None:
        logger.warning("[SESSION] redis 依赖不可用，Session 缓存将不生效。")
        return None

    try:
        _SESSION_REDIS_CLIENT = Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            db=settings.redis_db,
            password=settings.redis_password or None,
            ssl=settings.redis_ssl,
            decode_responses=True,
            socket_timeout=max(0.05, settings.redis_socket_timeout_seconds),
            socket_connect_timeout=max(0.05, settings.redis_connect_timeout_seconds),
        )
        _SESSION_REDIS_CLIENT.ping()
        logger.info("[SESSION] Redis 连接已建立。")
    except Exception:
        _SESSION_REDIS_CLIENT = None
        _SESSION_REDIS_DISABLED_UNTIL = (
            time.monotonic() + _SESSION_REDIS_BACKOFF_SECONDS
        )
        logger.warning(
            "[SESSION] Redis 连接失败，Session 缓存暂时禁用（backoff %ds）。",
            _SESSION_REDIS_BACKOFF_SECONDS,
            exc_info=True,
        )
    return _SESSION_REDIS_CLIENT


def _mark_session_redis_unavailable() -> None:
    global _SESSION_REDIS_CLIENT, _SESSION_REDIS_INIT, _SESSION_REDIS_DISABLED_UNTIL
    _SESSION_REDIS_CLIENT = None
    _SESSION_REDIS_INIT = False
    _SESSION_REDIS_DISABLED_UNTIL = (
        time.monotonic() + _SESSION_REDIS_BACKOFF_SECONDS
    )


# ─────────────────────────────────────────────────────────────────────────────
# Redis key helpers
# ─────────────────────────────────────────────────────────────────────────────

def _session_active_key(session_token_id: str) -> str:
    """Redis key for session-active marker.

    Value format: "{user_id}:{expires_at_ts}"
    """
    return f"{_SESSION_REDIS_KEY_PREFIX}:{session_token_id.strip()}"


# ─────────────────────────────────────────────────────────────────────────────
# Redis-backed session-active primitives
# ─────────────────────────────────────────────────────────────────────────────

def _touch_session_active_in_redis(
    session_token_id: str,
    *,
    user_id: int,
    ttl_seconds: int,
) -> None:
    """Set/refresh the session-active marker in Redis with TTL."""
    redis_client = _get_session_redis_client()
    if redis_client is None:
        return
    key = _session_active_key(session_token_id)
    value = f"{user_id}:{int(time.time())}"
    try:
        redis_client.setex(key, max(1, ttl_seconds), value)
    except RedisError:
        _mark_session_redis_unavailable()


def _get_session_active_from_redis(
    session_token_id: str,
) -> tuple[bool, int | None]:
    """Read the session-active marker from Redis.

    Returns (exists, user_id).  On Redis failure returns (False, None).
    """
    redis_client = _get_session_redis_client()
    if redis_client is None:
        return False, None
    key = _session_active_key(session_token_id)
    try:
        value = redis_client.get(key)
        if value is None:
            return False, None
        parts = value.split(":", 1)
        user_id = int(parts[0]) if parts else None
        return True, user_id
    except (RedisError, ValueError, IndexError):
        _mark_session_redis_unavailable()
        return False, None


def _delete_session_active_in_redis(session_token_id: str) -> None:
    """Delete the session-active marker from Redis."""
    redis_client = _get_session_redis_client()
    if redis_client is None:
        return
    key = _session_active_key(session_token_id)
    try:
        redis_client.delete(key)
    except RedisError:
        pass  # best-effort; DB state is authoritative


# ─────────────────────────────────────────────────────────────────────────────
# Public API (replaces in-process cache calls)
# ─────────────────────────────────────────────────────────────────────────────

def remember_active_session_token(
    session_token_id: str,
    *,
    user_id: int,
    ttl_seconds: int | None = None,
    expires_at: datetime | None = None,
) -> None:
    normalized_token = session_token_id.strip()
    if not normalized_token:
        return
    resolved_ttl = max(1, ttl_seconds or settings.session_touch_min_interval_seconds)
    if expires_at is not None:
        remaining = int((expires_at - _now_utc()).total_seconds())
        if remaining <= 0:
            forget_active_session_token(normalized_token)
            return
        resolved_ttl = min(resolved_ttl, remaining)
    if resolved_ttl < 1:
        forget_active_session_token(normalized_token)
        return
    _touch_session_active_in_redis(
        normalized_token,
        user_id=user_id,
        ttl_seconds=resolved_ttl,
    )


def forget_active_session_token(session_token_id: str) -> None:
    normalized_token = session_token_id.strip()
    if not normalized_token:
        return
    _delete_session_active_in_redis(normalized_token)


def is_session_active_in_redis(session_token_id: str) -> bool:
    """Fast check only — returns True if key exists in Redis."""
    redis_client = _get_session_redis_client()
    if redis_client is None:
        return False
    key = _session_active_key(session_token_id.strip())
    try:
        return redis_client.exists(key) > 0
    except RedisError:
        _mark_session_redis_unavailable()
        return False


# ─────────────────────────────────────────────────────────────────────────────
# Dataclasses
# ─────────────────────────────────────────────────────────────────────────────

@dataclass(frozen=True, slots=True)
class SessionStatusSnapshot:
    status: str
    user_id: int | None = None


@dataclass(frozen=True, slots=True)
class OnlineSessionProjection:
    id: int
    session_token_id: str
    user_id: int
    username: str
    role_code: str | None
    role_name: str | None
    stage_id: int | None
    stage_name: str | None
    login_time: datetime
    last_active_at: datetime
    expires_at: datetime
    ip_address: str | None
    terminal_info: str | None
    status: str


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _now_utc() -> datetime:
    return datetime.now(UTC)


def _session_expire_at() -> datetime:
    return _now_utc() + timedelta(seconds=settings.session_max_seconds)


def _session_touch_interval_seconds() -> int:
    return max(
        30,
        settings.session_touch_min_interval_seconds,
    )


def _cap_session_cache_ttl(ttl_seconds: int, expires_at: datetime, now: datetime) -> int:
    remaining = (expires_at - now).total_seconds()
    if remaining <= 0:
        return 1
    return max(1, min(ttl_seconds, int(remaining)))


def _build_login_log_filters(
    *,
    username: str | None = None,
    success: bool | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
) -> list[object]:
    filters: list[object] = []
    if username:
        filters.append(LoginLog.username.ilike(f"%{username.strip()}%"))
    if success is not None:
        filters.append(LoginLog.success.is_(success))
    if start_time:
        filters.append(LoginLog.login_time >= start_time)
    if end_time:
        filters.append(LoginLog.login_time <= end_time)
    return filters


def _build_online_session_filters(
    *,
    keyword: str | None = None,
    status_filter: str | None = None,
) -> list[object]:
    filters: list[object] = [User.is_deleted.is_(False)]
    if keyword:
        filters.append(User.username.ilike(f"%{keyword.strip()}%"))
    if status_filter:
        if status_filter == "offline":
            filters.append(UserSession.status != "active")
        else:
            filters.append(UserSession.status == status_filter)
    return filters


def _list_primary_role_meta_by_user_ids(
    db: Session,
    user_ids: list[int],
) -> dict[int, tuple[str | None, str | None]]:
    unique_user_ids = sorted({user_id for user_id in user_ids if user_id > 0})
    if not unique_user_ids:
        return {}
    primary_role_subquery = (
        select(
            user_roles.c.user_id.label("user_id"),
            func.min(user_roles.c.role_id).label("role_id"),
        )
        .where(user_roles.c.user_id.in_(unique_user_ids))
        .group_by(user_roles.c.user_id)
        .subquery()
    )
    role_rows = db.execute(
        select(
            primary_role_subquery.c.user_id,
            Role.code,
            Role.name,
        ).join(Role, Role.id == primary_role_subquery.c.role_id)
    ).all()
    return {
        int(user_id): (role_code, role_name)
        for user_id, role_code, role_name in role_rows
    }


def normalize_terminal_info(value: str | None) -> str | None:
    text = (value or "").strip()
    if not text:
        return None
    return text[:_TERMINAL_INFO_MAX_LENGTH]


def should_record_success_login(
    *,
    user_id: int,
    ip_address: str | None,
    terminal_info: str | None,
    min_interval_seconds: int = _SUCCESS_LOGIN_LOG_MIN_INTERVAL_SECONDS,
) -> bool:
    terminal_info = normalize_terminal_info(terminal_info)
    cache_key = f"{user_id}|{ip_address or '-'}|{terminal_info or '-'}"
    interval_seconds = max(1, min_interval_seconds)
    now_monotonic = time.monotonic()
    with _SUCCESS_LOGIN_LOG_LOCAL_CACHE_LOCK:
        expire_at = _SUCCESS_LOGIN_LOG_LOCAL_CACHE.get(cache_key)
        if expire_at is not None and expire_at > now_monotonic:
            return False
        _SUCCESS_LOGIN_LOG_LOCAL_CACHE[cache_key] = now_monotonic + interval_seconds
    return True


# ─────────────────────────────────────────────────────────────────────────────
# Core session operations
# ─────────────────────────────────────────────────────────────────────────────

def create_login_log(
    db: Session,
    *,
    username: str,
    user_id: int | None,
    success: bool,
    ip_address: str | None,
    terminal_info: str | None,
    failure_reason: str | None = None,
    session_token_id: str | None = None,
) -> LoginLog:
    terminal_info = normalize_terminal_info(terminal_info)
    row = LoginLog(
        login_time=_now_utc(),
        username=username,
        user_id=user_id,
        success=success,
        ip_address=ip_address,
        terminal_info=terminal_info,
        failure_reason=failure_reason,
        session_token_id=session_token_id,
    )
    db.add(row)
    return row


def create_user_session(
    db: Session,
    *,
    user: User,
    ip_address: str | None,
    terminal_info: str | None,
) -> UserSession:
    terminal_info = normalize_terminal_info(terminal_info)
    session_token_id = uuid4().hex
    row = UserSession(
        session_token_id=session_token_id,
        user_id=user.id,
        status="active",
        is_forced_offline=False,
        login_time=_now_utc(),
        last_active_at=_now_utc(),
        expires_at=_session_expire_at(),
        logout_time=None,
        login_ip=ip_address,
        terminal_info=terminal_info,
    )
    db.add(row)
    return row


def get_reusable_active_session(
    db: Session,
    *,
    user_id: int,
    ip_address: str | None,
    terminal_info: str | None,
    login_type: str,
) -> UserSession | None:
    """Find an active session that can be reused.

    Uses a raw SQL query to bypass SQLAlchemy's ORM identity map: if a session
    was recently marked as `forced_offline` in memory but not yet flushed to the
    DB, the ORM identity map would return that stale object. Raw SQL always reads
    from the database.
    """
    terminal_info = normalize_terminal_info(terminal_info)
    now = _now_utc()

    from sqlalchemy import text

    sql = text("""
        SELECT id, session_token_id, user_id, status, is_forced_offline,
               login_time, last_active_at, expires_at, logout_time,
               login_ip, terminal_info, login_type
        FROM sys_user_session
        WHERE user_id = :user_id
          AND status = 'active'
          AND is_forced_offline = false
          AND expires_at > :now_utc
          AND login_type = :login_type
        ORDER BY last_active_at DESC, id DESC
        LIMIT 1
    """)

    row = db.execute(
        sql,
        {"user_id": user_id, "now_utc": now, "login_type": login_type},
    ).fetchone()
    if row is None:
        return None

    # Reconstruct ORM object from raw row (avoids identity map)
    session = UserSession(
        id=row.id,
        session_token_id=row.session_token_id,
        user_id=row.user_id,
        status=row.status,
        is_forced_offline=row.is_forced_offline,
        login_time=row.login_time,
        last_active_at=row.last_active_at,
        expires_at=row.expires_at,
        logout_time=row.logout_time,
        login_ip=row.login_ip,
        terminal_info=row.terminal_info,
        login_type=row.login_type,
    )
    # Merge into session so subsequent attribute assignments are tracked.
    session = db.merge(session)
    return session


def create_or_reuse_user_session(
    db: Session,
    *,
    user: User,
    ip_address: str | None,
    terminal_info: str | None,
    login_type: str = "web",
) -> UserSession:
    terminal_info = normalize_terminal_info(terminal_info)

    # Fast path: check Redis for any active session marker.
    # If Redis says "active" for ANY session of this user, do NOT reuse —
    # an active Redis key means the session was recently forced-offlined
    # and a new login must create a fresh session.
    if is_session_active_in_redis_for_user(user.id):
        # Redis found a session that was marked active — always create new.
        return _create_user_session_no_cache(
            db,
            user=user,
            ip_address=ip_address,
            terminal_info=terminal_info,
            login_type=login_type,
        )

    # ── 安全策略：移动端（mobile_scan）登录永远创建新会话 ─────────────────
    # 隐患 F 防护：若复用旧会话，其 login_ip / terminal_info 会被更新，
    # 导致原会话的 Token 指纹校验失败（IP/UA 与新登录不一致）。
    # 为移动端创建全新会话可以避免这一混淆，也符合移动设备经常切换网络的场景。
    if login_type == "mobile_scan":
        return _create_user_session_no_cache(
            db,
            user=user,
            ip_address=ip_address,
            terminal_info=terminal_info,
            login_type=login_type,
        )

    row = get_reusable_active_session(
        db,
        user_id=user.id,
        ip_address=ip_address,
        terminal_info=terminal_info,
        login_type=login_type,
    )
    if row is not None:
        now = _now_utc()
        row.login_time = now
        row.last_active_at = now
        row.expires_at = _session_expire_at()
        row.login_ip = ip_address
        row.terminal_info = terminal_info
        row.login_type = login_type
        return row
    return _create_user_session_no_cache(
        db,
        user=user,
        ip_address=ip_address,
        terminal_info=terminal_info,
        login_type=login_type,
    )


def _create_user_session_no_cache(
    db: Session,
    *,
    user: User,
    ip_address: str | None,
    terminal_info: str | None,
    login_type: str = "web",
) -> UserSession:
    """Create a new session without checking for reusable sessions."""
    terminal_info = normalize_terminal_info(terminal_info)
    session_token_id = uuid4().hex
    row = UserSession(
        session_token_id=session_token_id,
        user_id=user.id,
        status="active",
        is_forced_offline=False,
        login_type=login_type,
        login_time=_now_utc(),
        last_active_at=_now_utc(),
        expires_at=_session_expire_at(),
        logout_time=None,
        login_ip=ip_address,
        terminal_info=terminal_info,
    )
    db.add(row)
    return row


def is_session_active_in_redis_for_user(user_id: int) -> bool:
    """Check if any active session marker exists in Redis for the given user.

    Returns True if a session-active key for any session of this user is found,
    indicating the user has recently logged in and should not reuse that session.
    """
    redis_client = _get_session_redis_client()
    if redis_client is None:
        return True  # Redis unavailable — be conservative, don't allow session reuse
    try:
        pattern = f"{_SESSION_REDIS_KEY_PREFIX}:*"
        cursor = 0
        while True:
            cursor, keys = redis_client.scan(cursor=cursor, match=pattern, count=100)
            for key in keys:
                val = redis_client.get(key)
                if val is not None:
                    try:
                        parts = val.split(":")
                        if len(parts) >= 1:
                            uid = int(parts[0])
                            if uid == user_id:
                                return True
                    except (ValueError, IndexError):
                        pass
            if cursor == 0:
                break
        return False
    except RedisError:
        return False


def get_session_by_token_id(db: Session, session_token_id: str) -> UserSession | None:
    stmt = select(UserSession).where(UserSession.session_token_id == session_token_id)
    return db.execute(stmt).scalars().first()


def touch_session_by_token_id(
    db: Session,
    session_token_id: str,
    *,
    require_user_id: int | None = None,
) -> tuple[UserSession | SessionStatusSnapshot | None, bool]:
    """
    Touch a session, optionally verifying the caller-supplied user_id against Redis.

    **require_user_id**: if provided, the Redis-active marker must belong to this
    user_id.  This eliminates the allow_cached_active identity-bypass that existed
    in the old in-process cache path.

    Returns (session_row_or_snapshot, was_db_touched).
    """
    redis_active, redis_user_id = _get_session_active_from_redis(session_token_id)

    # ── DB path (authoritative) — always check DB for fingerprint & status ──
    # IMPORTANT: even if Redis says "active", we must verify against DB because:
    #   1. Redis may be stale (DB force-offline doesn't invalidate Redis key atomically)
    #   2. SessionStatusSnapshot lacks login_ip/terminal_info for fingerprint validation
    #   3. Auth decisions must never trust stale Redis alone
    row = get_session_by_token_id(db, session_token_id)
    if not row:
        _delete_session_active_in_redis(session_token_id)
        return None, False

    now = _now_utc()
    if row.status != "active":
        _delete_session_active_in_redis(session_token_id)
        return row, False

    if row.expires_at <= now:
        row.status = "expired"
        row.logout_time = now
        db.flush()
        _delete_session_active_in_redis(session_token_id)
        return row, True

    # Verify user_id if provided (prevents token hijacking across users)
    if require_user_id is not None and row.user_id != require_user_id:
        _delete_session_active_in_redis(session_token_id)
        return SessionStatusSnapshot(status="invalidated", user_id=row.user_id), False

    min_touch_interval = _session_touch_interval_seconds()
    if row.last_active_at is not None:
        elapsed = (now - row.last_active_at).total_seconds()
        if elapsed < min_touch_interval:
            # Refresh Redis TTL without touching DB
            cache_ttl = _cap_session_cache_ttl(
                max(1, int(min_touch_interval - elapsed)),
                expires_at=row.expires_at,
                now=now,
            )
            _touch_session_active_in_redis(
                session_token_id,
                user_id=row.user_id,
                ttl_seconds=cache_ttl,
            )
            return row, False

    # Actual DB touch
    row.last_active_at = now
    db.flush()
    cache_ttl = _cap_session_cache_ttl(
        min_touch_interval,
        expires_at=row.expires_at,
        now=now,
    )
    _touch_session_active_in_redis(
        session_token_id,
        user_id=row.user_id,
        ttl_seconds=cache_ttl,
    )
    return row, True


def mark_session_logout(
    db: Session,
    *,
    session_token_id: str,
    forced_offline: bool = False,
) -> UserSession | None:
    row = get_session_by_token_id(db, session_token_id)
    if not row:
        return None
    now = _now_utc()
    row.status = "forced_offline" if forced_offline else "logged_out"
    row.is_forced_offline = forced_offline
    row.logout_time = now
    row.last_active_at = now
    db.flush()
    _delete_session_active_in_redis(session_token_id)
    return row


def renew_session(
    db: Session,
    *,
    session_token_id: str,
    extend_seconds: int = 3600,
) -> UserSession | None:
    now = _now_utc()
    row = get_session_by_token_id(db, session_token_id)
    if not row or row.status != "active" or row.expires_at <= now:
        return None
    row.expires_at = row.expires_at + timedelta(seconds=extend_seconds)
    row.last_active_at = now
    db.flush()
    _touch_session_active_in_redis(
        session_token_id,
        user_id=row.user_id,
        ttl_seconds=settings.session_touch_min_interval_seconds,
    )
    return row


# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────

def cleanup_expired_sessions(db: Session) -> int:
    now = _now_utc()
    result = db.execute(
        update(UserSession)
        .where(UserSession.status == "active", UserSession.expires_at <= now)
        .values(
            status="expired",
            logout_time=now,
            last_active_at=now,
        )
    )
    return int(result.rowcount or 0)


def cleanup_expired_sessions_if_due(
    db: Session,
    *,
    min_interval_seconds: int = _SESSION_CLEANUP_MIN_INTERVAL_SECONDS,
) -> int:
    global _SESSION_CLEANUP_NEXT_AT

    interval_seconds = max(1, min_interval_seconds)
    now_monotonic = time.monotonic()
    with _SESSION_CLEANUP_LOCK:
        if now_monotonic < _SESSION_CLEANUP_NEXT_AT:
            return 0
        _SESSION_CLEANUP_NEXT_AT = now_monotonic + interval_seconds

    try:
        return cleanup_expired_sessions(db)
    except Exception:
        with _SESSION_CLEANUP_LOCK:
            _SESSION_CLEANUP_NEXT_AT = 0.0
        raise


def get_user_current_session(db: Session, *, session_token_id: str) -> UserSession | None:
    cleanup_expired_sessions_if_due(db)
    return get_session_by_token_id(db, session_token_id)


# ─────────────────────────────────────────────────────────────────────────────
# Listing
# ─────────────────────────────────────────────────────────────────────────────

def list_online_sessions(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None = None,
    status_filter: str | None = None,
) -> tuple[int, list[OnlineSessionProjection]]:
    cleanup_expired_sessions_if_due(db)
    filters = _build_online_session_filters(
        keyword=keyword,
        status_filter=status_filter,
    )

    total_stmt = (
        select(func.count(UserSession.id))
        .select_from(UserSession)
        .join(User, User.id == UserSession.user_id)
        .where(*filters)
    )
    total = int(db.execute(total_stmt).scalar_one())

    rows_stmt = (
        select(
            UserSession.id.label("session_id"),
            UserSession.session_token_id.label("session_token_id"),
            UserSession.user_id.label("session_user_id"),
            UserSession.login_time.label("login_time"),
            UserSession.last_active_at.label("last_active_at"),
            UserSession.expires_at.label("expires_at"),
            UserSession.login_ip.label("login_ip"),
            UserSession.terminal_info.label("terminal_info"),
            UserSession.status.label("session_status"),
            User.username.label("username"),
            User.stage_id.label("stage_id"),
            ProcessStage.name.label("stage_name"),
        )
        .select_from(UserSession)
        .join(User, User.id == UserSession.user_id)
        .outerjoin(ProcessStage, ProcessStage.id == User.stage_id)
        .where(*filters)
        .order_by(UserSession.login_time.desc(), UserSession.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    rows = db.execute(rows_stmt).mappings().all()
    user_ids = [int(row["session_user_id"]) for row in rows]
    role_meta_by_user_id = _list_primary_role_meta_by_user_ids(db, user_ids)
    items: list[OnlineSessionProjection] = []
    for row in rows:
        role_code, role_name = role_meta_by_user_id.get(
            int(row["session_user_id"]),
            (None, None),
        )
        items.append(
            OnlineSessionProjection(
                id=row["session_id"],
                session_token_id=row["session_token_id"],
                user_id=row["session_user_id"],
                username=row["username"],
                role_code=role_code,
                role_name=role_name,
                stage_id=row["stage_id"],
                stage_name=row["stage_name"],
                login_time=row["login_time"],
                last_active_at=row["last_active_at"],
                expires_at=row["expires_at"],
                ip_address=row["login_ip"],
                terminal_info=row["terminal_info"],
                status=row["session_status"],
            )
        )
    return total, items


def list_login_logs(
    db: Session,
    *,
    page: int,
    page_size: int,
    username: str | None = None,
    success: bool | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
) -> tuple[int, list[LoginLog]]:
    stmt = select(LoginLog).order_by(LoginLog.login_time.desc(), LoginLog.id.desc())
    filters = _build_login_log_filters(
        username=username,
        success=success,
        start_time=start_time,
        end_time=end_time,
    )
    if filters:
        stmt = stmt.where(and_(*filters))
    total_stmt = select(func.count(LoginLog.id))
    if filters:
        total_stmt = total_stmt.where(and_(*filters))
    total = int(db.execute(total_stmt).scalar_one())
    rows = db.execute(stmt.offset((page - 1) * page_size).limit(page_size)).scalars().all()
    return total, rows


# ─────────────────────────────────────────────────────────────────────────────
# Force offline
# ─────────────────────────────────────────────────────────────────────────────

def force_offline_sessions(
    db: Session,
    *,
    session_token_ids: list[str],
) -> int:
    if not session_token_ids:
        return 0
    now = _now_utc()
    stmt = (
        select(UserSession)
        .where(
            UserSession.session_token_id.in_(session_token_ids),
            UserSession.status == "active",
        )
    )
    rows = db.execute(stmt).scalars().all()
    for row in rows:
        row.status = "forced_offline"
        row.is_forced_offline = True
        row.logout_time = now
        row.last_active_at = now
        _delete_session_active_in_redis(row.session_token_id)
    if rows:
        db.flush()
    return len(rows)


def force_offline_user_sessions_except(
    db: Session,
    *,
    user_id: int,
    exclude_session_token_id: str | None = None,
    login_type: str | None = None,
) -> int:
    """强制下线指定用户的所有活跃会话（可排除指定session）。

    login_type: 如果指定，只下线该类型的会话。
    用于web登录时只强制下线web会话，移动端登录时只强制下线移动端会话。
    """
    now = _now_utc()
    stmt = select(UserSession).where(
        UserSession.user_id == user_id,
        UserSession.status == "active",
        UserSession.is_forced_offline.is_(False),
    )
    if exclude_session_token_id:
        stmt = stmt.where(UserSession.session_token_id != exclude_session_token_id)
    if login_type:
        stmt = stmt.where(UserSession.login_type == login_type)

    rows = db.execute(stmt).scalars().all()
    for row in rows:
        row.status = "forced_offline"
        row.is_forced_offline = True
        row.logout_time = now
        row.last_active_at = now
        _delete_session_active_in_redis(row.session_token_id)

    if rows:
        db.flush()
    return len(rows)


# ─────────────────────────────────────────────────────────────────────────────
# Login log cleanup
# ─────────────────────────────────────────────────────────────────────────────

def delete_expired_login_logs(db: Session) -> int:
    deadline = _now_utc() - timedelta(days=settings.login_log_retention_days)
    result = db.execute(delete(LoginLog).where(LoginLog.login_time < deadline))
    return int(result.rowcount or 0)


def cleanup_expired_login_logs_if_due(
    db: Session,
    *,
    min_interval_seconds: int = _LOGIN_LOG_CLEANUP_MIN_INTERVAL_SECONDS,
) -> int:
    global _LOGIN_LOG_CLEANUP_NEXT_AT

    interval_seconds = max(1, min_interval_seconds)
    now_monotonic = time.monotonic()
    with _LOGIN_LOG_CLEANUP_LOCK:
        if now_monotonic < _LOGIN_LOG_CLEANUP_NEXT_AT:
            return 0
        _LOGIN_LOG_CLEANUP_NEXT_AT = now_monotonic + interval_seconds

    try:
        return delete_expired_login_logs(db)
    except Exception:
        with _LOGIN_LOG_CLEANUP_LOCK:
            _LOGIN_LOG_CLEANUP_NEXT_AT = 0.0
        raise


# ─────────────────────────────────────────────────────────────────────────────
# Online user IDs (delegated to online_status_service)
# ─────────────────────────────────────────────────────────────────────────────

def list_online_user_ids(
    db: Session, *, candidate_user_ids: list[int] | None = None
) -> set[int]:
    from app.services.online_status_service import list_online_user_ids as _list
    return _list(candidate_user_ids)
