from __future__ import annotations

import base64
import copy
import csv
import io
import threading
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from time import monotonic
from typing import Any
from uuid import uuid4

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.config import (
    production_default_verification_code_is_secure,
    settings,
)
from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_PENDING,
    RECORD_TYPE_FIRST_ARTICLE,
    RECORD_TYPE_PRODUCTION,
    SUB_ORDER_STATUS_IN_PROGRESS,
    SUB_ORDER_STATUS_PENDING,
)
from app.models.daily_verification_code import DailyVerificationCode
from app.models.first_article_disposition import FirstArticleDisposition
from app.models.first_article_disposition_history import FirstArticleDispositionHistory
from app.models.first_article_participant import FirstArticleParticipant
from app.models.first_article_record import FirstArticleRecord
from app.models.first_article_review_session import FirstArticleReviewSession
from app.models.order_sub_order_pipeline_instance import ProcessPipelineInstance
from app.models.production_assist_authorization import ProductionAssistAuthorization
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.production_sub_order import ProductionSubOrder
from app.models.product import Product
from app.models.repair_cause import RepairCause
from app.models.repair_order import RepairOrder
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
from app.models.user import User
from app.services.production_event_log_service import add_order_event_log

_QUALITY_ROWS_LOCAL_CACHE: dict[
    tuple[object, ...], tuple[float, list[dict[str, object]]]
] = {}
_QUALITY_RELATED_TOTALS_LOCAL_CACHE: dict[
    tuple[object, ...], tuple[float, dict[str, Any]]
] = {}
_QUALITY_STATS_CACHE_LOCK = threading.Lock()


@dataclass(slots=True)
class _FirstArticleActionContext:
    record: FirstArticleRecord
    order: ProductionOrder | None
    process_row: ProductionOrderProcess | None
    sub_order: ProductionSubOrder | None
    first_article_production_record: ProductionRecord | None
    review_sessions: list[FirstArticleReviewSession]
    assist_authorization: ProductionAssistAuthorization | None
    pipeline_instances: list[ProcessPipelineInstance]
    has_following_production: bool


def _build_datetime_range_filters(
    column,
    *,
    start_date: date | None,
    end_date: date | None,
) -> list[object]:
    filters: list[object] = []
    if start_date is not None:
        filters.append(column >= datetime.combine(start_date, time.min))
    if end_date is not None:
        filters.append(
            column < datetime.combine(end_date + timedelta(days=1), time.min)
        )
    return filters


def _build_created_at_filters(
    *,
    start_date: date | None,
    end_date: date | None,
) -> list[object]:
    return _build_datetime_range_filters(
        FirstArticleRecord.created_at,
        start_date=start_date,
        end_date=end_date,
    )


def _normalize_stat_date(value: object) -> date | None:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return date.fromisoformat(text[:10])
        except ValueError:
            return None
    return None


def _round_rate(passed: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return round((passed * 100.0) / total, 2)


def _normalize_process_key(value: object) -> str:
    return str(value or "").strip()


def _normalize_operator_key(*, user_id: object, username: object) -> str:
    if user_id is not None:
        return f"id:{_coerce_int(user_id)}"
    text = str(username or "").strip()
    if text:
        return f"name:{text}"
    return ""


def _record_process_name(
    mapping: dict[str, str],
    *,
    process_code: object,
    process_name: object,
) -> None:
    key = _normalize_process_key(process_code)
    if not key:
        return
    if key not in mapping or not mapping[key]:
        mapping[key] = str(process_name or "").strip()


def _record_operator_meta(
    mapping: dict[str, dict[str, object]],
    *,
    user_id: object,
    username: object,
) -> str:
    key = _normalize_operator_key(user_id=user_id, username=username)
    if not key:
        return ""
    current = mapping.get(key)
    normalized_username = str(username or "").strip()
    normalized_user_id = _coerce_int(user_id) if user_id is not None else None
    if current is None:
        mapping[key] = {
            "operator_user_id": normalized_user_id,
            "operator_username": normalized_username,
        }
        return key
    if current.get("operator_user_id") is None and normalized_user_id is not None:
        current["operator_user_id"] = normalized_user_id
    if not current.get("operator_username") and normalized_username:
        current["operator_username"] = normalized_username
    return key


def _coerce_int(value: object, default: int = 0) -> int:
    if value is None:
        return default
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return default
        try:
            return int(text)
        except ValueError:
            return default
    return default


def _quality_stats_cache_ttl_seconds() -> float:
    configured = getattr(settings, "quality_stats_cache_ttl_seconds", 5)
    try:
        ttl = float(configured)
    except (TypeError, ValueError):
        ttl = 5.0
    return max(0.0, ttl)


def _normalize_cache_text(value: str | None) -> str:
    return (value or "").strip().lower()


def _quality_stats_cache_key(
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None,
    process_code: str | None,
    operator_username: str | None,
    result_filter: str | None = None,
) -> tuple[object, ...]:
    return (
        start_date,
        end_date,
        _normalize_cache_text(keyword),
        _normalize_cache_text(product_name),
        _normalize_cache_text(process_code),
        _normalize_cache_text(operator_username),
        _normalize_cache_text(result_filter),
    )


def _invalidate_quality_stats_cache() -> None:
    with _QUALITY_STATS_CACHE_LOCK:
        _QUALITY_ROWS_LOCAL_CACHE.clear()
        _QUALITY_RELATED_TOTALS_LOCAL_CACHE.clear()


def _first_article_record_status(row: FirstArticleRecord) -> str:
    return "cancelled" if bool(row.is_cancelled) else "active"


def _find_linked_first_article_production_record(
    db: Session,
    *,
    record: FirstArticleRecord,
) -> ProductionRecord | None:
    base_stmt = select(ProductionRecord).where(
        ProductionRecord.order_id == record.order_id,
        ProductionRecord.order_process_id == record.order_process_id,
        ProductionRecord.operator_user_id == record.operator_user_id,
        ProductionRecord.record_type == RECORD_TYPE_FIRST_ARTICLE,
        ProductionRecord.production_quantity == 0,
    )
    if record.sub_order_id is not None:
        base_stmt = base_stmt.where(ProductionRecord.sub_order_id == record.sub_order_id)

    timed_stmt = base_stmt
    if record.created_at is not None:
        timed_stmt = timed_stmt.where(ProductionRecord.created_at >= record.created_at)

    row = (
        db.execute(
            timed_stmt.order_by(
                ProductionRecord.created_at.asc(),
                ProductionRecord.id.asc(),
            )
        )
        .scalars()
        .first()
    )
    if row is not None:
        return row
    return (
        db.execute(base_stmt.order_by(ProductionRecord.id.desc()))
        .scalars()
        .first()
    )


def _has_following_production_after_first_article(
    db: Session,
    *,
    record: FirstArticleRecord,
    sub_order_id: int | None,
) -> bool:
    if sub_order_id is None:
        return False
    stmt = select(func.count()).select_from(ProductionRecord).where(
        ProductionRecord.sub_order_id == sub_order_id,
        ProductionRecord.record_type == RECORD_TYPE_PRODUCTION,
    )
    if record.created_at is not None:
        stmt = stmt.where(ProductionRecord.created_at > record.created_at)
    return bool(db.execute(stmt).scalar() or 0)


def _build_first_article_action_context(
    db: Session,
    *,
    record: FirstArticleRecord,
    for_update: bool,
) -> _FirstArticleActionContext:
    first_article_production_record = _find_linked_first_article_production_record(
        db,
        record=record,
    )
    sub_order_id = record.sub_order_id
    if sub_order_id is None and first_article_production_record is not None:
        sub_order_id = first_article_production_record.sub_order_id

    sub_order_stmt = select(ProductionSubOrder).where(ProductionSubOrder.id == sub_order_id)
    if for_update:
        sub_order_stmt = sub_order_stmt.with_for_update()
    sub_order = (
        db.execute(sub_order_stmt).scalars().first() if sub_order_id is not None else None
    )

    review_session_stmt = select(FirstArticleReviewSession).where(
        FirstArticleReviewSession.first_article_record_id == record.id
    )
    if for_update:
        review_session_stmt = review_session_stmt.with_for_update()
    review_sessions = db.execute(review_session_stmt).scalars().all()

    assist_authorization_id = record.assist_authorization_id or next(
        (
            session.assist_authorization_id
            for session in review_sessions
            if session.assist_authorization_id is not None
        ),
        None,
    )
    assist_stmt = select(ProductionAssistAuthorization).where(
        ProductionAssistAuthorization.id == assist_authorization_id
    )
    if for_update:
        assist_stmt = assist_stmt.with_for_update()
    assist_authorization = (
        db.execute(assist_stmt).scalars().first()
        if assist_authorization_id is not None
        else None
    )

    pipeline_stmt = select(ProcessPipelineInstance).where(
        ProcessPipelineInstance.order_process_id == record.order_process_id,
        ProcessPipelineInstance.sub_order_id == sub_order_id,
        ProcessPipelineInstance.is_active.is_(True),
    )
    if for_update:
        pipeline_stmt = pipeline_stmt.with_for_update()
    pipeline_instances = (
        db.execute(pipeline_stmt).scalars().all() if sub_order_id is not None else []
    )

    return _FirstArticleActionContext(
        record=record,
        order=record.order,
        process_row=record.order_process,
        sub_order=sub_order,
        first_article_production_record=first_article_production_record,
        review_sessions=review_sessions,
        assist_authorization=assist_authorization,
        pipeline_instances=pipeline_instances,
        has_following_production=_has_following_production_after_first_article(
            db,
            record=record,
            sub_order_id=sub_order_id,
        ),
    )


def _load_first_article_action_context(
    db: Session,
    *,
    record_id: int,
) -> _FirstArticleActionContext:
    record = (
        db.execute(
            select(FirstArticleRecord)
            .where(FirstArticleRecord.id == record_id)
            .options(
                selectinload(FirstArticleRecord.order).selectinload(
                    ProductionOrder.product
                ),
                selectinload(FirstArticleRecord.order_process),
                selectinload(FirstArticleRecord.operator),
                selectinload(FirstArticleRecord.cancelled_by),
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if record is None:
        raise ValueError("首件记录不存在")
    return _build_first_article_action_context(db, record=record, for_update=True)


def _can_cancel_first_article_context(context: _FirstArticleActionContext) -> bool:
    return (
        context.record.result == "passed"
        and not bool(context.record.is_cancelled)
        and not context.has_following_production
        and context.order is not None
        and context.process_row is not None
        and context.sub_order is not None
        and context.first_article_production_record is not None
    )


def _can_delete_first_article_context(context: _FirstArticleActionContext) -> bool:
    if bool(context.record.is_cancelled):
        return True
    if context.record.result != "passed":
        return True
    if context.has_following_production:
        return False
    return (
        context.order is not None
        and context.process_row is not None
        and context.sub_order is not None
        and context.first_article_production_record is not None
    )


def _refresh_process_and_order_status_after_first_article_revert(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> None:
    in_progress_sub_order_count = int(
        db.execute(
            select(func.count())
            .select_from(ProductionSubOrder)
            .where(
                ProductionSubOrder.order_process_id == process_row.id,
                ProductionSubOrder.status == SUB_ORDER_STATUS_IN_PROGRESS,
            )
        ).scalar()
        or 0
    )
    completed_quantity = int(process_row.completed_quantity or 0)
    visible_quantity = int(process_row.visible_quantity or 0)
    if visible_quantity > 0 and completed_quantity >= visible_quantity:
        process_row.status = PROCESS_STATUS_COMPLETED
    elif in_progress_sub_order_count > 0:
        process_row.status = PROCESS_STATUS_IN_PROGRESS
    elif completed_quantity > 0:
        process_row.status = PROCESS_STATUS_PARTIAL
    else:
        process_row.status = PROCESS_STATUS_PENDING

    process_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == order.id)
            .order_by(
                ProductionOrderProcess.process_order.asc(),
                ProductionOrderProcess.id.asc(),
            )
            .with_for_update()
        )
        .scalars()
        .all()
    )
    first_incomplete = next(
        (
            row
            for row in process_rows
            if int(row.completed_quantity or 0) < int(row.visible_quantity or 0)
        ),
        None,
    )
    if first_incomplete is None and process_rows:
        order.status = ORDER_STATUS_COMPLETED
        order.current_process_code = None
        return

    has_in_progress_process = any(
        row.status == PROCESS_STATUS_IN_PROGRESS for row in process_rows
    )
    order.status = ORDER_STATUS_IN_PROGRESS if has_in_progress_process else ORDER_STATUS_PENDING
    if first_incomplete is not None:
        order.current_process_code = first_incomplete.process_code
    elif process_rows:
        order.current_process_code = process_rows[0].process_code


def _rollback_first_article_execution_state(
    db: Session,
    *,
    context: _FirstArticleActionContext,
) -> None:
    if context.has_following_production:
        raise ValueError("该条首件后已存在真实报工，无法回退首件执行状态")
    if (
        context.order is None
        or context.process_row is None
        or context.sub_order is None
        or context.first_article_production_record is None
    ):
        raise ValueError("该条首件缺少关联执行上下文，无法回退首件执行状态")

    db.delete(context.first_article_production_record)
    context.first_article_production_record = None
    context.sub_order.status = SUB_ORDER_STATUS_PENDING
    for pipeline_instance in context.pipeline_instances:
        pipeline_instance.sub_order_id = None
    if context.assist_authorization is not None:
        context.assist_authorization.first_article_used_at = None
    _refresh_process_and_order_status_after_first_article_revert(
        db,
        order=context.order,
        process_row=context.process_row,
    )


def _row_value(row: object, name: str, default: object = None) -> object:
    if isinstance(row, dict):
        return row.get(name, default)
    return getattr(row, name, default)


def _row_process_code(row: object) -> str:
    code = str(_row_value(row, "process_code", "") or "").strip()
    if code:
        return code
    process_row = _row_value(row, "order_process")
    return str(getattr(process_row, "process_code", "") or "").strip()


def _row_process_name(row: object) -> str:
    process_name = str(_row_value(row, "process_name", "") or "").strip()
    if process_name:
        return process_name
    process_row = _row_value(row, "order_process")
    return str(getattr(process_row, "process_name", "") or "").strip()


def _row_operator_user_id(row: object) -> int | None:
    user_id = _row_value(row, "operator_user_id")
    if user_id is None:
        return None
    normalized = _coerce_int(user_id, 0)
    return normalized if normalized > 0 else None


def _row_operator_username(row: object) -> str:
    username = str(_row_value(row, "operator_username", "") or "").strip()
    if username:
        return username
    operator = _row_value(row, "operator")
    return str(getattr(operator, "username", "") or "").strip()


def _row_result(row: object) -> str:
    return str(_row_value(row, "result", "") or "").strip().lower()


def _row_created_at(row: object) -> datetime | None:
    value = _row_value(row, "created_at")
    return value if isinstance(value, datetime) else None


def _row_order_id(row: object) -> int | None:
    order_id = _row_value(row, "order_id")
    if order_id is None:
        return None
    normalized = _coerce_int(order_id, 0)
    return normalized if normalized > 0 else None


def _row_product_id(row: object) -> int | None:
    product_id = _row_value(row, "product_id")
    if product_id is not None:
        normalized = _coerce_int(product_id, 0)
        return normalized if normalized > 0 else None
    order = _row_value(row, "order")
    if order is None:
        return None
    normalized = _coerce_int(getattr(order, "product_id", None), 0)
    return normalized if normalized > 0 else None


def _row_product_name(row: object) -> str:
    name = str(_row_value(row, "product_name", "") or "").strip()
    if name:
        return name
    order = _row_value(row, "order")
    product = getattr(order, "product", None) if order is not None else None
    return str(getattr(product, "name", "") or "").strip()


def _aggregate_quality_related_totals(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> dict[str, Any]:
    cache_key = _quality_stats_cache_key(
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
    )
    ttl_seconds = _quality_stats_cache_ttl_seconds()
    now = monotonic()
    if ttl_seconds > 0:
        with _QUALITY_STATS_CACHE_LOCK:
            cached = _QUALITY_RELATED_TOTALS_LOCAL_CACHE.get(cache_key)
            if cached is not None and cached[0] > now:
                return copy.deepcopy(cached[1])

    scrap_by_product: dict[int, int] = {}
    scrap_by_process: dict[str, int] = {}
    scrap_by_operator: dict[str, int] = {}
    process_name_by_code: dict[str, str] = {}
    operator_meta_by_key: dict[str, dict[str, object]] = {}
    covered_order_ids: set[int] = set()
    covered_process_keys: set[str] = set()
    covered_operator_keys: set[str] = set()
    scrap_total = 0
    for row in db.execute(
        select(
            ProductionScrapStatistics.order_id,
            ProductionScrapStatistics.product_id,
            ProductionScrapStatistics.process_code,
            ProductionScrapStatistics.process_name,
            ProductionScrapStatistics.operator_user_id,
            ProductionScrapStatistics.operator_username,
            func.sum(ProductionScrapStatistics.scrap_quantity).label("total"),
        )
        .where(
            *_build_scrap_filters(
                start_date=start_date,
                end_date=end_date,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            )
        )
        .group_by(
            ProductionScrapStatistics.order_id,
            ProductionScrapStatistics.product_id,
            ProductionScrapStatistics.process_code,
            ProductionScrapStatistics.process_name,
            ProductionScrapStatistics.operator_user_id,
            ProductionScrapStatistics.operator_username,
        )
    ).all():
        quantity = int(row.total or 0)
        scrap_total += quantity
        if row.order_id is not None:
            covered_order_ids.add(int(row.order_id))
        if row.product_id is not None:
            key = int(row.product_id)
            scrap_by_product[key] = int(scrap_by_product.get(key, 0)) + quantity
        process_key = _normalize_process_key(row.process_code)
        if process_key:
            covered_process_keys.add(process_key)
            _record_process_name(
                process_name_by_code,
                process_code=row.process_code,
                process_name=row.process_name,
            )
            scrap_by_process[process_key] = int(scrap_by_process.get(process_key, 0)) + quantity
        operator_key = _record_operator_meta(
            operator_meta_by_key,
            user_id=row.operator_user_id,
            username=row.operator_username,
        )
        if operator_key:
            covered_operator_keys.add(operator_key)
            scrap_by_operator[operator_key] = int(
                scrap_by_operator.get(operator_key, 0)
            ) + quantity

    repair_by_product: dict[int, int] = {}
    repair_by_process: dict[str, int] = {}
    repair_by_operator: dict[str, int] = {}
    repair_total = 0
    for row in db.execute(
        select(
            RepairOrder.source_order_id,
            RepairOrder.product_id,
            RepairOrder.source_process_code,
            RepairOrder.source_process_name,
            RepairOrder.sender_user_id,
            RepairOrder.sender_username,
            func.count(RepairOrder.id).label("total"),
        )
        .where(
            *_build_repair_filters(
                start_date=start_date,
                end_date=end_date,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            )
        )
        .group_by(
            RepairOrder.source_order_id,
            RepairOrder.product_id,
            RepairOrder.source_process_code,
            RepairOrder.source_process_name,
            RepairOrder.sender_user_id,
            RepairOrder.sender_username,
        )
    ).all():
        quantity = int(row.total or 0)
        repair_total += quantity
        if row.source_order_id is not None:
            covered_order_ids.add(int(row.source_order_id))
        if row.product_id is not None:
            key = int(row.product_id)
            repair_by_product[key] = int(repair_by_product.get(key, 0)) + quantity
        process_key = _normalize_process_key(row.source_process_code)
        if process_key:
            covered_process_keys.add(process_key)
            _record_process_name(
                process_name_by_code,
                process_code=row.source_process_code,
                process_name=row.source_process_name,
            )
            repair_by_process[process_key] = int(repair_by_process.get(process_key, 0)) + quantity
        operator_key = _record_operator_meta(
            operator_meta_by_key,
            user_id=row.sender_user_id,
            username=row.sender_username,
        )
        if operator_key:
            covered_operator_keys.add(operator_key)
            repair_by_operator[operator_key] = int(
                repair_by_operator.get(operator_key, 0)
            ) + quantity

    defect_by_product: dict[int, int] = {}
    defect_by_process: dict[str, int] = {}
    defect_by_operator: dict[str, int] = {}
    defect_total = 0
    for row in db.execute(
        select(
            RepairDefectPhenomenon.order_id,
            RepairDefectPhenomenon.product_id,
            RepairDefectPhenomenon.process_code,
            RepairDefectPhenomenon.process_name,
            RepairDefectPhenomenon.operator_user_id,
            RepairDefectPhenomenon.operator_username,
            func.sum(RepairDefectPhenomenon.quantity).label("total"),
        )
        .where(
            *_build_defect_filters(
                start_date=start_date,
                end_date=end_date,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            )
        )
        .group_by(
            RepairDefectPhenomenon.order_id,
            RepairDefectPhenomenon.product_id,
            RepairDefectPhenomenon.process_code,
            RepairDefectPhenomenon.process_name,
            RepairDefectPhenomenon.operator_user_id,
            RepairDefectPhenomenon.operator_username,
        )
    ).all():
        quantity = int(row.total or 0)
        defect_total += quantity
        if row.order_id is not None:
            covered_order_ids.add(int(row.order_id))
        if row.product_id is not None:
            key = int(row.product_id)
            defect_by_product[key] = int(defect_by_product.get(key, 0)) + quantity
        process_key = _normalize_process_key(row.process_code)
        if process_key:
            covered_process_keys.add(process_key)
            _record_process_name(
                process_name_by_code,
                process_code=row.process_code,
                process_name=row.process_name,
            )
            defect_by_process[process_key] = int(defect_by_process.get(process_key, 0)) + quantity
        operator_key = _record_operator_meta(
            operator_meta_by_key,
            user_id=row.operator_user_id,
            username=row.operator_username,
        )
        if operator_key:
            covered_operator_keys.add(operator_key)
            defect_by_operator[operator_key] = int(
                defect_by_operator.get(operator_key, 0)
            ) + quantity

    result = {
        "scrap_by_product": scrap_by_product,
        "scrap_by_process": scrap_by_process,
        "scrap_by_operator": scrap_by_operator,
        "scrap_total": {"all": scrap_total},
        "repair_by_product": repair_by_product,
        "repair_by_process": repair_by_process,
        "repair_by_operator": repair_by_operator,
        "repair_total": {"all": repair_total},
        "defect_by_product": defect_by_product,
        "defect_by_process": defect_by_process,
        "defect_by_operator": defect_by_operator,
        "defect_total": {"all": defect_total},
        "process_name_by_code": process_name_by_code,
        "operator_meta_by_key": operator_meta_by_key,
        "covered_order_ids": {"all": covered_order_ids},
        "covered_process_keys": {"all": covered_process_keys},
        "covered_operator_keys": {"all": covered_operator_keys},
    }
    if ttl_seconds > 0:
        with _QUALITY_STATS_CACHE_LOCK:
            _QUALITY_RELATED_TOTALS_LOCAL_CACHE[cache_key] = (
                now + ttl_seconds,
                copy.deepcopy(result),
            )
    return result


def _append_exact_or_like_filter(
    filters: list[object],
    column,
    value: str | None,
    *,
    exact: bool = False,
) -> None:
    text = (value or "").strip()
    if not text:
        return
    filters.append(column == text if exact else column.ilike(f"%{text}%"))


def _build_scrap_filters(
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> list[object]:
    filters = _build_datetime_range_filters(
        ProductionScrapStatistics.last_scrap_time,
        start_date=start_date,
        end_date=end_date,
    )
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        filters.append(
            or_(
                ProductionScrapStatistics.product_name.ilike(like_pattern),
                ProductionScrapStatistics.process_code.ilike(like_pattern),
                ProductionScrapStatistics.process_name.ilike(like_pattern),
                ProductionScrapStatistics.operator_username.ilike(like_pattern),
            )
        )
    _append_exact_or_like_filter(
        filters,
        ProductionScrapStatistics.product_name,
        product_name,
    )
    _append_exact_or_like_filter(
        filters,
        ProductionScrapStatistics.process_code,
        process_code,
        exact=True,
    )
    _append_exact_or_like_filter(
        filters,
        ProductionScrapStatistics.operator_username,
        operator_username,
    )
    return filters


def _build_repair_filters(
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> list[object]:
    filters = _build_datetime_range_filters(
        RepairOrder.repair_time,
        start_date=start_date,
        end_date=end_date,
    )
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        filters.append(
            or_(
                RepairOrder.product_name.ilike(like_pattern),
                RepairOrder.source_process_code.ilike(like_pattern),
                RepairOrder.source_process_name.ilike(like_pattern),
                RepairOrder.sender_username.ilike(like_pattern),
            )
        )
    _append_exact_or_like_filter(filters, RepairOrder.product_name, product_name)
    _append_exact_or_like_filter(
        filters,
        RepairOrder.source_process_code,
        process_code,
        exact=True,
    )
    _append_exact_or_like_filter(
        filters,
        RepairOrder.sender_username,
        operator_username,
    )
    return filters


def _build_defect_filters(
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> list[object]:
    filters = _build_datetime_range_filters(
        RepairDefectPhenomenon.production_time,
        start_date=start_date,
        end_date=end_date,
    )
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        filters.append(
            or_(
                RepairDefectPhenomenon.product_name.ilike(like_pattern),
                RepairDefectPhenomenon.process_code.ilike(like_pattern),
                RepairDefectPhenomenon.process_name.ilike(like_pattern),
                RepairDefectPhenomenon.operator_username.ilike(like_pattern),
            )
        )
    _append_exact_or_like_filter(
        filters,
        RepairDefectPhenomenon.product_name,
        product_name,
    )
    _append_exact_or_like_filter(
        filters,
        RepairDefectPhenomenon.process_code,
        process_code,
        exact=True,
    )
    _append_exact_or_like_filter(
        filters,
        RepairDefectPhenomenon.operator_username,
        operator_username,
    )
    return filters


def list_first_articles(
    db: Session,
    *,
    query_date: date,
    keyword: str | None,
    result_filter: str | None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    page: int,
    page_size: int,
) -> dict[str, object]:
    filters: list[object] = [FirstArticleRecord.verification_date == query_date]
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        filters.append(
            or_(
                ProductionOrder.order_code.ilike(like_pattern),
                User.username.ilike(like_pattern),
            )
        )
    normalized_result = (result_filter or "").strip().lower()
    if normalized_result in ("passed", "failed"):
        filters.append(FirstArticleRecord.result == normalized_result)
    if product_name and product_name.strip():
        filters.append(Product.name.ilike(f"%{product_name.strip()}%"))
    if process_code and process_code.strip():
        filters.append(
            ProductionOrderProcess.process_code.ilike(f"%{process_code.strip()}%")
        )
    if operator_username and operator_username.strip():
        filters.append(User.username.ilike(f"%{operator_username.strip()}%"))

    count_stmt = (
        select(func.count())
        .select_from(FirstArticleRecord)
        .join(FirstArticleRecord.order)
        .join(ProductionOrder.product)
        .join(FirstArticleRecord.order_process)
        .join(FirstArticleRecord.operator)
        .where(*filters)
    )
    total = int(db.execute(count_stmt).scalar_one() or 0)

    offset = (page - 1) * page_size
    rows = (
        db.execute(
            select(FirstArticleRecord)
            .join(FirstArticleRecord.order)
            .join(ProductionOrder.product)
            .join(FirstArticleRecord.order_process)
            .join(FirstArticleRecord.operator)
            .where(*filters)
            .options(
                selectinload(FirstArticleRecord.order).selectinload(
                    ProductionOrder.product
                ),
                selectinload(FirstArticleRecord.order_process),
                selectinload(FirstArticleRecord.operator),
            )
            .order_by(
                FirstArticleRecord.created_at.desc(), FirstArticleRecord.id.desc()
            )
            .offset(offset)
            .limit(page_size)
        )
        .scalars()
        .all()
    )

    code_row = (
        db.execute(
            select(DailyVerificationCode).where(
                DailyVerificationCode.verify_date == query_date
            )
        )
        .scalars()
        .first()
    )
    verification_code, verification_code_source = _resolve_query_verification_code(
        code_row=code_row,
        query_date=query_date,
    )

    items: list[dict[str, object]] = []
    for row in rows:
        order = row.order
        process_row = row.order_process
        operator = row.operator
        product = order.product if order else None
        items.append(
            {
                "id": row.id,
                "order_id": row.order_id,
                "order_code": order.order_code if order else "",
                "product_id": order.product_id if order else 0,
                "product_name": product.name if product else "",
                "order_process_id": row.order_process_id,
                "process_code": process_row.process_code if process_row else "",
                "process_name": process_row.process_name if process_row else "",
                "operator_user_id": row.operator_user_id,
                "operator_username": operator.username if operator else "",
                "result": row.result,
                "record_status": _first_article_record_status(row),
                "verification_date": row.verification_date,
                "verification_code": row.verification_code,
                "remark": row.remark,
                "created_at": row.created_at,
            }
        )

    return {
        "query_date": query_date,
        "verification_code": verification_code,
        "verification_code_source": verification_code_source,
        "total": total,
        "items": items,
    }


def _resolve_query_verification_code(
    *,
    code_row: DailyVerificationCode | None,
    query_date: date,
) -> tuple[str | None, str]:
    if code_row:
        return code_row.code, "stored"
    if query_date == date.today() and production_default_verification_code_is_secure():
        return settings.production_default_verification_code, "default"
    return None, "none"


def _load_first_article_rows(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, object]]:
    cache_key = _quality_stats_cache_key(
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    ttl_seconds = _quality_stats_cache_ttl_seconds()
    now = monotonic()
    if ttl_seconds > 0:
        with _QUALITY_STATS_CACHE_LOCK:
            cached = _QUALITY_ROWS_LOCAL_CACHE.get(cache_key)
            if cached is not None and cached[0] > now:
                return [dict(item) for item in cached[1]]

    filters = _build_created_at_filters(start_date=start_date, end_date=end_date)
    stmt = (
        select(
            FirstArticleRecord.order_id.label("order_id"),
            ProductionOrder.product_id.label("product_id"),
            Product.name.label("product_name"),
            ProductionOrderProcess.process_code.label("process_code"),
            ProductionOrderProcess.process_name.label("process_name"),
            FirstArticleRecord.operator_user_id.label("operator_user_id"),
            User.username.label("operator_username"),
            FirstArticleRecord.result.label("result"),
            FirstArticleRecord.created_at.label("created_at"),
        )
        .select_from(FirstArticleRecord)
        .join(ProductionOrder, ProductionOrder.id == FirstArticleRecord.order_id)
        .join(Product, Product.id == ProductionOrder.product_id)
        .join(
            ProductionOrderProcess,
            ProductionOrderProcess.id == FirstArticleRecord.order_process_id,
        )
        .join(User, User.id == FirstArticleRecord.operator_user_id)
        .where(FirstArticleRecord.is_cancelled.is_(False))
        .where(*filters)
    )
    if product_name and product_name.strip():
        stmt = stmt.where(Product.name.ilike(f"%{product_name.strip()}%"))
    if process_code and process_code.strip():
        stmt = stmt.where(
            ProductionOrderProcess.process_code.ilike(f"%{process_code.strip()}%")
        )
    if operator_username and operator_username.strip():
        stmt = stmt.where(User.username.ilike(f"%{operator_username.strip()}%"))
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        stmt = stmt.where(
            or_(
                Product.name.ilike(like_pattern),
                ProductionOrderProcess.process_code.ilike(like_pattern),
                ProductionOrderProcess.process_name.ilike(like_pattern),
                User.username.ilike(like_pattern),
            )
        )
    normalized_result = (result_filter or "").strip().lower()
    if normalized_result in ("passed", "failed"):
        stmt = stmt.where(FirstArticleRecord.result == normalized_result)
    rows = [dict(row._mapping) for row in db.execute(stmt).all()]
    if ttl_seconds > 0:
        with _QUALITY_STATS_CACHE_LOCK:
            _QUALITY_ROWS_LOCAL_CACHE[cache_key] = (
                now + ttl_seconds,
                [dict(item) for item in rows],
            )
    return rows


def get_quality_overview(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> dict[str, object]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
    )
    first_article_total = len(rows)
    passed_total = sum(1 for row in rows if _row_result(row) == "passed")
    failed_total = sum(1 for row in rows if _row_result(row) == "failed")
    latest_first_article_at = max(
        (created_at for created_at in (_row_created_at(row) for row in rows) if created_at),
        default=None,
    )

    covered_order_ids = {
        order_id for order_id in (_row_order_id(row) for row in rows) if order_id is not None
    }
    covered_process_codes = {
        process_key
        for process_key in (_normalize_process_key(_row_process_code(row)) for row in rows)
        if process_key
    }
    related_order_ids = related_totals.get("covered_order_ids", {}).get("all", set())
    related_process_keys = related_totals.get("covered_process_keys", {}).get(
        "all", set()
    )
    related_operator_keys = related_totals.get("covered_operator_keys", {}).get(
        "all", set()
    )
    if isinstance(related_order_ids, set):
        covered_order_ids.update(related_order_ids)
    if isinstance(related_process_keys, set):
        covered_process_codes.update(related_process_keys)
    covered_operator_keys = (
        set(related_operator_keys) if isinstance(related_operator_keys, set) else set()
    )
    for row in rows:
        covered_operator_keys.add(
            _normalize_operator_key(
                user_id=_row_operator_user_id(row),
                username=_row_operator_username(row),
            )
        )

    return {
        "first_article_total": first_article_total,
        "passed_total": passed_total,
        "failed_total": failed_total,
        "pass_rate_percent": _round_rate(passed_total, first_article_total),
        "defect_total": int(related_totals["defect_total"]["all"]),
        "scrap_total": int(related_totals["scrap_total"]["all"]),
        "repair_total": int(related_totals["repair_total"]["all"]),
        "covered_order_count": len(covered_order_ids),
        "covered_process_count": len(covered_process_codes),
        "covered_operator_count": len({key for key in covered_operator_keys if key}),
        "latest_first_article_at": latest_first_article_at,
    }


def get_quality_process_stats(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, object]]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
    )
    grouped: dict[str, dict[str, object]] = {}
    for row in rows:
        process_key = _normalize_process_key(_row_process_code(row))
        process_name = _row_process_name(row)
        if process_key not in grouped:
            grouped[process_key] = {
                "process_code": process_key,
                "process_name": process_name,
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "defect_total": 0,
                "scrap_total": 0,
                "repair_total": 0,
                "latest_first_article_at": None,
            }

        item = grouped[process_key]
        item["first_article_total"] = _coerce_int(item["first_article_total"]) + 1
        if _row_result(row) == "passed":
            item["passed_total"] = _coerce_int(item["passed_total"]) + 1
        elif _row_result(row) == "failed":
            item["failed_total"] = _coerce_int(item["failed_total"]) + 1
        created_at = _row_created_at(row)
        if created_at is not None and (
            item["latest_first_article_at"] is None
            or created_at > item["latest_first_article_at"]
        ):
            item["latest_first_article_at"] = created_at

    for process_key, process_name in related_totals["process_name_by_code"].items():
        grouped.setdefault(
            process_key,
            {
                "process_code": process_key,
                "process_name": process_name,
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "defect_total": 0,
                "scrap_total": 0,
                "repair_total": 0,
                "latest_first_article_at": None,
            },
        )

    result = list(grouped.values())
    for item in result:
        item["pass_rate_percent"] = _round_rate(
            _coerce_int(item["passed_total"]),
            _coerce_int(item["first_article_total"]),
        )
        process_key = _normalize_process_key(item["process_code"])
        if not item["process_name"]:
            item["process_name"] = related_totals["process_name_by_code"].get(
                process_key, ""
            )
        item["defect_total"] = int(
            related_totals["defect_by_process"].get(process_key, 0)
        )
        item["scrap_total"] = int(
            related_totals["scrap_by_process"].get(process_key, 0)
        )
        item["repair_total"] = int(
            related_totals["repair_by_process"].get(process_key, 0)
        )

    result.sort(key=lambda item: str(item["process_code"]))
    return result


def get_quality_operator_stats(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, object]]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
    )
    grouped: dict[str, dict[str, object]] = {}
    for row in rows:
        operator_name = _row_operator_username(row)
        operator_key = _normalize_operator_key(
            user_id=_row_operator_user_id(row),
            username=operator_name,
        )
        if not operator_key:
            continue
        item = grouped.get(operator_key)
        if item is None:
            item = {
                "operator_user_id": _row_operator_user_id(row),
                "operator_username": operator_name,
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "defect_total": 0,
                "scrap_total": 0,
                "repair_total": 0,
                "latest_first_article_at": None,
            }
            grouped[operator_key] = item

        item["first_article_total"] = _coerce_int(item["first_article_total"]) + 1
        if _row_result(row) == "passed":
            item["passed_total"] = _coerce_int(item["passed_total"]) + 1
        elif _row_result(row) == "failed":
            item["failed_total"] = _coerce_int(item["failed_total"]) + 1
        created_at = _row_created_at(row)
        if created_at is not None and (
            item["latest_first_article_at"] is None
            or created_at > item["latest_first_article_at"]
        ):
            item["latest_first_article_at"] = created_at

    for operator_key, meta in related_totals["operator_meta_by_key"].items():
        grouped.setdefault(
            operator_key,
            {
                "operator_user_id": _coerce_int(meta.get("operator_user_id"), 0),
                "operator_username": str(meta.get("operator_username") or ""),
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "defect_total": 0,
                "scrap_total": 0,
                "repair_total": 0,
                "latest_first_article_at": None,
            },
        )

    result = list(grouped.values())
    for item in result:
        item["pass_rate_percent"] = _round_rate(
            _coerce_int(item["passed_total"]),
            _coerce_int(item["first_article_total"]),
        )
        operator_key = _normalize_operator_key(
            user_id=item["operator_user_id"]
            if _coerce_int(item["operator_user_id"], 0) > 0
            else None,
            username=item["operator_username"],
        )
        meta = related_totals["operator_meta_by_key"].get(operator_key)
        if meta is not None:
            if _coerce_int(item["operator_user_id"], 0) <= 0 and meta.get(
                "operator_user_id"
            ):
                item["operator_user_id"] = _coerce_int(meta["operator_user_id"], 0)
            if not item["operator_username"] and meta.get("operator_username"):
                item["operator_username"] = str(meta["operator_username"])
        item["defect_total"] = int(
            related_totals["defect_by_operator"].get(operator_key, 0)
        )
        item["scrap_total"] = int(
            related_totals["scrap_by_operator"].get(operator_key, 0)
        )
        item["repair_total"] = int(
            related_totals["repair_by_operator"].get(operator_key, 0)
        )

    result.sort(
        key=lambda item: (
            -_coerce_int(item["first_article_total"]),
            -_coerce_int(item["defect_total"]),
            -_coerce_int(item["scrap_total"]),
            -_coerce_int(item["repair_total"]),
            str(item["operator_username"]),
            _coerce_int(item["operator_user_id"]),
        )
    )
    return result


def get_first_article_by_id(
    db: Session,
    *,
    record_id: int,
) -> dict[str, Any] | None:
    row = (
        db.execute(
            select(FirstArticleRecord)
            .where(FirstArticleRecord.id == record_id)
            .options(
                selectinload(FirstArticleRecord.order).selectinload(
                    ProductionOrder.product
                ),
                selectinload(FirstArticleRecord.order_process),
                selectinload(FirstArticleRecord.operator),
                selectinload(FirstArticleRecord.template),
                selectinload(FirstArticleRecord.participants).selectinload(
                    FirstArticleParticipant.user
                ),
                selectinload(FirstArticleRecord.cancelled_by),
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        return None

    order = row.order
    process_row = row.order_process
    operator = row.operator
    template = row.template
    product = order.product if order else None
    action_context = _build_first_article_action_context(
        db,
        record=row,
        for_update=False,
    )

    # 查询处置记录
    disposition = (
        db.execute(
            select(FirstArticleDisposition)
            .where(FirstArticleDisposition.first_article_record_id == record_id)
            .order_by(FirstArticleDisposition.id.desc())
        )
        .scalars()
        .first()
    )
    disposition_history = (
        db.execute(
            select(FirstArticleDispositionHistory)
            .where(FirstArticleDispositionHistory.first_article_record_id == record_id)
            .order_by(
                FirstArticleDispositionHistory.version.desc(),
                FirstArticleDispositionHistory.id.desc(),
            )
        )
        .scalars()
        .all()
    )

    return {
        "id": row.id,
        "order_id": row.order_id,
        "order_code": order.order_code if order else "",
        "product_id": order.product_id if order else 0,
        "product_name": product.name if product else "",
        "order_process_id": row.order_process_id,
        "process_code": process_row.process_code if process_row else "",
        "process_name": process_row.process_name if process_row else "",
        "operator_user_id": row.operator_user_id,
        "operator_username": operator.username if operator else "",
        "result": row.result,
        "record_status": _first_article_record_status(row),
        "can_cancel": _can_cancel_first_article_context(action_context),
        "can_delete": _can_delete_first_article_context(action_context),
        "verification_date": row.verification_date,
        "verification_code": row.verification_code,
        "template_id": row.template_id,
        "template_name": template.template_name if template else None,
        "check_content": row.check_content,
        "test_value": row.test_value,
        "cancelled_at": row.cancelled_at,
        "cancelled_by_username": row.cancelled_by.username
        if row.cancelled_by
        else None,
        "participants": [
            {
                "user_id": participant.user_id,
                "username": participant.user.username if participant.user else "",
                "full_name": participant.user.full_name if participant.user else None,
            }
            for participant in row.participants
        ],
        "remark": row.remark,
        "created_at": row.created_at,
        "disposition_id": disposition.id if disposition else None,
        "disposition_opinion": disposition.disposition_opinion if disposition else None,
        "disposition_username": disposition.disposition_username
        if disposition
        else None,
        "disposition_at": disposition.disposition_at if disposition else None,
        "recheck_result": disposition.recheck_result if disposition else None,
        "final_judgment": disposition.final_judgment if disposition else None,
        "disposition_history": [
            {
                "id": history.id,
                "version": history.version,
                "disposition_opinion": history.disposition_opinion,
                "disposition_username": history.disposition_username,
                "disposition_at": history.disposition_at,
                "recheck_result": history.recheck_result,
                "final_judgment": history.final_judgment,
            }
            for history in disposition_history
        ],
    }


def cancel_first_article(
    db: Session,
    *,
    record_id: int,
    operator: User,
) -> dict[str, Any]:
    context = _load_first_article_action_context(db, record_id=record_id)
    record = context.record
    if bool(record.is_cancelled):
        raise ValueError("该条首件已取消，请勿重复操作")
    if record.result != "passed":
        raise ValueError("仅首件通过记录支持取消")
    if context.has_following_production:
        raise ValueError("该条首件后已存在真实报工，不能取消首件")
    if not _can_cancel_first_article_context(context):
        raise ValueError("该条首件缺少关联执行上下文，暂不支持取消")

    _rollback_first_article_execution_state(db, context=context)
    record.is_cancelled = True
    record.cancelled_at = datetime.now(UTC)
    record.cancelled_by_user_id = operator.id
    add_order_event_log(
        db,
        order_id=record.order_id,
        event_type="first_article_cancelled",
        event_title="首件已取消",
        event_detail=(
            f"{operator.username} 取消了工序 {context.process_row.process_name if context.process_row else record.order_process_id} "
            "的首件，并将对应操作员退回待生产状态"
        ),
        operator_user_id=operator.id,
        payload={
            "first_article_record_id": record.id,
            "order_process_id": record.order_process_id,
            "sub_order_id": context.sub_order.id if context.sub_order else None,
            "assist_authorization_id": context.assist_authorization.id
            if context.assist_authorization
            else None,
            "review_session_ids": [session.id for session in context.review_sessions],
        },
    )
    _invalidate_quality_stats_cache()
    db.flush()
    return {
        "record_id": record.id,
        "order_id": record.order_id,
        "order_code": context.order.order_code if context.order else "",
        "process_name": context.process_row.process_name if context.process_row else "",
        "record_status": _first_article_record_status(record),
        "cancelled_at": record.cancelled_at,
        "cancelled_by_username": operator.username,
    }


def delete_first_article(
    db: Session,
    *,
    record_id: int,
    operator: User,
) -> dict[str, Any]:
    context = _load_first_article_action_context(db, record_id=record_id)
    record = context.record
    snapshot = {
        "record_id": record.id,
        "order_id": record.order_id,
        "order_code": context.order.order_code if context.order else "",
        "process_name": context.process_row.process_name if context.process_row else "",
        "result": record.result,
        "record_status": _first_article_record_status(record),
    }

    rolled_back_execution_state = False
    if not bool(record.is_cancelled) and record.result == "passed":
        if context.has_following_production:
            raise ValueError("该条有效首件后已存在真实报工，不能删除首件")
        if not _can_delete_first_article_context(context):
            raise ValueError("该条首件缺少关联执行上下文，暂不支持删除")
        _rollback_first_article_execution_state(db, context=context)
        rolled_back_execution_state = True

    if context.first_article_production_record is not None:
        db.delete(context.first_article_production_record)
        context.first_article_production_record = None
    for review_session in context.review_sessions:
        db.delete(review_session)

    disposition_history_rows = (
        db.execute(
            select(FirstArticleDispositionHistory).where(
                FirstArticleDispositionHistory.first_article_record_id == record.id
            )
        )
        .scalars()
        .all()
    )
    for history_row in disposition_history_rows:
        db.delete(history_row)

    disposition_rows = (
        db.execute(
            select(FirstArticleDisposition).where(
                FirstArticleDisposition.first_article_record_id == record.id
            )
        )
        .scalars()
        .all()
    )
    for disposition_row in disposition_rows:
        db.delete(disposition_row)

    participant_rows = (
        db.execute(
            select(FirstArticleParticipant).where(
                FirstArticleParticipant.record_id == record.id
            )
        )
        .scalars()
        .all()
    )
    for participant_row in participant_rows:
        db.delete(participant_row)

    db.delete(record)
    add_order_event_log(
        db,
        order_id=snapshot["order_id"],
        event_type="first_article_deleted",
        event_title="首件已删除",
        event_detail=(
            f"{operator.username} 删除了工序 {snapshot['process_name'] or record.order_process_id} 的首件记录"
        ),
        operator_user_id=operator.id,
        payload={
            "first_article_record_id": snapshot["record_id"],
            "rolled_back_execution_state": rolled_back_execution_state,
            "review_session_ids": [session.id for session in context.review_sessions],
        },
    )
    _invalidate_quality_stats_cache()
    db.flush()
    snapshot["rolled_back_execution_state"] = rolled_back_execution_state
    snapshot["deleted"] = True
    return snapshot


def export_first_articles_csv(
    db: Session,
    *,
    query_date: date,
    keyword: str | None,
    result_filter: str | None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> dict[str, Any]:
    payload = list_first_articles(
        db,
        query_date=query_date,
        keyword=keyword,
        result_filter=result_filter,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        page=1,
        page_size=10000,
    )
    items = payload["items"]

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "提交时间",
            "订单号",
            "产品",
            "工序编码",
            "工序名称",
            "操作员",
            "结果",
            "记录状态",
            "校验日期",
            "校验码",
            "备注",
        ]
    )
    for item in items:
        result_label = "通过" if item["result"] == "passed" else "不通过"
        record_status_label = (
            "已取消" if item.get("record_status") == "cancelled" else "有效"
        )
        writer.writerow(
            [
                str(item["created_at"])[:19] if item["created_at"] else "",
                item["order_code"],
                item["product_name"],
                item["process_code"],
                item["process_name"],
                item["operator_username"],
                result_label,
                record_status_label,
                str(item["verification_date"]),
                item["verification_code"] or "",
                item["remark"] or "",
            ]
        )

    csv_bytes = output.getvalue().encode("utf-8-sig")
    content_base64 = base64.b64encode(csv_bytes).decode("ascii")
    filename = f"首件记录_{query_date}_{uuid4().hex[:8]}.csv"
    return {
        "filename": filename,
        "content_base64": content_base64,
        "total_rows": len(items),
    }


def get_quality_product_stats(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, Any]]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
    )

    grouped: dict[int, dict[str, Any]] = {}
    for row in rows:
        product_id = _row_product_id(row)
        if product_id is None:
            continue
        product_name_value = _row_product_name(row)
        if not product_name_value:
            continue
        if product_id not in grouped:
            grouped[product_id] = {
                "product_id": product_id,
                "product_name": product_name_value,
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "defect_total": 0,
                "scrap_total": 0,
                "repair_total": 0,
            }
        item = grouped[product_id]
        item["first_article_total"] = int(item["first_article_total"]) + 1
        if _row_result(row) == "passed":
            item["passed_total"] = int(item["passed_total"]) + 1
        elif _row_result(row) == "failed":
            item["failed_total"] = int(item["failed_total"]) + 1

    scrap_rows = db.execute(
        select(
            ProductionScrapStatistics.product_id,
            ProductionScrapStatistics.product_name,
            func.sum(ProductionScrapStatistics.scrap_quantity).label("total"),
        )
        .where(
            ProductionScrapStatistics.product_id.is_not(None),
            *_build_scrap_filters(
                start_date=start_date,
                end_date=end_date,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            ),
        )
        .group_by(
            ProductionScrapStatistics.product_id,
            ProductionScrapStatistics.product_name,
        )
    ).all()
    for sr in scrap_rows:
        product_id = int(sr.product_id)
        item = grouped.setdefault(
            product_id,
            {
                "product_id": product_id,
                "product_name": sr.product_name or "",
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "defect_total": 0,
                "scrap_total": 0,
                "repair_total": 0,
            },
        )
        item["scrap_total"] = int(sr.total or 0)

    repair_rows = db.execute(
        select(
            RepairOrder.product_id,
            RepairOrder.product_name,
            func.count(RepairOrder.id).label("cnt"),
        )
        .where(
            RepairOrder.product_id.is_not(None),
            *_build_repair_filters(
                start_date=start_date,
                end_date=end_date,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            ),
        )
        .group_by(RepairOrder.product_id, RepairOrder.product_name)
    ).all()
    for rr in repair_rows:
        product_id = int(rr.product_id)
        item = grouped.setdefault(
            product_id,
            {
                "product_id": product_id,
                "product_name": rr.product_name or "",
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "defect_total": 0,
                "scrap_total": 0,
                "repair_total": 0,
            },
        )
        item["repair_total"] = int(rr.cnt or 0)

    result = list(grouped.values())
    for item in result:
        item["pass_rate_percent"] = _round_rate(
            int(item["passed_total"]),
            int(item["first_article_total"]),
        )
        product_id = int(item["product_id"])
        item["defect_total"] = int(
            related_totals["defect_by_product"].get(product_id, 0)
        )
    result.sort(
        key=lambda x: (
            -int(x["first_article_total"]),
            -int(x["repair_total"]),
            -int(x["scrap_total"]),
            str(x["product_name"]),
        )
    )
    return result


def get_quality_trend(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, Any]]:
    resolved_start = start_date or (date.today() - timedelta(days=29))
    resolved_end = end_date or date.today()

    base_filters: list[object] = []
    joined_filters: list[object] = []
    need_joins = False
    if product_name and product_name.strip():
        joined_filters.append(Product.name.ilike(f"%{product_name.strip()}%"))
        need_joins = True
    if process_code and process_code.strip():
        joined_filters.append(
            ProductionOrderProcess.process_code.ilike(f"%{process_code.strip()}%")
        )
        need_joins = True
    if operator_username and operator_username.strip():
        joined_filters.append(User.username.ilike(f"%{operator_username.strip()}%"))
        need_joins = True
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        joined_filters.append(
            or_(
                Product.name.ilike(like_pattern),
                ProductionOrderProcess.process_code.ilike(like_pattern),
                ProductionOrderProcess.process_name.ilike(like_pattern),
                User.username.ilike(like_pattern),
            )
        )
        need_joins = True
    if result_filter and result_filter.strip():
        base_filters.append(FirstArticleRecord.result == result_filter.strip())

    stmt = select(FirstArticleRecord).where(
        *_build_created_at_filters(start_date=resolved_start, end_date=resolved_end)
    )
    if base_filters:
        stmt = stmt.where(*base_filters)
    if need_joins:
        stmt = (
            stmt.join(FirstArticleRecord.order)
            .join(ProductionOrder.product)
            .join(FirstArticleRecord.order_process)
            .join(FirstArticleRecord.operator)
            .where(*joined_filters)
        )

    rows = db.execute(stmt).scalars().all()

    grouped: dict[date, dict[str, Any]] = {}
    current = resolved_start
    while current <= resolved_end:
        grouped[current] = {
            "stat_date": current,
            "first_article_total": 0,
            "passed_total": 0,
            "failed_total": 0,
            "pass_rate_percent": 0.0,
            "defect_total": 0,
            "scrap_total": 0,
            "repair_total": 0,
        }
        current += timedelta(days=1)

    for row in rows:
        d = row.created_at.date() if row.created_at else None
        if d is None or d not in grouped:
            continue
        item = grouped[d]
        item["first_article_total"] = int(item["first_article_total"]) + 1
        if row.result == "passed":
            item["passed_total"] = int(item["passed_total"]) + 1
        elif row.result == "failed":
            item["failed_total"] = int(item["failed_total"]) + 1

    defect_rows = db.execute(
        select(
            func.date(RepairDefectPhenomenon.production_time).label("d"),
            func.sum(RepairDefectPhenomenon.quantity).label("total"),
        )
        .where(
            *_build_defect_filters(
                start_date=resolved_start,
                end_date=resolved_end,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            )
        )
        .group_by(func.date(RepairDefectPhenomenon.production_time))
    ).all()
    for dr in defect_rows:
        stat_date = _normalize_stat_date(dr.d)
        if stat_date is not None and stat_date in grouped:
            grouped[stat_date]["defect_total"] = int(dr.total or 0)

    # 补充报废数量
    scrap_rows = db.execute(
        select(
            func.date(ProductionScrapStatistics.last_scrap_time).label("d"),
            func.sum(ProductionScrapStatistics.scrap_quantity).label("total"),
        )
        .where(
            *_build_scrap_filters(
                start_date=resolved_start,
                end_date=resolved_end,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            )
        )
        .group_by(func.date(ProductionScrapStatistics.last_scrap_time))
    ).all()
    for sr in scrap_rows:
        stat_date = _normalize_stat_date(sr.d)
        if stat_date is not None and stat_date in grouped:
            grouped[stat_date]["scrap_total"] = int(sr.total or 0)

    # 补充维修数量（按维修单创建日期聚合）
    repair_rows = db.execute(
        select(
            func.date(RepairOrder.repair_time).label("d"),
            func.count(RepairOrder.id).label("total"),
        )
        .where(
            *_build_repair_filters(
                start_date=resolved_start,
                end_date=resolved_end,
                keyword=keyword,
                product_name=product_name,
                process_code=process_code,
                operator_username=operator_username,
            )
        )
        .group_by(func.date(RepairOrder.repair_time))
    ).all()
    for rr in repair_rows:
        stat_date = _normalize_stat_date(rr.d)
        if stat_date is not None and stat_date in grouped:
            grouped[stat_date]["repair_total"] = int(rr.total or 0)

    result = list(grouped.values())
    for item in result:
        item["pass_rate_percent"] = _round_rate(
            int(item["passed_total"]),
            int(item["first_article_total"]),
        )
    result.sort(key=lambda x: x["stat_date"])
    return result


def export_quality_stats_csv(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    keyword: str | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> dict[str, Any]:
    overview = get_quality_overview(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    process_stats = get_quality_process_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    operator_stats = get_quality_operator_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    product_stats = get_quality_product_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    trend_stats = get_quality_trend(
        db,
        start_date=start_date,
        end_date=end_date,
        keyword=keyword,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )

    output = io.StringIO()
    writer = csv.writer(output)

    writer.writerow(["== 品质总览 =="])
    writer.writerow(
        [
            "首件总数",
            "通过数",
            "不通过数",
            "通过率",
            "不良总数",
            "报废总数",
            "维修总数",
            "覆盖订单数",
            "覆盖工序数",
            "覆盖人员数",
            "最近首件时间",
        ]
    )
    writer.writerow(
        [
            overview["first_article_total"],
            overview["passed_total"],
            overview["failed_total"],
            f"{overview['pass_rate_percent']}%",
            overview["defect_total"],
            overview["scrap_total"],
            overview["repair_total"],
            overview["covered_order_count"],
            overview["covered_process_count"],
            overview["covered_operator_count"],
            str(overview["latest_first_article_at"])[:19]
            if overview["latest_first_article_at"]
            else "",
        ]
    )
    writer.writerow([])

    writer.writerow(["== 工序统计 =="])
    writer.writerow(
        [
            "工序编码",
            "工序名称",
            "首件总数",
            "通过数",
            "不通过数",
            "通过率",
            "不良数",
            "报废数",
            "维修数",
            "最近首件时间",
        ]
    )
    for item in process_stats:
        writer.writerow(
            [
                item["process_code"],
                item["process_name"],
                item["first_article_total"],
                item["passed_total"],
                item["failed_total"],
                f"{item['pass_rate_percent']}%",
                item["defect_total"],
                item["scrap_total"],
                item["repair_total"],
                str(item["latest_first_article_at"])[:19]
                if item["latest_first_article_at"]
                else "",
            ]
        )
    writer.writerow([])

    writer.writerow(["== 人员统计 =="])
    writer.writerow(
        [
            "操作员",
            "首件总数",
            "通过数",
            "不通过数",
            "通过率",
            "不良数",
            "报废数",
            "维修数",
            "最近首件时间",
        ]
    )
    for item in operator_stats:
        writer.writerow(
            [
                item["operator_username"],
                item["first_article_total"],
                item["passed_total"],
                item["failed_total"],
                f"{item['pass_rate_percent']}%",
                item["defect_total"],
                item["scrap_total"],
                item["repair_total"],
                str(item["latest_first_article_at"])[:19]
                if item["latest_first_article_at"]
                else "",
            ]
        )

    writer.writerow([])
    writer.writerow(["== 产品统计 =="])
    writer.writerow(
        [
            "产品名称",
            "首件总数",
            "通过数",
            "不通过数",
            "通过率",
            "不良数",
            "报废数",
            "维修数",
        ]
    )
    for item in product_stats:
        writer.writerow(
            [
                item["product_name"],
                item["first_article_total"],
                item["passed_total"],
                item["failed_total"],
                f"{item['pass_rate_percent']}%",
                item["defect_total"],
                item["scrap_total"],
                item["repair_total"],
            ]
        )

    writer.writerow([])
    writer.writerow(["== 趋势分析 =="])
    writer.writerow(
        ["日期", "首件总数", "通过数", "不通过数", "通过率", "不良数", "报废数", "维修数"]
    )
    for item in trend_stats:
        writer.writerow(
            [
                item["stat_date"],
                item["first_article_total"],
                item["passed_total"],
                item["failed_total"],
                f"{item['pass_rate_percent']}%",
                item["defect_total"],
                item["scrap_total"],
                item["repair_total"],
            ]
        )

    csv_bytes = output.getvalue().encode("utf-8-sig")
    content_base64 = base64.b64encode(csv_bytes).decode("ascii")
    filename = f"品质统计_{uuid4().hex[:8]}.csv"
    total_rows = (
        len(process_stats) + len(operator_stats) + len(product_stats) + len(trend_stats)
    )
    return {
        "filename": filename,
        "content_base64": content_base64,
        "total_rows": total_rows,
    }


def submit_first_article_disposition(
    db: Session,
    *,
    record_id: int,
    disposition_opinion: str,
    recheck_result: str | None,
    final_judgment: str,
    operator: User,
) -> FirstArticleDisposition:
    from datetime import UTC

    now = datetime.now(UTC)

    record = (
        db.execute(select(FirstArticleRecord).where(FirstArticleRecord.id == record_id))
        .scalars()
        .first()
    )
    if record is None:
        raise ValueError("首件记录不存在")
    if record.result != "failed":
        raise ValueError("仅不通过首件记录允许执行处置")

    existing = (
        db.execute(
            select(FirstArticleDisposition).where(
                FirstArticleDisposition.first_article_record_id == record_id
            )
        )
        .scalars()
        .first()
    )

    # 计算新版本号
    if existing is not None:
        prev_version = (
            (
                db.execute(
                    select(func.max(FirstArticleDispositionHistory.version)).where(
                        FirstArticleDispositionHistory.first_article_record_id
                        == record_id
                    )
                ).scalar()
            )
            or existing.version
            if hasattr(existing, "version")
            else 1
        )
        new_version = int(prev_version or 1) + 1
    else:
        new_version = 1

    # 追加历史记录（每次处置均保留，不可覆盖）
    history = FirstArticleDispositionHistory(
        first_article_record_id=record_id,
        disposition_opinion=disposition_opinion,
        recheck_result=recheck_result,
        final_judgment=final_judgment,
        disposition_user_id=operator.id,
        disposition_username=operator.username,
        disposition_at=now,
        version=new_version,
    )
    db.add(history)

    # 更新或新建当前处置快照（供详情接口快速读取）
    if existing is not None:
        existing.disposition_opinion = disposition_opinion
        existing.recheck_result = recheck_result
        existing.final_judgment = final_judgment
        existing.disposition_user_id = operator.id
        existing.disposition_username = operator.username
        existing.disposition_at = now
        db.flush()
        return existing

    disposition = FirstArticleDisposition(
        first_article_record_id=record_id,
        disposition_opinion=disposition_opinion,
        recheck_result=recheck_result,
        final_judgment=final_judgment,
        disposition_user_id=operator.id,
        disposition_username=operator.username,
        disposition_at=now,
    )
    db.add(disposition)
    db.flush()
    return disposition


def get_defect_analysis(
    db: Session,
    *,
    start_date: date | None = None,
    end_date: date | None = None,
    keyword: str | None = None,
    product_id: int | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    phenomenon: str | None = None,
    top_n: int = 10,
) -> dict:
    from app.schemas.quality import (
        DefectAnalysisResult,
        DefectByDateItem,
        DefectByOperatorItem,
        DefectByProcessItem,
        DefectByProductItem,
        DefectReasonItem,
        DefectTopItem,
    )

    stmt = select(RepairDefectPhenomenon)
    if start_date is not None:
        stmt = stmt.where(
            RepairDefectPhenomenon.production_time
            >= datetime.combine(start_date, time.min)
        )
    if end_date is not None:
        stmt = stmt.where(
            RepairDefectPhenomenon.production_time
            < datetime.combine(end_date + timedelta(days=1), time.min)
        )
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        stmt = stmt.where(
            or_(
                RepairDefectPhenomenon.product_name.ilike(like_pattern),
                RepairDefectPhenomenon.process_code.ilike(like_pattern),
                RepairDefectPhenomenon.process_name.ilike(like_pattern),
                RepairDefectPhenomenon.operator_username.ilike(like_pattern),
                RepairDefectPhenomenon.phenomenon.ilike(like_pattern),
            )
        )
    if product_id is not None:
        stmt = stmt.where(RepairDefectPhenomenon.product_id == product_id)
    if product_name and product_name.strip():
        stmt = stmt.where(
            RepairDefectPhenomenon.product_name.ilike(f"%{product_name.strip()}%")
        )
    if process_code:
        stmt = stmt.where(RepairDefectPhenomenon.process_code == process_code)
    if operator_username and operator_username.strip():
        stmt = stmt.where(
            RepairDefectPhenomenon.operator_username.ilike(
                f"%{operator_username.strip()}%"
            )
        )
    if phenomenon and phenomenon.strip():
        stmt = stmt.where(
            RepairDefectPhenomenon.phenomenon.ilike(f"%{phenomenon.strip()}%")
        )

    rows = db.execute(stmt).scalars().all()

    total = sum(r.quantity for r in rows)

    # Top 缺陷现象
    phenomenon_counts: dict[str, int] = defaultdict(int)
    for r in rows:
        phenomenon_counts[r.phenomenon] += r.quantity
    sorted_phenomena = sorted(
        phenomenon_counts.items(), key=lambda x: x[1], reverse=True
    )
    top_defects = [
        DefectTopItem(
            phenomenon=ph,
            quantity=qty,
            ratio=round(qty * 100.0 / total, 2) if total > 0 else 0.0,
        )
        for ph, qty in sorted_phenomena[:top_n]
    ]

    repair_order_ids = {
        int(row.repair_order_id) for row in rows if row.repair_order_id is not None
    }
    reason_counts: dict[str, int] = defaultdict(int)
    if repair_order_ids:
        cause_stmt = select(RepairCause).where(
            RepairCause.repair_order_id.in_(repair_order_ids)
        )
        if phenomenon and phenomenon.strip():
            cause_stmt = cause_stmt.where(
                RepairCause.phenomenon.ilike(f"%{phenomenon.strip()}%")
            )
        cause_rows = db.execute(cause_stmt).scalars().all()
        for row in cause_rows:
            reason = (row.reason or "").strip()
            if not reason:
                continue
            reason_counts[reason] += int(row.quantity or 0)
    total_reason_quantity = sum(reason_counts.values())
    sorted_reasons = sorted(
        reason_counts.items(), key=lambda item: item[1], reverse=True
    )
    top_reasons = [
        DefectReasonItem(
            reason=reason,
            quantity=quantity,
            ratio=round(quantity * 100.0 / total_reason_quantity, 2)
            if total_reason_quantity > 0
            else 0.0,
        )
        for reason, quantity in sorted_reasons[:top_n]
    ]

    # 按工序分布
    process_counts: dict[tuple, int] = defaultdict(int)
    for r in rows:
        key = (r.process_code or "", r.process_name or "")
        process_counts[key] += r.quantity
    by_process = [
        DefectByProcessItem(process_code=k[0], process_name=k[1] or None, quantity=v)
        for k, v in sorted(process_counts.items(), key=lambda x: x[1], reverse=True)
    ]

    # 按产品分布
    product_counts: dict[tuple, int] = defaultdict(int)
    for r in rows:
        key = (r.product_id, r.product_name or "")
        product_counts[key] += r.quantity
    by_product = [
        DefectByProductItem(product_id=k[0], product_name=k[1] or None, quantity=v)
        for k, v in sorted(product_counts.items(), key=lambda x: x[1], reverse=True)
    ]

    operator_counts: dict[tuple[int | None, str], int] = defaultdict(int)
    for r in rows:
        key = (r.operator_user_id, r.operator_username or "")
        operator_counts[key] += r.quantity
    by_operator = [
        DefectByOperatorItem(
            operator_user_id=key[0],
            operator_username=key[1] or None,
            quantity=quantity,
        )
        for key, quantity in sorted(
            operator_counts.items(), key=lambda item: item[1], reverse=True
        )
    ]

    date_counts: dict[date, int] = defaultdict(int)
    for r in rows:
        stat_date = _normalize_stat_date(r.production_time)
        if stat_date is None:
            continue
        date_counts[stat_date] += r.quantity
    by_date = [
        DefectByDateItem(stat_date=stat_date, quantity=quantity)
        for stat_date, quantity in sorted(date_counts.items(), key=lambda item: item[0])
    ]

    product_quality_comparison = get_quality_product_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
    )
    if product_id is not None:
        product_quality_comparison = [
            item
            for item in product_quality_comparison
            if int(item["product_id"]) == product_id
        ]

    return DefectAnalysisResult(
        total_defect_quantity=total,
        top_defects=top_defects,
        top_reasons=top_reasons,
        product_quality_comparison=product_quality_comparison,
        by_process=by_process,
        by_product=by_product,
        by_operator=by_operator,
        by_date=by_date,
    )


def export_defect_analysis_csv(
    db: Session,
    *,
    start_date: date | None = None,
    end_date: date | None = None,
    keyword: str | None = None,
    product_id: int | None = None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    phenomenon: str | None = None,
) -> dict:
    from app.schemas.quality import DefectAnalysisExportResult

    stmt = select(RepairDefectPhenomenon)
    if start_date is not None:
        stmt = stmt.where(
            RepairDefectPhenomenon.production_time
            >= datetime.combine(start_date, time.min)
        )
    if end_date is not None:
        stmt = stmt.where(
            RepairDefectPhenomenon.production_time
            < datetime.combine(end_date + timedelta(days=1), time.min)
        )
    normalized_keyword = (keyword or "").strip()
    if normalized_keyword:
        like_pattern = f"%{normalized_keyword}%"
        stmt = stmt.where(
            or_(
                RepairDefectPhenomenon.product_name.ilike(like_pattern),
                RepairDefectPhenomenon.process_code.ilike(like_pattern),
                RepairDefectPhenomenon.process_name.ilike(like_pattern),
                RepairDefectPhenomenon.operator_username.ilike(like_pattern),
                RepairDefectPhenomenon.phenomenon.ilike(like_pattern),
            )
        )
    if product_id is not None:
        stmt = stmt.where(RepairDefectPhenomenon.product_id == product_id)
    if product_name and product_name.strip():
        stmt = stmt.where(
            RepairDefectPhenomenon.product_name.ilike(f"%{product_name.strip()}%")
        )
    if process_code:
        stmt = stmt.where(RepairDefectPhenomenon.process_code == process_code)
    if operator_username and operator_username.strip():
        stmt = stmt.where(
            RepairDefectPhenomenon.operator_username.ilike(
                f"%{operator_username.strip()}%"
            )
        )
    if phenomenon and phenomenon.strip():
        stmt = stmt.where(
            RepairDefectPhenomenon.phenomenon.ilike(f"%{phenomenon.strip()}%")
        )

    rows = db.execute(stmt).scalars().all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        ["缺陷现象", "产品", "工序编码", "工序名称", "数量", "操作员", "生产时间"]
    )
    for r in rows:
        writer.writerow(
            [
                r.phenomenon,
                r.product_name or "",
                r.process_code or "",
                r.process_name or "",
                r.quantity,
                r.operator_username or "",
                r.production_time.strftime("%Y-%m-%d %H:%M")
                if r.production_time
                else "",
            ]
        )

    content = output.getvalue().encode("utf-8-sig")
    filename = f"defect_analysis_{uuid4().hex[:8]}.csv"
    return DefectAnalysisExportResult(
        filename=filename,
        content_base64=base64.b64encode(content).decode(),
        total_rows=len(rows),
    )
