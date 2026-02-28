from __future__ import annotations

from datetime import UTC, datetime, timedelta
from threading import Lock

from app.core.config import settings


_lock = Lock()
_last_seen_by_user_id: dict[int, datetime] = {}


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _online_ttl() -> timedelta:
    return timedelta(seconds=settings.online_status_ttl_seconds)


def touch_user(user_id: int) -> None:
    with _lock:
        _last_seen_by_user_id[user_id] = _now_utc()


def _prune_expired(now: datetime) -> None:
    cutoff = now - _online_ttl()
    expired_user_ids = [user_id for user_id, last_seen in _last_seen_by_user_id.items() if last_seen < cutoff]
    for user_id in expired_user_ids:
        _last_seen_by_user_id.pop(user_id, None)


def get_user_online_snapshot(user_id: int) -> tuple[bool, datetime | None]:
    now = _now_utc()
    with _lock:
        _prune_expired(now)
        last_seen = _last_seen_by_user_id.get(user_id)

    if last_seen is None:
        return False, None
    return (now - last_seen) <= _online_ttl(), last_seen
