from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models.message import Message
from app.models.message_recipient import MessageRecipient
from app.schemas.message import MessageCreateRequest, MessageItem

logger = logging.getLogger(__name__)


def _to_item(msg: Message, recipient: MessageRecipient) -> MessageItem:
    return MessageItem(
        id=msg.id,
        message_type=msg.message_type,
        priority=msg.priority,
        title=msg.title,
        summary=msg.summary,
        content=msg.content,
        source_module=msg.source_module,
        source_type=msg.source_type,
        source_code=msg.source_code,
        target_page_code=msg.target_page_code,
        target_tab_code=msg.target_tab_code,
        target_route_payload_json=msg.target_route_payload_json,
        status=msg.status,
        published_at=msg.published_at,
        is_read=recipient.is_read,
        read_at=recipient.read_at,
        delivered_at=recipient.delivered_at,
    )


def list_messages(
    db: Session,
    *,
    user_id: int,
    page: int = 1,
    page_size: int = 20,
    keyword: str | None = None,
    status: str | None = None,
    message_type: str | None = None,
    priority: str | None = None,
    source_module: str | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
    todo_only: bool = False,
    active_only: bool = True,
) -> tuple[list[MessageItem], int]:
    """查询当前用户的消息列表，返回 (items, total)"""
    base_stmt = (
        select(Message, MessageRecipient)
        .join(MessageRecipient, MessageRecipient.message_id == Message.id)
        .where(
            MessageRecipient.recipient_user_id == user_id,
            MessageRecipient.is_deleted.is_(False),
        )
    )

    if keyword:
        like = f"%{keyword}%"
        base_stmt = base_stmt.where(
            Message.title.ilike(like) | Message.summary.ilike(like) | Message.source_code.ilike(like)
        )
    if status == "unread":
        base_stmt = base_stmt.where(MessageRecipient.is_read.is_(False))
    elif status == "read":
        base_stmt = base_stmt.where(MessageRecipient.is_read.is_(True))
    if message_type:
        base_stmt = base_stmt.where(Message.message_type == message_type)
    if priority:
        base_stmt = base_stmt.where(Message.priority == priority)
    if source_module:
        base_stmt = base_stmt.where(Message.source_module == source_module)
    if start_time:
        base_stmt = base_stmt.where(Message.published_at >= start_time)
    if end_time:
        base_stmt = base_stmt.where(Message.published_at <= end_time)
    if todo_only:
        base_stmt = base_stmt.where(Message.message_type == "todo")
    if active_only:
        base_stmt = base_stmt.where(Message.status == "active")

    count_stmt = select(func.count()).select_from(base_stmt.subquery())
    total: int = db.execute(count_stmt).scalar_one()

    # 高优先级置顶，同优先级按发布时间倒序
    priority_order = case(
        (Message.priority == "urgent", 0),
        (Message.priority == "important", 1),
        else_=2,
    )
    data_stmt = (
        base_stmt.order_by(priority_order, Message.published_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )

    rows = db.execute(data_stmt).all()
    items = [_to_item(msg, recipient) for msg, recipient in rows]
    return items, total


def get_message_summary(db: Session, *, user_id: int) -> dict[str, int]:
    base_stmt = (
        select(Message, MessageRecipient)
        .join(MessageRecipient, MessageRecipient.message_id == Message.id)
        .where(
            MessageRecipient.recipient_user_id == user_id,
            MessageRecipient.is_deleted.is_(False),
            Message.status == "active",
        )
    )
    rows = db.execute(base_stmt).all()
    total_count = len(rows)
    unread_count = 0
    todo_unread_count = 0
    urgent_unread_count = 0
    for msg, recipient in rows:
        if recipient.is_read:
            continue
        unread_count += 1
        if msg.message_type == "todo":
            todo_unread_count += 1
        if msg.priority == "urgent":
            urgent_unread_count += 1
    return {
        "total_count": total_count,
        "unread_count": unread_count,
        "todo_unread_count": todo_unread_count,
        "urgent_unread_count": urgent_unread_count,
    }


def get_unread_count(db: Session, *, user_id: int) -> int:
    """获取当前用户未读消息数"""
    stmt = (
        select(func.count())
        .select_from(MessageRecipient)
        .join(Message, Message.id == MessageRecipient.message_id)
        .where(
            MessageRecipient.recipient_user_id == user_id,
            MessageRecipient.is_read.is_(False),
            MessageRecipient.is_deleted.is_(False),
            Message.status == "active",
        )
    )
    return db.execute(stmt).scalar_one()


def mark_message_read(db: Session, *, user_id: int, message_id: int) -> bool:
    """标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）"""
    stmt = select(MessageRecipient).where(
        MessageRecipient.message_id == message_id,
        MessageRecipient.recipient_user_id == user_id,
        MessageRecipient.is_deleted.is_(False),
    )
    recipient = db.execute(stmt).scalar_one_or_none()
    if recipient is None:
        return False
    if not recipient.is_read:
        recipient.is_read = True
        recipient.read_at = datetime.now(UTC)
    return True


def mark_all_read(db: Session, *, user_id: int) -> int:
    """全部标记已读，返回更新条数（不提交，由调用方负责 commit）"""
    stmt = select(MessageRecipient).where(
        MessageRecipient.recipient_user_id == user_id,
        MessageRecipient.is_read.is_(False),
        MessageRecipient.is_deleted.is_(False),
    )
    recipients = db.execute(stmt).scalars().all()
    now = datetime.now(UTC)
    count = 0
    for r in recipients:
        r.is_read = True
        r.read_at = now
        count += 1
    return count


def mark_messages_read_batch(db: Session, *, user_id: int, message_ids: list[int]) -> int:
    normalized_ids = sorted({int(value) for value in message_ids if int(value) > 0})
    if not normalized_ids:
        return 0
    stmt = select(MessageRecipient).where(
        MessageRecipient.recipient_user_id == user_id,
        MessageRecipient.message_id.in_(normalized_ids),
        MessageRecipient.is_read.is_(False),
        MessageRecipient.is_deleted.is_(False),
    )
    recipients = db.execute(stmt).scalars().all()
    now = datetime.now(UTC)
    count = 0
    for recipient in recipients:
        recipient.is_read = True
        recipient.read_at = now
        count += 1
    return count


def create_message(db: Session, *, req: MessageCreateRequest) -> Message:
    """创建消息并生成收件记录（供来源模块调用）"""
    # 去重检查
    if req.dedupe_key:
        existing = db.execute(
            select(Message).where(Message.dedupe_key == req.dedupe_key)
        ).scalar_one_or_none()
        if existing is not None:
            return existing

    now = datetime.now(UTC)
    msg = Message(
        message_type=req.message_type,
        priority=req.priority,
        title=req.title,
        summary=req.summary,
        content=req.content,
        source_module=req.source_module,
        source_type=req.source_type,
        source_id=req.source_id,
        source_code=req.source_code,
        target_page_code=req.target_page_code,
        target_tab_code=req.target_tab_code,
        target_route_payload_json=req.target_route_payload_json,
        dedupe_key=req.dedupe_key,
        status="active",
        published_at=now,
        expires_at=req.expires_at,
        created_by_user_id=req.created_by_user_id,
    )
    db.add(msg)
    db.flush()

    for uid in req.recipient_user_ids:
        recipient = MessageRecipient(
            message_id=msg.id,
            recipient_user_id=uid,
            delivery_status="delivered",
            delivered_at=now,
            is_read=False,
            last_push_at=now,
        )
        db.add(recipient)

    db.commit()
    db.refresh(msg)

    # 提交后向每位收件人推送实时通知
    _push_message_created_async(db, msg)

    return msg


def _push_message_created_async(db: Session, msg: Message) -> None:
    """在同步上下文中调度异步 WebSocket 推送（fire-and-forget）"""
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        return  # 无事件循环（如单元测试），跳过推送

    from app.services.message_push_service import push_message_created
    from app.services.message_service import get_unread_count

    stmt = select(MessageRecipient.recipient_user_id).where(
        MessageRecipient.message_id == msg.id,
        MessageRecipient.is_deleted.is_(False),
    )
    recipient_ids: list[int] = list(db.execute(stmt).scalars().all())

    for uid in recipient_ids:
        unread = get_unread_count(db, user_id=uid)
        loop.create_task(push_message_created(uid, msg.id, unread))


def create_message_for_users(
    db: Session,
    *,
    message_type: str,
    priority: str = "normal",
    title: str,
    summary: str | None = None,
    content: str | None = None,
    source_module: str | None = None,
    source_type: str | None = None,
    source_id: str | None = None,
    source_code: str | None = None,
    target_page_code: str | None = None,
    target_tab_code: str | None = None,
    target_route_payload_json: str | None = None,
    recipient_user_ids: list[int],
    dedupe_key: str | None = None,
    created_by_user_id: int | None = None,
) -> Message:
    """便捷方法：创建消息并投递给指定用户列表"""
    req = MessageCreateRequest(
        message_type=message_type,
        priority=priority,
        title=title,
        summary=summary,
        content=content,
        source_module=source_module,
        source_type=source_type,
        source_id=source_id,
        source_code=source_code,
        target_page_code=target_page_code,
        target_tab_code=target_tab_code,
        target_route_payload_json=target_route_payload_json,
        recipient_user_ids=recipient_user_ids,
        dedupe_key=dedupe_key,
        created_by_user_id=created_by_user_id,
    )
    return create_message(db, req=req)
