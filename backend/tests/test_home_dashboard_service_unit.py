from datetime import UTC, datetime, timedelta

from app.services.home_dashboard_service import (
    DashboardMessageSeed,
    build_dashboard_todo_summary,
    select_dashboard_todo_items,
)


def test_select_dashboard_todo_items_orders_by_overdue_priority_and_publish_time() -> None:
    now = datetime.now(UTC)
    seeds = [
        DashboardMessageSeed(
            id=1,
            title="普通待办",
            source_module="production",
            priority="normal",
            published_at=now - timedelta(minutes=30),
            overdue=False,
            target_page_code="production",
            target_tab_code="production_order_query",
            target_route_payload_json=None,
        ),
        DashboardMessageSeed(
            id=2,
            title="高优待办",
            source_module="quality",
            priority="urgent",
            published_at=now - timedelta(minutes=20),
            overdue=False,
            target_page_code="quality",
            target_tab_code="quality_data_query",
            target_route_payload_json=None,
        ),
        DashboardMessageSeed(
            id=3,
            title="超时待办",
            source_module="user",
            priority="important",
            published_at=now - timedelta(minutes=10),
            overdue=True,
            target_page_code="user",
            target_tab_code="registration_approval",
            target_route_payload_json=None,
        ),
    ]

    result = select_dashboard_todo_items(seeds, limit=2)

    assert [item.id for item in result] == [3, 2]


def test_build_dashboard_todo_summary_counts_four_summary_numbers() -> None:
    summary = build_dashboard_todo_summary(
        total_count=12,
        pending_approval_count=2,
        high_priority_count=3,
        exception_count=5,
        overdue_count=1,
    )

    assert summary.total_count == 12
    assert summary.pending_approval_count == 2
    assert summary.high_priority_count == 3
    assert summary.exception_count == 5
    assert summary.overdue_count == 1
