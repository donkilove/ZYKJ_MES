from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
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


router = APIRouter()


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


@router.get("/first-articles/{record_id}", response_model=ApiResponse[FirstArticleDetail])
def get_first_article_detail_api(
    record_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.first_articles.detail")),
) -> ApiResponse[FirstArticleDetail]:
    detail = get_first_article_by_id(db, record_id=record_id)
    if detail is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="首件记录不存在")
    return success_response(FirstArticleDetail(**detail))


@router.post("/first-articles/export", response_model=ApiResponse[FirstArticleExportResult])
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


@router.post("/first-articles/{record_id}/disposition", response_model=ApiResponse[FirstArticleDetail])
def submit_disposition_api(
    record_id: int,
    payload: FirstArticleDispositionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("quality.first_articles.disposition")),
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
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    detail = get_first_article_by_id(db, record_id=record_id)
    if detail is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="首件记录不存在")

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
    return success_response(QualityProcessStatsResult(items=[QualityProcessStatItem(**item) for item in rows]))


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
        QualityOperatorStatsResult(items=[QualityOperatorStatItem(**item) for item in rows])
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
    return success_response(QualityProductStatsResult(items=[QualityProductStatItem(**item) for item in rows]))


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
    )
    return success_response(QualityTrendResult(items=[QualityTrendItem(**item) for item in rows]))


@router.get("/defect-analysis", response_model=ApiResponse[DefectAnalysisResult])
def get_defect_analysis_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_id: int | None = Query(default=None),
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
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
        top_n=top_n,
    )
    return success_response(result)


@router.post("/defect-analysis/export", response_model=ApiResponse[DefectAnalysisExportResult])
def export_defect_analysis_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_id: int | None = Query(default=None),
    process_code: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.defect_analysis.export")),
) -> ApiResponse[DefectAnalysisExportResult]:
    _validate_date_range(start_date, end_date)
    result = export_defect_analysis_csv(
        db,
        start_date=start_date,
        end_date=end_date,
        product_id=product_id,
        process_code=process_code,
    )
    return success_response(result)
