import sys
from datetime import UTC, date, datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api.v1.endpoints import equipment, quality  # noqa: E402
from app.schemas.equipment import MaintenanceWorkOrderCompleteRequest  # noqa: E402
from app.schemas.quality import FirstArticleDispositionRequest  # noqa: E402


def test_submit_disposition_endpoint_closes_todo_and_invalidates_home_cache() -> None:
    db = MagicMock()
    current_user = SimpleNamespace(id=11, username="quality_admin")
    detail = {
        "id": 7,
        "order_id": 1,
        "order_code": "ORDER-1",
        "product_id": 1,
        "product_name": "产品",
        "order_process_id": 2,
        "process_code": "PROC",
        "process_name": "工序",
        "operator_user_id": 12,
        "operator_username": "operator",
        "verification_date": date(2026, 3, 2),
        "verification_code": "FA-1",
        "result": "failed",
        "check_content": None,
        "test_value": None,
        "remark": None,
        "template_id": None,
        "template_name": None,
        "disposition_id": 1,
        "disposition_opinion": "复检通过",
        "disposition_username": "quality_admin",
        "disposition_at": datetime(2026, 3, 2, 8, 0, tzinfo=UTC),
        "recheck_result": "passed",
        "final_judgment": "accept",
        "disposition_history": [],
        "participants": [],
        "created_at": datetime(2026, 3, 2, 8, 0, tzinfo=UTC),
        "updated_at": datetime(2026, 3, 2, 8, 0, tzinfo=UTC),
    }

    with (
        patch.object(quality, "submit_first_article_disposition") as submit,
        patch.object(quality, "get_first_article_by_id", return_value=detail),
        patch.object(quality, "write_audit_log"),
        patch.object(
            quality,
            "close_source_todo_messages",
            return_value=(1, {11, 12}),
        ) as close_todos,
        patch.object(quality, "invalidate_home_dashboard_cache") as invalidate_cache,
    ):
        response = quality.submit_disposition_api(
            record_id=7,
            payload=FirstArticleDispositionRequest(
                disposition_opinion="复检通过",
                recheck_result="passed",
                final_judgment="accept",
            ),
            db=db,
            current_user=current_user,
        )

    assert response.data.id == 7
    submit.assert_called_once()
    close_todos.assert_called_once_with(
        db,
        source_module="quality",
        source_type="first_article_record",
        source_id="7",
        reason="first_article_disposition_submitted",
        action_code="message.first_article_todo_closed",
        action_name="首件不通过待办关闭",
    )
    invalidate_cache.assert_called_once_with(user_ids={11, 12})


def test_complete_maintenance_endpoint_closes_todo_and_invalidates_home_cache() -> None:
    db = MagicMock()
    current_user = SimpleNamespace(id=21, roles=[], processes=[])
    source_row = SimpleNamespace(id=31)
    updated_row = SimpleNamespace(
        id=31,
        plan_id=1,
        equipment_id=2,
        equipment=None,
        source_equipment_name="设备",
        source_equipment_code="EQ-1",
        item_id=3,
        item=None,
        source_item_name="点检",
        source_execution_process_code="laser_marking",
        due_date=date(2026, 3, 8),
        status="done",
        executor_user_id=21,
        executor=None,
        started_at=None,
        completed_at=datetime(2026, 3, 8, 9, 0, tzinfo=UTC),
        result_summary="完成",
        result_remark="完成",
        attachment_link=None,
        created_at=datetime(2026, 3, 8, 8, 0, tzinfo=UTC),
        updated_at=datetime(2026, 3, 8, 9, 0, tzinfo=UTC),
    )

    with (
        patch.object(equipment, "get_work_order_by_id", return_value=source_row),
        patch.object(equipment, "complete_work_order", return_value=updated_row),
        patch.object(equipment, "write_audit_log"),
        patch.object(
            equipment,
            "close_source_todo_messages",
            return_value=(1, {21, 22}),
        ) as close_todos,
        patch.object(equipment, "invalidate_home_dashboard_cache") as invalidate_cache,
    ):
        response = equipment.complete_maintenance_execution(
            work_order_id=31,
            payload=MaintenanceWorkOrderCompleteRequest(
                result_summary="完成",
                result_remark="完成",
                attachment_link=None,
            ),
            db=db,
            current_user=current_user,
        )

    assert response.data.id == 31
    close_todos.assert_called_once_with(
        db,
        source_module="equipment",
        source_type="maintenance_work_order",
        source_id="31",
        reason="maintenance_work_order_completed",
        action_code="message.maintenance_work_order_closed",
        action_name="保养工单待办关闭",
    )
    invalidate_cache.assert_called_once_with(user_ids={21, 22})
