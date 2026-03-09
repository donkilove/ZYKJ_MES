from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.quality import (
    FirstArticleListItem,
    FirstArticleListResult,
    QualityOperatorStatItem,
    QualityOperatorStatsResult,
    QualityProcessStatItem,
    QualityProcessStatsResult,
    QualityStatsOverview,
)
from app.services.quality_service import (
    get_quality_operator_stats,
    get_quality_overview,
    get_quality_process_stats,
    list_first_articles,
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
