from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class HomeDashboardTodoSummary(BaseModel):
    total_count: int
    pending_approval_count: int
    high_priority_count: int
    exception_count: int
    overdue_count: int


class HomeDashboardMetricItem(BaseModel):
    code: str
    label: str
    value: str
    target_page_code: str | None = None
    target_tab_code: str | None = None
    target_route_payload_json: str | None = None


class HomeDashboardTodoItem(BaseModel):
    id: int
    title: str
    category_label: str
    priority_label: str
    source_module: str | None = None
    target_page_code: str | None = None
    target_tab_code: str | None = None
    target_route_payload_json: str | None = None


class HomeDashboardDegradedBlock(BaseModel):
    code: str
    message: str


class HomeDashboardResult(BaseModel):
    generated_at: datetime
    notice_count: int
    todo_summary: HomeDashboardTodoSummary
    todo_items: list[HomeDashboardTodoItem]
    risk_items: list[HomeDashboardMetricItem]
    kpi_items: list[HomeDashboardMetricItem]
    degraded_blocks: list[HomeDashboardDegradedBlock]
