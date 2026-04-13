from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from app.schemas.home_dashboard import HomeDashboardTodoItem, HomeDashboardTodoSummary


@dataclass(frozen=True)
class DashboardMessageSeed:
    id: int
    title: str
    source_module: str | None
    priority: str
    published_at: datetime | None
    overdue: bool
    target_page_code: str | None
    target_tab_code: str | None
    target_route_payload_json: str | None


_PRIORITY_ORDER = {"urgent": 0, "important": 1, "normal": 2}
_CATEGORY_LABELS = {
    "user": "审批",
    "production": "生产",
    "quality": "质量",
    "equipment": "设备",
    "message": "消息",
    "craft": "工艺",
    "product": "产品",
}


def build_dashboard_todo_summary(
    *,
    total_count: int,
    pending_approval_count: int,
    high_priority_count: int,
    exception_count: int,
    overdue_count: int,
) -> HomeDashboardTodoSummary:
    return HomeDashboardTodoSummary(
        total_count=total_count,
        pending_approval_count=pending_approval_count,
        high_priority_count=high_priority_count,
        exception_count=exception_count,
        overdue_count=overdue_count,
    )


def select_dashboard_todo_items(
    seeds: list[DashboardMessageSeed],
    *,
    limit: int = 4,
) -> list[HomeDashboardTodoItem]:
    if limit < 0:
        return []

    ordered = sorted(
        seeds,
        key=lambda item: (
            0 if item.overdue else 1,
            _PRIORITY_ORDER.get(item.priority, 9),
            -(item.published_at.timestamp() if item.published_at else float("-inf")),
        ),
    )[:limit]

    return [
        HomeDashboardTodoItem(
            id=item.id,
            title=item.title,
            category_label=_CATEGORY_LABELS.get(item.source_module or "", "待办"),
            priority_label="超时"
            if item.overdue
            else ("高优" if item.priority in {"urgent", "important"} else "普通"),
            source_module=item.source_module,
            target_page_code=item.target_page_code,
            target_tab_code=item.target_tab_code,
            target_route_payload_json=item.target_route_payload_json,
        )
        for item in ordered
    ]
