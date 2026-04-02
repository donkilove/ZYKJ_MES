from datetime import date, datetime

from pydantic import BaseModel, Field


class SupplierBase(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    remark: str | None = Field(default=None, max_length=1024)
    is_enabled: bool = True


class SupplierCreate(SupplierBase):
    pass


class SupplierUpdate(SupplierBase):
    pass


class SupplierItem(BaseModel):
    id: int
    name: str
    remark: str | None = None
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class SupplierListResult(BaseModel):
    total: int
    items: list[SupplierItem]


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
    disposition_history: list["FirstArticleDispositionHistoryItem"] = []


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
    defect_total: int = 0
    scrap_total: int = 0
    repair_total: int = 0
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
    defect_total: int = 0
    scrap_total: int = 0
    repair_total: int = 0
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
    defect_total: int = 0
    scrap_total: int = 0
    repair_total: int = 0
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
    defect_total: int = 0
    scrap_total: int = 0
    repair_total: int = 0


class QualityProductStatsResult(BaseModel):
    items: list[QualityProductStatItem]


class QualityTrendItem(BaseModel):
    stat_date: date
    first_article_total: int
    passed_total: int
    failed_total: int
    pass_rate_percent: float
    defect_total: int = 0
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
    disposition_opinion: str = Field(min_length=1)
    recheck_result: str | None = None
    final_judgment: str


class FirstArticleDispositionHistoryItem(BaseModel):
    id: int
    version: int
    disposition_opinion: str
    disposition_username: str | None = None
    disposition_at: datetime | None = None
    recheck_result: str | None = None
    final_judgment: str


class DefectTopItem(BaseModel):
    phenomenon: str
    quantity: int
    ratio: float


class DefectReasonItem(BaseModel):
    reason: str
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


class DefectByOperatorItem(BaseModel):
    operator_user_id: int | None
    operator_username: str | None
    quantity: int


class DefectByDateItem(BaseModel):
    stat_date: date
    quantity: int


class DefectAnalysisResult(BaseModel):
    total_defect_quantity: int
    top_defects: list[DefectTopItem]
    top_reasons: list[DefectReasonItem]
    product_quality_comparison: list[QualityProductStatItem]
    by_process: list[DefectByProcessItem]
    by_product: list[DefectByProductItem]
    by_operator: list[DefectByOperatorItem]
    by_date: list[DefectByDateItem]


class DefectAnalysisExportResult(BaseModel):
    filename: str
    content_base64: str
    total_rows: int
