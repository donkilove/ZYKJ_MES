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
    max_producible_quantity: int
    can_first_article: bool
    can_end_production: bool
    updated_at: datetime


class MyOrderListResult(BaseModel):
    total: int
    items: list[MyOrderItem]


class FirstArticleRequest(BaseModel):
    order_process_id: int = Field(gt=0)
    verification_code: str = Field(min_length=1, max_length=32)
    remark: str | None = Field(default=None, max_length=1024)


class EndProductionRequest(BaseModel):
    order_process_id: int = Field(gt=0)
    quantity: int = Field(gt=0)
    remark: str | None = Field(default=None, max_length=1024)


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
