from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field


WorkOrderStatus = Literal["pending", "in_progress", "done", "overdue", "cancelled"]


class EquipmentLedgerUpsertRequest(BaseModel):
    code: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    model: str = Field(default="", min_length=0, max_length=128)
    location: str = Field(min_length=1, max_length=255)
    owner_name: str = Field(default="", min_length=0, max_length=64)
    remark: str = Field(default="", max_length=1024)


class EquipmentLedgerItem(BaseModel):
    id: int
    code: str
    name: str
    model: str
    location: str
    owner_name: str
    remark: str
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class EquipmentLedgerListResult(BaseModel):
    total: int
    items: list[EquipmentLedgerItem]


class EquipmentOwnerOption(BaseModel):
    id: int
    username: str
    full_name: str | None = None


class EquipmentOwnerOptionListResult(BaseModel):
    total: int
    items: list[EquipmentOwnerOption]


class MaintenanceItemUpsertRequest(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    default_cycle_days: int = Field(ge=1, le=3650)
    category: str = Field(default="", max_length=64)
    default_duration_minutes: int | None = Field(default=None, ge=1, le=1440)
    standard_description: str = Field(default="", max_length=1024)


class MaintenanceItemEntry(BaseModel):
    id: int
    name: str
    category: str
    default_cycle_days: int
    default_duration_minutes: int
    standard_description: str
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class MaintenanceItemListResult(BaseModel):
    total: int
    items: list[MaintenanceItemEntry]


class MaintenancePlanUpsertRequest(BaseModel):
    equipment_id: int
    item_id: int
    cycle_days: int | None = Field(default=None, ge=1, le=3650)
    execution_process_code: str = Field(min_length=1, max_length=64)
    estimated_duration_minutes: int | None = Field(default=None, ge=1, le=1440)
    start_date: date
    next_due_date: date | None = None
    default_executor_user_id: int | None = None


class ToggleEnabledRequest(BaseModel):
    enabled: bool


class MaintenancePlanToggleRequest(ToggleEnabledRequest):
    pass


class MaintenancePlanGenerateResult(BaseModel):
    created: bool
    work_order_id: int
    due_date: date
    next_due_date: date


class MaintenancePlanItem(BaseModel):
    id: int
    equipment_id: int
    equipment_name: str
    item_id: int
    item_name: str
    cycle_days: int
    execution_process_code: str
    execution_process_name: str
    estimated_duration_minutes: int | None
    start_date: date
    next_due_date: date
    default_executor_user_id: int | None
    default_executor_username: str | None
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class MaintenancePlanListResult(BaseModel):
    total: int
    items: list[MaintenancePlanItem]


class MaintenanceWorkOrderCompleteRequest(BaseModel):
    result_summary: Literal["完成", "失败"]
    result_remark: str | None = Field(default=None, max_length=1024)
    attachment_link: str | None = Field(default=None, max_length=1024)


class MaintenanceWorkOrderItem(BaseModel):
    id: int
    plan_id: int | None
    equipment_id: int | None
    equipment_name: str
    source_equipment_code: str | None = None
    item_id: int | None
    item_name: str
    source_item_name: str | None = None
    source_execution_process_code: str | None = None
    due_date: date
    status: WorkOrderStatus
    executor_user_id: int | None
    executor_username: str | None
    started_at: datetime | None
    completed_at: datetime | None
    result_summary: str | None
    result_remark: str | None
    attachment_link: str | None
    attachment_name: str | None = None
    created_at: datetime
    updated_at: datetime


class MaintenanceWorkOrderListResult(BaseModel):
    total: int
    items: list[MaintenanceWorkOrderItem]


class MaintenanceRecordItem(BaseModel):
    id: int
    work_order_id: int
    equipment_name: str
    item_name: str
    due_date: date
    executor_user_id: int | None
    executor_username: str | None
    completed_at: datetime
    result_summary: str
    result_remark: str | None
    attachment_link: str | None
    attachment_name: str | None = None
    created_at: datetime
    updated_at: datetime


class MaintenanceRecordListResult(BaseModel):
    total: int
    items: list[MaintenanceRecordItem]


class EquipmentDetailResult(BaseModel):
    id: int
    code: str
    name: str
    model: str
    location: str
    owner_name: str
    remark: str
    is_enabled: bool
    created_at: datetime
    updated_at: datetime
    active_plan_count: int
    pending_work_order_count: int
    active_plans_scope_limited: bool = False
    pending_work_orders_scope_limited: bool = False
    recent_records_scope_limited: bool = False
    active_plans: list[MaintenancePlanItem]
    pending_work_orders: list[MaintenanceWorkOrderItem]
    recent_records: list[MaintenanceRecordItem]


class MaintenanceWorkOrderDetail(MaintenanceWorkOrderItem):
    source_plan_id: int | None
    source_plan_cycle_days: int | None
    source_plan_start_date: date | None = None
    source_plan_summary: str | None = None
    source_execution_process_code: str | None
    source_equipment_name: str | None = None
    source_item_id: int | None = None
    source_item_name: str | None = None
    record_id: int | None = None


class MaintenanceRecordDetail(MaintenanceRecordItem):
    source_plan_id: int | None
    source_plan_cycle_days: int | None
    source_plan_start_date: date | None = None
    source_plan_summary: str | None = None
    source_equipment_code: str | None
    source_equipment_name: str | None = None
    source_execution_process_code: str | None = None
    source_item_id: int | None
    source_item_name: str | None = None


class EquipmentExportResult(BaseModel):
    file_name: str
    mime_type: str
    content_base64: str
    exported_count: int = 0
