from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.login_log import LoginLog
from app.models.user import User
from app.models.user_session import UserSession


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _session_expire_at() -> datetime:
    return _now_utc() + timedelta(seconds=settings.session_max_seconds)


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
    db.flush()
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
    db.flush()
    return row


def get_session_by_token_id(db: Session, session_token_id: str) -> UserSession | None:
    stmt = select(UserSession).where(UserSession.session_token_id == session_token_id)
    return db.execute(stmt).scalars().first()


def touch_session_by_token_id(db: Session, session_token_id: str) -> UserSession | None:
    row = get_session_by_token_id(db, session_token_id)
    if not row:
        return None
    now = _now_utc()
    if row.status != "active":
        return row
    if row.expires_at <= now:
        row.status = "expired"
        row.logout_time = now
        db.flush()
        return row
    row.last_active_at = now
    db.flush()
    return row


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
    return row


def cleanup_expired_sessions(db: Session) -> int:
    now = _now_utc()
    stmt = (
        select(UserSession)
        .where(
            UserSession.status == "active",
            UserSession.expires_at <= now,
        )
    )
    rows = db.execute(stmt).scalars().all()
    for row in rows:
        row.status = "expired"
        row.logout_time = now
        row.last_active_at = now
    if rows:
        db.flush()
    return len(rows)


def get_user_current_session(db: Session, *, session_token_id: str) -> UserSession | None:
    cleanup_expired_sessions(db)
    return get_session_by_token_id(db, session_token_id)


def list_online_sessions(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None = None,
) -> tuple[int, list[tuple[UserSession, User]]]:
    cleanup_expired_sessions(db)
    stmt = (
        select(UserSession, User)
        .join(User, User.id == UserSession.user_id)
        .where(
            UserSession.status == "active",
            User.is_deleted.is_(False),
        )
        .order_by(UserSession.login_time.desc(), UserSession.id.desc())
    )
    if keyword:
        stmt = stmt.where(User.username.ilike(f"%{keyword.strip()}%"))
    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = int(db.execute(total_stmt).scalar_one())
    rows = db.execute(stmt.offset((page - 1) * page_size).limit(page_size)).all()
    return total, rows


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
    filters = []
    if username:
        filters.append(LoginLog.username.ilike(f"%{username.strip()}%"))
    if success is not None:
        filters.append(LoginLog.success.is_(success))
    if start_time:
        filters.append(LoginLog.login_time >= start_time)
    if end_time:
        filters.append(LoginLog.login_time <= end_time)
    if filters:
        stmt = stmt.where(and_(*filters))
    total = int(db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one())
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
    if rows:
        db.flush()
    return len(rows)


def delete_expired_login_logs(db: Session) -> int:
    deadline = _now_utc() - timedelta(days=settings.login_log_retention_days)
    stmt = select(LoginLog).where(LoginLog.login_time < deadline)
    rows = db.execute(stmt).scalars().all()
    for row in rows:
        db.delete(row)
    if rows:
        db.flush()
    return len(rows)


def list_online_user_ids(db: Session) -> set[int]:
    cleanup_expired_sessions(db)
    stmt = select(UserSession.user_id).where(UserSession.status == "active")
    return {int(user_id) for user_id in db.execute(stmt).scalars().all()}
