import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services.home_dashboard_service import (
    DashboardMessageSeed,
    _HOME_DASHBOARD_LOCAL_CACHE,
    _HOME_DASHBOARD_LOCAL_CACHE_LOCK,
    build_dashboard_todo_summary,
    invalidate_home_dashboard_cache,
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


def test_select_dashboard_todo_items_maps_category_priority_and_fallback() -> None:
    now = datetime.now(UTC)
    seeds = [
        DashboardMessageSeed(
            id=11,
            title="工艺异常",
            source_module="craft",
            priority="important",
            published_at=now - timedelta(minutes=15),
            overdue=False,
            target_page_code="craft",
            target_tab_code="craft_kanban",
            target_route_payload_json=None,
        ),
        DashboardMessageSeed(
            id=12,
            title="未知模块告警",
            source_module="unknown_module",
            priority="normal",
            published_at=now - timedelta(minutes=14),
            overdue=False,
            target_page_code="unknown",
            target_tab_code=None,
            target_route_payload_json=None,
        ),
        DashboardMessageSeed(
            id=13,
            title="产品超时待办",
            source_module="product",
            priority="normal",
            published_at=now - timedelta(minutes=13),
            overdue=True,
            target_page_code="product",
            target_tab_code="product_parameter_query",
            target_route_payload_json=None,
        ),
    ]

    result = select_dashboard_todo_items(seeds, limit=3)
    by_id = {item.id: item for item in result}

    assert by_id[11].category_label == "工艺"
    assert by_id[11].priority_label == "高优"
    assert by_id[12].category_label == "待办"
    assert by_id[12].priority_label == "普通"
    assert by_id[13].category_label == "产品"
    assert by_id[13].priority_label == "超时"


def test_select_dashboard_todo_items_returns_empty_when_limit_is_negative() -> None:
    now = datetime.now(UTC)
    seeds = [
        DashboardMessageSeed(
            id=21,
            title="负数上限测试",
            source_module="quality",
            priority="urgent",
            published_at=now - timedelta(minutes=5),
            overdue=False,
            target_page_code="quality",
            target_tab_code="quality_data_query",
            target_route_payload_json=None,
        ),
    ]

    result = select_dashboard_todo_items(seeds, limit=-1)

    assert result == []


def test_build_dashboard_todo_summary_counts_all_summary_numbers() -> None:
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


def test_invalidate_home_dashboard_cache_removes_only_selected_user_entries() -> None:
    with _HOME_DASHBOARD_LOCAL_CACHE_LOCK:
        _HOME_DASHBOARD_LOCAL_CACHE.clear()
        _HOME_DASHBOARD_LOCAL_CACHE.update(
            {
                "home_dashboard:1:home,user": (999999999.0, object()),
                "home_dashboard:1:home,user,message": (999999999.0, object()),
                "home_dashboard:2:home,user": (999999999.0, object()),
            }
        )

    removed = invalidate_home_dashboard_cache(user_ids={1})

    assert removed == 2
    with _HOME_DASHBOARD_LOCAL_CACHE_LOCK:
        assert sorted(_HOME_DASHBOARD_LOCAL_CACHE) == ["home_dashboard:2:home,user"]
        _HOME_DASHBOARD_LOCAL_CACHE.clear()
