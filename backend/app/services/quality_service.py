from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, time, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.models.daily_verification_code import DailyVerificationCode
from app.models.first_article_record import FirstArticleRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.product import Product
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
