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
    verification_code: str | None = None
    remark: str | None = None
    created_at: datetime


class FirstArticleListResult(BaseModel):
    query_date: date
    verification_code: str | None = None
    verification_code_source: str
    total: int
    items: list[FirstArticleListItem]


class FirstArticleDetail(BaseModel):
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
    verification_code: str | None = None
    remark: str | None = None
    created_at: datetime
    # 处置信息（如有）
    disposition_id: int | None = None
    disposition_opinion: str | None = None
    disposition_username: str | None = None
    disposition_at: datetime | None = None
    recheck_result: str | None = None
    final_judgment: str | None = None


class FirstArticleExportRequest(BaseModel):
    query_date: date | None = None
    keyword: str | None = None
    result: str | None = None
    product_name: str | None = None
    process_code: str | None = None
    operator_username: str | None = None


class FirstArticleExportResult(BaseModel):
    filename: str
    content_base64: str
    total_rows: int


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


class QualityProductStatItem(BaseModel):
    product_id: int
    product_name: str
    first_article_total: int
    passed_total: int
    failed_total: int
    pass_rate_percent: float
    scrap_total: int
    repair_order_count: int


class QualityProductStatsResult(BaseModel):
    items: list[QualityProductStatItem]


class QualityTrendItem(BaseModel):
    stat_date: date
    first_article_total: int
    passed_total: int
    failed_total: int
    pass_rate_percent: float
    scrap_total: int
    repair_total: int = 0


class QualityTrendResult(BaseModel):
    items: list[QualityTrendItem]


class QualityStatsExportRequest(BaseModel):
    start_date: date | None = None
    end_date: date | None = None
    product_name: str | None = None
    process_code: str | None = None
    operator_username: str | None = None
    result: str | None = None


class QualityStatsExportResult(BaseModel):
    filename: str
    content_base64: str
    total_rows: int


class FirstArticleDispositionRequest(BaseModel):
    disposition_opinion: str
    recheck_result: str | None = None
    final_judgment: str


class DefectTopItem(BaseModel):
    phenomenon: str
    quantity: int
    ratio: float


class DefectByProcessItem(BaseModel):
    process_code: str
    process_name: str | None
    quantity: int


class DefectByProductItem(BaseModel):
    product_id: int | None
    product_name: str | None
    quantity: int


class DefectAnalysisResult(BaseModel):
    total_defect_quantity: int
    top_defects: list[DefectTopItem]
    by_process: list[DefectByProcessItem]
    by_product: list[DefectByProductItem]


class DefectAnalysisExportResult(BaseModel):
    filename: str
    content_base64: str
    total_rows: int
