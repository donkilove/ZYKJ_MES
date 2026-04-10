from __future__ import annotations

import base64
import csv
import io
import json
from dataclasses import dataclass
from datetime import UTC, date, datetime, time
from typing import Any
from uuid import uuid4

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_PENDING,
    REPAIR_STATUS_ALL,
    REPAIR_STATUS_COMPLETED,
    REPAIR_STATUS_IN_REPAIR,
    SCRAP_PROGRESS_ALL,
    SCRAP_PROGRESS_APPLIED,
    SCRAP_PROGRESS_PENDING_APPLY,
)
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.repair_cause import RepairCause
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
from app.models.repair_order import RepairOrder
from app.models.repair_return_route import RepairReturnRoute
from app.models.user import User
from app.services.production_event_log_service import add_order_event_log
from app.services.production_order_service import ensure_sub_orders_visible_quantity
from app.services.message_service import create_message_for_users


REPAIR_STATUS_FILTER_ALL = "all"
SCRAP_PROGRESS_FILTER_ALL = "all"


@dataclass(slots=True)
class RepairListFilters:
    keyword: str | None
    status: str | None
    start_date: date | None
    end_date: date | None


@dataclass(slots=True)
class ScrapStatisticsFilters:
    keyword: str | None
    progress: str | None
    product_name: str | None
    process_code: str | None
    start_date: date | None
    end_date: date | None


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _normalize_text(value: str | None) -> str:
    return (value or "").strip()


def normalize_repair_status(status: str | None) -> str | None:
    normalized = _normalize_text(status).lower() or REPAIR_STATUS_FILTER_ALL
    if normalized == REPAIR_STATUS_FILTER_ALL:
        return None
    if normalized not in REPAIR_STATUS_ALL:
        raise ValueError(f"Invalid repair status: {status}")
    return normalized


def normalize_scrap_progress(progress: str | None) -> str | None:
    normalized = _normalize_text(progress).lower() or SCRAP_PROGRESS_FILTER_ALL
    if normalized == SCRAP_PROGRESS_FILTER_ALL:
        return None
    if normalized not in SCRAP_PROGRESS_ALL:
        raise ValueError(f"Invalid scrap progress: {progress}")
    return normalized


def _normalize_date_range(
    *,
    start_date: date | None,
    end_date: date | None,
) -> tuple[datetime | None, datetime | None]:
    if start_date is None and end_date is None:
        return None, None
    resolved_start = start_date or end_date
    resolved_end = end_date or start_date
    if resolved_start and resolved_end and resolved_start > resolved_end:
        raise ValueError("start_date cannot be later than end_date")
    assert resolved_start is not None
    assert resolved_end is not None
    return (
        datetime.combine(resolved_start, time.min).replace(tzinfo=UTC),
        datetime.combine(resolved_end, time.max).replace(tzinfo=UTC),
    )


def _normalize_quantity(value: Any, *, field_name: str) -> int:
    number = int(value or 0)
    if number <= 0:
        raise ValueError(f"{field_name} must be greater than 0")
    return number


def _sanitize_defect_items(
    defect_items: list[dict[str, Any]] | None,
) -> list[dict[str, Any]]:
    normalized: list[dict[str, Any]] = []
    for item in defect_items or []:
        if not isinstance(item, dict):
            continue
        phenomenon = _normalize_text(str(item.get("phenomenon") or ""))
        if not phenomenon:
            continue
        quantity = int(item.get("quantity") or 0)
        if quantity <= 0:
            continue
        normalized.append(
            {
                "phenomenon": phenomenon,
                "quantity": quantity,
                "production_record_id": int(item.get("production_record_id") or 0) or None,
                "production_time": item.get("production_time"),
            }
        )
    return normalized


def _sanitize_cause_items(
    cause_items: list[dict[str, Any]] | None,
) -> list[dict[str, Any]]:
    normalized: list[dict[str, Any]] = []
    for item in cause_items or []:
        if not isinstance(item, dict):
            continue
        phenomenon = _normalize_text(str(item.get("phenomenon") or ""))
        reason = _normalize_text(str(item.get("reason") or ""))
        quantity = int(item.get("quantity") or 0)
        if not phenomenon:
            raise ValueError("phenomenon is required")
        if not reason:
            raise ValueError("reason is required")
        if quantity <= 0:
            raise ValueError("quantity must be greater than 0")
        normalized.append(
            {
                "phenomenon": phenomenon,
                "reason": reason,
                "quantity": quantity,
                "is_scrap": bool(item.get("is_scrap")),
            }
        )
    return normalized


def _sanitize_return_allocations(
    return_allocations: list[dict[str, Any]] | None,
) -> list[dict[str, Any]]:
    normalized: list[dict[str, Any]] = []
    for item in return_allocations or []:
        if not isinstance(item, dict):
            continue
        target_order_process_id = int(item.get("target_order_process_id") or 0)
        quantity = int(item.get("quantity") or 0)
        if target_order_process_id <= 0:
            continue
        if quantity <= 0:
            continue
        normalized.append(
            {
                "target_order_process_id": target_order_process_id,
                "quantity": quantity,
            }
        )
    return normalized


def _generate_repair_order_code() -> str:
    return f"RW{_now_utc().strftime('%Y%m%d%H%M%S%f')}{uuid4().hex[:4].upper()}"


def _load_order_with_process(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
) -> tuple[ProductionOrder, ProductionOrderProcess]:
    order = (
        db.execute(
            select(ProductionOrder)
            .where(ProductionOrder.id == order_id)
            .options(selectinload(ProductionOrder.product))
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if order is None:
        raise ValueError("Order not found")
    process_row = (
        db.execute(
            select(ProductionOrderProcess)
            .where(
                ProductionOrderProcess.id == order_process_id,
                ProductionOrderProcess.order_id == order_id,
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if process_row is None:
        raise ValueError("Order process not found")
    return order, process_row


def create_repair_order(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    sender: User | None,
    production_quantity: int,
    defect_items: list[dict[str, Any]] | None,
    auto_created: bool,
) -> RepairOrder:
    defects = _sanitize_defect_items(defect_items)
    repair_quantity = int(sum(int(item["quantity"]) for item in defects))
    if repair_quantity <= 0:
        raise ValueError("defect_items must contain at least one positive quantity")
    normalized_production_quantity = _normalize_quantity(
        production_quantity,
        field_name="production_quantity",
    )
    if normalized_production_quantity < repair_quantity:
        raise ValueError(
            "production_quantity must be greater than or equal to total defect quantity"
        )

    order, process_row = _load_order_with_process(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    event_time = _now_utc()
    repair_row = RepairOrder(
        repair_order_code=_generate_repair_order_code(),
        source_order_id=order.id,
        source_order_code=order.order_code,
        product_id=order.product_id,
        product_name=order.product.name if order.product else "",
        source_order_process_id=process_row.id,
        source_process_code=process_row.process_code,
        source_process_name=process_row.process_name,
        sender_user_id=sender.id if sender else None,
        sender_username=sender.username if sender else None,
        production_quantity=normalized_production_quantity,
        repair_quantity=repair_quantity,
        repaired_quantity=0,
        scrap_quantity=0,
        scrap_replenished=False,
        repair_time=event_time,
        status=REPAIR_STATUS_IN_REPAIR,
    )
    db.add(repair_row)
    db.flush()

    production_record_by_id: dict[int, ProductionRecord] = {}
    production_record_ids = {
        int(item["production_record_id"])
        for item in defects
        if item.get("production_record_id")
    }
    if production_record_ids:
        production_record_rows = (
            db.execute(
                select(ProductionRecord).where(ProductionRecord.id.in_(production_record_ids))
            )
            .scalars()
            .all()
        )
        production_record_by_id = {int(row.id): row for row in production_record_rows}

    for item in defects:
        production_record_id = item.get("production_record_id")
        production_record = (
            production_record_by_id.get(int(production_record_id))
            if production_record_id
            else None
        )
        production_time = item.get("production_time")
        if not isinstance(production_time, datetime):
            production_time = production_record.created_at if production_record else event_time
        db.add(
            RepairDefectPhenomenon(
                repair_order_id=repair_row.id,
                production_record_id=production_record.id if production_record else None,
                order_id=order.id,
                order_code=order.order_code,
                product_id=order.product_id,
                product_name=order.product.name if order.product else "",
                process_id=process_row.id,
                process_code=process_row.process_code,
                process_name=process_row.process_name,
                phenomenon=str(item["phenomenon"]),
                quantity=int(item["quantity"]),
                operator_user_id=sender.id if sender else None,
                operator_username=sender.username if sender else None,
                production_time=production_time,
            )
        )

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="repair_order_created_auto"
        if auto_created
        else "repair_order_created_manual",
        event_title="维修单已创建",
        event_detail=f"工序 {process_row.process_name} 创建维修单 {repair_row.repair_order_code}",
        operator_user_id=sender.id if sender else None,
        process_code_snapshot=process_row.process_code,
        payload={
            "repair_order_id": repair_row.id,
            "repair_order_code": repair_row.repair_order_code,
            "order_process_id": process_row.id,
            "defect_count": len(defects),
            "repair_quantity": repair_quantity,
            "auto_created": auto_created,
        },
    )
    db.flush()
    return repair_row


def _recompute_order_status_by_quantities(order: ProductionOrder) -> None:
    process_rows = sorted(order.processes, key=lambda row: (row.process_order, row.id))
    first_incomplete = next(
        (
            row
            for row in process_rows
            if int(row.completed_quantity or 0) < int(row.visible_quantity or 0)
        ),
        None,
    )
    if first_incomplete is None:
        order.status = ORDER_STATUS_COMPLETED
        order.current_process_code = None
        return
    order.status = ORDER_STATUS_IN_PROGRESS
    order.current_process_code = first_incomplete.process_code


def complete_repair_order(
    db: Session,
    *,
    repair_order_id: int,
    cause_items: list[dict[str, Any]] | None,
    scrap_replenished: bool,
    return_allocations: list[dict[str, Any]] | None,
    operator: User,
) -> RepairOrder:
    repair_row = (
        db.execute(
            select(RepairOrder)
            .where(RepairOrder.id == repair_order_id)
            .options(
                selectinload(RepairOrder.source_order).selectinload(
                    ProductionOrder.processes
                ),
                selectinload(RepairOrder.source_order_process),
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if repair_row is None:
        raise ValueError("Repair order not found")
    if repair_row.status == REPAIR_STATUS_COMPLETED:
        raise RuntimeError("Repair order already completed")

    normalized_causes = _sanitize_cause_items(cause_items)
    if not normalized_causes:
        raise ValueError("cause_items is required")
    total_quantity = int(sum(int(item["quantity"]) for item in normalized_causes))
    if total_quantity != int(repair_row.repair_quantity):
        raise ValueError(
            f"cause quantity must equal repair quantity {repair_row.repair_quantity}"
        )

    scrap_quantity = int(
        sum(
            int(item["quantity"])
            for item in normalized_causes
            if bool(item["is_scrap"])
        )
    )
    repaired_quantity = int(repair_row.repair_quantity) - scrap_quantity

    normalized_returns = _sanitize_return_allocations(return_allocations)
    return_quantity_total = int(
        sum(int(item["quantity"]) for item in normalized_returns)
    )
    if repaired_quantity > 0 and return_quantity_total != repaired_quantity:
        raise ValueError(
            "sum(return_allocations.quantity) must equal repaired quantity"
        )
    if repaired_quantity <= 0 and return_quantity_total > 0:
        raise ValueError("return_allocations must be empty when repaired quantity is 0")

    source_order = repair_row.source_order
    source_process = repair_row.source_order_process
    process_map_by_id: dict[int, ProductionOrderProcess] = {}
    process_order_rank: dict[int, int] = {}
    if source_order is not None:
        process_rows = sorted(
            source_order.processes, key=lambda row: (row.process_order, row.id)
        )
        process_map_by_id = {row.id: row for row in process_rows}
        process_order_rank = {row.id: int(row.process_order) for row in process_rows}
    if source_process is None and repair_row.source_order_process_id:
        source_process = process_map_by_id.get(int(repair_row.source_order_process_id))
    if source_process is None:
        raise ValueError("Source process snapshot is missing")

    source_rank = process_order_rank.get(
        source_process.id, int(source_process.process_order)
    )
    for item in normalized_returns:
        target_process = process_map_by_id.get(int(item["target_order_process_id"]))
        if target_process is None:
            raise ValueError("Return allocation target process not found")
        target_rank = process_order_rank.get(
            target_process.id, int(target_process.process_order)
        )
        if target_rank > source_rank:
            raise ValueError(
                "Return allocation target must be current process or previous process"
            )

    db.execute(
        select(RepairCause)
        .where(RepairCause.repair_order_id == repair_row.id)
        .with_for_update()
    )
    db.execute(
        select(RepairReturnRoute)
        .where(RepairReturnRoute.repair_order_id == repair_row.id)
        .with_for_update()
    )
    repair_row.cause_rows = []
    repair_row.return_routes = []
    db.flush()

    now = _now_utc()
    for item in normalized_causes:
        db.add(
            RepairCause(
                repair_order_id=repair_row.id,
                order_id=repair_row.source_order_id,
                order_code=repair_row.source_order_code,
                product_id=repair_row.product_id,
                product_name=repair_row.product_name,
                process_id=repair_row.source_order_process_id,
                process_code=repair_row.source_process_code,
                process_name=repair_row.source_process_name,
                phenomenon=str(item["phenomenon"]),
                reason=str(item["reason"]),
                is_scrap=bool(item["is_scrap"]),
                quantity=int(item["quantity"]),
                cause_time=now,
                operator_user_id=operator.id,
                operator_username=operator.username,
            )
        )

    affected_process_ids: set[int] = set()
    for item in normalized_returns:
        target_process = process_map_by_id[int(item["target_order_process_id"])]
        qty = int(item["quantity"])
        db.add(
            RepairReturnRoute(
                repair_order_id=repair_row.id,
                source_order_id=repair_row.source_order_id,
                source_process_id=source_process.id,
                source_process_code=source_process.process_code,
                source_process_name=source_process.process_name,
                target_process_id=target_process.id,
                target_process_code=target_process.process_code,
                target_process_name=target_process.process_name,
                return_quantity=qty,
                operator_user_id=operator.id,
                operator_username=operator.username,
            )
        )
        target_process.visible_quantity = int(target_process.visible_quantity) + qty
        if (
            target_process.status == PROCESS_STATUS_COMPLETED
            and target_process.visible_quantity > target_process.completed_quantity
        ):
            target_process.status = (
                PROCESS_STATUS_PARTIAL
                if int(target_process.completed_quantity) > 0
                else PROCESS_STATUS_PENDING
            )
        ensure_sub_orders_visible_quantity(
            db,
            process_row=target_process,
            target_visible_quantity=target_process.visible_quantity,
        )
        affected_process_ids.add(target_process.id)
        if target_process.id != source_process.id:
            source_process.visible_quantity = max(
                int(source_process.completed_quantity),
                int(source_process.visible_quantity) - qty,
            )
            if (
                source_process.status == PROCESS_STATUS_COMPLETED
                and source_process.visible_quantity > source_process.completed_quantity
            ):
                source_process.status = (
                    PROCESS_STATUS_PARTIAL
                    if int(source_process.completed_quantity) > 0
                    else PROCESS_STATUS_PENDING
                )
            ensure_sub_orders_visible_quantity(
                db,
                process_row=source_process,
                target_visible_quantity=source_process.visible_quantity,
            )
            affected_process_ids.add(source_process.id)

    if scrap_replenished and scrap_quantity > 0 and source_order is not None:
        first_process = min(
            source_order.processes,
            key=lambda row: (row.process_order, row.id),
            default=None,
        )
        if first_process is not None:
            first_process.visible_quantity = (
                int(first_process.visible_quantity) + scrap_quantity
            )
            if (
                first_process.status == PROCESS_STATUS_COMPLETED
                and first_process.visible_quantity > first_process.completed_quantity
            ):
                first_process.status = (
                    PROCESS_STATUS_PARTIAL
                    if int(first_process.completed_quantity) > 0
                    else PROCESS_STATUS_PENDING
                )
            ensure_sub_orders_visible_quantity(
                db,
                process_row=first_process,
                target_visible_quantity=first_process.visible_quantity,
            )
            affected_process_ids.add(first_process.id)

    if source_order is not None:
        _recompute_order_status_by_quantities(source_order)

    scrap_reason_bucket: dict[str, int] = {}
    for item in normalized_causes:
        if not bool(item["is_scrap"]):
            continue
        reason = str(item["reason"])
        scrap_reason_bucket[reason] = int(scrap_reason_bucket.get(reason, 0)) + int(
            item["quantity"]
        )
    if scrap_reason_bucket:
        for reason, qty in scrap_reason_bucket.items():
            existing = (
                db.execute(
                    select(ProductionScrapStatistics)
                    .where(
                        ProductionScrapStatistics.order_id
                        == repair_row.source_order_id,
                        ProductionScrapStatistics.process_id
                        == repair_row.source_order_process_id,
                        ProductionScrapStatistics.scrap_reason == reason,
                        ProductionScrapStatistics.progress
                        == SCRAP_PROGRESS_PENDING_APPLY,
                    )
                    .with_for_update()
                )
                .scalars()
                .first()
            )
            if existing is None:
                db.add(
                    ProductionScrapStatistics(
                        order_id=repair_row.source_order_id,
                        order_code=repair_row.source_order_code,
                        product_id=repair_row.product_id,
                        product_name=repair_row.product_name,
                        process_id=repair_row.source_order_process_id,
                        process_code=repair_row.source_process_code,
                        process_name=repair_row.source_process_name,
                        operator_user_id=repair_row.sender_user_id,
                        operator_username=repair_row.sender_username,
                        scrap_reason=reason,
                        scrap_quantity=qty,
                        last_scrap_time=now,
                        progress=SCRAP_PROGRESS_APPLIED,
                        applied_at=now,
                    )
                )
            else:
                existing.scrap_quantity = int(existing.scrap_quantity) + qty
                existing.last_scrap_time = now
                existing.operator_user_id = repair_row.sender_user_id
                existing.operator_username = repair_row.sender_username
                existing.progress = SCRAP_PROGRESS_APPLIED
                existing.applied_at = now

    repair_row.repaired_quantity = repaired_quantity
    repair_row.scrap_quantity = scrap_quantity
    repair_row.scrap_replenished = bool(scrap_replenished)
    repair_row.completed_at = now
    repair_row.status = REPAIR_STATUS_COMPLETED
    repair_row.repair_operator_user_id = operator.id
    repair_row.repair_operator_username = operator.username

    if repair_row.source_order_id:
        add_order_event_log(
            db,
            order_id=int(repair_row.source_order_id),
            event_type="repair_order_completed",
            event_title="维修单已完成",
            event_detail=(
                f"维修单 {repair_row.repair_order_code} 完成，"
                f"报废 {scrap_quantity}，回流 {repaired_quantity}"
            ),
            operator_user_id=operator.id,
            process_code_snapshot=repair_row.source_process_code,
            payload={
                "repair_order_id": repair_row.id,
                "repair_order_code": repair_row.repair_order_code,
                "scrap_quantity": scrap_quantity,
                "repaired_quantity": repaired_quantity,
                "scrap_replenished": bool(scrap_replenished),
                "affected_process_ids": sorted(affected_process_ids),
            },
        )

    db.commit()
    db.refresh(repair_row)

    # 通知订单相关操作员：维修完成
    if repair_row.source_order_id and repair_row.sender_user_id:
        create_message_for_users(
            db,
            message_type="notice",
            priority="normal",
            title=f"维修单已完成：{repair_row.repair_order_code}",
            summary=(
                f"订单 {repair_row.source_order_code or ''} / {repair_row.source_process_name or ''} "
                f"维修完成，回流 {repaired_quantity}，报废 {scrap_quantity}"
            ),
            source_module="quality",
            source_type="repair_order",
            source_id=str(repair_row.id),
            source_code=repair_row.repair_order_code,
            target_page_code="quality",
            target_tab_code="quality_repair_orders",
            target_route_payload_json=json.dumps(
                {
                    "action": "detail",
                    "repair_order_id": repair_row.id,
                    "repair_order_code": repair_row.repair_order_code,
                },
                ensure_ascii=False,
            ),
            recipient_user_ids=[repair_row.sender_user_id],
            dedupe_key=f"repair_complete_{repair_row.id}",
            created_by_user_id=operator.id,
        )
        if scrap_quantity > 0:
            scrap_row = (
                db.execute(
                    select(ProductionScrapStatistics)
                    .where(
                        ProductionScrapStatistics.order_id == repair_row.source_order_id,
                        ProductionScrapStatistics.process_id
                        == repair_row.source_order_process_id,
                    )
                    .order_by(ProductionScrapStatistics.applied_at.desc(), ProductionScrapStatistics.id.desc())
                )
                .scalars()
                .first()
            )
            if scrap_row is not None:
                create_message_for_users(
                    db,
                    message_type="notice",
                    priority="normal",
                    title=f"报废已处理：{repair_row.source_order_code or ''} / {repair_row.source_process_name or ''}",
                    summary=f"维修完成后已归档报废 {scrap_quantity} 件，可直接查看品质报废详情。",
                    source_module="quality",
                    source_type="scrap_statistics",
                    source_id=str(scrap_row.id),
                    source_code=repair_row.source_order_code,
                    target_page_code="quality",
                    target_tab_code="quality_scrap_statistics",
                    target_route_payload_json=json.dumps(
                        {
                            "action": "detail",
                            "scrap_id": scrap_row.id,
                            "order_code": scrap_row.order_code,
                        },
                        ensure_ascii=False,
                    ),
                    recipient_user_ids=[repair_row.sender_user_id],
                    dedupe_key=f"scrap_applied_{repair_row.id}_{scrap_row.id}",
                    created_by_user_id=operator.id,
                )

    return repair_row


def list_repair_orders(
    db: Session,
    *,
    page: int,
    page_size: int,
    filters: RepairListFilters,
) -> tuple[int, list[RepairOrder]]:
    normalized_status = normalize_repair_status(filters.status)
    start_at, end_at = _normalize_date_range(
        start_date=filters.start_date,
        end_date=filters.end_date,
    )
    keyword = _normalize_text(filters.keyword)

    stmt = select(RepairOrder).options(
        selectinload(RepairOrder.sender_user),
    )
    if normalized_status:
        stmt = stmt.where(RepairOrder.status == normalized_status)
    if start_at:
        stmt = stmt.where(RepairOrder.repair_time >= start_at)
    if end_at:
        stmt = stmt.where(RepairOrder.repair_time <= end_at)
    if keyword:
        like_value = f"%{keyword}%"
        stmt = stmt.where(
            or_(
                RepairOrder.repair_order_code.ilike(like_value),
                RepairOrder.source_order_code.ilike(like_value),
                RepairOrder.product_name.ilike(like_value),
                RepairOrder.source_process_name.ilike(like_value),
                RepairOrder.sender_username.ilike(like_value),
            )
        )
    rows = (
        db.execute(
            stmt.order_by(
                RepairOrder.repair_time.desc(),
                RepairOrder.id.desc(),
            )
        )
        .scalars()
        .all()
    )
    total = len(rows)
    offset = (page - 1) * page_size
    return total, rows[offset : offset + page_size]


def get_repair_order_by_id(db: Session, *, repair_order_id: int) -> RepairOrder | None:
    return (
        db.execute(
            select(RepairOrder)
            .where(RepairOrder.id == repair_order_id)
            .options(
                selectinload(RepairOrder.defect_rows),
                selectinload(RepairOrder.cause_rows),
                selectinload(RepairOrder.return_routes),
            )
        )
        .scalars()
        .first()
    )


def get_repair_order_phenomena_summary(
    db: Session,
    *,
    repair_order_id: int,
) -> list[dict[str, Any]]:
    rows = db.execute(
        select(
            RepairDefectPhenomenon.phenomenon.label("phenomenon"),
            func.sum(RepairDefectPhenomenon.quantity).label("quantity"),
        )
        .where(RepairDefectPhenomenon.repair_order_id == repair_order_id)
        .group_by(RepairDefectPhenomenon.phenomenon)
        .order_by(
            func.sum(RepairDefectPhenomenon.quantity).desc(),
            RepairDefectPhenomenon.phenomenon.asc(),
        )
    ).all()
    return [
        {
            "phenomenon": str(row.phenomenon),
            "quantity": int(row.quantity or 0),
        }
        for row in rows
        if int(row.quantity or 0) > 0
    ]


def create_manual_repair_order(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    production_quantity: int,
    defect_items: list[dict[str, Any]] | None,
    sender: User,
) -> RepairOrder:
    return create_repair_order(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
        sender=sender,
        production_quantity=_normalize_quantity(
            production_quantity, field_name="production_quantity"
        ),
        defect_items=defect_items,
        auto_created=False,
    )


def list_scrap_statistics(
    db: Session,
    *,
    page: int,
    page_size: int,
    filters: ScrapStatisticsFilters,
) -> tuple[int, list[ProductionScrapStatistics]]:
    normalized_progress = normalize_scrap_progress(filters.progress)
    start_at, end_at = _normalize_date_range(
        start_date=filters.start_date,
        end_date=filters.end_date,
    )
    keyword = _normalize_text(filters.keyword)
    product_name = _normalize_text(filters.product_name)
    process_code = _normalize_text(filters.process_code)

    stmt = select(ProductionScrapStatistics)
    if normalized_progress:
        stmt = stmt.where(ProductionScrapStatistics.progress == normalized_progress)
    if start_at:
        stmt = stmt.where(ProductionScrapStatistics.last_scrap_time >= start_at)
    if end_at:
        stmt = stmt.where(ProductionScrapStatistics.last_scrap_time <= end_at)
    if keyword:
        like_value = f"%{keyword}%"
        stmt = stmt.where(
            or_(
                ProductionScrapStatistics.order_code.ilike(like_value),
                ProductionScrapStatistics.product_name.ilike(like_value),
                ProductionScrapStatistics.process_name.ilike(like_value),
                ProductionScrapStatistics.scrap_reason.ilike(like_value),
            )
        )
    if product_name:
        stmt = stmt.where(ProductionScrapStatistics.product_name == product_name)
    if process_code:
        stmt = stmt.where(ProductionScrapStatistics.process_code == process_code)
    rows = (
        db.execute(
            stmt.order_by(
                ProductionScrapStatistics.last_scrap_time.desc(),
                ProductionScrapStatistics.id.desc(),
            )
        )
        .scalars()
        .all()
    )
    total = len(rows)
    offset = (page - 1) * page_size
    return total, rows[offset : offset + page_size]


def _build_csv_base64(headers: list[str], rows: list[list[Any]]) -> str:
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for row in rows:
        writer.writerow(row)
    return base64.b64encode(output.getvalue().encode("utf-8-sig")).decode("ascii")


def export_scrap_statistics_csv(
    db: Session,
    *,
    filters: ScrapStatisticsFilters,
    operator: User,
) -> dict[str, Any]:
    _, rows = list_scrap_statistics(
        db,
        page=1,
        page_size=200000,
        filters=filters,
    )
    csv_rows: list[list[Any]] = []
    for row in rows:
        csv_rows.append(
            [
                row.order_code or "",
                row.product_name or "",
                row.process_name or "",
                row.scrap_reason,
                int(row.scrap_quantity),
                row.last_scrap_time.astimezone().strftime("%Y-%m-%d %H:%M:%S")
                if row.last_scrap_time
                else "",
                row.process_code or "",
                row.operator_username or "",
                "待处理" if row.progress == SCRAP_PROGRESS_PENDING_APPLY else "已处理",
                row.applied_at.astimezone().strftime("%Y-%m-%d %H:%M:%S")
                if row.applied_at
                else "",
            ]
        )
    content_base64 = _build_csv_base64(
        [
            "订单编号",
            "产品名称",
            "工序名称",
            "报废原因",
            "报废数量",
            "最近报废时间",
            "工序编码",
            "操作员",
            "进度",
            "处理时间",
        ],
        csv_rows,
    )
    return {
        "file_name": f"production_scrap_statistics_{_now_utc().strftime('%Y%m%d_%H%M%S')}.csv",
        "mime_type": "text/csv",
        "content_base64": content_base64,
        "exported_count": len(rows),
    }


def export_repair_orders_csv(
    db: Session,
    *,
    filters: RepairListFilters,
    operator: User,
) -> dict[str, Any]:
    _, rows = list_repair_orders(
        db,
        page=1,
        page_size=200000,
        filters=filters,
    )
    csv_rows: list[list[Any]] = []
    for row in rows:
        csv_rows.append(
            [
                row.repair_order_code,
                row.source_order_code or "",
                row.product_name or "",
                row.source_process_code,
                row.source_process_name,
                row.sender_username or "",
                row.repair_operator_username or "",
                int(row.production_quantity),
                int(row.repair_quantity),
                int(row.repaired_quantity),
                int(row.scrap_quantity),
                "是" if row.scrap_replenished else "否",
                "维修中" if row.status == REPAIR_STATUS_IN_REPAIR else "已完成",
                row.repair_time.astimezone().strftime("%Y-%m-%d %H:%M:%S")
                if row.repair_time
                else "",
                row.completed_at.astimezone().strftime("%Y-%m-%d %H:%M:%S")
                if row.completed_at
                else "",
            ]
        )
    content_base64 = _build_csv_base64(
        [
            "维修单编号",
            "订单编号",
            "产品名称",
            "送修工序编码",
            "送修工序",
            "送修人",
            "维修人",
            "本次生产数量",
            "送修数量",
            "已修复数量",
            "报废数量",
            "报废已补充",
            "维修状态",
            "送修时间",
            "完成时间",
        ],
        csv_rows,
    )
    unique_order_ids = sorted(
        {int(row.source_order_id) for row in rows if row.source_order_id}
    )
    for order_id in unique_order_ids:
        add_order_event_log(
            db,
            order_id=order_id,
            event_type="repair_orders_export",
            event_title="维修订单已导出",
            event_detail=f"导出记录数：{len(rows)}",
            operator_user_id=operator.id,
            payload={
                "exported_count": len(rows),
                "repair_order_ids": [int(row.id) for row in rows],
            },
        )
    db.commit()
    now = _now_utc()
    return {
        "file_name": f"repair_orders_{now.strftime('%Y%m%d_%H%M%S')}.csv",
        "mime_type": "text/csv",
        "content_base64": content_base64,
        "exported_count": len(rows),
    }
