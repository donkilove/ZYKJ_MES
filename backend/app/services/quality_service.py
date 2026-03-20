from __future__ import annotations

import base64
import csv
import io
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from typing import Any
from uuid import uuid4

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.models.daily_verification_code import DailyVerificationCode
from app.models.first_article_disposition import FirstArticleDisposition
from app.models.first_article_disposition_history import FirstArticleDispositionHistory
from app.models.first_article_record import FirstArticleRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.product import Product
from app.models.repair_order import RepairOrder
from app.models.repair_order import RepairOrder
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
from app.models.user import User


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
        filters.append(column < datetime.combine(end_date + timedelta(days=1), time.min))
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


def _collect_quality_scope(rows: list[FirstArticleRecord]) -> dict[str, set[int] | set[str]]:
    return {
        "product_ids": {
            int(row.order.product_id)
            for row in rows
            if row.order is not None and row.order.product_id is not None
        },
        "order_ids": {int(row.order_id) for row in rows if row.order_id is not None},
        "order_process_ids": {
            int(row.order_process_id)
            for row in rows
            if row.order_process_id is not None
        },
        "process_codes": {
            row.order_process.process_code
            for row in rows
            if row.order_process is not None and row.order_process.process_code
        },
    }


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
        filters.append(ProductionOrderProcess.process_code.ilike(f"%{process_code.strip()}%"))
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
                selectinload(FirstArticleRecord.order).selectinload(ProductionOrder.product),
                selectinload(FirstArticleRecord.order_process),
                selectinload(FirstArticleRecord.operator),
            )
            .order_by(FirstArticleRecord.created_at.desc(), FirstArticleRecord.id.desc())
            .offset(offset)
            .limit(page_size)
        )
        .scalars()
        .all()
    )

    code_row = db.execute(
        select(DailyVerificationCode).where(DailyVerificationCode.verify_date == query_date)
    ).scalars().first()
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
) -> list[FirstArticleRecord]:
    filters = _build_created_at_filters(start_date=start_date, end_date=end_date)
    stmt = (
        select(FirstArticleRecord)
        .join(FirstArticleRecord.order)
        .join(ProductionOrder.product)
        .join(FirstArticleRecord.order_process)
        .join(FirstArticleRecord.operator)
        .where(*filters)
        .options(
            selectinload(FirstArticleRecord.order).selectinload(ProductionOrder.product),
            selectinload(FirstArticleRecord.order_process),
            selectinload(FirstArticleRecord.operator),
        )
        .order_by(FirstArticleRecord.created_at.desc(), FirstArticleRecord.id.desc())
    )
    if product_name and product_name.strip():
        stmt = stmt.where(Product.name.ilike(f"%{product_name.strip()}%"))
    if process_code and process_code.strip():
        stmt = stmt.where(ProductionOrderProcess.process_code.ilike(f"%{process_code.strip()}%"))
    if operator_username and operator_username.strip():
        stmt = stmt.where(User.username.ilike(f"%{operator_username.strip()}%"))
    normalized_result = (result_filter or "").strip().lower()
    if normalized_result in ("passed", "failed"):
        stmt = stmt.where(FirstArticleRecord.result == normalized_result)
    return (
        db.execute(stmt)
        .scalars()
        .all()
    )


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
    first_article_total = len(rows)
    passed_total = sum(1 for row in rows if row.result == "passed")
    failed_total = sum(1 for row in rows if row.result == "failed")
    latest_first_article_at = max((row.created_at for row in rows), default=None)

    covered_order_ids = {row.order_id for row in rows}
    covered_process_codes = {
        row.order_process.process_code
        for row in rows
        if row.order_process is not None and row.order_process.process_code
    }
    covered_operator_ids = {row.operator_user_id for row in rows}

    return {
        "first_article_total": first_article_total,
        "passed_total": passed_total,
        "failed_total": failed_total,
        "pass_rate_percent": _round_rate(passed_total, first_article_total),
        "covered_order_count": len(covered_order_ids),
        "covered_process_count": len(covered_process_codes),
        "covered_operator_count": len(covered_operator_ids),
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
    grouped: dict[str, dict[str, object]] = {}
    for row in rows:
        process_row = row.order_process
        process_code = process_row.process_code if process_row else ""
        process_name = process_row.process_name if process_row else ""
        if process_code not in grouped:
            grouped[process_code] = {
                "process_code": process_code,
                "process_name": process_name,
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "latest_first_article_at": None,
            }

        item = grouped[process_code]
        item["first_article_total"] = int(item["first_article_total"]) + 1
        if row.result == "passed":
            item["passed_total"] = int(item["passed_total"]) + 1
        elif row.result == "failed":
            item["failed_total"] = int(item["failed_total"]) + 1
        if item["latest_first_article_at"] is None:
            item["latest_first_article_at"] = row.created_at

    result = list(grouped.values())
    for item in result:
        item["pass_rate_percent"] = _round_rate(
            int(item["passed_total"]),
            int(item["first_article_total"]),
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
    grouped: dict[int, dict[str, object]] = defaultdict(dict)
    for row in rows:
        operator_user_id = row.operator_user_id
        operator_name = row.operator.username if row.operator else ""
        item = grouped.get(operator_user_id)
        if not item:
            item = {
                "operator_user_id": operator_user_id,
                "operator_username": operator_name,
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "latest_first_article_at": None,
            }
            grouped[operator_user_id] = item

        item["first_article_total"] = int(item["first_article_total"]) + 1
        if row.result == "passed":
            item["passed_total"] = int(item["passed_total"]) + 1
        elif row.result == "failed":
            item["failed_total"] = int(item["failed_total"]) + 1
        if item["latest_first_article_at"] is None:
            item["latest_first_article_at"] = row.created_at

    result = list(grouped.values())
    for item in result:
        item["pass_rate_percent"] = _round_rate(
            int(item["passed_total"]),
            int(item["first_article_total"]),
        )

    result.sort(
        key=lambda item: (
            -int(item["first_article_total"]),
            int(item["operator_user_id"]),
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
                selectinload(FirstArticleRecord.order).selectinload(ProductionOrder.product),
                selectinload(FirstArticleRecord.order_process),
                selectinload(FirstArticleRecord.operator),
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
        "remark": row.remark,
        "created_at": row.created_at,
        "disposition_id": disposition.id if disposition else None,
        "disposition_opinion": disposition.disposition_opinion if disposition else None,
        "disposition_username": disposition.disposition_username if disposition else None,
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
    writer.writerow(["提交时间", "订单号", "产品", "工序编码", "工序名称", "操作员", "结果", "校验日期", "校验码", "备注"])
    for item in items:
        result_label = "通过" if item["result"] == "passed" else "不通过"
        writer.writerow([
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
        ])

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

    grouped: dict[int, dict[str, Any]] = {}
    for row in rows:
        order = row.order
        if order is None:
            continue
        product = order.product
        if product is None:
            continue
        pid = product.id
        if pid not in grouped:
            grouped[pid] = {
                "product_id": pid,
                "product_name": product.name,
                "first_article_total": 0,
                "passed_total": 0,
                "failed_total": 0,
                "pass_rate_percent": 0.0,
                "scrap_total": 0,
                "repair_order_count": 0,
            }
        item = grouped[pid]
        item["first_article_total"] = int(item["first_article_total"]) + 1
        if row.result == "passed":
            item["passed_total"] = int(item["passed_total"]) + 1
        elif row.result == "failed":
            item["failed_total"] = int(item["failed_total"]) + 1

    scope = _collect_quality_scope(rows)

    # 补充报废和维修数量
    if grouped:
        product_ids = list(grouped.keys())
        scrap_time_filters = _build_datetime_range_filters(
            ProductionScrapStatistics.last_scrap_time,
            start_date=start_date,
            end_date=end_date,
        )
        scrap_rows = (
            db.execute(
                select(
                    ProductionScrapStatistics.product_id,
                    func.sum(ProductionScrapStatistics.scrap_quantity).label("total"),
                )
                .where(
                    ProductionScrapStatistics.product_id.in_(product_ids),
                    *scrap_time_filters,
                )
                .where(
                    ProductionScrapStatistics.process_code == process_code
                    if process_code and process_code.strip()
                    else True,
                )
                .where(
                    ProductionScrapStatistics.operator_username.ilike(f"%{operator_username.strip()}%")
                    if operator_username and operator_username.strip()
                    else True,
                )
                .where(
                    ProductionScrapStatistics.process_id.in_(scope["order_process_ids"])
                    if scope["order_process_ids"]
                    else True,
                )
                .where(
                    ProductionScrapStatistics.order_id.in_(scope["order_ids"])
                    if scope["order_ids"]
                    else True,
                )
                .group_by(ProductionScrapStatistics.product_id)
            )
            .all()
        )
        for sr in scrap_rows:
            if sr.product_id in grouped:
                grouped[sr.product_id]["scrap_total"] = int(sr.total or 0)

        repair_time_filters = _build_datetime_range_filters(
            RepairOrder.repair_time,
            start_date=start_date,
            end_date=end_date,
        )
        repair_rows = (
            db.execute(
                select(
                    RepairOrder.product_id,
                    func.count(RepairOrder.id).label("cnt"),
                )
                .where(
                    RepairOrder.product_id.in_(product_ids),
                    *repair_time_filters,
                )
                .where(
                    RepairOrder.source_process_code == process_code
                    if process_code and process_code.strip()
                    else True,
                )
                .where(
                    RepairOrder.sender_username.ilike(f"%{operator_username.strip()}%")
                    if operator_username and operator_username.strip()
                    else True,
                )
                .where(
                    RepairOrder.source_order_process_id.in_(scope["order_process_ids"])
                    if scope["order_process_ids"]
                    else True,
                )
                .where(
                    RepairOrder.source_order_id.in_(scope["order_ids"])
                    if scope["order_ids"]
                    else True,
                )
                .group_by(RepairOrder.product_id)
            )
            .all()
        )
        for rr in repair_rows:
            if rr.product_id in grouped:
                grouped[rr.product_id]["repair_order_count"] = int(rr.cnt or 0)

    result = list(grouped.values())
    for item in result:
        item["pass_rate_percent"] = _round_rate(
            int(item["passed_total"]),
            int(item["first_article_total"]),
        )
    result.sort(key=lambda x: -int(x["first_article_total"]))
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
        joined_filters.append(ProductionOrderProcess.process_code.ilike(f"%{process_code.strip()}%"))
        need_joins = True
    if operator_username and operator_username.strip():
        joined_filters.append(User.username.ilike(f"%{operator_username.strip()}%"))
        need_joins = True
    if result_filter and result_filter.strip():
        base_filters.append(FirstArticleRecord.result == result_filter.strip())

    stmt = (
        select(FirstArticleRecord)
        .where(*_build_created_at_filters(start_date=resolved_start, end_date=resolved_end))
    )
    if base_filters:
        stmt = stmt.where(*base_filters)
    if need_joins:
        stmt = (
            stmt
            .join(FirstArticleRecord.order)
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

    scope = _collect_quality_scope(rows)

    # 补充报废数量
    scrap_rows = []
    if scope["product_ids"] or scope["order_ids"]:
        scrap_rows = (
            db.execute(
                select(
                    func.date(ProductionScrapStatistics.last_scrap_time).label("d"),
                    func.sum(ProductionScrapStatistics.scrap_quantity).label("total"),
                )
                .where(
                    ProductionScrapStatistics.last_scrap_time >= datetime.combine(resolved_start, time.min),
                    ProductionScrapStatistics.last_scrap_time < datetime.combine(resolved_end + timedelta(days=1), time.min),
                )
                .where(
                    ProductionScrapStatistics.product_id.in_(scope["product_ids"])
                    if scope["product_ids"]
                    else True,
                )
                .where(
                    ProductionScrapStatistics.process_code == process_code
                    if process_code and process_code.strip()
                    else True,
                )
                .where(
                    ProductionScrapStatistics.operator_username.ilike(f"%{operator_username.strip()}%")
                    if operator_username and operator_username.strip()
                    else True,
                )
                .where(
                    ProductionScrapStatistics.process_id.in_(scope["order_process_ids"])
                    if scope["order_process_ids"]
                    else True,
                )
                .where(
                    ProductionScrapStatistics.order_id.in_(scope["order_ids"])
                    if scope["order_ids"]
                    else True,
                )
                .group_by(func.date(ProductionScrapStatistics.last_scrap_time))
            )
            .all()
        )
    for sr in scrap_rows:
        stat_date = _normalize_stat_date(sr.d)
        if stat_date is not None and stat_date in grouped:
            grouped[stat_date]["scrap_total"] = int(sr.total or 0)

    # 补充维修数量（按维修单创建日期聚合）
    repair_rows = []
    if scope["product_ids"] or scope["order_ids"]:
        repair_rows = (
            db.execute(
                select(
                    func.date(RepairOrder.repair_time).label("d"),
                    func.count(RepairOrder.id).label("total"),
                )
                .where(
                    RepairOrder.repair_time >= datetime.combine(resolved_start, time.min),
                    RepairOrder.repair_time < datetime.combine(resolved_end + timedelta(days=1), time.min),
                )
                .where(
                    RepairOrder.product_id.in_(scope["product_ids"])
                    if scope["product_ids"]
                    else True,
                )
                .where(
                    RepairOrder.source_process_code == process_code
                    if process_code and process_code.strip()
                    else True,
                )
                .where(
                    RepairOrder.sender_username.ilike(f"%{operator_username.strip()}%")
                    if operator_username and operator_username.strip()
                    else True,
                )
                .where(
                    RepairOrder.source_order_process_id.in_(scope["order_process_ids"])
                    if scope["order_process_ids"]
                    else True,
                )
                .where(
                    RepairOrder.source_order_id.in_(scope["order_ids"])
                    if scope["order_ids"]
                    else True,
                )
                .group_by(func.date(RepairOrder.repair_time))
            )
            .all()
        )
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
    writer.writerow(["首件总数", "通过数", "不通过数", "通过率", "覆盖订单数", "覆盖工序数", "覆盖人员数", "最近首件时间"])
    writer.writerow([
        overview["first_article_total"],
        overview["passed_total"],
        overview["failed_total"],
        f"{overview['pass_rate_percent']}%",
        overview["covered_order_count"],
        overview["covered_process_count"],
        overview["covered_operator_count"],
        str(overview["latest_first_article_at"])[:19] if overview["latest_first_article_at"] else "",
    ])
    writer.writerow([])

    writer.writerow(["== 工序统计 =="])
    writer.writerow(["工序编码", "工序名称", "首件总数", "通过数", "不通过数", "通过率", "最近首件时间"])
    for item in process_stats:
        writer.writerow([
            item["process_code"],
            item["process_name"],
            item["first_article_total"],
            item["passed_total"],
            item["failed_total"],
            f"{item['pass_rate_percent']}%",
            str(item["latest_first_article_at"])[:19] if item["latest_first_article_at"] else "",
        ])
    writer.writerow([])

    writer.writerow(["== 人员统计 =="])
    writer.writerow(["操作员", "首件总数", "通过数", "不通过数", "通过率", "最近首件时间"])
    for item in operator_stats:
        writer.writerow([
            item["operator_username"],
            item["first_article_total"],
            item["passed_total"],
            item["failed_total"],
            f"{item['pass_rate_percent']}%",
            str(item["latest_first_article_at"])[:19] if item["latest_first_article_at"] else "",
        ])

    writer.writerow([])
    writer.writerow(["== 产品统计 =="])
    writer.writerow(["产品名称", "首件总数", "通过数", "不通过数", "通过率", "报废数", "维修数"])
    for item in product_stats:
        writer.writerow([
            item["product_name"],
            item["first_article_total"],
            item["passed_total"],
            item["failed_total"],
            f"{item['pass_rate_percent']}%",
            item["scrap_total"],
            item["repair_order_count"],
        ])

    writer.writerow([])
    writer.writerow(["== 趋势分析 =="])
    writer.writerow(["日期", "首件总数", "通过数", "不通过数", "通过率", "报废数", "维修数"])
    for item in trend_stats:
        writer.writerow([
            item["stat_date"],
            item["first_article_total"],
            item["passed_total"],
            item["failed_total"],
            f"{item['pass_rate_percent']}%",
            item["scrap_total"],
            item["repair_total"],
        ])

    csv_bytes = output.getvalue().encode("utf-8-sig")
    content_base64 = base64.b64encode(csv_bytes).decode("ascii")
    filename = f"品质统计_{uuid4().hex[:8]}.csv"
    total_rows = len(process_stats) + len(operator_stats) + len(product_stats) + len(trend_stats)
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
        db.execute(
            select(FirstArticleRecord).where(FirstArticleRecord.id == record_id)
        )
        .scalars()
        .first()
    )
    if record is None:
        raise ValueError("首件记录不存在")
    if record.result != "failed":
        raise ValueError("仅不通过首件记录允许执行处置")

    existing = (
        db.execute(
            select(FirstArticleDisposition)
            .where(FirstArticleDisposition.first_article_record_id == record_id)
        )
        .scalars()
        .first()
    )

    # 计算新版本号
    if existing is not None:
        prev_version = (
            db.execute(
                select(func.max(FirstArticleDispositionHistory.version))
                .where(FirstArticleDispositionHistory.first_article_record_id == record_id)
            )
            .scalar()
        ) or existing.version if hasattr(existing, "version") else 1
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
    from app.schemas.quality import DefectAnalysisResult, DefectTopItem, DefectByProcessItem, DefectByProductItem

    stmt = select(RepairDefectPhenomenon)
    if start_date is not None:
        stmt = stmt.where(
            RepairDefectPhenomenon.production_time >= datetime.combine(start_date, time.min)
        )
    if end_date is not None:
        stmt = stmt.where(
            RepairDefectPhenomenon.production_time < datetime.combine(end_date + timedelta(days=1), time.min)
        )
    if product_id is not None:
        stmt = stmt.where(RepairDefectPhenomenon.product_id == product_id)
    if product_name and product_name.strip():
        stmt = stmt.where(RepairDefectPhenomenon.product_name.ilike(f"%{product_name.strip()}%"))
    if process_code:
        stmt = stmt.where(RepairDefectPhenomenon.process_code == process_code)
    if operator_username and operator_username.strip():
        stmt = stmt.where(RepairDefectPhenomenon.operator_username.ilike(f"%{operator_username.strip()}%"))
    if phenomenon and phenomenon.strip():
        stmt = stmt.where(RepairDefectPhenomenon.phenomenon.ilike(f"%{phenomenon.strip()}%"))

    rows = db.execute(stmt).scalars().all()

    total = sum(r.quantity for r in rows)

    # Top 缺陷现象
    phenomenon_counts: dict[str, int] = defaultdict(int)
    for r in rows:
        phenomenon_counts[r.phenomenon] += r.quantity
    sorted_phenomena = sorted(phenomenon_counts.items(), key=lambda x: x[1], reverse=True)
    top_defects = [
        DefectTopItem(
            phenomenon=ph,
            quantity=qty,
            ratio=round(qty * 100.0 / total, 2) if total > 0 else 0.0,
        )
        for ph, qty in sorted_phenomena[:top_n]
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

    return DefectAnalysisResult(
        total_defect_quantity=total,
        top_defects=top_defects,
        by_process=by_process,
        by_product=by_product,
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
            RepairDefectPhenomenon.production_time >= datetime.combine(start_date, time.min)
        )
    if end_date is not None:
        stmt = stmt.where(
            RepairDefectPhenomenon.production_time < datetime.combine(end_date + timedelta(days=1), time.min)
        )
    if product_id is not None:
        stmt = stmt.where(RepairDefectPhenomenon.product_id == product_id)
    if product_name and product_name.strip():
        stmt = stmt.where(RepairDefectPhenomenon.product_name.ilike(f"%{product_name.strip()}%"))
    if process_code:
        stmt = stmt.where(RepairDefectPhenomenon.process_code == process_code)
    if operator_username and operator_username.strip():
        stmt = stmt.where(RepairDefectPhenomenon.operator_username.ilike(f"%{operator_username.strip()}%"))
    if phenomenon and phenomenon.strip():
        stmt = stmt.where(RepairDefectPhenomenon.phenomenon.ilike(f"%{phenomenon.strip()}%"))

    rows = db.execute(stmt).scalars().all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["缺陷现象", "产品", "工序编码", "工序名称", "数量", "操作员", "生产时间"])
    for r in rows:
        writer.writerow([
            r.phenomenon,
            r.product_name or "",
            r.process_code or "",
            r.process_name or "",
            r.quantity,
            r.operator_username or "",
            r.production_time.strftime("%Y-%m-%d %H:%M") if r.production_time else "",
        ])

    content = output.getvalue().encode("utf-8-sig")
    filename = f"defect_analysis_{uuid4().hex[:8]}.csv"
    return DefectAnalysisExportResult(
        filename=filename,
        content_base64=base64.b64encode(content).decode(),
        total_rows=len(rows),
    )
