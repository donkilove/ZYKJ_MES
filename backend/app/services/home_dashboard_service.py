from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.home_dashboard import (
    HomeDashboardDegradedBlock,
    HomeDashboardMetricItem,
    HomeDashboardResult,
    HomeDashboardTodoItem,
    HomeDashboardTodoSummary,
)
from app.services.authz_snapshot_service import get_authz_snapshot
from app.services.message_service import get_message_summary, list_messages
from app.services.production_data_query_service import (
    build_today_filters,
    get_today_realtime_data,
)
from app.services.production_statistics_service import get_overview_stats
from app.services.quality_service import get_quality_overview


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


def _safe_int(value: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def build_home_dashboard(db: Session, *, current_user: User) -> HomeDashboardResult:
    degraded_blocks: list[HomeDashboardDegradedBlock] = []
    generated_at = datetime.now(UTC)
    snapshot = get_authz_snapshot(db, user=current_user)
    visible_sidebar_codes = set(snapshot.get("visible_sidebar_codes", []))

    summary_dict = get_message_summary(db, user_id=current_user.id)
    todo_rows, _ = list_messages(
        db,
        user_id=current_user.id,
        current_user=current_user,
        page=1,
        page_size=20,
        todo_only=True,
        active_only=True,
    )
    todo_seeds = [
        DashboardMessageSeed(
            id=row.id,
            title=row.title,
            source_module=row.source_module,
            priority=row.priority,
            published_at=row.published_at,
            overdue=False,
            target_page_code=row.target_page_code,
            target_tab_code=row.target_tab_code,
            target_route_payload_json=row.target_route_payload_json,
        )
        for row in todo_rows
    ]

    risk_items: list[HomeDashboardMetricItem] = []
    kpi_items: list[HomeDashboardMetricItem] = []

    try:
        if "production" in visible_sidebar_codes:
            production_overview = get_overview_stats(db)
            production_today = get_today_realtime_data(
                db,
                filters=build_today_filters(
                    stat_mode="main_order",
                    product_ids=None,
                    stage_ids=None,
                    process_ids=None,
                    operator_user_ids=None,
                    order_status=None,
                ),
            )
            risk_items.append(
                HomeDashboardMetricItem(
                    code="production_exception",
                    label="生产异常",
                    value="0",
                    target_page_code="production",
                    target_tab_code="production_order_query",
                    target_route_payload_json='{"dashboard_filter":"exception"}',
                )
            )
            kpi_items.extend(
                [
                    HomeDashboardMetricItem(
                        code="wip_orders",
                        label="在制订单",
                        value=str(production_overview["in_progress_orders"]),
                        target_page_code="production",
                        target_tab_code="production_data_query",
                    ),
                    HomeDashboardMetricItem(
                        code="today_quantity",
                        label="今日产量",
                        value=str(production_today["summary"]["total_quantity"]),
                        target_page_code="production",
                        target_tab_code="production_data_query",
                    ),
                ]
            )
    except Exception:
        degraded_blocks.append(
            HomeDashboardDegradedBlock(code="production", message="生产摘要加载失败")
        )

    try:
        if "quality" in visible_sidebar_codes:
            quality_overview = get_quality_overview(
                db,
                start_date=None,
                end_date=None,
                product_name=None,
                process_code=None,
                operator_username=None,
                result_filter=None,
            )
            risk_items.append(
                HomeDashboardMetricItem(
                    code="quality_warning",
                    label="质量预警",
                    value=str(quality_overview["failed_total"]),
                    target_page_code="quality",
                    target_tab_code="quality_data_query",
                    target_route_payload_json='{"dashboard_filter":"warning"}',
                )
            )
            kpi_items.extend(
                [
                    HomeDashboardMetricItem(
                        code="first_article_pass_rate",
                        label="首件通过率",
                        value=f'{quality_overview["pass_rate_percent"]}%',
                        target_page_code="quality",
                        target_tab_code="quality_data_query",
                    ),
                    HomeDashboardMetricItem(
                        code="scrap_total",
                        label="报废数",
                        value=str(quality_overview["scrap_total"]),
                        target_page_code="quality",
                        target_tab_code="quality_data_query",
                    ),
                ]
            )
    except Exception:
        degraded_blocks.append(
            HomeDashboardDegradedBlock(code="quality", message="质量摘要加载失败")
        )

    return HomeDashboardResult(
        generated_at=generated_at,
        notice_count=summary_dict["unread_count"],
        todo_summary=build_dashboard_todo_summary(
            total_count=summary_dict["total_count"],
            pending_approval_count=summary_dict["todo_unread_count"],
            high_priority_count=summary_dict["urgent_unread_count"],
            exception_count=sum(_safe_int(item.value) for item in risk_items),
            overdue_count=sum(1 for item in todo_seeds if item.overdue),
        ),
        todo_items=select_dashboard_todo_items(todo_seeds, limit=4),
        risk_items=risk_items,
        kpi_items=kpi_items,
        degraded_blocks=degraded_blocks,
    )
