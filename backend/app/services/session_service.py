from __future__ import annotations

from datetime import UTC, datetime, timedelta
from dataclasses import dataclass
from threading import Lock, RLock
import time
from uuid import uuid4

from sqlalchemy import and_, delete, func, select, update
from sqlalchemy.orm import Session

from app.models.associations import user_roles
from app.core.config import settings
from app.models.login_log import LoginLog
from app.models.process_stage import ProcessStage
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession
from app.services.online_status_service import (
    list_online_user_ids as list_online_user_ids_from_memory,
)

_LOGIN_LOG_CLEANUP_LOCK = Lock()
_LOGIN_LOG_CLEANUP_NEXT_AT = 0.0
_LOGIN_LOG_CLEANUP_MIN_INTERVAL_SECONDS = 300
_SESSION_CLEANUP_LOCK = Lock()
_SESSION_CLEANUP_NEXT_AT = 0.0
_SESSION_CLEANUP_MIN_INTERVAL_SECONDS = 30
_SESSION_TOUCH_WRITE_MIN_INTERVAL_SECONDS = 30
_SESSION_ACTIVE_LOCAL_CACHE: dict[str, float] = {}
_SESSION_ACTIVE_LOCAL_CACHE_LOCK = RLock()
_SUCCESS_LOGIN_LOG_LOCAL_CACHE: dict[str, float] = {}
_SUCCESS_LOGIN_LOG_LOCAL_CACHE_LOCK = RLock()
_SUCCESS_LOGIN_LOG_MIN_INTERVAL_SECONDS = 60


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


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _session_expire_at() -> datetime:
    return _now_utc() + timedelta(seconds=settings.session_max_seconds)


def _session_touch_interval_seconds() -> int:
    return max(
        _SESSION_TOUCH_WRITE_MIN_INTERVAL_SECONDS,
        settings.session_touch_min_interval_seconds,
    )


def _cap_session_cache_ttl(ttl_seconds: int, expires_at: datetime, now: datetime) -> int:
    remaining = (expires_at - now).total_seconds()
    if remaining <= 0:
        return 1
    return max(1, min(ttl_seconds, int(remaining)))


def _get_cached_active_session(session_token_id: str) -> bool:
    normalized_token = session_token_id.strip()
    if not normalized_token:
        return False
    with _SESSION_ACTIVE_LOCAL_CACHE_LOCK:
        expire_at = _SESSION_ACTIVE_LOCAL_CACHE.get(normalized_token)
        if expire_at is None:
            return False
        if expire_at <= time.monotonic():
            _SESSION_ACTIVE_LOCAL_CACHE.pop(normalized_token, None)
            return False
        return True


def remember_active_session_token(
    session_token_id: str,
    *,
    ttl_seconds: int | None = None,
    expires_at: datetime | None = None,
) -> None:
    normalized_token = session_token_id.strip()
    if not normalized_token:
        return
    resolved_ttl = max(1, ttl_seconds or _session_touch_interval_seconds())
    if expires_at is not None:
        remaining_seconds = int((expires_at - _now_utc()).total_seconds())
        if remaining_seconds <= 0:
            forget_active_session_token(normalized_token)
            return
        resolved_ttl = min(resolved_ttl, remaining_seconds)
    if resolved_ttl < 1:
        forget_active_session_token(normalized_token)
        return
    with _SESSION_ACTIVE_LOCAL_CACHE_LOCK:
        _SESSION_ACTIVE_LOCAL_CACHE[normalized_token] = time.monotonic() + resolved_ttl


def forget_active_session_token(session_token_id: str) -> None:
    normalized_token = session_token_id.strip()
    if not normalized_token:
        return
    with _SESSION_ACTIVE_LOCAL_CACHE_LOCK:
        _SESSION_ACTIVE_LOCAL_CACHE.pop(normalized_token, None)


def should_record_success_login(
    *,
    user_id: int,
    ip_address: str | None,
    terminal_info: str | None,
    min_interval_seconds: int = _SUCCESS_LOGIN_LOG_MIN_INTERVAL_SECONDS,
) -> bool:
    cache_key = f"{user_id}|{ip_address or '-'}|{terminal_info or '-'}"
    interval_seconds = max(1, min_interval_seconds)
    now_monotonic = time.monotonic()
    with _SUCCESS_LOGIN_LOG_LOCAL_CACHE_LOCK:
        expire_at = _SUCCESS_LOGIN_LOG_LOCAL_CACHE.get(cache_key)
        if expire_at is not None and expire_at > now_monotonic:
            return False
        _SUCCESS_LOGIN_LOG_LOCAL_CACHE[cache_key] = now_monotonic + interval_seconds
    return True


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
) -> UserSession | None:
    now = _now_utc()
    stmt = (
        select(UserSession)
        .where(
            UserSession.user_id == user_id,
            UserSession.status == "active",
            UserSession.is_forced_offline.is_(False),
            UserSession.expires_at > now,
        )
        .order_by(UserSession.last_active_at.desc(), UserSession.id.desc())
    )
    if ip_address is not None:
        stmt = stmt.where(UserSession.login_ip == ip_address)
    if terminal_info is not None:
        stmt = stmt.where(UserSession.terminal_info == terminal_info)
    return db.execute(stmt).scalars().first()


def create_or_reuse_user_session(
    db: Session,
    *,
    user: User,
    ip_address: str | None,
    terminal_info: str | None,
) -> UserSession:
    row = get_reusable_active_session(
        db,
        user_id=user.id,
        ip_address=ip_address,
        terminal_info=terminal_info,
    )
    if row is not None:
        now = _now_utc()
        row.login_time = now
        row.last_active_at = now
        row.expires_at = _session_expire_at()
        row.login_ip = ip_address
        row.terminal_info = terminal_info
        return row
    return create_user_session(
        db,
        user=user,
        ip_address=ip_address,
        terminal_info=terminal_info,
    )


def get_session_by_token_id(db: Session, session_token_id: str) -> UserSession | None:
    stmt = select(UserSession).where(UserSession.session_token_id == session_token_id)
    return db.execute(stmt).scalars().first()


def touch_session_by_token_id(
    db: Session,
    session_token_id: str,
    *,
    allow_cached_active: bool = False,
) -> tuple[UserSession | SessionStatusSnapshot | None, bool]:
    if allow_cached_active and _get_cached_active_session(session_token_id):
        return SessionStatusSnapshot(status="active"), False
    row = get_session_by_token_id(db, session_token_id)
    if not row:
        forget_active_session_token(session_token_id)
        return None, False
    now = _now_utc()
    if row.status != "active":
        forget_active_session_token(session_token_id)
        return row, False
    if row.expires_at <= now:
        row.status = "expired"
        row.logout_time = now
        db.flush()
        forget_active_session_token(session_token_id)
        return row, True
    min_touch_interval = _session_touch_interval_seconds()
    if row.last_active_at is not None:
        elapsed_seconds = (now - row.last_active_at).total_seconds()
        if elapsed_seconds < min_touch_interval:
            cache_ttl = _cap_session_cache_ttl(
                max(1, int(min_touch_interval - elapsed_seconds)),
                expires_at=row.expires_at,
                now=now,
            )
            remember_active_session_token(
                session_token_id,
                ttl_seconds=cache_ttl,
            )
            return row, False
    row.last_active_at = now
    db.flush()
    cache_ttl = _cap_session_cache_ttl(
        min_touch_interval,
        expires_at=row.expires_at,
        now=now,
    )
    remember_active_session_token(
        session_token_id,
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
    forget_active_session_token(session_token_id)
    return row


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
        forget_active_session_token(row.session_token_id)
    if rows:
        db.flush()
    return len(rows)


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


def list_online_user_ids(
    db: Session, *, candidate_user_ids: list[int] | None = None
) -> set[int]:
    _ = db
    return list_online_user_ids_from_memory(candidate_user_ids)
