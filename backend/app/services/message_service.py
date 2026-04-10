from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.orm import Session

from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN, ROLE_SYSTEM_ADMIN
from app.core.authz_catalog import PAGE_PERMISSION_BY_PAGE_CODE
from app.core.config import settings
from app.db.session import SessionLocal
from app.models.first_article_record import FirstArticleRecord
from app.models.maintenance_work_order import MaintenanceWorkOrder
from app.models.message import Message
from app.models.message_recipient import MessageRecipient
from app.models.product import Product
from app.models.product_process_template import ProductProcessTemplate
from app.models.production_assist_authorization import ProductionAssistAuthorization
from app.models.production_order import ProductionOrder
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.registration_request import RegistrationRequest
from app.models.repair_order import RepairOrder
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession
from app.schemas.message import (
    AnnouncementPublishRequest,
    AnnouncementPublishResult,
    MessageCreateRequest,
    MessageDetailResult,
    MessageItem,
    MessageJumpResult,
)
from app.services.authz_service import get_user_permission_codes
from app.services.audit_service import write_audit_log

logger = logging.getLogger(__name__)

_MESSAGE_DELIVERY_MAX_RETRY = 3
_MESSAGE_DELIVERY_RETRY_DELAYS = (5, 30, 120)
_MESSAGE_RETENTION_DAYS = 30
_MESSAGE_STATUS_SOURCE_UNAVAILABLE = "src_unavailable"
_PUBLIC_MESSAGE_STATUS_SOURCE_UNAVAILABLE = "source_unavailable"


@dataclass(frozen=True)
class _MessageSourceRegistryEntry:
    model: type
    id_attr: str = "id"


_HIGH_PRIORITY_LEVELS = {"urgent", "important"}

_MESSAGE_SOURCE_MODEL_REGISTRY: dict[tuple[str, str], _MessageSourceRegistryEntry] = {
    ("user", "registration_request"): _MessageSourceRegistryEntry(RegistrationRequest),
    ("user", "user_disable"): _MessageSourceRegistryEntry(User),
    ("user", "force_offline"): _MessageSourceRegistryEntry(
        UserSession,
        id_attr="session_token_id",
    ),
    ("product", "product_version"): _MessageSourceRegistryEntry(Product),
    ("craft", "product_process_template"): _MessageSourceRegistryEntry(
        ProductProcessTemplate
    ),
    ("production", "assist_authorization"): _MessageSourceRegistryEntry(
        ProductionAssistAuthorization
    ),
    ("production", "production_order"): _MessageSourceRegistryEntry(ProductionOrder),
    ("equipment", "maintenance_work_order"): _MessageSourceRegistryEntry(
        MaintenanceWorkOrder
    ),
    ("quality", "first_article_record"): _MessageSourceRegistryEntry(
        FirstArticleRecord
    ),
    ("quality", "repair_order"): _MessageSourceRegistryEntry(RepairOrder),
    ("quality", "scrap_statistics"): _MessageSourceRegistryEntry(
        ProductionScrapStatistics
    ),
}

_PUBLIC_FAILURE_REASON_HINTS: dict[str, str] = {
    "no_active_connection": "接收端离线，等待重试或下次登录后查看。",
    "push_failed": "实时推送失败，系统将按计划继续重试。",
    "connection_closed": "实时连接已断开，系统将按计划继续重试。",
}


def _next_retry_time(attempt_count: int, *, now: datetime) -> datetime | None:
    if attempt_count <= 0 or attempt_count > _MESSAGE_DELIVERY_MAX_RETRY:
        return None
    delay_seconds = _MESSAGE_DELIVERY_RETRY_DELAYS[
        min(attempt_count, len(_MESSAGE_DELIVERY_RETRY_DELAYS)) - 1
    ]
    return now.replace(microsecond=0) + timedelta(seconds=delay_seconds)


def _resolve_source_model(msg: Message) -> _MessageSourceRegistryEntry | None:
    source_module = (msg.source_module or "").strip()
    source_type = (msg.source_type or "").strip()
    return _MESSAGE_SOURCE_MODEL_REGISTRY.get((source_module, source_type))


def _source_record_exists(db: Session, msg: Message) -> bool:
    entry = _resolve_source_model(msg)
    if entry is None:
        return True
    source_id = (msg.source_id or "").strip()
    if not source_id:
        return False
    model = entry.model
    id_attr = getattr(model, entry.id_attr, None)
    if id_attr is None:
        return False
    if entry.id_attr == "id":
        if not source_id.isdigit():
            return False
        stmt = select(model).where(id_attr == int(source_id))
    else:
        stmt = select(model).where(id_attr == source_id)
    row = db.execute(stmt).scalar_one_or_none()
    if row is None:
        return False
    is_deleted = getattr(row, "is_deleted", False)
    return not bool(is_deleted)


def _failure_reason_hint(failure_reason: str | None) -> str | None:
    normalized = (failure_reason or "").strip().lower()
    if not normalized:
        return None
    for code, hint in _PUBLIC_FAILURE_REASON_HINTS.items():
        if normalized.startswith(code):
            return hint
    return "消息投递暂未成功，系统将继续按策略重试。"


def _is_high_priority(priority: str | None) -> bool:
    return (priority or "").strip().lower() in _HIGH_PRIORITY_LEVELS


def _active_message_visibility_condition(*, now: datetime):
    return and_(
        Message.status == "active",
        or_(Message.expires_at.is_(None), Message.expires_at > now),
    )


def _list_active_user_ids_by_role_codes(db: Session, role_codes: set[str]) -> list[int]:
    if not role_codes:
        return []
    rows = (
        db.execute(
            select(User.id)
            .join(User.roles)
            .where(
                User.is_active.is_(True),
                User.is_deleted.is_(False),
                Role.code.in_(sorted(role_codes)),
            )
            .distinct()
            .order_by(User.id.asc())
        )
        .scalars()
        .all()
    )
    result: list[int] = []
    for row in rows:
        raw_value = getattr(row, "id", row)
        try:
            result.append(int(raw_value))
        except (TypeError, ValueError):
            continue
    return result


def _message_recipient_user_ids_for_order(
    db: Session, *, order: ProductionOrder
) -> list[int]:
    recipient_ids = set(
        _list_active_user_ids_by_role_codes(
            db,
            {ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN},
        )
    )
    if order.created_by_user_id is not None:
        recipient_ids.add(int(order.created_by_user_id))
    return sorted(recipient_ids)


def _sync_pending_registration_request_messages(db: Session) -> None:
    recipient_user_ids = _list_active_user_ids_by_role_codes(db, {ROLE_SYSTEM_ADMIN})
    if not recipient_user_ids:
        return
    rows = (
        db.execute(
            select(RegistrationRequest)
            .where(RegistrationRequest.status == "pending")
            .order_by(RegistrationRequest.id.asc())
        )
        .scalars()
        .all()
    )
    for row in rows:
        create_message_for_users(
            db,
            message_type="todo",
            priority="important",
            title=f"注册审批待处理：{row.account}",
            summary=f"账号 {row.account} 已提交注册申请，请进入注册审批页面处理。",
            source_module="user",
            source_type="registration_request",
            source_id=str(row.id),
            source_code=row.account,
            target_page_code="user",
            target_tab_code="registration_approval",
            target_route_payload_json=('{"action":"detail","request_id":%s}' % row.id),
            recipient_user_ids=recipient_user_ids,
            dedupe_key=f"registration_request_pending_{row.id}",
            created_by_user_id=row.reviewed_by_user_id,
        )


def _sync_failed_first_article_messages(db: Session) -> None:
    recipient_user_ids = _list_active_user_ids_by_role_codes(
        db,
        {ROLE_QUALITY_ADMIN, ROLE_SYSTEM_ADMIN},
    )
    if not recipient_user_ids:
        return
    rows = (
        db.execute(
            select(FirstArticleRecord)
            .where(FirstArticleRecord.result == "failed")
            .order_by(FirstArticleRecord.id.asc())
        )
        .scalars()
        .all()
    )
    for row in rows:
        order_code = (
            getattr(row.order, "order_code", "") if getattr(row, "order", None) else ""
        )
        process_name = (
            getattr(row.order_process, "process_name", "")
            if getattr(row, "order_process", None)
            else ""
        )
        create_message_for_users(
            db,
            message_type="todo",
            priority="urgent",
            title=f"首件不通过待处理：{order_code} / {process_name}",
            summary="存在首件不通过记录，请进入每日首件页面查看并完成处置。",
            source_module="quality",
            source_type="first_article_record",
            source_id=str(row.id),
            source_code=order_code or str(row.id),
            target_page_code="quality",
            target_tab_code="first_article_management",
            target_route_payload_json='{"action":"detail","record_id":%s}' % row.id,
            recipient_user_ids=recipient_user_ids,
            dedupe_key=f"first_article_failed_{row.id}",
            created_by_user_id=row.operator_user_id,
        )


def _sync_overdue_production_order_messages(
    db: Session,
    *,
    current_time: datetime,
) -> None:
    today = current_time.date()
    rows = (
        db.execute(
            select(ProductionOrder)
            .where(
                ProductionOrder.due_date.is_not(None),
                ProductionOrder.due_date < today,
                ProductionOrder.status != "completed",
            )
            .order_by(ProductionOrder.due_date.asc(), ProductionOrder.id.asc())
        )
        .scalars()
        .all()
    )
    for row in rows:
        recipient_user_ids = _message_recipient_user_ids_for_order(db, order=row)
        if not recipient_user_ids:
            continue
        create_message_for_users(
            db,
            message_type="warning",
            priority="urgent",
            title=f"工单已逾期：{row.order_code}",
            summary=(
                f"订单 {row.order_code} 计划交期 {row.due_date} 已逾期，"
                f"当前工序 {row.current_process_code or '待确认'}，请尽快处理。"
            ),
            source_module="production",
            source_type="production_order",
            source_id=str(row.id),
            source_code=row.order_code,
            target_page_code="production",
            target_tab_code="production_order_management",
            target_route_payload_json='{"action":"detail","order_id":%s}' % row.id,
            recipient_user_ids=recipient_user_ids,
            dedupe_key=f"production_order_overdue_{row.id}_{row.due_date}",
            created_by_user_id=row.created_by_user_id,
        )


def _write_delivery_audit_log(
    db: Session,
    *,
    recipient: MessageRecipient,
    previous_status: str,
    previous_attempt_count: int,
    previous_failure_reason: str | None,
    previous_next_retry_at: datetime | None,
    failure_reason: str | None,
) -> None:
    write_audit_log(
        db,
        action_code="message.delivery_state_changed",
        action_name="消息投递状态变更",
        target_type="message_delivery",
        target_id=str(recipient.id),
        target_name=f"message:{recipient.message_id}/user:{recipient.recipient_user_id}",
        before_data={
            "delivery_status": previous_status,
            "delivery_attempt_count": previous_attempt_count,
            "last_failure_reason": previous_failure_reason,
            "next_retry_at": previous_next_retry_at.isoformat()
            if previous_next_retry_at is not None
            else None,
        },
        after_data={
            "delivery_status": recipient.delivery_status,
            "delivery_attempt_count": recipient.delivery_attempt_count,
            "last_failure_reason": recipient.last_failure_reason,
            "next_retry_at": recipient.next_retry_at.isoformat()
            if recipient.next_retry_at is not None
            else None,
            "delivered_at": recipient.delivered_at.isoformat()
            if recipient.delivered_at is not None
            else None,
            "last_push_at": recipient.last_push_at.isoformat()
            if recipient.last_push_at is not None
            else None,
        },
        remark=failure_reason,
    )


def _mark_recipient_delivery_result(
    *,
    message_id: int,
    user_id: int,
    delivered: bool,
    failure_reason: str | None,
    pushed_at: datetime,
) -> None:
    with SessionLocal() as db:
        recipient = db.execute(
            select(MessageRecipient).where(
                MessageRecipient.message_id == message_id,
                MessageRecipient.recipient_user_id == user_id,
                MessageRecipient.is_deleted.is_(False),
            )
        ).scalar_one_or_none()
        if recipient is None:
            return
        previous_status = recipient.delivery_status
        previous_attempt_count = recipient.delivery_attempt_count
        previous_failure_reason = recipient.last_failure_reason
        previous_next_retry_at = recipient.next_retry_at
        attempt_count = recipient.delivery_attempt_count + 1
        recipient.last_push_at = pushed_at
        recipient.delivery_attempt_count = attempt_count
        if delivered:
            recipient.delivery_status = "delivered"
            recipient.delivered_at = pushed_at
            recipient.last_failure_reason = None
            recipient.next_retry_at = None
        else:
            recipient.delivery_status = "failed"
            recipient.delivered_at = None
            recipient.last_failure_reason = (failure_reason or "push_failed").strip()[
                :255
            ]
            recipient.next_retry_at = _next_retry_time(attempt_count, now=pushed_at)
        _write_delivery_audit_log(
            db,
            recipient=recipient,
            previous_status=previous_status,
            previous_attempt_count=previous_attempt_count,
            previous_failure_reason=previous_failure_reason,
            previous_next_retry_at=previous_next_retry_at,
            failure_reason=recipient.last_failure_reason,
        )
        db.commit()


async def _retry_message_delivery_after_delay(
    message_id: int,
    user_id: int,
    next_retry_at: datetime,
) -> None:
    delay_seconds = max((next_retry_at - datetime.now(UTC)).total_seconds(), 0)
    if delay_seconds > 0:
        await asyncio.sleep(delay_seconds)
    with SessionLocal() as db:
        recipient = db.execute(
            select(MessageRecipient).where(
                MessageRecipient.message_id == message_id,
                MessageRecipient.recipient_user_id == user_id,
                MessageRecipient.is_deleted.is_(False),
            )
        ).scalar_one_or_none()
        if recipient is None:
            return
        if recipient.delivery_status != "failed":
            return
        if recipient.next_retry_at is None or recipient.next_retry_at != next_retry_at:
            return
    await _push_message_created_for_recipient(message_id, user_id)


def _schedule_message_retry_if_possible(
    *,
    message_id: int,
    user_id: int,
    next_retry_at: datetime | None,
) -> None:
    if next_retry_at is None:
        return
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        return
    loop.create_task(
        _retry_message_delivery_after_delay(message_id, user_id, next_retry_at)
    )


async def _push_message_created_for_recipients(
    message_id: int,
    recipient_user_ids: list[int],
) -> None:
    for user_id in recipient_user_ids:
        await _push_message_created_for_recipient(message_id, user_id)


def _resolve_message_status(
    msg: Message,
    *,
    now: datetime,
    user_permission_codes: set[str] | None,
) -> tuple[str, str | None]:
    if msg.status == "archived":
        return "archived", "archived"
    if msg.status in {
        _MESSAGE_STATUS_SOURCE_UNAVAILABLE,
        _PUBLIC_MESSAGE_STATUS_SOURCE_UNAVAILABLE,
    }:
        return (
            _PUBLIC_MESSAGE_STATUS_SOURCE_UNAVAILABLE,
            _PUBLIC_MESSAGE_STATUS_SOURCE_UNAVAILABLE,
        )
    if msg.status != "active":
        return "source_unavailable", "source_unavailable"
    if msg.expires_at is not None and msg.expires_at <= now:
        return "expired", "expired"

    target_page_code = (msg.target_page_code or "").strip()
    if target_page_code and user_permission_codes is not None:
        target_permission_code = PAGE_PERMISSION_BY_PAGE_CODE.get(target_page_code)
        if target_permission_code is None:
            return "source_unavailable", "source_unavailable"
        if target_permission_code not in user_permission_codes:
            return "no_permission", "no_permission"

    return "active", None


def _to_item(
    msg: Message,
    recipient: MessageRecipient,
    *,
    effective_status: str,
    inactive_reason: str | None,
) -> MessageItem:
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
        status=effective_status,
        inactive_reason=inactive_reason,
        published_at=msg.published_at,
        is_read=recipient.is_read,
        read_at=recipient.read_at,
        delivered_at=recipient.delivered_at,
        delivery_status=recipient.delivery_status,
        delivery_attempt_count=recipient.delivery_attempt_count,
        last_push_at=recipient.last_push_at,
        next_retry_at=recipient.next_retry_at,
    )


def _to_detail(
    msg: Message,
    recipient: MessageRecipient,
    *,
    effective_status: str,
    inactive_reason: str | None,
) -> MessageDetailResult:
    return MessageDetailResult(
        id=msg.id,
        message_type=msg.message_type,
        priority=msg.priority,
        title=msg.title,
        summary=msg.summary,
        content=msg.content,
        source_module=msg.source_module,
        source_type=msg.source_type,
        source_id=msg.source_id,
        source_code=msg.source_code,
        target_page_code=msg.target_page_code,
        target_tab_code=msg.target_tab_code,
        target_route_payload_json=msg.target_route_payload_json,
        status=effective_status,
        inactive_reason=inactive_reason,
        published_at=msg.published_at,
        is_read=recipient.is_read,
        read_at=recipient.read_at,
        delivered_at=recipient.delivered_at,
        delivery_status=recipient.delivery_status,
        delivery_attempt_count=recipient.delivery_attempt_count,
        last_push_at=recipient.last_push_at,
        next_retry_at=recipient.next_retry_at,
        failure_reason_hint=_failure_reason_hint(recipient.last_failure_reason),
    )


def _get_message_and_recipient_for_user(
    db: Session,
    *,
    user_id: int,
    message_id: int,
) -> tuple[Message, MessageRecipient] | None:
    row = db.execute(
        select(Message, MessageRecipient)
        .join(MessageRecipient, MessageRecipient.message_id == Message.id)
        .where(
            Message.id == message_id,
            MessageRecipient.recipient_user_id == user_id,
            MessageRecipient.is_deleted.is_(False),
        )
    ).one_or_none()
    if row is None:
        return None
    return row[0], row[1]


def _write_message_state_audit_log(
    db: Session,
    *,
    message: Message,
    action_code: str,
    action_name: str,
    previous_status: str,
    current_status: str,
    reason: str,
) -> None:
    write_audit_log(
        db,
        action_code=action_code,
        action_name=action_name,
        target_type="message",
        target_id=str(getattr(message, "id", "")),
        target_name=getattr(message, "title", None),
        before_data={
            "status": previous_status,
            "source_module": getattr(message, "source_module", None),
            "source_type": getattr(message, "source_type", None),
            "source_id": getattr(message, "source_id", None),
        },
        after_data={
            "status": current_status,
            "source_module": getattr(message, "source_module", None),
            "source_type": getattr(message, "source_type", None),
            "source_id": getattr(message, "source_id", None),
        },
        remark=reason,
    )


def list_messages(
    db: Session,
    *,
    user_id: int,
    current_user: User | None = None,
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
    run_maintenance: bool = False,
) -> tuple[list[MessageItem], int]:
    """查询当前用户的消息列表，返回 (items, total)"""
    now = datetime.now(UTC)
    if run_maintenance:
        run_message_maintenance(db, now=now)
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
            Message.title.ilike(like)
            | Message.summary.ilike(like)
            | Message.source_code.ilike(like)
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
        base_stmt = base_stmt.where(
            Message.status == "active",
            or_(Message.expires_at.is_(None), Message.expires_at > now),
        )

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
    user_permission_codes = (
        get_user_permission_codes(db, user=current_user)
        if current_user is not None
        else None
    )
    items = []
    for msg, recipient in rows:
        effective_status, inactive_reason = _resolve_message_status(
            msg,
            now=now,
            user_permission_codes=user_permission_codes,
        )
        items.append(
            _to_item(
                msg,
                recipient,
                effective_status=effective_status,
                inactive_reason=inactive_reason,
            )
        )
    return items, total


def get_message_summary(
    db: Session,
    *,
    user_id: int,
    run_maintenance: bool = False,
) -> dict[str, int]:
    now = datetime.now(UTC)
    if run_maintenance:
        run_message_maintenance(db, now=now)
    active_condition = _active_message_visibility_condition(now=now)
    normalized_priority = func.lower(func.coalesce(Message.priority, ""))
    total_count, unread_count, todo_unread_count, urgent_unread_count = db.execute(
        select(
            func.count().label("total_count"),
            func.coalesce(
                func.sum(
                    case(
                        (
                            and_(
                                active_condition,
                                MessageRecipient.is_read.is_(False),
                            ),
                            1,
                        ),
                        else_=0,
                    )
                ),
                0,
            ).label("unread_count"),
            func.coalesce(
                func.sum(
                    case(
                        (
                            and_(
                                active_condition,
                                Message.message_type == "todo",
                            ),
                            1,
                        ),
                        else_=0,
                    )
                ),
                0,
            ).label("todo_unread_count"),
            func.coalesce(
                func.sum(
                    case(
                        (
                            and_(
                                active_condition,
                                normalized_priority.in_(sorted(_HIGH_PRIORITY_LEVELS)),
                            ),
                            1,
                        ),
                        else_=0,
                    )
                ),
                0,
            ).label("urgent_unread_count"),
        )
        .select_from(MessageRecipient)
        .join(Message, Message.id == MessageRecipient.message_id)
        .where(
            MessageRecipient.recipient_user_id == user_id,
            MessageRecipient.is_deleted.is_(False),
        )
    ).one()
    return {
        "total_count": int(total_count),
        "unread_count": int(unread_count),
        "todo_unread_count": int(todo_unread_count),
        "urgent_unread_count": int(urgent_unread_count),
    }


def get_unread_count(
    db: Session,
    *,
    user_id: int,
    run_maintenance: bool = False,
) -> int:
    """获取当前用户未读消息数"""
    now = datetime.now(UTC)
    if run_maintenance:
        run_message_maintenance(db, now=now)
    active_condition = _active_message_visibility_condition(now=now)
    stmt = (
        select(func.count())
        .select_from(MessageRecipient)
        .join(Message, Message.id == MessageRecipient.message_id)
        .where(
            MessageRecipient.recipient_user_id == user_id,
            MessageRecipient.is_read.is_(False),
            MessageRecipient.is_deleted.is_(False),
            active_condition,
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


def mark_messages_read_batch(
    db: Session, *, user_id: int, message_ids: list[int]
) -> int:
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


def get_message_detail(
    db: Session,
    *,
    user_id: int,
    message_id: int,
    current_user: User | None = None,
    run_maintenance: bool = False,
) -> MessageDetailResult | None:
    now = datetime.now(UTC)
    if run_maintenance:
        run_message_maintenance(db, now=now)
    row = _get_message_and_recipient_for_user(
        db, user_id=user_id, message_id=message_id
    )
    if row is None:
        return None
    msg, recipient = row
    user_permission_codes = (
        get_user_permission_codes(db, user=current_user)
        if current_user is not None
        else None
    )
    effective_status, inactive_reason = _resolve_message_status(
        msg,
        now=now,
        user_permission_codes=user_permission_codes,
    )
    return _to_detail(
        msg,
        recipient,
        effective_status=effective_status,
        inactive_reason=inactive_reason,
    )


def get_message_jump_target(
    db: Session,
    *,
    user_id: int,
    message_id: int,
    current_user: User | None = None,
    run_maintenance: bool = False,
) -> MessageJumpResult | None:
    now = datetime.now(UTC)
    if run_maintenance:
        run_message_maintenance(db, now=now)
    row = _get_message_and_recipient_for_user(
        db, user_id=user_id, message_id=message_id
    )
    if row is None:
        return None
    msg, _recipient = row
    user_permission_codes = (
        get_user_permission_codes(db, user=current_user)
        if current_user is not None
        else None
    )
    effective_status, inactive_reason = _resolve_message_status(
        msg,
        now=now,
        user_permission_codes=user_permission_codes,
    )
    if effective_status != "active":
        return MessageJumpResult(
            can_jump=False,
            disabled_reason=inactive_reason or effective_status,
        )
    if not (msg.target_page_code or "").strip():
        return MessageJumpResult(can_jump=False, disabled_reason="missing_target")
    return MessageJumpResult(
        can_jump=True,
        target_page_code=msg.target_page_code,
        target_tab_code=msg.target_tab_code,
        target_route_payload_json=msg.target_route_payload_json,
    )


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
    try:
        db.flush()
    except IntegrityError as exc:
        db.rollback()
        if req.dedupe_key:
            existing = db.execute(
                select(Message).where(Message.dedupe_key == req.dedupe_key)
            ).scalar_one_or_none()
            if existing is not None:
                return existing
        raise exc

    for uid in req.recipient_user_ids:
        recipient = MessageRecipient(
            message_id=msg.id,
            recipient_user_id=uid,
            delivery_status="pending",
            delivered_at=None,
            is_read=False,
            last_push_at=None,
            last_failure_reason=None,
            delivery_attempt_count=0,
            next_retry_at=None,
        )
        db.add(recipient)

    db.commit()
    db.refresh(msg)

    # 提交后向每位收件人推送实时通知
    _push_message_created_async(db, msg)

    return msg


async def _push_message_created_for_recipient(message_id: int, user_id: int) -> None:
    from app.services.message_push_service import push_message_created

    with SessionLocal() as db:
        unread = get_unread_count(db, user_id=user_id)
    delivered, failure_reason, pushed_at = await push_message_created(
        user_id,
        message_id,
        unread,
    )
    _mark_recipient_delivery_result(
        message_id=message_id,
        user_id=user_id,
        delivered=delivered,
        failure_reason=failure_reason,
        pushed_at=pushed_at,
    )
    if not delivered:
        with SessionLocal() as db:
            recipient = db.execute(
                select(MessageRecipient).where(
                    MessageRecipient.message_id == message_id,
                    MessageRecipient.recipient_user_id == user_id,
                    MessageRecipient.is_deleted.is_(False),
                )
            ).scalar_one_or_none()
            next_retry_at = recipient.next_retry_at if recipient is not None else None
        _schedule_message_retry_if_possible(
            message_id=message_id,
            user_id=user_id,
            next_retry_at=next_retry_at,
        )


def run_message_maintenance(
    db: Session,
    *,
    now: datetime | None = None,
) -> dict[str, int]:
    current_time = now or datetime.now(UTC)
    _sync_pending_registration_request_messages(db)
    _sync_failed_first_article_messages(db)
    _sync_overdue_production_order_messages(db, current_time=current_time)
    stats = {
        "source_unavailable_updated": 0,
        "archived_messages": 0,
    }
    messages = db.execute(select(Message)).scalars().all()
    archive_before = current_time - timedelta(days=_MESSAGE_RETENTION_DAYS)
    changed = False
    for msg in messages:
        if msg.status == "active" and not _source_record_exists(db, msg):
            previous_status = msg.status
            msg.status = _MESSAGE_STATUS_SOURCE_UNAVAILABLE
            stats["source_unavailable_updated"] += 1
            _write_message_state_audit_log(
                db,
                message=msg,
                action_code="message.source_unavailable",
                action_name="消息来源失效",
                previous_status=previous_status,
                current_status=msg.status,
                reason="source_record_missing_or_deleted",
            )
            changed = True
        if msg.status in {
            _MESSAGE_STATUS_SOURCE_UNAVAILABLE,
            _PUBLIC_MESSAGE_STATUS_SOURCE_UNAVAILABLE,
        }:
            reference_time = msg.updated_at or msg.created_at or current_time
            if reference_time <= archive_before:
                previous_status = msg.status
                msg.status = "archived"
                stats["archived_messages"] += 1
                _write_message_state_audit_log(
                    db,
                    message=msg,
                    action_code="message.archived",
                    action_name="消息归档",
                    previous_status=previous_status,
                    current_status=msg.status,
                    reason="source_unavailable_retention_expired",
                )
                changed = True
        if msg.expires_at is not None and msg.expires_at <= current_time:
            reference_time = msg.expires_at
            if reference_time <= archive_before and msg.status != "archived":
                previous_status = msg.status
                msg.status = "archived"
                stats["archived_messages"] += 1
                _write_message_state_audit_log(
                    db,
                    message=msg,
                    action_code="message.archived",
                    action_name="消息归档",
                    previous_status=previous_status,
                    current_status=msg.status,
                    reason="message_retention_expired",
                )
                changed = True
    if changed:
        db.flush()
    return stats


async def retry_failed_message_deliveries(
    db: Session,
    *,
    now: datetime | None = None,
    limit: int = 100,
) -> list[int]:
    from app.services.message_push_service import push_message_created

    current_time = now or datetime.now(UTC)
    recipients = (
        db.execute(
            select(MessageRecipient)
            .where(
                MessageRecipient.delivery_status == "failed",
                MessageRecipient.next_retry_at.is_not(None),
                MessageRecipient.next_retry_at <= current_time,
                MessageRecipient.is_deleted.is_(False),
            )
            .order_by(MessageRecipient.next_retry_at.asc(), MessageRecipient.id.asc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    retried_ids: list[int] = []
    for recipient in recipients:
        message_id = recipient.message_id
        user_id = recipient.recipient_user_id
        with SessionLocal() as retry_db:
            unread = get_unread_count(retry_db, user_id=user_id)
        delivered, failure_reason, pushed_at = await push_message_created(
            user_id,
            message_id,
            unread,
        )
        _mark_recipient_delivery_result(
            message_id=message_id,
            user_id=user_id,
            delivered=delivered,
            failure_reason=failure_reason,
            pushed_at=pushed_at,
        )
        retried_ids.append(recipient.id)
    return retried_ids


async def compensate_pending_message_deliveries(
    db: Session,
    *,
    now: datetime | None = None,
    limit: int = 100,
    grace_seconds: int | None = None,
) -> list[int]:
    current_time = now or datetime.now(UTC)
    pending_grace_seconds = (
        grace_seconds
        if grace_seconds is not None
        else settings.message_delivery_pending_grace_seconds
    )
    pending_before = current_time - timedelta(seconds=max(pending_grace_seconds, 0))
    recipients = (
        db.execute(
            select(MessageRecipient)
            .where(
                MessageRecipient.delivery_status == "pending",
                MessageRecipient.delivery_attempt_count == 0,
                MessageRecipient.last_push_at.is_(None),
                MessageRecipient.is_deleted.is_(False),
                MessageRecipient.created_at <= pending_before,
            )
            .order_by(MessageRecipient.created_at.asc(), MessageRecipient.id.asc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    compensated_ids: list[int] = []
    for recipient in recipients:
        await _push_message_created_for_recipient(
            recipient.message_id,
            recipient.recipient_user_id,
        )
        compensated_ids.append(recipient.id)
    return compensated_ids


async def run_message_delivery_maintenance_once(
    *,
    now: datetime | None = None,
    limit: int = 100,
) -> dict[str, int]:
    current_time = now or datetime.now(UTC)
    with SessionLocal() as db:
        maintenance_stats = run_message_maintenance(db, now=current_time)
        db.commit()

    with SessionLocal() as db:
        pending_ids = await compensate_pending_message_deliveries(
            db,
            now=current_time,
            limit=limit,
        )

    with SessionLocal() as db:
        retried_ids = await retry_failed_message_deliveries(
            db,
            now=current_time,
            limit=limit,
        )

    return {
        "pending_compensated": len(pending_ids),
        "failed_retried": len(retried_ids),
        "source_unavailable_updated": maintenance_stats["source_unavailable_updated"],
        "archived_messages": maintenance_stats["archived_messages"],
    }


async def run_message_delivery_maintenance_loop() -> None:
    interval_seconds = max(settings.message_delivery_maintenance_interval_seconds, 5)
    logger.info(
        "[MSG_MAINT] 消息投递维护循环已启动，间隔 %s 秒。",
        interval_seconds,
    )
    while True:
        try:
            stats = await run_message_delivery_maintenance_once(limit=200)
            if any(value > 0 for value in stats.values()):
                logger.info("[MSG_MAINT] 本轮维护完成：%s", stats)
        except (RuntimeError, ValueError, SQLAlchemyError):
            logger.exception("[MSG_MAINT] 消息投递维护循环执行失败")
        await asyncio.sleep(interval_seconds)


def _push_message_created_async(db: Session, msg: Message) -> None:
    stmt = select(MessageRecipient.recipient_user_id).where(
        MessageRecipient.message_id == msg.id,
        MessageRecipient.is_deleted.is_(False),
    )
    recipient_ids: list[int] = list(db.execute(stmt).scalars().all())

    if not recipient_ids:
        return

    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        # 同步业务入口通常运行在无线程事件循环的上下文；此处在事务提交后直接补做首次投递，
        # 若失败则仍走失败持久化与后续维护重试链路，不影响主业务提交结果。
        asyncio.run(_push_message_created_for_recipients(msg.id, recipient_ids))
        return

    for uid in recipient_ids:
        loop.create_task(_push_message_created_for_recipient(msg.id, uid))


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
    expires_at: datetime | None = None,
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
        expires_at=expires_at,
        created_by_user_id=created_by_user_id,
    )
    return create_message(db, req=req)


_VALID_ANNOUNCEMENT_PRIORITIES = {"normal", "important", "urgent"}
_VALID_ANNOUNCEMENT_RANGE_TYPES = {"all", "roles", "users"}


def _normalize_announcement_text(value: str, *, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} 不能为空")
    return normalized


def _normalize_announcement_priority(priority: str) -> str:
    normalized = priority.strip().lower()
    if normalized not in _VALID_ANNOUNCEMENT_PRIORITIES:
        raise ValueError("priority 仅支持 normal / important / urgent")
    return normalized


def _normalize_announcement_range_type(range_type: str) -> str:
    normalized = range_type.strip().lower()
    if normalized not in _VALID_ANNOUNCEMENT_RANGE_TYPES:
        raise ValueError("range_type 仅支持 all / roles / users")
    return normalized


def _announcement_summary(content: str) -> str:
    summary = " ".join(content.split())
    if len(summary) <= 120:
        return summary
    return f"{summary[:117]}..."


def _resolve_announcement_recipient_user_ids(
    db: Session,
    *,
    range_type: str,
    role_codes: list[str],
    user_ids: list[int],
) -> list[int]:
    base_stmt = select(User.id).where(
        User.is_deleted.is_(False),
        User.is_active.is_(True),
    )
    if range_type == "all":
        stmt = base_stmt.order_by(User.id.asc())
    elif range_type == "roles":
        normalized_role_codes = sorted(
            {code.strip() for code in role_codes if code and code.strip()}
        )
        if not normalized_role_codes:
            raise ValueError("range_type=roles 时必须选择至少一个角色")
        stmt = (
            base_stmt.join(User.roles)
            .where(
                Role.code.in_(normalized_role_codes),
                Role.is_enabled.is_(True),
                Role.is_deleted.is_(False),
            )
            .distinct()
            .order_by(User.id.asc())
        )
    else:
        normalized_user_ids = sorted(
            {int(user_id) for user_id in user_ids if int(user_id) > 0}
        )
        if not normalized_user_ids:
            raise ValueError("range_type=users 时必须选择至少一个用户")
        stmt = base_stmt.where(User.id.in_(normalized_user_ids)).order_by(User.id.asc())

    recipient_user_ids = list(db.execute(stmt).scalars().all())
    if not recipient_user_ids:
        raise ValueError("未匹配到可投递的有效用户")
    return recipient_user_ids


def publish_announcement(
    db: Session,
    *,
    req: AnnouncementPublishRequest,
    operator: User,
) -> AnnouncementPublishResult:
    title = _normalize_announcement_text(req.title, field_name="title")
    content = _normalize_announcement_text(req.content, field_name="content")
    priority = _normalize_announcement_priority(req.priority)
    range_type = _normalize_announcement_range_type(req.range_type)
    if req.expires_at is not None and req.expires_at <= datetime.now(UTC):
        raise ValueError("expires_at 必须晚于当前时间")

    recipient_user_ids = _resolve_announcement_recipient_user_ids(
        db,
        range_type=range_type,
        role_codes=req.role_codes,
        user_ids=req.user_ids,
    )
    message = create_message_for_users(
        db,
        message_type="announcement",
        priority=priority,
        title=title,
        summary=_announcement_summary(content),
        content=content,
        source_module="message",
        source_type="announcement",
        source_id=str(operator.id),
        source_code=range_type,
        recipient_user_ids=recipient_user_ids,
        expires_at=req.expires_at,
        created_by_user_id=operator.id,
    )
    return AnnouncementPublishResult(
        message_id=message.id,
        recipient_count=len(recipient_user_ids),
    )
