from __future__ import annotations

import json
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.order_event_log import OrderEventLog


def add_order_event_log(
    db: Session,
    *,
    order_id: int,
    event_type: str,
    event_title: str,
    event_detail: str | None,
    operator_user_id: int | None = None,
    payload: dict[str, Any] | None = None,
) -> OrderEventLog:
    payload_json = None
    if payload is not None:
        payload_json = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))

    row = OrderEventLog(
        order_id=order_id,
        event_type=event_type,
        event_title=event_title,
        event_detail=event_detail,
        operator_user_id=operator_user_id,
        payload_json=payload_json,
    )
    db.add(row)
    db.flush()
    return row


def list_order_event_logs(
    db: Session,
    *,
    order_id: int,
    limit: int = 200,
) -> list[OrderEventLog]:
    stmt = (
        select(OrderEventLog)
        .where(OrderEventLog.order_id == order_id)
        .order_by(OrderEventLog.created_at.desc(), OrderEventLog.id.desc())
        .limit(limit)
    )
    return db.execute(stmt).scalars().all()
