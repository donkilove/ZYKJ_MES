from __future__ import annotations

from collections import defaultdict
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_PENDING,
    RECORD_TYPE_PRODUCTION,
)
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.user import User


def get_overview_stats(
    db: Session,
    *,
    start_date: date | None = None,
    end_date: date | None = None,
) -> dict[str, int]:
    filters = []
    if start_date is not None:
        filters.append(ProductionOrder.created_at >= start_date)
    if end_date is not None:
        filters.append(ProductionOrder.created_at < (end_date))

    total_orders = db.execute(
        select(func.count()).select_from(ProductionOrder).where(*filters)
    ).scalar_one()
    pending_orders = db.execute(
        select(func.count())
        .select_from(ProductionOrder)
        .where(*filters, ProductionOrder.status == ORDER_STATUS_PENDING)
    ).scalar_one()
    in_progress_orders = db.execute(
        select(func.count())
        .select_from(ProductionOrder)
        .where(*filters, ProductionOrder.status == ORDER_STATUS_IN_PROGRESS)
    ).scalar_one()
    completed_orders = db.execute(
        select(func.count())
        .select_from(ProductionOrder)
        .where(*filters, ProductionOrder.status == ORDER_STATUS_COMPLETED)
    ).scalar_one()
    total_quantity = db.execute(
        select(func.coalesce(func.sum(ProductionOrder.quantity), 0)).where(*filters)
    ).scalar_one()

    last_process_subquery = (
        select(
            ProductionOrderProcess.order_id,
            func.max(ProductionOrderProcess.process_order).label("max_process_order"),
        )
        .group_by(ProductionOrderProcess.order_id)
        .subquery()
    )
    finished_quantity = db.execute(
        select(func.coalesce(func.sum(ProductionOrderProcess.completed_quantity), 0))
        .join(
            last_process_subquery,
            (ProductionOrderProcess.order_id == last_process_subquery.c.order_id)
            & (ProductionOrderProcess.process_order == last_process_subquery.c.max_process_order),
        )
        .join(ProductionOrder, ProductionOrder.id == ProductionOrderProcess.order_id)
        .where(*filters)
    ).scalar_one()

    return {
        "total_orders": int(total_orders or 0),
        "pending_orders": int(pending_orders or 0),
        "in_progress_orders": int(in_progress_orders or 0),
        "completed_orders": int(completed_orders or 0),
        "total_quantity": int(total_quantity or 0),
        "finished_quantity": int(finished_quantity or 0),
    }


def get_process_stats(db: Session) -> list[dict[str, int | str]]:
    rows = (
        db.execute(
            select(ProductionOrderProcess).order_by(
                ProductionOrderProcess.process_code.asc(),
                ProductionOrderProcess.process_order.asc(),
            )
        )
        .scalars()
        .all()
    )

    grouped: dict[str, dict[str, int | str]] = {}
    for row in rows:
        key = row.process_code
        if key not in grouped:
            grouped[key] = {
                "process_code": row.process_code,
                "process_name": row.process_name,
                "total_orders": 0,
                "pending_orders": 0,
                "in_progress_orders": 0,
                "partial_orders": 0,
                "completed_orders": 0,
                "total_visible_quantity": 0,
                "total_completed_quantity": 0,
            }
        item = grouped[key]
        item["total_orders"] = int(item["total_orders"]) + 1
        item["total_visible_quantity"] = int(item["total_visible_quantity"]) + row.visible_quantity
        item["total_completed_quantity"] = int(item["total_completed_quantity"]) + row.completed_quantity
        if row.status == PROCESS_STATUS_PENDING:
            item["pending_orders"] = int(item["pending_orders"]) + 1
        elif row.status == PROCESS_STATUS_IN_PROGRESS:
            item["in_progress_orders"] = int(item["in_progress_orders"]) + 1
        elif row.status == PROCESS_STATUS_PARTIAL:
            item["partial_orders"] = int(item["partial_orders"]) + 1
        elif row.status == PROCESS_STATUS_COMPLETED:
            item["completed_orders"] = int(item["completed_orders"]) + 1

    return list(grouped.values())


def get_operator_stats(db: Session) -> list[dict[str, int | str]]:
    rows = (
        db.execute(
            select(ProductionRecord)
            .where(ProductionRecord.record_type == RECORD_TYPE_PRODUCTION)
            .order_by(ProductionRecord.created_at.desc(), ProductionRecord.id.desc())
        )
        .scalars()
        .all()
    )
    user_rows = db.execute(select(User)).scalars().all()
    username_by_id = {row.id: row.username for row in user_rows}

    grouped: dict[tuple[int, str], dict[str, int | str]] = defaultdict(dict)
    for row in rows:
        key = (row.operator_user_id, row.order_process.process_code if row.order_process else "")
        item = grouped.get(key)
        if not item:
            item = {
                "operator_user_id": row.operator_user_id,
                "operator_username": username_by_id.get(row.operator_user_id, ""),
                "process_code": row.order_process.process_code if row.order_process else "",
                "process_name": row.order_process.process_name if row.order_process else "",
                "production_records": 0,
                "production_quantity": 0,
                "last_production_at": None,
            }
            grouped[key] = item
        item["production_records"] = int(item["production_records"]) + 1
        item["production_quantity"] = int(item["production_quantity"]) + row.production_quantity
        if item["last_production_at"] is None:
            item["last_production_at"] = row.created_at

    return list(grouped.values())
