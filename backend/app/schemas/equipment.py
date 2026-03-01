from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field


WorkOrderStatus = Literal["pending", "in_progress", "done", "overdue", "cancelled"]


class EquipmentLedgerUpsertRequest(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    model: str = Field(default="", min_length=0, max_length=128)
    location: str = Field(default="", min_length=0, max_length=255)
    owner_name: str = Field(default="", min_length=0, max_length=64)


class EquipmentLedgerItem(BaseModel):
    id: int
    name: str
    model: str
    location: str
    owner_name: str
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class EquipmentLedgerListResult(BaseModel):
    total: int
    items: list[EquipmentLedgerItem]


class MaintenanceItemUpsertRequest(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: str = Field(default="", min_length=0, max_length=64)
    default_cycle_days: int = Field(ge=1, le=3650)
    default_duration_minutes: int = Field(ge=1, le=1440)


class MaintenanceItemEntry(BaseModel):
    id: int
    name: str
    category: str
    default_cycle_days: int
    default_duration_minutes: int
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class MaintenanceItemListResult(BaseModel):
    total: int
    items: list[MaintenanceItemEntry]


class MaintenancePlanUpsertRequest(BaseModel):
    equipment_id: int
    item_id: int
    cycle_days: int = Field(ge=1, le=3650)
    estimated_duration_minutes: int | None = Field(default=None, ge=1, le=1440)
    start_date: date
    next_due_date: date | None = None
    default_executor_user_id: int | None = None


class MaintenancePlanToggleRequest(BaseModel):
    enabled: bool


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
    result_summary: str = Field(min_length=1, max_length=255)
    result_remark: str | None = Field(default=None, max_length=1024)
    attachment_link: str | None = Field(default=None, max_length=1024)


class MaintenanceWorkOrderItem(BaseModel):
    id: int
    plan_id: int
    equipment_id: int
    equipment_name: str
    item_id: int
    item_name: str
    due_date: date
    status: WorkOrderStatus
    executor_user_id: int | None
    executor_username: str | None
    started_at: datetime | None
    completed_at: datetime | None
    result_summary: str | None
    result_remark: str | None
    attachment_link: str | None
    created_at: datetime
    updated_at: datetime


class MaintenanceWorkOrderListResult(BaseModel):
    total: int
    items: list[MaintenanceWorkOrderItem]
