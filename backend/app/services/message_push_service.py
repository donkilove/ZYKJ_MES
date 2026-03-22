from __future__ import annotations

from datetime import UTC, datetime

from app.services.message_connection_manager import message_connection_manager


async def push_unread_count_changed(
    user_id: int, unread_count: int, latest_message_id: int | None = None
) -> None:
    """向指定用户推送未读数变化事件"""
    payload = {
        "event": "unread_count_changed",
        "user_id": user_id,
        "unread_count": unread_count,
        "latest_message_id": latest_message_id,
        "occurred_at": datetime.now(UTC).isoformat(),
    }
    await message_connection_manager.push_to_user(user_id, payload)


async def push_message_created(
    user_id: int,
    message_id: int,
    unread_count: int,
) -> tuple[bool, str | None, datetime]:
    """向指定用户推送新消息事件"""
    pushed_at = datetime.now(UTC)
    payload = {
        "event": "message_created",
        "user_id": user_id,
        "message_id": message_id,
        "unread_count": unread_count,
        "occurred_at": pushed_at.isoformat(),
    }
    delivered, failure_reason = await message_connection_manager.push_to_user(
        user_id,
        payload,
    )
    return delivered, failure_reason, pushed_at


async def push_message_read_state_changed(
    user_id: int,
    *,
    message_id: int | None,
    unread_count: int,
    is_read: bool,
) -> None:
    payload = {
        "event": "message_read_state_changed",
        "user_id": user_id,
        "message_id": message_id,
        "unread_count": unread_count,
        "is_read": is_read,
        "occurred_at": datetime.now(UTC).isoformat(),
    }
    await message_connection_manager.push_to_user(user_id, payload)
