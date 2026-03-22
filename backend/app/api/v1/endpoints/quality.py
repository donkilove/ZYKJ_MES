from __future__ import annotations

import json
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.production import (
    RepairOrderDetailItem,
    RepairOrderItem,
    RepairOrderListResult,
    RepairEventLogItem,
    RepairCauseDetailItem,
    RepairDefectPhenomenonItem,
    RepairReturnRouteItem,
    ScrapEventLogItem,
    ScrapRelatedRepairItem,
    ScrapStatisticsDetailItem,
    ScrapStatisticsItem,
    ScrapStatisticsListResult,
)
from app.services.audit_service import write_audit_log
from app.services.message_service import create_message_for_users
from app.schemas.quality import (
    DefectAnalysisExportResult,
    DefectAnalysisResult,
    FirstArticleDetail,
    FirstArticleDispositionRequest,
    FirstArticleExportRequest,
    FirstArticleExportResult,
    FirstArticleListItem,
    FirstArticleListResult,
    QualityOperatorStatItem,
    QualityOperatorStatsResult,
    QualityProcessStatItem,
    QualityProcessStatsResult,
    QualityProductStatItem,
    QualityProductStatsResult,
    QualityStatsExportRequest,
    QualityStatsExportResult,
    QualityStatsOverview,
    QualityTrendItem,
    QualityTrendResult,
)
from app.services.quality_service import (
    export_defect_analysis_csv,
    export_first_articles_csv,
    export_quality_stats_csv,
    get_defect_analysis,
    get_first_article_by_id,
    get_quality_operator_stats,
    get_quality_overview,
    get_quality_process_stats,
    get_quality_product_stats,
    get_quality_trend,
    list_first_articles,
    submit_first_article_disposition,
)
from app.services.production_repair_service import (
    RepairListFilters,
    ScrapStatisticsFilters,
    get_repair_order_by_id,
    list_repair_orders,
    list_scrap_statistics,
)
from app.models.order_event_log import OrderEventLog
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.repair_order import RepairOrder


router = APIRouter()


def _to_quality_repair_order_item(row: RepairOrder) -> RepairOrderItem:
    return RepairOrderItem(
        id=row.id,
        repair_order_code=row.repair_order_code,
        source_order_id=row.source_order_id,
        source_order_code=row.source_order_code,
        product_id=row.product_id,
        product_name=row.product_name,
        source_order_process_id=row.source_order_process_id,
        source_process_code=row.source_process_code,
        source_process_name=row.source_process_name,
        sender_user_id=row.sender_user_id,
        sender_username=row.sender_username,
        production_quantity=row.production_quantity,
        repair_quantity=row.repair_quantity,
        repaired_quantity=row.repaired_quantity,
        scrap_quantity=row.scrap_quantity,
        scrap_replenished=row.scrap_replenished,
        repair_time=row.repair_time,
        status=row.status,
        completed_at=row.completed_at,
        repair_operator_user_id=row.repair_operator_user_id,
        repair_operator_username=row.repair_operator_username,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_quality_scrap_statistics_item(
    row: ProductionScrapStatistics,
) -> ScrapStatisticsItem:
    return ScrapStatisticsItem(
        id=row.id,
        order_id=row.order_id,
        order_code=row.order_code,
        product_id=row.product_id,
        product_name=row.product_name,
        process_id=row.process_id,
        process_code=row.process_code,
        process_name=row.process_name,
        scrap_reason=row.scrap_reason,
        scrap_quantity=row.scrap_quantity,
        last_scrap_time=row.last_scrap_time,
        progress=row.progress,
        applied_at=row.applied_at,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_quality_repair_order_detail_item(
    row: RepairOrder,
    *,
    event_logs: list[OrderEventLog] | None = None,
) -> RepairOrderDetailItem:
    return RepairOrderDetailItem(
        id=row.id,
        repair_order_code=row.repair_order_code,
        source_order_id=row.source_order_id,
        source_order_code=row.source_order_code,
        product_id=row.product_id,
        product_name=row.product_name,
        source_order_process_id=row.source_order_process_id,
        source_process_code=row.source_process_code,
        source_process_name=row.source_process_name,
        sender_user_id=row.sender_user_id,
        sender_username=row.sender_username,
        production_quantity=row.production_quantity,
        repair_quantity=row.repair_quantity,
        repaired_quantity=row.repaired_quantity,
        scrap_quantity=row.scrap_quantity,
        scrap_replenished=row.scrap_replenished,
        repair_time=row.repair_time,
        status=row.status,
        completed_at=row.completed_at,
        repair_operator_user_id=row.repair_operator_user_id,
        repair_operator_username=row.repair_operator_username,
        defect_rows=[
            RepairDefectPhenomenonItem(
                id=item.id,
                phenomenon=item.phenomenon,
                quantity=item.quantity,
            )
            for item in (row.defect_rows or [])
        ],
        cause_rows=[
            RepairCauseDetailItem(
                id=item.id,
                phenomenon=item.phenomenon,
                reason=item.reason,
                quantity=item.quantity,
                is_scrap=item.is_scrap,
            )
            for item in (row.cause_rows or [])
        ],
        return_routes=[
            RepairReturnRouteItem(
                id=item.id,
                target_process_id=item.target_process_id,
                target_process_code=item.target_process_code,
                target_process_name=item.target_process_name,
                return_quantity=item.return_quantity,
            )
            for item in (row.return_routes or [])
        ],
        event_logs=[
            RepairEventLogItem(
                id=item.id,
                order_code=item.order_code_snapshot,
                order_status=item.order_status_snapshot,
                product_name=item.product_name_snapshot,
                process_code=item.process_code_snapshot,
                event_type=item.event_type,
                event_title=item.event_title,
                event_detail=item.event_detail,
                payload_json=item.payload_json,
                created_at=item.created_at,
            )
            for item in (event_logs or [])
        ],
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _validate_date_range(start_date: date | None, end_date: date | None) -> None:
    if start_date is not None and end_date is not None and start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date cannot be greater than end_date",
        )


@router.get("/first-articles", response_model=ApiResponse[FirstArticleListResult])
def get_first_articles_api(
    query_date: date | None = Query(default=None, alias="date"),
    keyword: str | None = Query(default=None),
    result: str | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.first_articles.list")),
) -> ApiResponse[FirstArticleListResult]:
    target_date = query_date or date.today()
    payload = list_first_articles(
        db,
        query_date=target_date,
        keyword=keyword,
        result_filter=result,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        page=page,
        page_size=page_size,
    )
    return success_response(
        FirstArticleListResult(
            query_date=payload["query_date"],
            verification_code=payload["verification_code"],
            verification_code_source=payload["verification_code_source"],
            total=payload["total"],
            items=[FirstArticleListItem(**item) for item in payload["items"]],
        )
    )


@router.get(
    "/first-articles/{record_id}", response_model=ApiResponse[FirstArticleDetail]
)
def get_first_article_detail_api(
    record_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.first_articles.detail")),
) -> ApiResponse[FirstArticleDetail]:
    detail = get_first_article_by_id(db, record_id=record_id)
    if detail is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="首件记录不存在"
        )
    return success_response(FirstArticleDetail(**detail))


@router.get(
    "/first-articles/{record_id}/disposition-detail",
    response_model=ApiResponse[FirstArticleDetail],
)
def get_first_article_disposition_detail_api(
    record_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.first_articles.disposition")),
) -> ApiResponse[FirstArticleDetail]:
    detail = get_first_article_by_id(db, record_id=record_id)
    if detail is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="首件记录不存在"
        )
    return success_response(FirstArticleDetail(**detail))


@router.post(
    "/first-articles/export", response_model=ApiResponse[FirstArticleExportResult]
)
def export_first_articles_api(
    payload: FirstArticleExportRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.first_articles.export")),
) -> ApiResponse[FirstArticleExportResult]:
    result = export_first_articles_csv(
        db,
        query_date=payload.query_date or date.today(),
        keyword=payload.keyword,
        result_filter=payload.result,
        product_name=payload.product_name,
        process_code=payload.process_code,
        operator_username=payload.operator_username,
    )
    return success_response(FirstArticleExportResult(**result))


@router.post(
    "/first-articles/{record_id}/disposition",
    response_model=ApiResponse[FirstArticleDetail],
)
def submit_disposition_api(
    record_id: int,
    payload: FirstArticleDispositionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("quality.first_articles.disposition")
    ),
) -> ApiResponse[FirstArticleDetail]:
    try:
        submit_first_article_disposition(
            db,
            record_id=record_id,
            disposition_opinion=payload.disposition_opinion,
            recheck_result=payload.recheck_result,
            final_judgment=payload.final_judgment,
            operator=current_user,
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    detail = get_first_article_by_id(db, record_id=record_id)
    if detail is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="首件记录不存在"
        )

    _judgment_label = {
        "accept": "接受",
        "reject": "拒绝",
        "rework": "返工",
        "scrap": "报废",
    }.get(payload.final_judgment, payload.final_judgment)
    write_audit_log(
        db,
        action_code="quality.first_article.disposition",
        action_name="首件处置",
        target_type="first_article_record",
        target_id=str(record_id),
        target_name=f"{detail.get('order_code', '')} / {detail.get('process_name', '')}",
        operator=current_user,
        after_data={
            "final_judgment": payload.final_judgment,
            "final_judgment_label": _judgment_label,
            "disposition_opinion": payload.disposition_opinion,
            "recheck_result": payload.recheck_result,
        },
    )
    db.commit()

    if payload.final_judgment != "accept":
        operator_user_id = detail.get("operator_user_id")
        if operator_user_id and operator_user_id != current_user.id:
            create_message_for_users(
                db,
                message_type="notice",
                priority="normal",
                title=f"首件处置结果：{_judgment_label} — {detail.get('order_code', '')} / {detail.get('process_name', '')}",
                summary=f"{current_user.username} 处置意见：{payload.disposition_opinion or ''}，最终判定：{_judgment_label}",
                source_module="quality",
                source_type="first_article_record",
                source_id=str(record_id),
                source_code=detail.get("order_code"),
                target_page_code="quality",
                target_tab_code="first_article_management",
                target_route_payload_json=json.dumps(
                    {"action": "detail", "record_id": record_id},
                    ensure_ascii=False,
                ),
                recipient_user_ids=[operator_user_id],
                dedupe_key=f"first_article_disposition_{record_id}_{payload.final_judgment}",
                created_by_user_id=current_user.id,
            )

    return success_response(FirstArticleDetail(**detail))


@router.get("/stats/overview", response_model=ApiResponse[QualityStatsOverview])
def get_quality_overview_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    result: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.overview")),
) -> ApiResponse[QualityStatsOverview]:
    _validate_date_range(start_date, end_date)
    payload = get_quality_overview(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result,
    )
    return success_response(QualityStatsOverview(**payload))


@router.get("/stats/processes", response_model=ApiResponse[QualityProcessStatsResult])
def get_quality_process_stats_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    result: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.processes")),
) -> ApiResponse[QualityProcessStatsResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_process_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result,
    )
    return success_response(
        QualityProcessStatsResult(
            items=[QualityProcessStatItem(**item) for item in rows]
        )
    )


@router.get("/stats/operators", response_model=ApiResponse[QualityOperatorStatsResult])
def get_quality_operator_stats_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    result: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.operators")),
) -> ApiResponse[QualityOperatorStatsResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_operator_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result,
    )
    return success_response(
        QualityOperatorStatsResult(
            items=[QualityOperatorStatItem(**item) for item in rows]
        )
    )


@router.get("/stats/products", response_model=ApiResponse[QualityProductStatsResult])
def get_quality_product_stats_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    result: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.products")),
) -> ApiResponse[QualityProductStatsResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_product_stats(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result,
    )
    return success_response(
        QualityProductStatsResult(
            items=[QualityProductStatItem(**item) for item in rows]
        )
    )


@router.post("/stats/export", response_model=ApiResponse[QualityStatsExportResult])
def export_quality_stats_api(
    payload: QualityStatsExportRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.export")),
) -> ApiResponse[QualityStatsExportResult]:
    _validate_date_range(payload.start_date, payload.end_date)
    result = export_quality_stats_csv(
        db,
        start_date=payload.start_date,
        end_date=payload.end_date,
        product_name=payload.product_name,
        process_code=payload.process_code,
        operator_username=payload.operator_username,
        result_filter=payload.result,
    )
    return success_response(QualityStatsExportResult(**result))


@router.get("/trend", response_model=ApiResponse[QualityTrendResult])
def get_quality_trend_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    result: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.trend")),
) -> ApiResponse[QualityTrendResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_trend(
        db,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        result_filter=result,
    )
    return success_response(
        QualityTrendResult(items=[QualityTrendItem(**item) for item in rows])
    )


@router.post("/trend/export", response_model=ApiResponse[QualityStatsExportResult])
def export_quality_trend_api(
    payload: QualityStatsExportRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.trend")),
) -> ApiResponse[QualityStatsExportResult]:
    _validate_date_range(payload.start_date, payload.end_date)
    rows = get_quality_trend(
        db,
        start_date=payload.start_date,
        end_date=payload.end_date,
        product_name=payload.product_name,
        process_code=payload.process_code,
        operator_username=payload.operator_username,
        result_filter=payload.result,
    )
    import base64, csv, io

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "日期",
            "首件总数",
            "通过数",
            "不通过数",
            "通过率",
            "不良数",
            "报废数",
            "维修数",
        ]
    )
    for item in rows:
        writer.writerow(
            [
                item["stat_date"],
                item["first_article_total"],
                item["passed_total"],
                item["failed_total"],
                item["pass_rate_percent"],
                item.get("defect_total", 0),
                item["scrap_total"],
                item["repair_total"],
            ]
        )
    csv_bytes = output.getvalue().encode("utf-8-sig")
    return success_response(
        QualityStatsExportResult(
            filename="quality_trend.csv",
            content_base64=base64.b64encode(csv_bytes).decode("ascii"),
            total_rows=len(rows),
        )
    )


@router.get("/scrap-statistics", response_model=ApiResponse[ScrapStatisticsListResult])
def get_quality_scrap_statistics_api(
    keyword: str | None = Query(default=None),
    progress: str | None = Query(default="all"),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.scrap_statistics.list")),
) -> ApiResponse[ScrapStatisticsListResult]:
    _validate_date_range(start_date, end_date)
    total, rows = list_scrap_statistics(
        db,
        page=page,
        page_size=page_size,
        filters=ScrapStatisticsFilters(
            keyword=keyword,
            progress=progress,
            product_name=product_name,
            process_code=process_code,
            start_date=start_date,
            end_date=end_date,
        ),
    )
    return success_response(
        ScrapStatisticsListResult(
            total=total,
            items=[_to_quality_scrap_statistics_item(row) for row in rows],
        )
    )


@router.get(
    "/scrap-statistics/{scrap_id}",
    response_model=ApiResponse[ScrapStatisticsDetailItem],
)
def get_quality_scrap_statistics_detail_api(
    scrap_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.scrap_statistics.detail")),
) -> ApiResponse[ScrapStatisticsDetailItem]:
    row = (
        db.execute(
            select(ProductionScrapStatistics).where(
                ProductionScrapStatistics.id == scrap_id
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scrap statistics not found",
        )

    related_repairs: list[ScrapRelatedRepairItem] = []
    if row.order_id is not None:
        repair_filters = [RepairOrder.source_order_id == row.order_id]
        if row.process_id is not None:
            repair_filters.append(RepairOrder.source_order_process_id == row.process_id)
        repair_rows = (
            db.execute(
                select(RepairOrder)
                .where(*repair_filters)
                .order_by(RepairOrder.repair_time.desc())
            )
            .scalars()
            .all()
        )
        related_repairs = [
            ScrapRelatedRepairItem(
                id=item.id,
                repair_order_code=item.repair_order_code,
                status=item.status,
                repair_quantity=item.repair_quantity,
                repaired_quantity=item.repaired_quantity,
                scrap_quantity=item.scrap_quantity,
                repair_time=item.repair_time,
                completed_at=item.completed_at,
            )
            for item in repair_rows
        ]

    related_logs: list[ScrapEventLogItem] = []
    if row.order_id is not None:
        log_rows = [
            item
            for item in db.execute(
                select(OrderEventLog)
                .where(OrderEventLog.order_id == row.order_id)
                .order_by(OrderEventLog.created_at.desc())
                .limit(100)
            )
            .scalars()
            .all()
            if (
                item.process_code_snapshot == row.process_code
                or item.event_type == "scrap_statistics_export"
            )
        ]
        related_logs = [
            ScrapEventLogItem(
                id=item.id,
                order_code=item.order_code_snapshot,
                order_status=item.order_status_snapshot,
                product_name=item.product_name_snapshot,
                process_code=item.process_code_snapshot,
                event_type=item.event_type,
                event_title=item.event_title,
                event_detail=item.event_detail,
                payload_json=item.payload_json,
                created_at=item.created_at,
            )
            for item in log_rows
        ]

    return success_response(
        ScrapStatisticsDetailItem(
            id=row.id,
            order_id=row.order_id,
            order_code=row.order_code,
            product_id=row.product_id,
            product_name=row.product_name,
            process_id=row.process_id,
            process_code=row.process_code,
            process_name=row.process_name,
            scrap_reason=row.scrap_reason,
            scrap_quantity=row.scrap_quantity,
            last_scrap_time=row.last_scrap_time,
            progress=row.progress,
            applied_at=row.applied_at,
            created_at=row.created_at,
            updated_at=row.updated_at,
            related_repair_orders=related_repairs,
            related_event_logs=related_logs,
        )
    )


@router.get("/repair-orders", response_model=ApiResponse[RepairOrderListResult])
def get_quality_repair_orders_api(
    keyword: str | None = Query(default=None),
    status_text: str | None = Query(default="all", alias="status"),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.repair_orders.list")),
) -> ApiResponse[RepairOrderListResult]:
    _validate_date_range(start_date, end_date)
    total, rows = list_repair_orders(
        db,
        page=page,
        page_size=page_size,
        filters=RepairListFilters(
            keyword=keyword,
            status=status_text,
            start_date=start_date,
            end_date=end_date,
        ),
    )
    return success_response(
        RepairOrderListResult(
            total=total,
            items=[_to_quality_repair_order_item(row) for row in rows],
        )
    )


@router.get(
    "/repair-orders/{repair_order_id}/detail",
    response_model=ApiResponse[RepairOrderDetailItem],
)
def get_quality_repair_order_detail_api(
    repair_order_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.repair_orders.detail")),
) -> ApiResponse[RepairOrderDetailItem]:
    row = get_repair_order_by_id(db, repair_order_id=repair_order_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Repair order not found",
        )

    event_logs: list[OrderEventLog] = []
    if row.source_order_id is not None:
        event_logs = [
            item
            for item in db.execute(
                select(OrderEventLog)
                .where(OrderEventLog.order_id == row.source_order_id)
                .order_by(OrderEventLog.created_at.desc())
                .limit(100)
            )
            .scalars()
            .all()
            if (
                item.process_code_snapshot == row.source_process_code
                or (
                    item.payload_json
                    and f'"repair_order_id":{row.id}' in item.payload_json
                )
            )
        ]

    return success_response(
        _to_quality_repair_order_detail_item(row, event_logs=event_logs)
    )


@router.get("/defect-analysis", response_model=ApiResponse[DefectAnalysisResult])
def get_defect_analysis_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_id: int | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    phenomenon: str | None = Query(default=None),
    top_n: int = Query(default=10, ge=1, le=50),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.defect_analysis.list")),
) -> ApiResponse[DefectAnalysisResult]:
    _validate_date_range(start_date, end_date)
    result = get_defect_analysis(
        db,
        start_date=start_date,
        end_date=end_date,
        product_id=product_id,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        phenomenon=phenomenon,
        top_n=top_n,
    )
    return success_response(result)


@router.post(
    "/defect-analysis/export", response_model=ApiResponse[DefectAnalysisExportResult]
)
def export_defect_analysis_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_id: int | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    phenomenon: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.defect_analysis.export")),
) -> ApiResponse[DefectAnalysisExportResult]:
    _validate_date_range(start_date, end_date)
    result = export_defect_analysis_csv(
        db,
        start_date=start_date,
        end_date=end_date,
        product_id=product_id,
        product_name=product_name,
        process_code=process_code,
        operator_username=operator_username,
        phenomenon=phenomenon,
    )
    return success_response(result)
