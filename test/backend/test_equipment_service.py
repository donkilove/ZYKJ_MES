from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest
from sqlalchemy import select

from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.maintenance_record import MaintenanceRecord
from app.models.maintenance_work_order import MaintenanceWorkOrder
from app.services import equipment_service


def _prepare_equipment_base(db, factory):
    factory.ensure_default_roles()
    stage = factory.stage(code="61", name="保养工段", sort_order=1, is_enabled=True)
    admin = factory.user(username="equip_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    operator = factory.user(username="equip_op", role_codes=[ROLE_OPERATOR])
    prod_admin = factory.user(username="equip_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    equipment = equipment_service.create_equipment(
        db,
        code="EQ-01",
        name="设备A",
        model="M1",
        location="L1",
        owner_name="owner",
    )
    item = equipment_service.create_maintenance_item(db, name="点检", default_cycle_days=7)
    db.commit()
    return stage, admin, operator, prod_admin, equipment, item


def test_equipment_and_item_crud(db, factory) -> None:
    _, _, _, _, equipment, item = _prepare_equipment_base(db, factory)

    total, rows = equipment_service.list_equipment(db, page=1, page_size=10, keyword="设备", enabled=True)
    assert total == 1
    assert rows[0].id == equipment.id

    updated = equipment_service.update_equipment(
        db,
        row=equipment,
        code="EQ-01",
        name="设备A-更新",
        model="M2",
        location="L2",
        owner_name="owner2",
    )
    assert updated.name == "设备A-更新"

    disabled = equipment_service.toggle_equipment(db, row=updated, enabled=False)
    assert disabled.is_enabled is False

    reenabled = equipment_service.toggle_equipment(db, row=updated, enabled=True)
    assert reenabled.is_enabled is True

    item_updated = equipment_service.update_maintenance_item(
        db,
        row=item,
        name="点检-更新",
        default_cycle_days=10,
    )
    assert item_updated.default_cycle_days == 10

    item_disabled = equipment_service.toggle_maintenance_item(db, row=item_updated, enabled=False)
    assert item_disabled.is_enabled is False


def test_maintenance_plan_create_update_generate_and_delete_guards(db, factory) -> None:
    stage, admin, _, _, equipment, item = _prepare_equipment_base(db, factory)

    plan = equipment_service.create_maintenance_plan(
        db,
        equipment_id=equipment.id,
        item_id=item.id,
        execution_process_code=stage.code,
        estimated_duration_minutes=30,
        start_date=date.today() - timedelta(days=7),
        next_due_date=date.today(),
        default_executor_user_id=admin.id,
    )
    assert plan.execution_process_code == stage.code
    assert plan.cycle_days == item.default_cycle_days

    updated = equipment_service.update_maintenance_plan(
        db,
        row=plan,
        equipment_id=equipment.id,
        item_id=item.id,
        execution_process_code=stage.code,
        estimated_duration_minutes=45,
        start_date=plan.start_date,
        next_due_date=plan.next_due_date,
        default_executor_user_id=None,
    )
    assert updated.estimated_duration_minutes == 45

    work_order, created = equipment_service.generate_work_order_for_plan(db, row=updated)
    assert created is True
    assert work_order.plan_id == updated.id

    work_order2, created2 = equipment_service.generate_work_order_for_plan(db, row=updated)
    assert created2 is False
    assert work_order2.id == work_order.id

    # cannot delete plan with unfinished work order
    with pytest.raises(ValueError, match="unfinished"):
        equipment_service.delete_maintenance_plan(db, row=updated)

    work_order.status = equipment_service.WORK_ORDER_STATUS_DONE
    db.commit()

    equipment_service.delete_maintenance_plan(db, row=updated)
    assert equipment_service.get_maintenance_plan_by_id(db, plan.id) is None


def test_work_order_list_start_complete_and_records(db, factory) -> None:
    stage, admin, operator, prod_admin, equipment, item = _prepare_equipment_base(db, factory)

    plan = equipment_service.create_maintenance_plan(
        db,
        equipment_id=equipment.id,
        item_id=item.id,
        execution_process_code=stage.code,
        estimated_duration_minutes=60,
        start_date=date.today() - timedelta(days=14),
        next_due_date=date.today() - timedelta(days=1),
        default_executor_user_id=None,
    )
    work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)

    total_none, rows_none = equipment_service.list_work_orders(
        db,
        page=1,
        page_size=20,
        status=None,
        keyword=None,
        mine=False,
        current_user_id=operator.id,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[],
        done_only=False,
        executor_user_id=None,
        start_date=None,
        end_date=None,
    )
    assert total_none == 0
    assert rows_none == []

    total, rows = equipment_service.list_work_orders(
        db,
        page=1,
        page_size=20,
        status=None,
        keyword="设备A",
        mine=False,
        current_user_id=operator.id,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
        done_only=False,
        executor_user_id=None,
        start_date=None,
        end_date=None,
    )
    assert total >= 1
    assert rows[0].id == work_order.id

    started = equipment_service.start_work_order(
        db,
        row=work_order,
        operator=operator,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
    )
    assert started.status == equipment_service.WORK_ORDER_STATUS_IN_PROGRESS

    completed = equipment_service.complete_work_order(
        db,
        row=started,
        operator=operator,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
        result_summary="瀹屾垚",
        result_remark="ok",
        attachment_link="http://example.com",
    )
    assert completed.status == equipment_service.WORK_ORDER_STATUS_DONE
    assert completed.result_summary == "完成"

    records = db.execute(select(MaintenanceRecord).where(MaintenanceRecord.work_order_id == completed.id)).scalars().all()
    assert len(records) == 1

    list_total, list_rows = equipment_service.list_maintenance_records(
        db,
        page=1,
        page_size=10,
        keyword="设备A",
        executor_user_id=operator.id,
        start_date=date.today() - timedelta(days=1),
        end_date=date.today() + timedelta(days=1),
    )
    assert list_total == 1
    assert list_rows[0].work_order_id == completed.id


def test_equipment_delete_guards_with_work_orders(db, factory) -> None:
    stage, _, _, _, equipment, item = _prepare_equipment_base(db, factory)
    plan = equipment_service.create_maintenance_plan(
        db,
        equipment_id=equipment.id,
        item_id=item.id,
        execution_process_code=stage.code,
        estimated_duration_minutes=30,
        start_date=date.today(),
        next_due_date=date.today(),
        default_executor_user_id=None,
    )
    work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)

    with pytest.raises(ValueError, match="referenced"):
        equipment_service.delete_equipment(db, row=equipment)

    with pytest.raises(ValueError, match="referenced"):
        equipment_service.delete_maintenance_item(db, row=item)

    work_order.status = equipment_service.WORK_ORDER_STATUS_DONE
    db.commit()

    equipment_service.delete_maintenance_plan(db, row=plan)
    equipment_service.delete_equipment(db, row=equipment)
    equipment_service.delete_maintenance_item(db, row=item)


def test_work_order_permission_and_invalid_complete_result(db, factory) -> None:
    stage, admin, operator, _, equipment, item = _prepare_equipment_base(db, factory)
    plan = equipment_service.create_maintenance_plan(
        db,
        equipment_id=equipment.id,
        item_id=item.id,
        execution_process_code=stage.code,
        estimated_duration_minutes=30,
        start_date=date.today(),
        next_due_date=date.today(),
        default_executor_user_id=admin.id,
    )
    work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)

    with pytest.raises(ValueError, match="Access denied"):
        equipment_service.start_work_order(
            db,
            row=work_order,
            operator=operator,
            current_user_role_codes=[ROLE_OPERATOR],
            current_user_stage_codes=["other-stage"],
        )

    started = equipment_service.start_work_order(
        db,
        row=work_order,
        operator=admin,
        current_user_role_codes=[ROLE_PRODUCTION_ADMIN],
        current_user_stage_codes=[],
    )
    with pytest.raises(ValueError, match="Result summary"):
        equipment_service.complete_work_order(
            db,
            row=started,
            operator=admin,
            current_user_role_codes=[ROLE_PRODUCTION_ADMIN],
            current_user_stage_codes=[],
            result_summary="invalid",
            result_remark=None,
            attachment_link=None,
        )
