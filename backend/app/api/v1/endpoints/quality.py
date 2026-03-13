from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.quality import (
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
    export_first_articles_csv,
    export_quality_stats_csv,
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
    return success_response(FirstArticleDetail(**detail))


@router.get("/stats/overview", response_model=ApiResponse[QualityStatsOverview])
def get_quality_overview_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.overview")),
) -> ApiResponse[QualityStatsOverview]:
    _validate_date_range(start_date, end_date)
    payload = get_quality_overview(
        db,
        start_date=start_date,
        end_date=end_date,
    )
    return success_response(QualityStatsOverview(**payload))


@router.get("/stats/processes", response_model=ApiResponse[QualityProcessStatsResult])
def get_quality_process_stats_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.processes")),
) -> ApiResponse[QualityProcessStatsResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_process_stats(
        db,
        start_date=start_date,
        end_date=end_date,
    )
    return success_response(QualityProcessStatsResult(items=[QualityProcessStatItem(**item) for item in rows]))


@router.get("/stats/operators", response_model=ApiResponse[QualityOperatorStatsResult])
def get_quality_operator_stats_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.operators")),
) -> ApiResponse[QualityOperatorStatsResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_operator_stats(
        db,
        start_date=start_date,
        end_date=end_date,
    )
    return success_response(
        QualityOperatorStatsResult(items=[QualityOperatorStatItem(**item) for item in rows])
    )


@router.get("/stats/products", response_model=ApiResponse[QualityProductStatsResult])
def get_quality_product_stats_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.products")),
) -> ApiResponse[QualityProductStatsResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_product_stats(db, start_date=start_date, end_date=end_date)
    return success_response(QualityProductStatsResult(items=[QualityProductStatItem(**item) for item in rows]))


@router.post("/stats/export", response_model=ApiResponse[QualityStatsExportResult])
def export_quality_stats_api(
    payload: QualityStatsExportRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.stats.export")),
) -> ApiResponse[QualityStatsExportResult]:
    _validate_date_range(payload.start_date, payload.end_date)
    result = export_quality_stats_csv(db, start_date=payload.start_date, end_date=payload.end_date)
    return success_response(QualityStatsExportResult(**result))


@router.get("/trend", response_model=ApiResponse[QualityTrendResult])
def get_quality_trend_api(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("quality.trend")),
) -> ApiResponse[QualityTrendResult]:
    _validate_date_range(start_date, end_date)
    rows = get_quality_trend(db, start_date=start_date, end_date=end_date)
    return success_response(QualityTrendResult(items=[QualityTrendItem(**item) for item in rows]))
