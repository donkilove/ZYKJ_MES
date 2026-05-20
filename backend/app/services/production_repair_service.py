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
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_PENDING,
    REPAIR_STATUS_ALL,
    REPAIR_STATUS_COMPLETED,
    REPAIR_STATUS_IN_REPAIR,
    REPAIR_STATUS_RETURNED_TO_PRODUCTION,
    SCRAP_PROGRESS_ALL,
    SCRAP_PROGRESS_APPLIED,
    SCRAP_PROGRESS_PENDING_APPLY,
    SUB_ORDER_STATUS_IN_PROGRESS,
)
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.production_sub_order import ProductionSubOrder
from app.models.repair_cause import RepairCause
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
from app.models.repair_order import RepairOrder
from app.models.repair_return_route import RepairReturnRoute
from app.models.user import User
from app.services.assist_authorization_service import (
    ASSIST_OP_MANUAL_REPAIR,
    get_usable_assist_authorization_for_operation,
)
from app.services.production_event_log_service import add_order_event_log
from app.services.production_order_service import (
    ensure_sub_orders_visible_quantity,
    get_in_progress_sub_order_count,
    get_process_remaining_quantity,
    get_runtime_max_producible_quantity,
)
from app.services.message_service import create_message_for_users
from app.models.first_article_record import FirstArticleRecord


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


@dataclass(slots=True)
class RepairAggregateChildSnapshot:
    id: int
    repair_order_code: str
    source_order_id: int | None
    source_order_code: str | None
    product_id: int | None
    product_name: str | None
    source_order_process_id: int | None
    source_process_code: str
    source_process_name: str
    sender_user_id: int | None
    sender_username: str | None
    production_quantity: int
    repair_quantity: int
    repaired_quantity: int
    scrap_quantity: int
    scrap_replenished: bool
    repair_time: datetime
    status: str
    completed_at: datetime | None
    repair_operator_user_id: int | None
    repair_operator_username: str | None
    created_at: datetime
    updated_at: datetime


@dataclass(slots=True)
class RepairAggregateSnapshot:
    id: int
    repair_order_code: str
    source_order_id: int | None
    source_order_code: str | None
    product_id: int | None
    product_name: str | None
    source_order_process_id: int | None
    source_process_code: str
    source_process_name: str
    sender_user_id: int | None
    sender_username: str | None
    production_quantity: int
    repair_quantity: int
    repaired_quantity: int
    scrap_quantity: int
    scrap_replenished: bool
    repair_time: datetime
    status: str
    completed_at: datetime | None
    repair_operator_user_id: int | None
    repair_operator_username: str | None
    created_at: datetime
    updated_at: datetime
    is_aggregated: bool
    aggregate_status: str | None
    aggregate_anchor_repair_order_id: int | None
    child_repair_order_count: int
    child_repair_order_ids: list[int]
    child_repair_order_codes: list[str]
    child_rows: list[RepairAggregateChildSnapshot]
    phenomenon_summary: list[dict[str, Any]]
    cause_summary: list[dict[str, Any]]


@dataclass(slots=True)
class RepairCycleContext:
    cycle_started_at: datetime
    next_cycle_started_at: datetime | None
    production_record_quantity: int
    production_record_ended_at: datetime | None


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _repair_status_label(status: str) -> str:
    return {
        REPAIR_STATUS_IN_REPAIR: "维修中",
        REPAIR_STATUS_COMPLETED: "已完成",
        REPAIR_STATUS_RETURNED_TO_PRODUCTION: "已退回生产",
    }.get(status, status)


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


def _is_manual_repair_row(repair_row: RepairOrder) -> bool:
    return all(defect_row.production_record_id is None for defect_row in repair_row.defect_rows)


def _is_manual_repair_by_fields(
    *,
    repair_order_id: int,
    manual_repair_order_ids: set[int],
) -> bool:
    return repair_order_id in manual_repair_order_ids


def _resolve_cycle_started_at_for_repair(
    db: Session,
    *,
    repair_row: RepairOrder,
) -> datetime | None:
    context = _resolve_repair_cycle_context(db, repair_row=repair_row)
    return context.cycle_started_at if context else None


def _resolve_repair_cycle_context(
    db: Session,
    *,
    repair_row: RepairOrder,
) -> RepairCycleContext | None:
    if (
        repair_row.source_order_id is None
        or repair_row.sender_user_id is None
        or repair_row.source_order_process_id is None
    ):
        return None
    cycle_started_at = (
        db.execute(
            select(FirstArticleRecord.created_at)
            .where(
                FirstArticleRecord.order_id == repair_row.source_order_id,
                FirstArticleRecord.order_process_id
                == repair_row.source_order_process_id,
                FirstArticleRecord.operator_user_id == repair_row.sender_user_id,
                FirstArticleRecord.result == "passed",
                FirstArticleRecord.is_cancelled.is_(False),
                FirstArticleRecord.created_at <= repair_row.repair_time,
            )
            .order_by(
                FirstArticleRecord.created_at.desc(),
                FirstArticleRecord.id.desc(),
            )
        )
        .scalars()
        .first()
    )
    if cycle_started_at is None:
        return None

    next_cycle_started_at = (
        db.execute(
            select(FirstArticleRecord.created_at)
            .where(
                FirstArticleRecord.order_id == repair_row.source_order_id,
                FirstArticleRecord.order_process_id
                == repair_row.source_order_process_id,
                FirstArticleRecord.operator_user_id == repair_row.sender_user_id,
                FirstArticleRecord.result == "passed",
                FirstArticleRecord.is_cancelled.is_(False),
                FirstArticleRecord.created_at > cycle_started_at,
            )
            .order_by(
                FirstArticleRecord.created_at.asc(),
                FirstArticleRecord.id.asc(),
            )
        )
        .scalars()
        .first()
    )

    production_stmt = select(ProductionRecord).where(
        ProductionRecord.order_id == repair_row.source_order_id,
        ProductionRecord.order_process_id == repair_row.source_order_process_id,
        ProductionRecord.operator_user_id == repair_row.sender_user_id,
        ProductionRecord.record_type == "production",
        ProductionRecord.created_at >= cycle_started_at,
    )
    if next_cycle_started_at is not None:
        production_stmt = production_stmt.where(
            ProductionRecord.created_at < next_cycle_started_at
        )
    production_rows = (
        db.execute(
            production_stmt.order_by(
                ProductionRecord.created_at.desc(),
                ProductionRecord.id.desc(),
            )
        )
        .scalars()
        .all()
    )
    production_record_quantity = sum(
        int(row.production_quantity or 0) for row in production_rows
    )
    production_record_ended_at = (
        production_rows[0].created_at if production_rows else None
    )
    return RepairCycleContext(
        cycle_started_at=cycle_started_at,
        next_cycle_started_at=next_cycle_started_at,
        production_record_quantity=production_record_quantity,
        production_record_ended_at=production_record_ended_at,
    )


def _resolve_cycle_end_at(
    db: Session,
    *,
    order_process_id: int,
    operator_user_id: int,
    cycle_started_at: datetime,
) -> datetime | None:
    rows = (
        db.execute(
            select(ProductionRecord)
            .where(
                ProductionRecord.order_process_id == order_process_id,
                ProductionRecord.operator_user_id == operator_user_id,
                ProductionRecord.record_type == "production",
                ProductionRecord.created_at >= cycle_started_at,
            )
            .order_by(ProductionRecord.created_at.desc(), ProductionRecord.id.desc())
        )
        .scalars()
        .all()
    )
    if not rows:
        return None
    return rows[0].created_at


def _group_repair_cause_summary(rows: list[RepairCause]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str, bool], int] = {}
    for row in rows:
        key = (
            _normalize_text(row.phenomenon),
            _normalize_text(row.reason),
            bool(row.is_scrap),
        )
        if not key[0] or not key[1]:
            continue
        grouped[key] = int(grouped.get(key, 0)) + int(row.quantity or 0)
    items = [
        {
            "phenomenon": phenomenon,
            "reason": reason,
            "quantity": quantity,
            "is_scrap": is_scrap,
        }
        for (phenomenon, reason, is_scrap), quantity in grouped.items()
    ]
    items.sort(
        key=lambda item: (
            item["phenomenon"],
            item["reason"],
            1 if item["is_scrap"] else 0,
        )
    )
    return items


def _group_repair_phenomena_summary(
    rows: list[RepairDefectPhenomenon],
) -> list[dict[str, Any]]:
    grouped: dict[str, int] = {}
    for row in rows:
        phenomenon = _normalize_text(row.phenomenon)
        if not phenomenon:
            continue
        grouped[phenomenon] = int(grouped.get(phenomenon, 0)) + int(row.quantity or 0)
    items = [
        {"phenomenon": phenomenon, "quantity": quantity}
        for phenomenon, quantity in grouped.items()
    ]
    items.sort(key=lambda item: (-int(item["quantity"]), str(item["phenomenon"])))
    return items


def _snapshot_repair_child(row: RepairOrder) -> RepairAggregateChildSnapshot:
    return RepairAggregateChildSnapshot(
        id=int(row.id),
        repair_order_code=str(row.repair_order_code),
        source_order_id=row.source_order_id,
        source_order_code=row.source_order_code,
        product_id=row.product_id,
        product_name=row.product_name,
        source_order_process_id=row.source_order_process_id,
        source_process_code=row.source_process_code,
        source_process_name=row.source_process_name,
        sender_user_id=row.sender_user_id,
        sender_username=row.sender_username,
        production_quantity=int(row.production_quantity or 0),
        repair_quantity=int(row.repair_quantity or 0),
        repaired_quantity=int(row.repaired_quantity or 0),
        scrap_quantity=int(row.scrap_quantity or 0),
        scrap_replenished=bool(row.scrap_replenished),
        repair_time=row.repair_time,
        status=row.status,
        completed_at=row.completed_at,
        repair_operator_user_id=row.repair_operator_user_id,
        repair_operator_username=row.repair_operator_username,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _build_single_repair_snapshot(row: RepairOrder) -> RepairAggregateSnapshot:
    child = _snapshot_repair_child(row)
    return RepairAggregateSnapshot(
        id=child.id,
        repair_order_code=child.repair_order_code,
        source_order_id=child.source_order_id,
        source_order_code=child.source_order_code,
        product_id=child.product_id,
        product_name=child.product_name,
        source_order_process_id=child.source_order_process_id,
        source_process_code=child.source_process_code,
        source_process_name=child.source_process_name,
        sender_user_id=child.sender_user_id,
        sender_username=child.sender_username,
        production_quantity=child.production_quantity,
        repair_quantity=child.repair_quantity,
        repaired_quantity=child.repaired_quantity,
        scrap_quantity=child.scrap_quantity,
        scrap_replenished=child.scrap_replenished,
        repair_time=child.repair_time,
        status=child.status,
        completed_at=child.completed_at,
        repair_operator_user_id=child.repair_operator_user_id,
        repair_operator_username=child.repair_operator_username,
        created_at=child.created_at,
        updated_at=child.updated_at,
        is_aggregated=False,
        aggregate_status=None,
        aggregate_anchor_repair_order_id=None,
        child_repair_order_count=0,
        child_repair_order_ids=[],
        child_repair_order_codes=[],
        child_rows=[],
        phenomenon_summary=_group_repair_phenomena_summary(row.defect_rows or []),
        cause_summary=_group_repair_cause_summary(row.cause_rows or []),
    )


def _aggregate_status_from_children(children: list[RepairOrder]) -> str:
    if any(child.status == REPAIR_STATUS_IN_REPAIR for child in children):
        return REPAIR_STATUS_IN_REPAIR
    if any(child.status == REPAIR_STATUS_COMPLETED for child in children):
        return REPAIR_STATUS_COMPLETED
    return REPAIR_STATUS_RETURNED_TO_PRODUCTION


def _format_repair_production_quantity_display(item: RepairAggregateSnapshot) -> str:
    if item.production_quantity <= 0:
        return "未报工"
    return str(int(item.production_quantity))


def _build_aggregated_repair_snapshot(
    *,
    children: list[RepairOrder],
    production_record_quantity: int,
) -> RepairAggregateSnapshot:
    anchor = min(children, key=lambda row: (row.created_at, row.id))
    child_snapshots = [_snapshot_repair_child(row) for row in children]
    repair_time = min(row.repair_time for row in children)
    completed_times = [row.completed_at for row in children if row.completed_at is not None]
    updated_times = [row.updated_at for row in children]
    repair_quantity = sum(int(row.repair_quantity or 0) for row in children)
    production_quantity = int(production_record_quantity or 0)
    repaired_quantity = sum(int(row.repaired_quantity or 0) for row in children)
    scrap_quantity = sum(int(row.scrap_quantity or 0) for row in children)
    phenomenon_rows = [defect for row in children for defect in (row.defect_rows or [])]
    cause_rows = [cause for row in children for cause in (row.cause_rows or [])]
    child_ids = [int(row.id) for row in children]
    child_codes = [str(row.repair_order_code) for row in children]
    aggregate_status = _aggregate_status_from_children(children)
    return RepairAggregateSnapshot(
        id=int(anchor.id),
        repair_order_code=f"{anchor.repair_order_code}-AGG",
        source_order_id=anchor.source_order_id,
        source_order_code=anchor.source_order_code,
        product_id=anchor.product_id,
        product_name=anchor.product_name,
        source_order_process_id=anchor.source_order_process_id,
        source_process_code=anchor.source_process_code,
        source_process_name=anchor.source_process_name,
        sender_user_id=anchor.sender_user_id,
        sender_username=anchor.sender_username,
        production_quantity=production_quantity,
        repair_quantity=repair_quantity,
        repaired_quantity=repaired_quantity,
        scrap_quantity=scrap_quantity,
        scrap_replenished=all(bool(row.scrap_replenished) for row in children),
        repair_time=repair_time,
        status=aggregate_status,
        completed_at=max(completed_times) if completed_times else None,
        repair_operator_user_id=anchor.repair_operator_user_id,
        repair_operator_username=anchor.repair_operator_username,
        created_at=min(row.created_at for row in children),
        updated_at=max(updated_times) if updated_times else anchor.updated_at,
        is_aggregated=True,
        aggregate_status=aggregate_status,
        aggregate_anchor_repair_order_id=int(anchor.id),
        child_repair_order_count=len(children),
        child_repair_order_ids=child_ids,
        child_repair_order_codes=child_codes,
        child_rows=child_snapshots,
        phenomenon_summary=_group_repair_phenomena_summary(phenomenon_rows),
        cause_summary=_group_repair_cause_summary(cause_rows),
    )


def _build_repair_aggregate_rows(
    db: Session,
    *,
    rows: list[RepairOrder],
) -> list[RepairAggregateSnapshot]:
    if not rows:
        return []

    grouped: dict[
        tuple[int | None, int | None, int | None, datetime | None, datetime | None],
        list[RepairOrder],
    ] = {}
    group_contexts: dict[
        tuple[int | None, int | None, int | None, datetime | None, datetime | None],
        RepairCycleContext,
    ] = {}
    passthrough: list[RepairAggregateSnapshot] = []

    for row in rows:
        cycle_context = _resolve_repair_cycle_context(db, repair_row=row)
        if (
            cycle_context is None
            or cycle_context.production_record_ended_at is None
            or row.sender_user_id is None
            or row.source_order_process_id is None
        ):
            passthrough.append(_build_single_repair_snapshot(row))
            continue
        key = (
            row.source_order_id,
            row.source_order_process_id,
            row.sender_user_id,
            cycle_context.cycle_started_at,
            cycle_context.next_cycle_started_at,
        )
        grouped.setdefault(key, []).append(row)
        group_contexts[key] = cycle_context

    aggregated: list[RepairAggregateSnapshot] = []
    for key, matched_rows in grouped.items():
        cycle_context = group_contexts[key]
        child_rows = _load_cycle_repair_orders(
            db,
            source_order_id=key[0],
            source_order_process_id=key[1],
            sender_user_id=key[2],
            cycle_started_at=cycle_context.cycle_started_at,
            next_cycle_started_at=cycle_context.next_cycle_started_at,
        )
        if any(child.status == REPAIR_STATUS_IN_REPAIR for child in child_rows):
            aggregated.extend(_build_single_repair_snapshot(child) for child in matched_rows)
            continue
        aggregated.append(
            _build_aggregated_repair_snapshot(
                children=child_rows,
                production_record_quantity=cycle_context.production_record_quantity,
            )
        )

    all_rows = [*aggregated, *passthrough]
    all_rows.sort(key=lambda item: (item.repair_time, item.id), reverse=True)
    return all_rows


def get_repair_order_aggregate_by_anchor_id(
    db: Session,
    *,
    repair_order_id: int,
) -> RepairAggregateSnapshot | None:
    anchor = get_repair_order_by_id(db, repair_order_id=repair_order_id)
    if anchor is None:
        return None
    if (
        anchor.source_order_id is None
        or anchor.source_order_process_id is None
        or anchor.sender_user_id is None
    ):
        return _build_single_repair_snapshot(anchor)

    cycle_context = _resolve_repair_cycle_context(db, repair_row=anchor)
    if cycle_context is None or cycle_context.production_record_ended_at is None:
        return _build_single_repair_snapshot(anchor)
    rows = _load_cycle_repair_orders(
        db,
        source_order_id=anchor.source_order_id,
        source_order_process_id=anchor.source_order_process_id,
        sender_user_id=anchor.sender_user_id,
        cycle_started_at=cycle_context.cycle_started_at,
        next_cycle_started_at=cycle_context.next_cycle_started_at,
    )
    if not rows:
        return _build_single_repair_snapshot(anchor)
    if any(row.id == anchor.id for row in rows) and all(
        row.status != REPAIR_STATUS_IN_REPAIR for row in rows
    ):
        return _build_aggregated_repair_snapshot(
            children=rows,
            production_record_quantity=cycle_context.production_record_quantity,
        )
    return _build_single_repair_snapshot(anchor)


def _load_cycle_repair_orders(
    db: Session,
    *,
    source_order_id: int | None,
    source_order_process_id: int | None,
    sender_user_id: int | None,
    cycle_started_at: datetime,
    next_cycle_started_at: datetime | None,
) -> list[RepairOrder]:
    if (
        source_order_id is None
        or source_order_process_id is None
        or sender_user_id is None
    ):
        return []
    stmt = (
        select(RepairOrder)
        .options(
            selectinload(RepairOrder.defect_rows),
            selectinload(RepairOrder.cause_rows),
            selectinload(RepairOrder.return_routes),
        )
        .where(
            RepairOrder.source_order_id == source_order_id,
            RepairOrder.source_order_process_id == source_order_process_id,
            RepairOrder.sender_user_id == sender_user_id,
            RepairOrder.repair_time >= cycle_started_at,
        )
    )
    if next_cycle_started_at is not None:
        stmt = stmt.where(RepairOrder.repair_time < next_cycle_started_at)
    return (
        db.execute(stmt.order_by(RepairOrder.repair_time.asc(), RepairOrder.id.asc()))
        .scalars()
        .all()
    )


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


def _aggregate_cause_quantities_by_phenomenon(
    cause_items: list[dict[str, Any]],
) -> dict[str, int]:
    result: dict[str, int] = {}
    for item in cause_items:
        phenomenon = _normalize_text(str(item.get("phenomenon") or ""))
        quantity = int(item.get("quantity") or 0)
        if not phenomenon or quantity <= 0:
            continue
        result[phenomenon] = int(result.get(phenomenon, 0)) + quantity
    return result


def _load_repair_defect_targets(
    db: Session,
    *,
    repair_order_id: int,
) -> dict[str, int]:
    rows = db.execute(
        select(
            RepairDefectPhenomenon.phenomenon,
            func.sum(RepairDefectPhenomenon.quantity).label("quantity"),
        )
        .where(RepairDefectPhenomenon.repair_order_id == repair_order_id)
        .group_by(RepairDefectPhenomenon.phenomenon)
    ).all()
    result: dict[str, int] = {}
    for phenomenon, quantity in rows:
        phenomenon_text = _normalize_text(str(phenomenon or ""))
        quantity_value = int(quantity or 0)
        if phenomenon_text and quantity_value > 0:
            result[phenomenon_text] = quantity_value
    return result


def _validate_cause_phenomena_match_repair_defects(
    db: Session,
    *,
    repair_order_id: int,
    cause_items: list[dict[str, Any]],
) -> None:
    expected = _load_repair_defect_targets(db, repair_order_id=repair_order_id)
    if not expected:
        return
    actual = _aggregate_cause_quantities_by_phenomenon(cause_items)
    extra = [name for name in actual if name not in expected]
    if extra:
        raise ValueError(
            "维修原因存在未匹配送修记录的不良现象: " + "、".join(extra)
        )
    mismatch: list[str] = []
    for phenomenon, expected_quantity in expected.items():
        actual_quantity = int(actual.get(phenomenon, 0) or 0)
        if actual_quantity != int(expected_quantity):
            mismatch.append(
                f"{phenomenon} 需 {int(expected_quantity)}，当前 {actual_quantity}"
            )
    if mismatch:
        raise ValueError(
            "维修原因的不良现象数量必须与送修明细一致: " + "；".join(mismatch)
        )


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
    raw_production_quantity = int(production_quantity or 0)
    if raw_production_quantity < 0:
        raise ValueError("production_quantity cannot be negative")
    if auto_created:
        normalized_production_quantity = _normalize_quantity(
            production_quantity,
            field_name="production_quantity",
        )
        if normalized_production_quantity < repair_quantity:
            raise ValueError(
                "production_quantity must be greater than or equal to total defect quantity"
            )
    else:
        normalized_production_quantity = raw_production_quantity

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
        event_type="defect_repair_order_created"
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


def _recompute_order_status_by_quantities(
    db: Session, *, order: ProductionOrder
) -> None:
    from app.services.production_execution_service import _refresh_order_status

    _refresh_order_status(db, order=order)


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
    _validate_cause_phenomena_match_repair_defects(
        db,
        repair_order_id=repair_row.id,
        cause_items=normalized_causes,
    )

    scrap_quantity = int(
        sum(
            int(item["quantity"])
            for item in normalized_causes
            if bool(item["is_scrap"])
        )
    )
    if scrap_replenished and scrap_quantity <= 0:
        raise ValueError("报废已补充只能在存在报废原因时勾选")
    unreplenished_scrap_quantity = scrap_quantity if not scrap_replenished else 0
    repaired_quantity = int(repair_row.repair_quantity) - unreplenished_scrap_quantity

    normalized_returns = _sanitize_return_allocations(return_allocations)
    return_quantity_total = int(
        sum(int(item["quantity"]) for item in normalized_returns)
    )
    if repaired_quantity > 0 and return_quantity_total != repaired_quantity:
        raise ValueError(
            "回流数量合计必须等于送修数量 "
            f"{int(repair_row.repair_quantity)} - 未补充报废数量 "
            f"{unreplenished_scrap_quantity} = {repaired_quantity}"
        )
    if repaired_quantity <= 0 and return_quantity_total > 0:
        raise ValueError("有效回流数量为 0 时，回流分配必须为空")

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
    rerouted_return_quantity = 0
    source_return_quantity = 0
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
        if target_process.id == source_process.id:
            source_return_quantity += qty
            continue
        rerouted_return_quantity += qty
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

    source_visible_decrement = (
        unreplenished_scrap_quantity + rerouted_return_quantity
    )
    if source_visible_decrement > 0 or source_return_quantity > 0:
        source_process.visible_quantity = max(
            int(source_process.completed_quantity),
            int(source_process.visible_quantity) - source_visible_decrement,
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

    if source_order is not None:
        _recompute_order_status_by_quantities(db, order=source_order)

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


def return_repair_order_to_production(
    db: Session,
    *,
    repair_order_id: int,
    operator: User,
) -> RepairOrder:
    repair_row = (
        db.execute(
            select(RepairOrder)
            .where(RepairOrder.id == repair_order_id)
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if repair_row is None:
        raise ValueError("Repair order not found")
    if repair_row.status != REPAIR_STATUS_IN_REPAIR:
        raise RuntimeError("仅维修中的维修单可退回生产")

    source_order = None
    if repair_row.source_order_id:
        source_order = (
            db.execute(
                select(ProductionOrder)
                .where(ProductionOrder.id == repair_row.source_order_id)
                .with_for_update()
            )
            .scalars()
            .first()
        )

    source_process = None
    if repair_row.source_order_process_id:
        source_process = (
            db.execute(
                select(ProductionOrderProcess)
                .where(ProductionOrderProcess.id == repair_row.source_order_process_id)
                .with_for_update()
            )
            .scalars()
            .first()
        )
    if source_process is None:
        raise ValueError("Source process snapshot is missing")

    now = _now_utc()
    returned_quantity = int(repair_row.repair_quantity or 0)
    previous_visible_quantity = int(source_process.visible_quantity or 0)
    target_visible_quantity = previous_visible_quantity + returned_quantity
    source_process.visible_quantity = target_visible_quantity
    if (
        source_process.status == PROCESS_STATUS_COMPLETED
        and target_visible_quantity > int(source_process.completed_quantity or 0)
    ):
        source_process.status = (
            PROCESS_STATUS_PARTIAL
            if int(source_process.completed_quantity or 0) > 0
            else PROCESS_STATUS_PENDING
        )
    ensure_sub_orders_visible_quantity(
        db,
        process_row=source_process,
        target_visible_quantity=target_visible_quantity,
    )

    repair_row.repaired_quantity = 0
    repair_row.scrap_quantity = 0
    repair_row.scrap_replenished = False
    repair_row.completed_at = now
    repair_row.status = REPAIR_STATUS_RETURNED_TO_PRODUCTION
    repair_row.repair_operator_user_id = operator.id
    repair_row.repair_operator_username = operator.username

    # SessionLocal 关闭了 autoflush，先落库再重算订单状态，避免读取到旧工序数量。
    db.flush()

    if source_order is not None:
        _recompute_order_status_by_quantities(db, order=source_order)
        add_order_event_log(
            db,
            order_id=source_order.id,
            event_type="repair_order_returned_to_production",
            event_title="维修单已退回生产",
            event_detail=(
                f"维修单 {repair_row.repair_order_code} 已退回生产，"
                f"送修工序 {repair_row.source_process_name} 恢复 {returned_quantity} 件"
            ),
            operator_user_id=operator.id,
            process_code_snapshot=repair_row.source_process_code,
            payload={
                "repair_order_id": repair_row.id,
                "repair_order_code": repair_row.repair_order_code,
                "returned_quantity": returned_quantity,
                "source_order_process_id": source_process.id,
                "source_process_code": source_process.process_code,
                "previous_visible_quantity": previous_visible_quantity,
                "target_visible_quantity": target_visible_quantity,
            },
        )

    db.commit()
    db.refresh(repair_row)
    return repair_row


def list_repair_orders(
    db: Session,
    *,
    page: int,
    page_size: int,
    filters: RepairListFilters,
) -> tuple[int, list[RepairAggregateSnapshot]]:
    normalized_status = normalize_repair_status(filters.status)
    _, rows = _list_repair_order_rows(
        db,
        page=1,
        page_size=200000,
        filters=RepairListFilters(
            keyword=filters.keyword,
            status="all",
            start_date=filters.start_date,
            end_date=filters.end_date,
        ),
    )
    aggregate_rows = _build_repair_aggregate_rows(db, rows=rows)
    if normalized_status is not None:
        aggregate_rows = [
            row for row in aggregate_rows if str(row.status) == normalized_status
        ]
    total = len(aggregate_rows)
    offset = max(page - 1, 0) * page_size
    paged_rows = aggregate_rows[offset : offset + page_size]
    return total, paged_rows


def _list_repair_order_rows(
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
        selectinload(RepairOrder.defect_rows),
        selectinload(RepairOrder.cause_rows),
        selectinload(RepairOrder.return_routes),
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
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(count_stmt).scalar() or 0
    offset = (page - 1) * page_size
    paged_stmt = (
        stmt.order_by(
            RepairOrder.repair_time.desc(),
            RepairOrder.id.desc(),
        )
        .offset(offset)
        .limit(page_size)
    )
    paged_rows = db.execute(paged_stmt).scalars().all()
    return total, paged_rows


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
    snapshot = get_repair_order_aggregate_by_anchor_id(
        db,
        repair_order_id=repair_order_id,
    )
    if snapshot is None:
        return []
    return list(snapshot.phenomenon_summary)


def create_manual_repair_order(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    effective_operator_user_id: int | None = None,
    assist_authorization_id: int | None = None,
    defect_items: list[dict[str, Any]] | None,
    sender: User,
) -> RepairOrder:
    order, process_row = _load_order_with_process(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    if assist_authorization_id is not None:
        get_usable_assist_authorization_for_operation(
            db,
            authorization_id=assist_authorization_id,
            order_id=order_id,
            order_process_id=order_process_id,
            helper_user_id=sender.id,
            operation=ASSIST_OP_MANUAL_REPAIR,
        )
    elif (
        effective_operator_user_id is not None
        and int(effective_operator_user_id) != int(sender.id)
    ):
        raise PermissionError("手工送修只能由当前操作者本人执行")
    sender_sub_order = (
        db.execute(
            select(ProductionSubOrder)
            .where(
                ProductionSubOrder.order_process_id == process_row.id,
                ProductionSubOrder.operator_user_id == sender.id,
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if process_row.status not in {PROCESS_STATUS_IN_PROGRESS, PROCESS_STATUS_PARTIAL}:
        raise ValueError("Current process does not allow manual repair order creation")
    if sender_sub_order is None or sender_sub_order.status != SUB_ORDER_STATUS_IN_PROGRESS:
        raise ValueError("Manual repair order can only be created while current sub-order is in progress")

    process_remaining = get_process_remaining_quantity(
        db,
        process_row=process_row,
    )
    in_progress_count = get_in_progress_sub_order_count(
        db,
        order_process_id=process_row.id,
    )
    max_producible = get_runtime_max_producible_quantity(
        process_remaining_quantity=process_remaining,
        in_progress_count=in_progress_count,
        current_sub_order_status=sender_sub_order.status,
    )
    repair_quantity = int(
        sum(
            int(item.get("quantity") or 0)
            for item in (defect_items or [])
            if isinstance(item, dict)
        )
    )
    if repair_quantity >= max_producible:
        raise ValueError("Manual repair quantity must leave at least 1 producible unit")

    return create_repair_order(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        sender=sender,
        production_quantity=0,
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
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(count_stmt).scalar() or 0
    offset = (page - 1) * page_size
    paged_stmt = (
        stmt.order_by(
            ProductionScrapStatistics.last_scrap_time.desc(),
            ProductionScrapStatistics.id.desc(),
        )
        .offset(offset)
        .limit(page_size)
    )
    paged_rows = db.execute(paged_stmt).scalars().all()
    return total, paged_rows


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
    _, rows = list_repair_orders(db, page=1, page_size=200000, filters=filters)
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
                _format_repair_production_quantity_display(row),
                int(row.repair_quantity),
                int(row.repaired_quantity),
                int(row.scrap_quantity),
                "是" if row.scrap_replenished else "否",
                _repair_status_label(row.status),
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
