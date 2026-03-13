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
from app.models.first_article_record import FirstArticleRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.product import Product
from app.models.repair_order import RepairOrder
from app.models.user import User


def _build_created_at_filters(
    *,
    start_date: date | None,
    end_date: date | None,
) -> list[object]:
    filters: list[object] = []
    if start_date is not None:
        filters.append(FirstArticleRecord.created_at >= datetime.combine(start_date, time.min))
    if end_date is not None:
        filters.append(
            FirstArticleRecord.created_at
            < datetime.combine(end_date + timedelta(days=1), time.min)
        )
    return filters


def _round_rate(passed: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return round((passed * 100.0) / total, 2)


def list_first_articles(
    db: Session,
    *,
    query_date: date,
    keyword: str | None,
    result_filter: str | None,
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
) -> list[FirstArticleRecord]:
    filters = _build_created_at_filters(start_date=start_date, end_date=end_date)
    return (
        db.execute(
            select(FirstArticleRecord)
            .where(*filters)
            .options(
                selectinload(FirstArticleRecord.order_process),
                selectinload(FirstArticleRecord.operator),
            )
            .order_by(FirstArticleRecord.created_at.desc(), FirstArticleRecord.id.desc())
        )
        .scalars()
        .all()
    )


def get_quality_overview(
    db: Session,
    *,
    start_date: date | None,
    end_date: date | None,
) -> dict[str, object]:
    rows = _load_first_article_rows(db, start_date=start_date, end_date=end_date)
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
) -> list[dict[str, object]]:
    rows = _load_first_article_rows(db, start_date=start_date, end_date=end_date)
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
) -> list[dict[str, object]]:
    rows = _load_first_article_rows(db, start_date=start_date, end_date=end_date)
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
    }


def export_first_articles_csv(
    db: Session,
    *,
    query_date: date,
    keyword: str | None,
    result_filter: str | None,
) -> dict[str, Any]:
    payload = list_first_articles(
        db,
        query_date=query_date,
        keyword=keyword,
        result_filter=result_filter,
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
) -> list[dict[str, Any]]:
    rows = (
        db.execute(
            select(FirstArticleRecord)
            .where(*_build_created_at_filters(start_date=start_date, end_date=end_date))
            .options(
                selectinload(FirstArticleRecord.order).selectinload(ProductionOrder.product),
            )
        )
        .scalars()
        .all()
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

    # 补充报废和维修数量
    if grouped:
        product_ids = list(grouped.keys())
        scrap_rows = (
            db.execute(
                select(
                    ProductionScrapStatistics.product_id,
                    func.sum(ProductionScrapStatistics.scrap_quantity).label("total"),
                )
                .where(ProductionScrapStatistics.product_id.in_(product_ids))
                .group_by(ProductionScrapStatistics.product_id)
            )
            .all()
        )
        for sr in scrap_rows:
            if sr.product_id in grouped:
                grouped[sr.product_id]["scrap_total"] = int(sr.total or 0)

        repair_rows = (
            db.execute(
                select(
                    RepairOrder.product_id,
                    func.count(RepairOrder.id).label("cnt"),
                )
                .where(RepairOrder.product_id.in_(product_ids))
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
) -> list[dict[str, Any]]:
    resolved_start = start_date or (date.today() - timedelta(days=29))
    resolved_end = end_date or date.today()

    rows = (
        db.execute(
            select(FirstArticleRecord)
            .where(*_build_created_at_filters(start_date=resolved_start, end_date=resolved_end))
        )
        .scalars()
        .all()
    )

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

    # 补充报废数量
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
            .group_by(func.date(ProductionScrapStatistics.last_scrap_time))
        )
        .all()
    )
    for sr in scrap_rows:
        if sr.d and sr.d in grouped:
            grouped[sr.d]["scrap_total"] = int(sr.total or 0)

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
) -> dict[str, Any]:
    overview = get_quality_overview(db, start_date=start_date, end_date=end_date)
    process_stats = get_quality_process_stats(db, start_date=start_date, end_date=end_date)
    operator_stats = get_quality_operator_stats(db, start_date=start_date, end_date=end_date)

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

    csv_bytes = output.getvalue().encode("utf-8-sig")
    content_base64 = base64.b64encode(csv_bytes).decode("ascii")
    filename = f"品质统计_{uuid4().hex[:8]}.csv"
    total_rows = len(process_stats) + len(operator_stats)
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
    existing = (
        db.execute(
            select(FirstArticleDisposition)
            .where(FirstArticleDisposition.first_article_record_id == record_id)
        )
        .scalars()
        .first()
    )
    if existing is not None:
        existing.disposition_opinion = disposition_opinion
        existing.recheck_result = recheck_result
        existing.final_judgment = final_judgment
        existing.disposition_user_id = operator.id
        existing.disposition_username = operator.username
        existing.disposition_at = datetime.now(UTC)
        db.flush()
        return existing

    disposition = FirstArticleDisposition(
        first_article_record_id=record_id,
        disposition_opinion=disposition_opinion,
        recheck_result=recheck_result,
        final_judgment=final_judgment,
        disposition_user_id=operator.id,
        disposition_username=operator.username,
        disposition_at=datetime.now(UTC),
    )
    db.add(disposition)
    db.flush()
    return disposition
