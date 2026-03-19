from __future__ import annotations

import json
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.order_event_log import OrderEventLog
from app.models.production_order import ProductionOrder


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

    order_row = (
        db.execute(
            select(ProductionOrder)
            .where(ProductionOrder.id == order_id)
            .limit(1)
        )
        .scalars()
        .first()
    )

    row = OrderEventLog(
        order_id=order_id,
        order_code_snapshot=order_row.order_code if order_row else None,
        order_status_snapshot=order_row.status if order_row else None,
        product_name_snapshot=order_row.product.name if order_row and order_row.product else None,
        process_code_snapshot=order_row.current_process_code if order_row else None,
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
