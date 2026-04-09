from __future__ import annotations

import base64
import copy
import csv
import io
import threading
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from time import monotonic
from typing import Any
from uuid import uuid4

from sqlalchemy import event, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.models.daily_verification_code import DailyVerificationCode
from app.models.first_article_disposition import FirstArticleDisposition
from app.models.first_article_disposition_history import FirstArticleDispositionHistory
from app.models.first_article_participant import FirstArticleParticipant
from app.models.first_article_record import FirstArticleRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.product import Product
from app.models.repair_cause import RepairCause
from app.models.repair_order import RepairOrder
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
from app.models.user import User

_QUALITY_ROWS_LOCAL_CACHE: dict[
    tuple[object, ...], tuple[float, list[dict[str, object]]]
] = {}
_QUALITY_RELATED_TOTALS_LOCAL_CACHE: dict[
    tuple[object, ...], tuple[float, dict[str, Any]]
] = {}
_QUALITY_STATS_CACHE_LOCK = threading.Lock()
_QUALITY_STATS_DIRTY_FLAG = "quality_stats_dirty"
_QUALITY_STATS_DIRTY_MODELS = (
    FirstArticleRecord,
    ProductionScrapStatistics,
    RepairOrder,
    RepairDefectPhenomenon,
)


def _clear_quality_stats_local_cache() -> None:
    with _QUALITY_STATS_CACHE_LOCK:
        _QUALITY_ROWS_LOCAL_CACHE.clear()
        _QUALITY_RELATED_TOTALS_LOCAL_CACHE.clear()


@event.listens_for(Session, "before_flush")
def _track_quality_stats_writes(
    session: Session,
    _flush_context,
    _instances,
) -> None:
    if session.info.get(_QUALITY_STATS_DIRTY_FLAG):
        return
    for collection in (session.new, session.dirty, session.deleted):
        if any(isinstance(obj, _QUALITY_STATS_DIRTY_MODELS) for obj in collection):
            session.info[_QUALITY_STATS_DIRTY_FLAG] = True
            return


@event.listens_for(Session, "after_commit")
def _invalidate_quality_stats_cache_after_commit(session: Session) -> None:
    if not session.info.pop(_QUALITY_STATS_DIRTY_FLAG, False):
        return
    _clear_quality_stats_local_cache()


@event.listens_for(Session, "after_rollback")
def _clear_quality_stats_dirty_flag_after_rollback(session: Session) -> None:
    session.info.pop(_QUALITY_STATS_DIRTY_FLAG, None)


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
    product_name: str | None,
    process_code: str | None,
    operator_username: str | None,
    result_filter: str | None = None,
) -> tuple[object, ...]:
    return (
        start_date,
        end_date,
        _normalize_cache_text(product_name),
        _normalize_cache_text(process_code),
        _normalize_cache_text(operator_username),
        _normalize_cache_text(result_filter),
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> dict[str, Any]:
    cache_key = _quality_stats_cache_key(
        start_date=start_date,
        end_date=end_date,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> list[object]:
    filters = _build_datetime_range_filters(
        ProductionScrapStatistics.last_scrap_time,
        start_date=start_date,
        end_date=end_date,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> list[object]:
    filters = _build_datetime_range_filters(
        RepairOrder.repair_time,
        start_date=start_date,
        end_date=end_date,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
) -> list[object]:
    filters = _build_datetime_range_filters(
        RepairDefectPhenomenon.production_time,
        start_date=start_date,
        end_date=end_date,
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
                Product.name.ilike(like_pattern),
                ProductionOrderProcess.process_name.ilike(like_pattern),
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
    if code_row:
        verification_code = code_row.code
        verification_code_source = "stored"
    elif query_date == date.today():
        verification_code = settings.production_default_verification_code
        verification_code_source = "default"
    else:
        verification_code = None
        verification_code_source = "none"

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


def _load_first_article_rows(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, object]]:
    cache_key = _quality_stats_cache_key(
        start_date=start_date,
        end_date=end_date,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> dict[str, object]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, object]]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, object]]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
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
        "verification_date": row.verification_date,
        "verification_code": row.verification_code,
        "template_id": row.template_id,
        "template_name": template.template_name if template else None,
        "check_content": row.check_content,
        "test_value": row.test_value,
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
            "校验日期",
            "校验码",
            "备注",
        ]
    )
    for item in items:
        result_label = "通过" if item["result"] == "passed" else "不通过"
        writer.writerow(
            [
                str(item["created_at"])[:19] if item["created_at"] else "",
                item["order_code"],
                item["product_name"],
                item["process_code"],
                item["process_name"],
                item["operator_username"],
                result_label,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> list[dict[str, Any]]:
    rows = _load_first_article_rows(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    related_totals = _aggregate_quality_related_totals(
        db,
        start_date=start_date,
        end_date=end_date,
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
    product_name: str | None = None,
    process_code: str | None = None,
    operator_username: str | None = None,
    result_filter: str | None = None,
) -> dict[str, Any]:
    overview = get_quality_overview(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    process_stats = get_quality_process_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    operator_stats = get_quality_operator_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    product_stats = get_quality_product_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result_filter,
    )
    trend_stats = get_quality_trend(
        db,
        start_date=start_date,
        end_date=end_date,
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
