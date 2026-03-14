from datetime import date, datetime

from pydantic import BaseModel, Field, field_validator


class ProcessConfigItem(BaseModel):
    process_code: str = Field(min_length=2, max_length=64)


class OrderProcessStepPayload(BaseModel):
    step_order: int = Field(gt=0)
    stage_id: int = Field(gt=0)
    process_id: int = Field(gt=0)


class OrderCreate(BaseModel):
    order_code: str = Field(min_length=2, max_length=64)
    product_id: int = Field(gt=0)
    quantity: int = Field(gt=0)
    start_date: date | None = None
    due_date: date | None = None
    remark: str | None = Field(default=None, max_length=1024)
    template_id: int | None = Field(default=None, gt=0)
    process_steps: list[OrderProcessStepPayload] | None = None
    process_codes: list[str] = Field(default_factory=list)
    save_as_template: bool = False
    new_template_name: str | None = Field(default=None, max_length=128)
    new_template_set_default: bool = False

    @field_validator("process_codes")
    @classmethod
    def validate_process_codes(cls, value: list[str]) -> list[str]:
        normalized = [item.strip() for item in value if item and item.strip()]
        deduplicated = list(dict.fromkeys(normalized))
        if len(deduplicated) != len(normalized):
            raise ValueError("Process codes cannot contain duplicates")
        return deduplicated

    @field_validator("process_steps")
    @classmethod
    def validate_process_steps(cls, value: list[OrderProcessStepPayload] | None) -> list[OrderProcessStepPayload] | None:
        if value is None:
            return value
        step_orders = [item.step_order for item in value]
        if len(step_orders) != len(set(step_orders)):
            raise ValueError("step_order cannot be duplicated")
        return value


class OrderUpdate(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(gt=0)
    start_date: date | None = None
    due_date: date | None = None
    remark: str | None = Field(default=None, max_length=1024)
    template_id: int | None = Field(default=None, gt=0)
    process_steps: list[OrderProcessStepPayload] | None = None
    process_codes: list[str] = Field(default_factory=list)
    save_as_template: bool = False
    new_template_name: str | None = Field(default=None, max_length=128)
    new_template_set_default: bool = False

    @field_validator("process_codes")
    @classmethod
    def validate_process_codes(cls, value: list[str]) -> list[str]:
        normalized = [item.strip() for item in value if item and item.strip()]
        deduplicated = list(dict.fromkeys(normalized))
        if len(deduplicated) != len(normalized):
            raise ValueError("Process codes cannot contain duplicates")
        return deduplicated

    @field_validator("process_steps")
    @classmethod
    def validate_process_steps(cls, value: list[OrderProcessStepPayload] | None) -> list[OrderProcessStepPayload] | None:
        if value is None:
            return value
        step_orders = [item.step_order for item in value]
        if len(step_orders) != len(set(step_orders)):
            raise ValueError("step_order cannot be duplicated")
        return value


class ProductionOrderProcessItem(BaseModel):
    id: int
    stage_id: int | None = None
    stage_code: str | None = None
    stage_name: str | None = None
    process_code: str
    process_name: str
    process_order: int
    status: str
    visible_quantity: int
    completed_quantity: int
    created_at: datetime
    updated_at: datetime


class ProductionSubOrderItem(BaseModel):
    id: int
    order_process_id: int
    process_code: str
    process_name: str
    operator_user_id: int
    operator_username: str
    assigned_quantity: int
    completed_quantity: int
    status: str
    is_visible: bool
    created_at: datetime
    updated_at: datetime


class ProductionRecordItem(BaseModel):
    id: int
    order_process_id: int
    process_code: str
    process_name: str
    operator_user_id: int
    operator_username: str
    production_quantity: int
    record_type: str
    created_at: datetime


class OrderEventLogItem(BaseModel):
    id: int
    event_type: str
    event_title: str
    event_detail: str | None = None
    operator_user_id: int | None = None
    operator_username: str | None = None
    payload_json: str | None = None
    created_at: datetime


class OrderItem(BaseModel):
    id: int
    order_code: str
    product_id: int
    product_name: str
    product_version: int | None = None
    quantity: int
    status: str
    current_process_code: str | None = None
    current_process_name: str | None = None
    start_date: date | None = None
    due_date: date | None = None
    remark: str | None = None
    process_template_id: int | None = None
    process_template_name: str | None = None
    process_template_version: int | None = None
    pipeline_enabled: bool = False
    pipeline_process_codes: list[str] = Field(default_factory=list)
    created_by_user_id: int | None = None
    created_by_username: str | None = None
    created_at: datetime
    updated_at: datetime


class OrderListResult(BaseModel):
    total: int
    items: list[OrderItem]


class OrderDetail(BaseModel):
    order: OrderItem
    processes: list[ProductionOrderProcessItem]
    sub_orders: list[ProductionSubOrderItem]
    records: list[ProductionRecordItem]
    events: list[OrderEventLogItem]


class OrderActionResult(BaseModel):
    order_id: int
    status: str
    message: str


class OrderPipelineModeItem(BaseModel):
    order_id: int
    enabled: bool
    process_codes: list[str] = Field(default_factory=list)
    available_process_codes: list[str] = Field(default_factory=list)


class OrderPipelineModeUpdateRequest(BaseModel):
    enabled: bool
    process_codes: list[str] = Field(default_factory=list)

    @field_validator("process_codes")
    @classmethod
    def validate_process_codes(cls, value: list[str]) -> list[str]:
        normalized = [item.strip() for item in value if item and item.strip()]
        deduplicated = list(dict.fromkeys(normalized))
        if len(deduplicated) != len(normalized):
            raise ValueError("Process codes cannot contain duplicates")
        return deduplicated


class MyOrderItem(BaseModel):
    order_id: int
    order_code: str
    product_id: int
    product_name: str
    quantity: int
    order_status: str
    current_process_id: int
    current_stage_id: int | None = None
    current_stage_code: str | None = None
    current_stage_name: str | None = None
    current_process_code: str
    current_process_name: str
    current_process_order: int
    process_status: str
    visible_quantity: int
    process_completed_quantity: int
    user_sub_order_id: int | None = None
    user_assigned_quantity: int | None = None
    user_completed_quantity: int | None = None
    operator_user_id: int | None = None
    operator_username: str | None = None
    work_view: str = "own"
    assist_authorization_id: int | None = None
    pipeline_mode_enabled: bool = False
    pipeline_start_allowed: bool = False
    pipeline_end_allowed: bool = False
    max_producible_quantity: int
    can_first_article: bool
    can_end_production: bool
    updated_at: datetime


class MyOrderListResult(BaseModel):
    total: int
    items: list[MyOrderItem]


class MyOrderContextResult(BaseModel):
    found: bool
    item: MyOrderItem | None = None


class FirstArticleRequest(BaseModel):
    order_process_id: int = Field(gt=0)
    verification_code: str = Field(min_length=1, max_length=32)
    remark: str | None = Field(default=None, max_length=1024)
    effective_operator_user_id: int | None = Field(default=None, gt=0)
    assist_authorization_id: int | None = Field(default=None, gt=0)


class ProductionDefectItem(BaseModel):
    phenomenon: str = Field(min_length=1, max_length=128)
    quantity: int = Field(gt=0)


class EndProductionRequest(BaseModel):
    order_process_id: int = Field(gt=0)
    quantity: int = Field(gt=0)
    remark: str | None = Field(default=None, max_length=1024)
    effective_operator_user_id: int | None = Field(default=None, gt=0)
    assist_authorization_id: int | None = Field(default=None, gt=0)
    defect_items: list[ProductionDefectItem] = Field(default_factory=list)


class AssistAuthorizationCreateRequest(BaseModel):
    order_process_id: int = Field(gt=0)
    target_operator_user_id: int = Field(gt=0)
    helper_user_id: int = Field(gt=0)
    reason: str | None = Field(default=None, max_length=1024)


class AssistAuthorizationReviewRequest(BaseModel):
    approve: bool
    review_remark: str | None = Field(default=None, max_length=1024)


class AssistAuthorizationItem(BaseModel):
    id: int
    order_id: int
    order_code: str
    order_process_id: int
    process_code: str
    process_name: str
    target_operator_user_id: int
    target_operator_username: str
    requester_user_id: int
    requester_username: str
    helper_user_id: int
    helper_username: str
    status: str
    reason: str | None = None
    review_remark: str | None = None
    reviewer_user_id: int | None = None
    reviewer_username: str | None = None
    reviewed_at: datetime | None = None
    first_article_used_at: datetime | None = None
    end_production_used_at: datetime | None = None
    consumed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class AssistAuthorizationListResult(BaseModel):
    total: int
    items: list[AssistAuthorizationItem]


class AssistUserOptionItem(BaseModel):
    id: int
    username: str
    full_name: str | None = None
    role_codes: list[str]


class AssistUserOptionListResult(BaseModel):
    total: int
    items: list[AssistUserOptionItem]


class ProductionStatsOverview(BaseModel):
    total_orders: int
    pending_orders: int
    in_progress_orders: int
    completed_orders: int
    total_quantity: int
    finished_quantity: int


class ProductionProcessStatItem(BaseModel):
    process_code: str
    process_name: str
    total_orders: int
    pending_orders: int
    in_progress_orders: int
    partial_orders: int
    completed_orders: int
    total_visible_quantity: int
    total_completed_quantity: int


class ProductionProcessStatsResult(BaseModel):
    items: list[ProductionProcessStatItem]


class ProductionOperatorStatItem(BaseModel):
    operator_user_id: int
    operator_username: str
    process_code: str
    process_name: str
    production_records: int
    production_quantity: int
    last_production_at: datetime | None = None


class ProductionOperatorStatsResult(BaseModel):
    items: list[ProductionOperatorStatItem]


class ProductionDataTodayRealtimeRow(BaseModel):
    product_id: int
    product_name: str
    quantity: int
    latest_time: datetime | None = None
    latest_time_text: str = ""


class ProductionDataTodayRealtimeChartItem(BaseModel):
    label: str
    value: int


class ProductionDataTodayRealtimeSummary(BaseModel):
    total_products: int
    total_quantity: int


class ProductionDataTodayRealtimeResult(BaseModel):
    stat_mode: str
    summary: ProductionDataTodayRealtimeSummary
    table_rows: list[ProductionDataTodayRealtimeRow]
    chart_data: list[ProductionDataTodayRealtimeChartItem]
    query_signature: str


class ProductionDataUnfinishedProgressRow(BaseModel):
    order_id: int
    order_code: str
    product_id: int
    product_name: str
    order_status: str
    process_count: int
    produced_total: int
    target_total: int
    progress_percent: float


class ProductionDataUnfinishedProgressSummary(BaseModel):
    total_orders: int
    avg_progress_percent: float


class ProductionDataUnfinishedProgressResult(BaseModel):
    summary: ProductionDataUnfinishedProgressSummary
    table_rows: list[ProductionDataUnfinishedProgressRow]
    query_signature: str


class ProductionDataManualRow(BaseModel):
    order_id: int
    order_code: str
    product_id: int
    product_name: str
    stage_id: int | None = None
    stage_code: str | None = None
    stage_name: str | None = None
    process_id: int
    process_code: str
    process_name: str
    operator_user_id: int | None = None
    operator_username: str = ""
    quantity: int
    production_time: datetime | None = None
    production_time_text: str = ""
    order_status: str


class ProductionDataManualModelChartItem(BaseModel):
    product_name: str
    quantity: int


class ProductionDataManualTrendChartItem(BaseModel):
    bucket: str
    quantity: int


class ProductionDataManualPieChartItem(BaseModel):
    name: str
    quantity: int


class ProductionDataManualChartData(BaseModel):
    single_day: bool
    model_output: list[ProductionDataManualModelChartItem]
    trend_output: list[ProductionDataManualTrendChartItem]
    pie_output: list[ProductionDataManualPieChartItem]


class ProductionDataManualSummary(BaseModel):
    rows: int
    filtered_total: int
    time_range_total: int
    ratio_percent: float


class ProductionDataManualResult(BaseModel):
    stat_mode: str
    summary: ProductionDataManualSummary
    table_rows: list[ProductionDataManualRow]
    chart_data: ProductionDataManualChartData
    query_signature: str


class ProductionDataManualExportRequest(BaseModel):
    stat_mode: str = Field(default="main_order")
    start_date: date | None = None
    end_date: date | None = None
    product_ids: list[int] = Field(default_factory=list)
    stage_ids: list[int] = Field(default_factory=list)
    process_ids: list[int] = Field(default_factory=list)
    operator_user_ids: list[int] = Field(default_factory=list)
    order_status: str = Field(default="all")

    @field_validator("product_ids", "stage_ids", "process_ids", "operator_user_ids")
    @classmethod
    def validate_positive_unique_ids(cls, value: list[int]) -> list[int]:
        deduped = []
        seen = set()
        for item in value:
            number = int(item)
            if number <= 0:
                raise ValueError("id list items must be > 0")
            if number in seen:
                continue
            seen.add(number)
            deduped.append(number)
        return deduped


class ProductionDataManualExportResult(BaseModel):
    file_name: str
    mime_type: str
    content_base64: str


class RepairOrderCreateRequest(BaseModel):
    order_process_id: int = Field(gt=0)
    production_quantity: int = Field(gt=0)
    defect_items: list[ProductionDefectItem] = Field(default_factory=list)


class RepairCauseItem(BaseModel):
    phenomenon: str = Field(min_length=1, max_length=128)
    reason: str = Field(min_length=1, max_length=128)
    quantity: int = Field(gt=0)
    is_scrap: bool = False


class RepairReturnAllocationItem(BaseModel):
    target_order_process_id: int = Field(gt=0)
    quantity: int = Field(gt=0)


class RepairOrderCompleteRequest(BaseModel):
    cause_items: list[RepairCauseItem] = Field(min_length=1)
    scrap_replenished: bool = False
    return_allocations: list[RepairReturnAllocationItem] = Field(default_factory=list)


class RepairOrderItem(BaseModel):
    id: int
    repair_order_code: str
    source_order_id: int | None = None
    source_order_code: str | None = None
    product_id: int | None = None
    product_name: str | None = None
    source_order_process_id: int | None = None
    source_process_code: str
    source_process_name: str
    sender_user_id: int | None = None
    sender_username: str | None = None
    production_quantity: int
    repair_quantity: int
    repaired_quantity: int
    scrap_quantity: int
    scrap_replenished: bool
    repair_time: datetime
    status: str
    completed_at: datetime | None = None
    repair_operator_user_id: int | None = None
    repair_operator_username: str | None = None
    created_at: datetime
    updated_at: datetime


class RepairOrderListResult(BaseModel):
    total: int
    items: list[RepairOrderItem]


class RepairOrderPhenomenonSummaryItem(BaseModel):
    phenomenon: str
    quantity: int


class RepairOrderPhenomenaSummaryResult(BaseModel):
    repair_order_id: int
    items: list[RepairOrderPhenomenonSummaryItem]


class ScrapStatisticsItem(BaseModel):
    id: int
    order_id: int | None = None
    order_code: str | None = None
    product_id: int | None = None
    product_name: str | None = None
    process_id: int | None = None
    process_code: str | None = None
    process_name: str | None = None
    scrap_reason: str
    scrap_quantity: int
    last_scrap_time: datetime | None = None
    progress: str
    applied_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class ScrapStatisticsListResult(BaseModel):
    total: int
    items: list[ScrapStatisticsItem]


class ScrapStatisticsExportRequest(BaseModel):
    keyword: str | None = Field(default=None, max_length=128)
    progress: str | None = Field(default="all", max_length=32)
    start_date: date | None = None
    end_date: date | None = None


class RepairOrdersExportRequest(BaseModel):
    keyword: str | None = Field(default=None, max_length=128)
    status: str | None = Field(default="all", max_length=32)
    start_date: date | None = None
    end_date: date | None = None


class ProductionExportResult(BaseModel):
    file_name: str
    mime_type: str
    content_base64: str
    exported_count: int = 0


class RepairCauseItemDetail(BaseModel):
    phenomenon: str
    reason: str
    quantity: int
    is_scrap: bool


class RepairReturnRouteDetail(BaseModel):
    target_order_process_id: int | None = None
    target_process_code: str
    target_process_name: str
    quantity: int


class RepairOrderDetail(BaseModel):
    id: int
    repair_order_code: str
    source_order_id: int | None = None
    source_order_code: str | None = None
    product_id: int | None = None
    product_name: str | None = None
    source_order_process_id: int | None = None
    source_process_code: str
    source_process_name: str
    sender_user_id: int | None = None
    sender_username: str | None = None
    production_quantity: int
    repair_quantity: int
    repaired_quantity: int
    scrap_quantity: int
    scrap_replenished: bool
    repair_time: datetime
    status: str
    completed_at: datetime | None = None
    repair_operator_user_id: int | None = None
    repair_operator_username: str | None = None
    created_at: datetime
    updated_at: datetime
    cause_items: list[RepairCauseItemDetail] = []
    return_routes: list[RepairReturnRouteDetail] = []


class OrdersExportRequest(BaseModel):
    keyword: str | None = Field(default=None, max_length=128)
    status: str | None = Field(default=None, max_length=32)
    product_name: str | None = Field(default=None, max_length=128)
    pipeline_enabled: bool | None = None
    start_date_from: date | None = None
    start_date_to: date | None = None
    due_date_from: date | None = None
    due_date_to: date | None = None


class PipelineInstanceItem(BaseModel):
    id: int
    sub_order_id: int
    order_id: int
    order_process_id: int
    process_code: str
    pipeline_seq: int
    pipeline_sub_order_no: str
    is_active: bool
    invalid_reason: str | None = None
    invalidated_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class PipelineInstanceListResult(BaseModel):
    total: int
    items: list[PipelineInstanceItem]


class ScrapRelatedRepairItem(BaseModel):
    """报废详情中关联的维修单摘要"""
    id: int
    repair_order_code: str
    status: str
    repair_quantity: int
    repaired_quantity: int
    scrap_quantity: int
    repair_time: datetime
    completed_at: datetime | None = None


class ScrapStatisticsDetailItem(BaseModel):
    id: int
    order_id: int | None = None
    order_code: str | None = None
    product_id: int | None = None
    product_name: str | None = None
    process_id: int | None = None
    process_code: str | None = None
    process_name: str | None = None
    scrap_reason: str
    scrap_quantity: int
    last_scrap_time: datetime | None = None
    progress: str
    applied_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    related_repair_orders: list[ScrapRelatedRepairItem] = Field(default_factory=list)


class RepairDefectPhenomenonItem(BaseModel):
    id: int
    phenomenon: str
    quantity: int


class RepairCauseDetailItem(BaseModel):
    id: int
    phenomenon: str
    reason: str
    quantity: int
    is_scrap: bool


class RepairReturnRouteItem(BaseModel):
    id: int
    target_process_id: int | None = None
    target_process_code: str
    target_process_name: str
    return_quantity: int


class RepairEventLogItem(BaseModel):
    """维修详情中关联的订单事件日志摘要"""
    id: int
    event_type: str
    event_title: str
    event_detail: str | None = None
    created_at: datetime


class RepairOrderDetailItem(BaseModel):
    id: int
    repair_order_code: str
    source_order_id: int | None = None
    source_order_code: str | None = None
    product_id: int | None = None
    product_name: str | None = None
    source_order_process_id: int | None = None
    source_process_code: str
    source_process_name: str
    sender_user_id: int | None = None
    sender_username: str | None = None
    production_quantity: int
    repair_quantity: int
    repaired_quantity: int
    scrap_quantity: int
    scrap_replenished: bool
    repair_time: datetime
    status: str
    completed_at: datetime | None = None
    repair_operator_user_id: int | None = None
    repair_operator_username: str | None = None
    defect_rows: list[RepairDefectPhenomenonItem] = Field(default_factory=list)
    cause_rows: list[RepairCauseDetailItem] = Field(default_factory=list)
    return_routes: list[RepairReturnRouteItem] = Field(default_factory=list)
    event_logs: list[RepairEventLogItem] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime
