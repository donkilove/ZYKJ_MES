from datetime import date, datetime

from pydantic import BaseModel


class FirstArticleListItem(BaseModel):
    id: int
    order_id: int
    order_code: str
    product_id: int
    product_name: str
    order_process_id: int
    process_code: str
    process_name: str
    operator_user_id: int
    operator_username: str
    result: str
    verification_date: date
    remark: str | None = None
    created_at: datetime


class FirstArticleListResult(BaseModel):
    query_date: date
    verification_code: str | None = None
    verification_code_source: str
    total: int
    items: list[FirstArticleListItem]


class QualityStatsOverview(BaseModel):
    first_article_total: int
    passed_total: int
    failed_total: int
    pass_rate_percent: float
    covered_order_count: int
    covered_process_count: int
    covered_operator_count: int
    latest_first_article_at: datetime | None = None


class QualityProcessStatItem(BaseModel):
    process_code: str
    process_name: str
    first_article_total: int
    passed_total: int
    failed_total: int
    pass_rate_percent: float
    latest_first_article_at: datetime | None = None


class QualityProcessStatsResult(BaseModel):
    items: list[QualityProcessStatItem]


class QualityOperatorStatItem(BaseModel):
    operator_user_id: int
    operator_username: str
    first_article_total: int
    passed_total: int
    failed_total: int
    pass_rate_percent: float
    latest_first_article_at: datetime | None = None


class QualityOperatorStatsResult(BaseModel):
    items: list[QualityOperatorStatItem]
