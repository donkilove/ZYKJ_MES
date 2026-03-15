from __future__ import annotations

import base64
import csv
import io
import json
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    RECORD_TYPE_PRODUCTION,
)
from app.models.order_event_log import OrderEventLog
from app.models.process_stage import ProcessStage
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.user import User
from app.services.production_event_log_service import add_order_event_log


STAT_MODE_MAIN_ORDER = "main_order"
STAT_MODE_SUB_ORDER = "sub_order"
STAT_MODE_OPTIONS = {STAT_MODE_MAIN_ORDER, STAT_MODE_SUB_ORDER}

ORDER_STATUS_FILTER_ALL = "all"
ORDER_STATUS_FILTER_OPTIONS = {
    ORDER_STATUS_FILTER_ALL,
    ORDER_STATUS_PENDING,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_COMPLETED,
}


@dataclass(slots=True)
class ProductionDataFilters:
    stat_mode: str
    start_date: date
    end_date: date
    product_ids: set[int]
    stage_ids: set[int]
    process_ids: set[int]
    operator_user_ids: set[int]
    order_status: str | None

    def to_signature(self, *, view: str) -> str:
        payload = {
            "view": view,
            "stat_mode": self.stat_mode,
            "start_date": self.start_date.isoformat(),
            "end_date": self.end_date.isoformat(),
            "product_ids": sorted(self.product_ids),
            "stage_ids": sorted(self.stage_ids),
            "process_ids": sorted(self.process_ids),
            "operator_user_ids": sorted(self.operator_user_ids),
            "order_status": self.order_status or ORDER_STATUS_FILTER_ALL,
        }
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def _normalize_id_set(values: list[int] | None) -> set[int]:
    if not values:
        return set()
    return {int(item) for item in values if int(item) > 0}


def normalize_stat_mode(value: str | None) -> str:
    normalized = (value or STAT_MODE_MAIN_ORDER).strip().lower()
    if normalized not in STAT_MODE_OPTIONS:
        raise ValueError(f"Invalid stat_mode: {value}")
    return normalized


def normalize_order_status(value: str | None) -> str | None:
    normalized = (value or ORDER_STATUS_FILTER_ALL).strip().lower()
    if normalized not in ORDER_STATUS_FILTER_OPTIONS:
        raise ValueError(f"Invalid order_status: {value}")
    if normalized == ORDER_STATUS_FILTER_ALL:
        return None
    return normalized


def parse_id_list_param(raw_value: str | None) -> list[int]:
    if raw_value is None:
        return []
    normalized = raw_value.strip()
    if not normalized:
        return []
    result: list[int] = []
    for part in normalized.split(","):
        token = part.strip()
        if not token:
            continue
        try:
            number = int(token)
        except ValueError as error:
            raise ValueError(f"Invalid integer list item: {token}") from error
        if number <= 0:
            raise ValueError(f"Invalid integer list item: {token}")
        result.append(number)
    return result


def build_today_filters(
    *,
    stat_mode: str | None,
    product_ids: list[int] | None,
    stage_ids: list[int] | None,
    process_ids: list[int] | None,
    operator_user_ids: list[int] | None,
    order_status: str | None,
) -> ProductionDataFilters:
    today = datetime.now().date()
    return ProductionDataFilters(
        stat_mode=normalize_stat_mode(stat_mode),
        start_date=today,
        end_date=today,
        product_ids=_normalize_id_set(product_ids),
        stage_ids=_normalize_id_set(stage_ids),
        process_ids=_normalize_id_set(process_ids),
        operator_user_ids=_normalize_id_set(operator_user_ids),
        order_status=normalize_order_status(order_status),
    )


def build_manual_filters(
    *,
    stat_mode: str | None,
    start_date: date | None,
    end_date: date | None,
    product_ids: list[int] | None,
    stage_ids: list[int] | None,
    process_ids: list[int] | None,
    operator_user_ids: list[int] | None,
    order_status: str | None,
) -> ProductionDataFilters:
    today = datetime.now().date()
    resolved_start = start_date or (today - timedelta(days=6))
    resolved_end = end_date or today
    if resolved_start > resolved_end:
        raise ValueError("start_date cannot be later than end_date")
    return ProductionDataFilters(
        stat_mode=normalize_stat_mode(stat_mode),
        start_date=resolved_start,
        end_date=resolved_end,
        product_ids=_normalize_id_set(product_ids),
        stage_ids=_normalize_id_set(stage_ids),
        process_ids=_normalize_id_set(process_ids),
        operator_user_ids=_normalize_id_set(operator_user_ids),
        order_status=normalize_order_status(order_status),
    )


def _date_range_to_datetime(
    start_date: date,
    end_date: date,
) -> tuple[datetime, datetime]:
    return (
        datetime.combine(start_date, time.min),
        datetime.combine(end_date, time.max),
    )


def _load_relevant_records(
    db: Session,
    *,
    start_date: date,
    end_date: date,
) -> list[ProductionRecord]:
    start_at, end_at = _date_range_to_datetime(start_date, end_date)
    stmt = (
        select(ProductionRecord)
        .where(
            ProductionRecord.record_type == RECORD_TYPE_PRODUCTION,
            ProductionRecord.created_at >= start_at,
            ProductionRecord.created_at <= end_at,
        )
        .options(
            selectinload(ProductionRecord.order).selectinload(ProductionOrder.product),
            selectinload(ProductionRecord.order_process),
            selectinload(ProductionRecord.operator),
        )
        .order_by(ProductionRecord.created_at.asc(), ProductionRecord.id.asc())
    )
    return db.execute(stmt).scalars().all()


def _build_last_process_order_map(
    db: Session,
    *,
    order_ids: set[int],
) -> dict[int, int]:
    if not order_ids:
        return {}
    rows = (
        db.execute(
            select(ProductionOrderProcess.order_id, ProductionOrderProcess.process_order).where(
                ProductionOrderProcess.order_id.in_(order_ids)
            )
        )
        .all()
    )
    result: dict[int, int] = {}
    for order_id, process_order in rows:
        current = result.get(int(order_id))
        if current is None or int(process_order) > current:
            result[int(order_id)] = int(process_order)
    return result


def _record_matches_common_filters(
    record: ProductionRecord,
    *,
    filters: ProductionDataFilters,
    last_process_order_map: dict[int, int],
) -> bool:
    order = record.order
    process = record.order_process
    if order is None or process is None:
        return False
    if filters.order_status and order.status != filters.order_status:
        return False
    if filters.product_ids and order.product_id not in filters.product_ids:
        return False
    if filters.stage_ids and (process.stage_id or 0) not in filters.stage_ids:
        return False
    if filters.process_ids and process.process_id not in filters.process_ids:
        return False
    if filters.operator_user_ids and record.operator_user_id not in filters.operator_user_ids:
        return False
    if filters.stat_mode == STAT_MODE_MAIN_ORDER:
        max_order = last_process_order_map.get(order.id)
        if max_order is None:
            return False
        return process.process_order == max_order
    return True


def _format_datetime_text(value: datetime | None) -> str:
    if value is None:
        return ""
    local = value.astimezone() if value.tzinfo is not None else value
    return local.strftime("%Y-%m-%d %H:%M:%S")


def get_today_realtime_data(
    db: Session,
    *,
    filters: ProductionDataFilters,
) -> dict[str, Any]:
    rows = _load_relevant_records(
        db,
        start_date=filters.start_date,
        end_date=filters.end_date,
    )
    order_ids = {row.order_id for row in rows}
    last_process_order_map = _build_last_process_order_map(db, order_ids=order_ids)

    product_bucket: dict[int, dict[str, Any]] = {}
    for row in rows:
        if not _record_matches_common_filters(
            row,
            filters=filters,
            last_process_order_map=last_process_order_map,
        ):
            continue
        order = row.order
        if order is None:
            continue
        product = order.product
        product_name = product.name if product else ""
        bucket = product_bucket.get(order.product_id)
        if bucket is None:
            bucket = {
                "product_id": order.product_id,
                "product_name": product_name,
                "quantity": 0,
                "latest_time": None,
            }
            product_bucket[order.product_id] = bucket
        bucket["quantity"] = int(bucket["quantity"]) + int(row.production_quantity or 0)
        previous_latest = bucket.get("latest_time")
        if previous_latest is None or (row.created_at and row.created_at > previous_latest):
            bucket["latest_time"] = row.created_at

    table_rows = sorted(
        product_bucket.values(),
        key=lambda item: (-int(item["quantity"]), str(item["product_name"]), int(item["product_id"])),
    )
    chart_data = [
        {
            "label": str(item["product_name"]),
            "value": int(item["quantity"]),
        }
        for item in table_rows
    ]
    total_quantity = int(sum(int(item["quantity"]) for item in table_rows))
    for item in table_rows:
        item["latest_time_text"] = _format_datetime_text(item.get("latest_time"))

    return {
        "stat_mode": filters.stat_mode,
        "summary": {
            "total_products": len(table_rows),
            "total_quantity": total_quantity,
        },
        "table_rows": table_rows,
        "chart_data": chart_data,
        "query_signature": filters.to_signature(view="today_realtime"),
    }


def get_unfinished_progress_data(
    db: Session,
    *,
    product_ids: list[int] | None,
    stage_ids: list[int] | None,
    process_ids: list[int] | None,
    operator_user_ids: list[int] | None,
    order_status: str | None,
) -> dict[str, Any]:
    normalized_product_ids = _normalize_id_set(product_ids)
    normalized_stage_ids = _normalize_id_set(stage_ids)
    normalized_process_ids = _normalize_id_set(process_ids)
    normalized_operator_ids = _normalize_id_set(operator_user_ids)
    normalized_order_status = normalize_order_status(order_status)

    stmt = (
        select(ProductionOrder)
        .where(ProductionOrder.status != ORDER_STATUS_COMPLETED)
        .options(
            selectinload(ProductionOrder.product),
            selectinload(ProductionOrder.processes),
            selectinload(ProductionOrder.production_records),
        )
        .order_by(ProductionOrder.updated_at.desc(), ProductionOrder.id.desc())
    )
    if normalized_product_ids:
        stmt = stmt.where(ProductionOrder.product_id.in_(normalized_product_ids))
    if normalized_order_status:
        if normalized_order_status == ORDER_STATUS_COMPLETED:
            return {
                "summary": {"total_orders": 0, "avg_progress_percent": 0.0},
                "table_rows": [],
                "query_signature": json.dumps(
                    {
                        "view": "unfinished_progress",
                        "product_ids": sorted(normalized_product_ids),
                        "stage_ids": sorted(normalized_stage_ids),
                        "process_ids": sorted(normalized_process_ids),
                        "operator_user_ids": sorted(normalized_operator_ids),
                        "order_status": normalized_order_status,
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
            }
        stmt = stmt.where(ProductionOrder.status == normalized_order_status)

    orders = db.execute(stmt).scalars().all()
    table_rows: list[dict[str, Any]] = []
    for order in orders:
        process_rows = sorted(
            list(order.processes or []),
            key=lambda row: (row.process_order, row.id),
        )
        if not process_rows:
            continue
        if normalized_stage_ids and not any((row.stage_id or 0) in normalized_stage_ids for row in process_rows):
            continue
        if normalized_process_ids and not any(row.process_id in normalized_process_ids for row in process_rows):
            continue

        record_rows = [
            row
            for row in (order.production_records or [])
            if row.record_type == RECORD_TYPE_PRODUCTION
        ]
        if normalized_operator_ids and not any(row.operator_user_id in normalized_operator_ids for row in record_rows):
            continue

        current_process = next(
            (row for row in process_rows if row.status != PROCESS_STATUS_COMPLETED),
            None,
        )
        if current_process is None:
            current_process = process_rows[-1]

        current_process_name = str(current_process.process_name or "")
        produced_total = int(current_process.completed_quantity or 0)
        process_count = len(process_rows)
        target_total = int(max(order.quantity, 0))
        remaining_quantity = max(target_total - produced_total, 0)
        progress_percent = round((produced_total / target_total * 100.0), 2) if target_total > 0 else 0.0
        progress_percent = max(0.0, min(progress_percent, 100.0))

        table_rows.append(
            {
                "order_id": order.id,
                "order_code": order.order_code,
                "product_id": order.product_id,
                "product_name": order.product.name if order.product else "",
                "order_status": order.status,
                "current_process_name": current_process_name,
                "remaining_quantity": remaining_quantity,
                "process_count": process_count,
                "produced_total": produced_total,
                "target_total": target_total,
                "progress_percent": progress_percent,
            }
        )

    table_rows.sort(
        key=lambda item: (
            float(item["progress_percent"]),
            str(item["order_code"]),
            int(item["order_id"]),
        )
    )
    avg_progress = round(
        sum(float(item["progress_percent"]) for item in table_rows) / len(table_rows),
        2,
    ) if table_rows else 0.0
    query_signature = json.dumps(
        {
            "view": "unfinished_progress",
            "product_ids": sorted(normalized_product_ids),
            "stage_ids": sorted(normalized_stage_ids),
            "process_ids": sorted(normalized_process_ids),
            "operator_user_ids": sorted(normalized_operator_ids),
            "order_status": normalized_order_status or ORDER_STATUS_FILTER_ALL,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
    return {
        "summary": {
            "total_orders": len(table_rows),
            "avg_progress_percent": avg_progress,
        },
        "table_rows": table_rows,
        "query_signature": query_signature,
    }


def _build_manual_rows(
    rows: list[ProductionRecord],
    *,
    filters: ProductionDataFilters,
    last_process_order_map: dict[int, int],
) -> list[dict[str, Any]]:
    if filters.stat_mode == STAT_MODE_MAIN_ORDER:
        grouped: dict[int, dict[str, Any]] = {}
        for row in rows:
            if not _record_matches_common_filters(
                row,
                filters=filters,
                last_process_order_map=last_process_order_map,
            ):
                continue
            order = row.order
            process = row.order_process
            if order is None or process is None:
                continue

            bucket = grouped.get(order.id)
            if bucket is None:
                bucket = {
                    "order_id": order.id,
                    "order_code": order.order_code,
                    "product_id": order.product_id,
                    "product_name": order.product.name if order.product else "",
                    "stage_id": process.stage_id,
                    "stage_code": process.stage_code,
                    "stage_name": process.stage_name,
                    "process_id": process.process_id,
                    "process_code": process.process_code,
                    "process_name": process.process_name,
                    "operator_user_id": None,
                    "operator_username": "",
                    "quantity": 0,
                    "production_time": None,
                    "order_status": order.status,
                }
                grouped[order.id] = bucket
            bucket["quantity"] = int(bucket["quantity"]) + int(row.production_quantity or 0)
            previous_time = bucket.get("production_time")
            if previous_time is None or (row.created_at and row.created_at > previous_time):
                bucket["production_time"] = row.created_at
        return list(grouped.values())

    grouped_sub: dict[tuple[int, int, int], dict[str, Any]] = {}
    for row in rows:
        if not _record_matches_common_filters(
            row,
            filters=filters,
            last_process_order_map=last_process_order_map,
        ):
            continue
        order = row.order
        process = row.order_process
        if order is None or process is None:
            continue
        key = (order.id, process.id, row.operator_user_id)
        bucket = grouped_sub.get(key)
        if bucket is None:
            bucket = {
                "order_id": order.id,
                "order_code": order.order_code,
                "product_id": order.product_id,
                "product_name": order.product.name if order.product else "",
                "stage_id": process.stage_id,
                "stage_code": process.stage_code,
                "stage_name": process.stage_name,
                "process_id": process.process_id,
                "process_code": process.process_code,
                "process_name": process.process_name,
                "operator_user_id": row.operator_user_id,
                "operator_username": row.operator.username if row.operator else "",
                "quantity": 0,
                "production_time": None,
                "order_status": order.status,
            }
            grouped_sub[key] = bucket
        bucket["quantity"] = int(bucket["quantity"]) + int(row.production_quantity or 0)
        previous_time = bucket.get("production_time")
        if previous_time is None or (row.created_at and row.created_at > previous_time):
            bucket["production_time"] = row.created_at
    return list(grouped_sub.values())


def _build_manual_chart_data(
    table_rows: list[dict[str, Any]],
    *,
    filtered_records: list[ProductionRecord],
    start_date: date,
    end_date: date,
) -> dict[str, Any]:
    model_output_map: dict[str, int] = {}
    for row in table_rows:
        model_name = str(row.get("product_name") or "")
        model_output_map[model_name] = int(model_output_map.get(model_name, 0)) + int(row.get("quantity", 0) or 0)
    model_output = [
        {"product_name": key, "quantity": value}
        for key, value in sorted(model_output_map.items(), key=lambda item: (-int(item[1]), str(item[0])))
    ]

    single_day = start_date == end_date
    if single_day:
        hour_counter = {index: 0 for index in range(24)}
        for record in filtered_records:
            if not isinstance(record.created_at, datetime):
                continue
            local_time = record.created_at.astimezone() if record.created_at.tzinfo is not None else record.created_at
            hour_counter[int(local_time.hour)] = int(hour_counter[int(local_time.hour)]) + int(record.production_quantity or 0)
        trend_output = [
            {"bucket": f"{hour:02d}:00", "quantity": int(hour_counter[hour])}
            for hour in range(24)
        ]
    else:
        day_counter: dict[str, int] = {}
        cursor = start_date
        while cursor <= end_date:
            key = cursor.strftime("%Y-%m-%d")
            day_counter[key] = 0
            cursor += timedelta(days=1)
        for record in filtered_records:
            if not isinstance(record.created_at, datetime):
                continue
            local_time = record.created_at.astimezone() if record.created_at.tzinfo is not None else record.created_at
            key = local_time.strftime("%Y-%m-%d")
            if key in day_counter:
                day_counter[key] = int(day_counter[key]) + int(record.production_quantity or 0)
        trend_output = [
            {"bucket": key, "quantity": int(value)}
            for key, value in sorted(day_counter.items(), key=lambda item: item[0])
        ]

    filtered_total = int(sum(int(row.get("quantity", 0) or 0) for row in table_rows))
    pie_output = [
        {"name": "筛选结果", "quantity": filtered_total},
        {"name": "其余产量", "quantity": 0},
    ]
    return {
        "single_day": single_day,
        "model_output": model_output,
        "trend_output": trend_output,
        "pie_output": pie_output,
    }


def get_manual_production_data(
    db: Session,
    *,
    filters: ProductionDataFilters,
) -> dict[str, Any]:
    rows = _load_relevant_records(
        db,
        start_date=filters.start_date,
        end_date=filters.end_date,
    )
    order_ids = {row.order_id for row in rows}
    last_process_order_map = _build_last_process_order_map(db, order_ids=order_ids)
    filtered_records = [
        row
        for row in rows
        if _record_matches_common_filters(
            row,
            filters=filters,
            last_process_order_map=last_process_order_map,
        )
    ]
    table_rows = _build_manual_rows(
        rows,
        filters=filters,
        last_process_order_map=last_process_order_map,
    )
    table_rows.sort(
        key=lambda row: (
            row["production_time"] or datetime.min,
            str(row["order_code"]),
            str(row["process_code"]),
            int(row["order_id"]),
        ),
        reverse=True,
    )

    chart_data = _build_manual_chart_data(
        table_rows,
        filtered_records=filtered_records,
        start_date=filters.start_date,
        end_date=filters.end_date,
    )
    filtered_total = int(sum(int(item.get("quantity", 0) or 0) for item in table_rows))

    broad_filters = ProductionDataFilters(
        stat_mode=filters.stat_mode,
        start_date=filters.start_date,
        end_date=filters.end_date,
        product_ids=set(),
        stage_ids=set(),
        process_ids=set(),
        operator_user_ids=set(),
        order_status=filters.order_status,
    )
    broad_rows = _build_manual_rows(
        rows,
        filters=broad_filters,
        last_process_order_map=last_process_order_map,
    )
    time_range_total = int(sum(int(item.get("quantity", 0) or 0) for item in broad_rows))
    remaining_total = max(time_range_total - filtered_total, 0)
    chart_data["pie_output"] = [
        {"name": "筛选结果", "quantity": filtered_total},
        {"name": "其余产量", "quantity": remaining_total},
    ]

    ratio_percent = round((filtered_total / time_range_total * 100.0), 2) if time_range_total > 0 else 0.0

    for row in table_rows:
        row["production_time_text"] = _format_datetime_text(row.get("production_time"))

    return {
        "stat_mode": filters.stat_mode,
        "summary": {
            "rows": len(table_rows),
            "filtered_total": filtered_total,
            "time_range_total": time_range_total,
            "ratio_percent": ratio_percent,
        },
        "table_rows": table_rows,
        "chart_data": chart_data,
        "query_signature": filters.to_signature(view="manual"),
    }


def export_manual_production_data_csv(
    db: Session,
    *,
    filters: ProductionDataFilters,
    operator: User | None,
) -> dict[str, Any]:
    payload = get_manual_production_data(db, filters=filters)
    rows = payload["table_rows"]

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "订单编号",
            "产品名称",
            "工段编码",
            "工段名称",
            "工序编码",
            "工序名称",
            "操作员",
            "产量",
            "生产时间",
            "订单状态",
            "统计模式",
        ]
    )
    for row in rows:
        writer.writerow(
            [
                str(row.get("order_code") or ""),
                str(row.get("product_name") or ""),
                str(row.get("stage_code") or ""),
                str(row.get("stage_name") or ""),
                str(row.get("process_code") or ""),
                str(row.get("process_name") or ""),
                str(row.get("operator_username") or ""),
                int(row.get("quantity", 0) or 0),
                str(row.get("production_time_text") or ""),
                str(row.get("order_status") or ""),
                "主订单" if filters.stat_mode == STAT_MODE_MAIN_ORDER else "子订单",
            ]
        )
    content_base64 = base64.b64encode(output.getvalue().encode("utf-8-sig")).decode("ascii")
    file_name = f"production_manual_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    mime_type = "text/csv"

    unique_order_ids = {
        int(row.get("order_id"))
        for row in rows
        if row.get("order_id") is not None
    }
    if unique_order_ids:
        for order_id in unique_order_ids:
            add_order_event_log(
                db,
                order_id=order_id,
                event_type="production_data_manual_export",
                event_title="生产数据导出",
                event_detail="导出手动筛选结果",
                operator_user_id=operator.id if operator else None,
                payload={
                    "stat_mode": filters.stat_mode,
                    "start_date": filters.start_date.isoformat(),
                    "end_date": filters.end_date.isoformat(),
                    "product_ids": sorted(filters.product_ids),
                    "stage_ids": sorted(filters.stage_ids),
                    "process_ids": sorted(filters.process_ids),
                    "operator_user_ids": sorted(filters.operator_user_ids),
                    "order_status": filters.order_status or ORDER_STATUS_FILTER_ALL,
                    "rows": len(rows),
                },
            )
        db.commit()
    return {
        "file_name": file_name,
        "mime_type": mime_type,
        "content_base64": content_base64,
    }


def list_stage_options_for_filters(db: Session) -> list[ProcessStage]:
    return (
        db.execute(
            select(ProcessStage)
            .where(ProcessStage.is_enabled.is_(True))
            .order_by(ProcessStage.sort_order.asc(), ProcessStage.id.asc())
        )
        .scalars()
        .all()
    )


def list_manual_export_events(
    db: Session,
    *,
    limit: int = 50,
) -> list[OrderEventLog]:
    stmt = (
        select(OrderEventLog)
        .where(OrderEventLog.event_type == "production_data_manual_export")
        .order_by(OrderEventLog.created_at.desc(), OrderEventLog.id.desc())
        .limit(limit)
    )
    return db.execute(stmt).scalars().all()
