from __future__ import annotations

from datetime import date, timedelta

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
        remark="初始备注",
    )
    item = equipment_service.create_maintenance_item(
        db,
        name="点检",
        default_cycle_days=7,
        category="常规",
        default_duration_minutes=90,
        standard_description="按标准点检项执行",
    )
    db.commit()
    return stage, admin, operator, prod_admin, equipment, item


def _create_plan(
    db,
    *,
    stage_code: str,
    equipment_id: int,
    item_id: int,
    start_date: date,
    next_due_date: date,
    default_executor_user_id: int | None,
    cycle_days: int | None,
    estimated_duration_minutes: int = 30,
):
    return equipment_service.create_maintenance_plan(
        db,
        equipment_id=equipment_id,
        item_id=item_id,
        cycle_days=cycle_days,
        execution_process_code=stage_code,
        estimated_duration_minutes=estimated_duration_minutes,
        start_date=start_date,
        next_due_date=next_due_date,
        default_executor_user_id=default_executor_user_id,
    )


def _list_work_orders_for(
    db,
    *,
    role_codes: list[str],
    stage_codes: list[str],
    status: str | None = None,
    mine: bool = False,
    current_user_id: int | None = None,
    done_only: bool = False,
):
    return equipment_service.list_work_orders(
        db,
        page=1,
        page_size=50,
        status=status,
        keyword=None,
        mine=mine,
        current_user_id=current_user_id,
        current_user_role_codes=role_codes,
        current_user_stage_codes=stage_codes,
        done_only=done_only,
        executor_user_id=None,
        start_date=None,
        end_date=None,
    )


def test_equipment_crud_lookup_and_duplicate_guard(db, factory) -> None:
    _, _, _, _, equipment, _ = _prepare_equipment_base(db, factory)

    assert equipment_service.get_equipment_by_id(db, equipment.id) is not None
    assert equipment_service.get_equipment_by_name(db, "设备A").id == equipment.id
    assert equipment_service.get_equipment_by_code(db, "EQ-01").id == equipment.id

    with pytest.raises(ValueError, match="code already exists"):
        equipment_service.create_equipment(
            db,
            code="EQ-01",
            name="设备重复",
            model="M",
            location="L",
            owner_name="O",
        )

    extra = equipment_service.create_equipment(
        db,
        code="EQ-02",
        name="设备B",
        model="M2",
        location="L2",
        owner_name="owner2",
    )
    assert equipment_service.get_equipment_by_code(db, "EQ-02").id == extra.id

    updated = equipment_service.update_equipment(
        db,
        row=equipment,
        code="EQ-01",
        name="设备A-更新",
        model="M3",
        location="L3",
        owner_name=" owner3 ",
        remark=" 更新备注 ",
    )
    assert updated.name == "设备A-更新"
    assert updated.owner_name == "owner3"
    assert updated.remark == "更新备注"

    with pytest.raises(ValueError, match="code already exists"):
        equipment_service.update_equipment(
            db,
            row=updated,
            code="EQ-02",
            name="设备A-更新2",
            model="M4",
            location="L4",
            owner_name="owner4",
        )

    disabled = equipment_service.disable_equipment(db, row=updated)
    assert disabled.is_enabled is False
    reenabled = equipment_service.toggle_equipment(db, row=updated, enabled=True)
    assert reenabled.is_enabled is True

    total, rows = equipment_service.list_equipment(
        db,
        page=1,
        page_size=10,
        keyword="设备",
        enabled=True,
    )
    assert total == 2
    assert {row.id for row in rows} == {equipment.id, extra.id}


def test_list_active_system_admin_owners_filters_role_and_activity(db, factory) -> None:
    factory.ensure_default_roles()
    sys_active = factory.user(username="sys_active", role_codes=[ROLE_SYSTEM_ADMIN], is_active=True)
    factory.user(username="sys_inactive", role_codes=[ROLE_SYSTEM_ADMIN], is_active=False)
    factory.user(username="prod_active", role_codes=[ROLE_PRODUCTION_ADMIN], is_active=True)

    rows = equipment_service.list_active_system_admin_owners(db)

    assert [user.username for user in rows] == [sys_active.username]


def test_list_active_owners_equipment_detail_and_record_lookup(db, factory) -> None:
    stage, admin, operator, _, equipment, item = _prepare_equipment_base(db, factory)
    inactive_user = factory.user(username="inactive_owner", role_codes=[ROLE_OPERATOR], is_active=False)

    active_owners = equipment_service.list_active_owners(db)
    active_usernames = [user.username for user in active_owners]
    assert admin.username in active_usernames
    assert operator.username in active_usernames
    assert inactive_user.username not in active_usernames

    plan = _create_plan(
        db,
        stage_code=stage.code,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=None,
        estimated_duration_minutes=30,
        start_date=date.today() - timedelta(days=3),
        next_due_date=date.today(),
        default_executor_user_id=admin.id,
    )
    work_order, created = equipment_service.generate_work_order_for_plan(db, row=plan)
    assert created is True

    before_detail = equipment_service.get_equipment_detail(db, equipment.id)
    assert before_detail is not None
    _, active_plan_count, pending_work_order_count, recent_records = before_detail
    assert active_plan_count == 1
    assert pending_work_order_count == 1
    assert recent_records == []

    started = equipment_service.start_work_order(
        db,
        row=work_order,
        operator=operator,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
    )
    equipment_service.complete_work_order(
        db,
        row=started,
        operator=operator,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
        result_summary="完成",
        result_remark="正常",
        attachment_link=None,
    )

    after_detail = equipment_service.get_equipment_detail(db, equipment.id)
    assert after_detail is not None
    _, _, pending_after, recent_after = after_detail
    assert pending_after == 0
    assert len(recent_after) == 1

    record_row = recent_after[0]
    looked_up = equipment_service.get_maintenance_record_by_id(db, record_row.id)
    assert looked_up is not None
    assert looked_up.work_order_id == work_order.id


def test_maintenance_item_crud_and_plan_cycle_sync(db, factory) -> None:
    stage, admin, _, _, equipment, item = _prepare_equipment_base(db, factory)
    start = date.today() - timedelta(days=28)
    plan = _create_plan(
        db,
        stage_code=stage.code,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=None,
        estimated_duration_minutes=40,
        start_date=start,
        next_due_date=start + timedelta(days=7),
        default_executor_user_id=admin.id,
    )
    assert plan.cycle_days == 7

    with pytest.raises(ValueError, match="name already exists"):
        equipment_service.create_maintenance_item(
            db,
            name="点检",
            default_cycle_days=10,
            category="重复",
        )

    updated = equipment_service.update_maintenance_item(
        db,
        row=item,
        name="点检-更新",
        default_cycle_days=10,
        category="电气",
        default_duration_minutes=120,
        standard_description="每周检查电气状态",
    )
    assert updated.name == "点检-更新"
    assert updated.category == "电气"
    assert updated.default_cycle_days == 10
    assert updated.default_duration_minutes == 120
    assert updated.standard_description == "每周检查电气状态"

    plan_after_cycle_change = equipment_service.get_maintenance_plan_by_id(db, plan.id)
    assert plan_after_cycle_change is not None
    assert plan_after_cycle_change.cycle_days == 10
    expected_due = equipment_service._recalculate_next_due_date(start_date=start, cycle_days=10)
    assert plan_after_cycle_change.next_due_date == expected_due

    fallback_duration_item = equipment_service.update_maintenance_item(
        db,
        row=updated,
        name="点检-更新",
        default_cycle_days=10,
        category="电气",
        default_duration_minutes=None,
        standard_description="",
    )
    assert fallback_duration_item.default_duration_minutes == equipment_service.MAINTENANCE_ITEM_DEFAULT_DURATION_MINUTES

    disabled = equipment_service.disable_maintenance_item(db, row=fallback_duration_item)
    assert disabled.is_enabled is False


def test_maintenance_plan_create_update_generate_and_delete_guards(db, factory) -> None:
    stage, admin, _, _, equipment, item = _prepare_equipment_base(db, factory)

    plan = _create_plan(
        db,
        stage_code=stage.code,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=12,
        estimated_duration_minutes=35,
        start_date=date.today() - timedelta(days=7),
        next_due_date=date.today(),
        default_executor_user_id=admin.id,
    )
    assert plan.cycle_days == 12

    with pytest.raises(ValueError, match="already exists"):
        _create_plan(
            db,
            stage_code=stage.code,
            equipment_id=equipment.id,
            item_id=item.id,
            cycle_days=7,
            estimated_duration_minutes=20,
            start_date=date.today() - timedelta(days=7),
            next_due_date=date.today(),
            default_executor_user_id=admin.id,
        )

    updated = equipment_service.update_maintenance_plan(
        db,
        row=plan,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=None,
        execution_process_code=stage.code,
        estimated_duration_minutes=45,
        start_date=plan.start_date,
        next_due_date=plan.next_due_date,
        default_executor_user_id=None,
    )
    assert updated.cycle_days == item.default_cycle_days
    assert updated.estimated_duration_minutes == 45

    work_order, created = equipment_service.generate_work_order_for_plan(db, row=updated)
    assert created is True
    assert work_order.plan_id == updated.id

    work_order2, created2 = equipment_service.generate_work_order_for_plan(db, row=updated)
    assert created2 is False
    assert work_order2.id == work_order.id

    with pytest.raises(ValueError, match="unfinished"):
        equipment_service.delete_maintenance_plan(db, row=updated)

    work_order.status = equipment_service.WORK_ORDER_STATUS_DONE
    db.commit()

    equipment_service.delete_maintenance_plan(db, row=updated)
    assert equipment_service.get_maintenance_plan_by_id(db, plan.id) is None

    detached = db.execute(select(MaintenanceWorkOrder).where(MaintenanceWorkOrder.id == work_order.id)).scalars().one()
    assert detached.plan_id is None


def test_generate_due_work_orders_for_today_counts_created_and_existing(db, factory) -> None:
    factory.ensure_default_roles()
    stage = factory.stage(code="71", name="保养工段71", sort_order=1, is_enabled=True)

    equipment_a = factory.equipment(code="EQ-TODAY-1", name="设备-今日-1")
    item_a = factory.maintenance_item(name="保养项-今日-1", default_cycle_days=5)
    plan_create = factory.maintenance_plan(
        equipment=equipment_a,
        item=item_a,
        start_date=date.today() - timedelta(days=10),
        next_due_date=date.today() - timedelta(days=1),
        execution_process_code=stage.code,
    )

    equipment_b = factory.equipment(code="EQ-TODAY-2", name="设备-今日-2")
    item_b = factory.maintenance_item(name="保养项-今日-2", default_cycle_days=7)
    plan_existing = factory.maintenance_plan(
        equipment=equipment_b,
        item=item_b,
        start_date=date.today() - timedelta(days=7),
        next_due_date=date.today(),
        execution_process_code=stage.code,
    )
    factory.work_order(
        due_date=date.today(),
        status=equipment_service.WORK_ORDER_STATUS_PENDING,
        execution_process_code=stage.code,
        plan=plan_existing,
        equipment=equipment_b,
        item=item_b,
        executor=None,
    )

    equipment_c = factory.equipment(code="EQ-TODAY-3", name="设备-今日-3")
    item_c = factory.maintenance_item(name="保养项-今日-3", default_cycle_days=9)
    factory.maintenance_plan(
        equipment=equipment_c,
        item=item_c,
        start_date=date.today() - timedelta(days=9),
        next_due_date=date.today() - timedelta(days=1),
        execution_process_code=stage.code,
        is_enabled=False,
    )
    db.commit()

    total, created, existing = equipment_service.generate_due_work_orders_for_today(db)

    assert total == 2
    assert created == 1
    assert existing == 1

    created_orders = db.execute(
        select(MaintenanceWorkOrder).where(MaintenanceWorkOrder.plan_id == plan_create.id)
    ).scalars().all()
    assert len(created_orders) == 1


def test_work_order_list_filters_and_permissions(db, factory) -> None:
    factory.ensure_default_roles()
    stage_a = factory.stage(code="81", name="保养工段81", sort_order=1, is_enabled=True)
    stage_b = factory.stage(code="82", name="保养工段82", sort_order=2, is_enabled=True)
    operator = factory.user(username="op_filter", role_codes=[ROLE_OPERATOR])

    equipment = factory.equipment(code="EQ-LIST-1", name="设备-列表")
    item = factory.maintenance_item(name="保养项-列表", default_cycle_days=7)

    pending_order = factory.work_order(
        due_date=date.today() + timedelta(days=1),
        status=equipment_service.WORK_ORDER_STATUS_PENDING,
        execution_process_code=stage_a.code,
        equipment=equipment,
        item=item,
        executor=operator,
    )
    done_order = factory.work_order(
        due_date=date.today(),
        status=equipment_service.WORK_ORDER_STATUS_DONE,
        execution_process_code=stage_b.code,
        equipment=equipment,
        item=item,
        executor=operator,
    )
    db.commit()

    total_none, rows_none = _list_work_orders_for(
        db,
        role_codes=[ROLE_OPERATOR],
        stage_codes=[],
        current_user_id=operator.id,
    )
    assert total_none == 0
    assert rows_none == []

    total_visible, rows_visible = _list_work_orders_for(
        db,
        role_codes=[ROLE_OPERATOR],
        stage_codes=[stage_a.code],
        current_user_id=operator.id,
    )
    assert total_visible == 1
    assert rows_visible[0].id == pending_order.id

    done_total, done_rows = _list_work_orders_for(
        db,
        role_codes=[ROLE_OPERATOR],
        stage_codes=[stage_a.code, stage_b.code],
        status=equipment_service.WORK_ORDER_STATUS_DONE,
        current_user_id=operator.id,
    )
    assert done_total == 1
    assert done_rows[0].id == done_order.id

    done_only_total, done_only_rows = _list_work_orders_for(
        db,
        role_codes=[ROLE_OPERATOR],
        stage_codes=[stage_a.code, stage_b.code],
        done_only=True,
        current_user_id=operator.id,
    )
    assert done_only_total == 1
    assert done_only_rows[0].id == done_order.id

    with pytest.raises(ValueError, match="Current user is required"):
        _list_work_orders_for(
            db,
            role_codes=[ROLE_OPERATOR],
            stage_codes=[stage_a.code],
            mine=True,
            current_user_id=None,
        )

    with pytest.raises(ValueError, match="Invalid status"):
        _list_work_orders_for(
            db,
            role_codes=[ROLE_OPERATOR],
            stage_codes=[stage_a.code],
            status="unknown-status",
            current_user_id=operator.id,
        )

    all_total, all_rows = _list_work_orders_for(
        db,
        role_codes=[ROLE_PRODUCTION_ADMIN],
        stage_codes=[],
        current_user_id=operator.id,
    )
    assert all_total == 1
    assert all_rows[0].id == pending_order.id


def test_work_order_start_complete_and_record_snapshot(db, factory) -> None:
    stage, _, operator, _, equipment, item = _prepare_equipment_base(db, factory)
    plan = _create_plan(
        db,
        stage_code=stage.code,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=None,
        estimated_duration_minutes=25,
        start_date=date.today() - timedelta(days=7),
        next_due_date=date.today(),
        default_executor_user_id=None,
    )
    work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)

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
        result_remark="执行正常",
        attachment_link="http://example.com/report",
    )
    assert completed.status == equipment_service.WORK_ORDER_STATUS_DONE
    assert completed.result_summary == "完成"

    records = db.execute(
        select(MaintenanceRecord).where(MaintenanceRecord.work_order_id == completed.id)
    ).scalars().all()
    assert len(records) == 1
    assert records[0].source_equipment_id == equipment.id
    assert records[0].source_item_id == item.id
    assert records[0].result_summary == "完成"
    assert records[0].executor_username == operator.username

    with pytest.raises(ValueError, match="in progress"):
        equipment_service.complete_work_order(
            db,
            row=completed,
            operator=operator,
            current_user_role_codes=[ROLE_OPERATOR],
            current_user_stage_codes=[stage.code],
            result_summary="完成",
            result_remark="重复提交",
            attachment_link=None,
        )


def test_complete_work_order_failure_requires_exception_report(db, factory) -> None:
    stage, _, operator, _, equipment, item = _prepare_equipment_base(db, factory)
    plan = _create_plan(
        db,
        stage_code=stage.code,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=None,
        estimated_duration_minutes=20,
        start_date=date.today() - timedelta(days=3),
        next_due_date=date.today(),
        default_executor_user_id=None,
    )
    work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)
    started = equipment_service.start_work_order(
        db,
        row=work_order,
        operator=operator,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
    )

    with pytest.raises(ValueError, match="Exception report is required"):
        equipment_service.complete_work_order(
            db,
            row=started,
            operator=operator,
            current_user_role_codes=[ROLE_OPERATOR],
            current_user_stage_codes=[stage.code],
            result_summary="失败",
            result_remark=" ",
            attachment_link=None,
        )

    completed = equipment_service.complete_work_order(
        db,
        row=started,
        operator=operator,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
        result_summary="失败",
        result_remark="电机异常",
        attachment_link=None,
    )
    assert completed.status == equipment_service.WORK_ORDER_STATUS_DONE
    assert completed.result_summary == "失败"
    assert completed.result_remark == "电机异常"


def test_cancel_work_order_flow_and_guards(db, factory) -> None:
    stage, _, operator, prod_admin, equipment, item = _prepare_equipment_base(db, factory)
    plan = _create_plan(
        db,
        stage_code=stage.code,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=None,
        estimated_duration_minutes=30,
        start_date=date.today() - timedelta(days=5),
        next_due_date=date.today(),
        default_executor_user_id=None,
    )
    work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)

    with pytest.raises(ValueError, match="Access denied"):
        equipment_service.cancel_work_order(
            db,
            row=work_order,
            operator=operator,
            current_user_role_codes=[ROLE_OPERATOR],
            current_user_stage_codes=["other-stage"],
        )

    cancelled = equipment_service.cancel_work_order(
        db,
        row=work_order,
        operator=operator,
        current_user_role_codes=[ROLE_OPERATOR],
        current_user_stage_codes=[stage.code],
    )
    assert cancelled.status == equipment_service.WORK_ORDER_STATUS_CANCELLED

    with pytest.raises(ValueError, match="already cancelled"):
        equipment_service.cancel_work_order(
            db,
            row=cancelled,
            operator=operator,
            current_user_role_codes=[ROLE_OPERATOR],
            current_user_stage_codes=[stage.code],
        )

    done_row = factory.work_order(
        due_date=date.today(),
        status=equipment_service.WORK_ORDER_STATUS_DONE,
        execution_process_code=stage.code,
        plan=None,
        equipment=equipment,
        item=item,
        executor=operator,
    )
    db.commit()
    with pytest.raises(ValueError, match="cannot be cancelled"):
        equipment_service.cancel_work_order(
            db,
            row=done_row,
            operator=prod_admin,
            current_user_role_codes=[ROLE_PRODUCTION_ADMIN],
            current_user_stage_codes=[],
        )

    pending_row = factory.work_order(
        due_date=date.today(),
        status=equipment_service.WORK_ORDER_STATUS_PENDING,
        execution_process_code="other-stage",
        plan=None,
        equipment=equipment,
        item=item,
        executor=operator,
    )
    db.commit()
    cancelled_by_admin = equipment_service.cancel_work_order(
        db,
        row=pending_row,
        operator=prod_admin,
        current_user_role_codes=[ROLE_PRODUCTION_ADMIN],
        current_user_stage_codes=[],
    )
    assert cancelled_by_admin.status == equipment_service.WORK_ORDER_STATUS_CANCELLED


def test_delete_equipment_and_item_nullifies_done_work_order_fk(db, factory) -> None:
    stage, _, _, _, equipment, item = _prepare_equipment_base(db, factory)
    plan = _create_plan(
        db,
        stage_code=stage.code,
        equipment_id=equipment.id,
        item_id=item.id,
        cycle_days=None,
        estimated_duration_minutes=20,
        start_date=date.today(),
        next_due_date=date.today(),
        default_executor_user_id=None,
    )
    work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)

    with pytest.raises(ValueError, match="referenced"):
        equipment_service.delete_equipment(db, row=equipment)
    with pytest.raises(ValueError, match="referenced"):
        equipment_service.delete_maintenance_item(db, row=item)
    with pytest.raises(ValueError, match="unfinished"):
        equipment_service.delete_maintenance_plan(db, row=plan)

    work_order.status = equipment_service.WORK_ORDER_STATUS_DONE
    db.commit()

    equipment_service.delete_maintenance_plan(db, row=plan)
    equipment_service.delete_equipment(db, row=equipment)
    equipment_service.delete_maintenance_item(db, row=item)

    detached = db.execute(select(MaintenanceWorkOrder).where(MaintenanceWorkOrder.id == work_order.id)).scalars().one()
    assert detached.plan_id is None
    assert detached.equipment_id is None
    assert detached.item_id is None


def test_list_maintenance_records_supports_result_equipment_and_date_filters(db, factory) -> None:
    stage, _, operator, _, equipment_a, item_a = _prepare_equipment_base(db, factory)
    operator_b = factory.user(username="equip_op_b", role_codes=[ROLE_OPERATOR])
    equipment_b = equipment_service.create_equipment(
        db,
        code="EQ-02",
        name="设备B",
        model="M2",
        location="L2",
        owner_name="owner2",
    )
    item_b = equipment_service.create_maintenance_item(
        db,
        name="润滑",
        default_cycle_days=5,
        category="润滑",
        default_duration_minutes=30,
        standard_description="润滑保养",
    )

    def _complete_once(*, equipment_id: int, item_id: int, executor, summary: str, remark: str) -> int:
        plan = _create_plan(
            db,
            stage_code=stage.code,
            equipment_id=equipment_id,
            item_id=item_id,
            cycle_days=None,
            estimated_duration_minutes=25,
            start_date=date.today() - timedelta(days=2),
            next_due_date=date.today(),
            default_executor_user_id=None,
        )
        work_order, _ = equipment_service.generate_work_order_for_plan(db, row=plan)
        started = equipment_service.start_work_order(
            db,
            row=work_order,
            operator=executor,
            current_user_role_codes=[ROLE_OPERATOR],
            current_user_stage_codes=[stage.code],
        )
        completed = equipment_service.complete_work_order(
            db,
            row=started,
            operator=executor,
            current_user_role_codes=[ROLE_OPERATOR],
            current_user_stage_codes=[stage.code],
            result_summary=summary,
            result_remark=remark,
            attachment_link=None,
        )
        return completed.id

    completed_a_id = _complete_once(
        equipment_id=equipment_a.id,
        item_id=item_a.id,
        executor=operator,
        summary="完成",
        remark="正常",
    )
    completed_b_id = _complete_once(
        equipment_id=equipment_b.id,
        item_id=item_b.id,
        executor=operator_b,
        summary="失败",
        remark="异常",
    )

    total_a, rows_a = equipment_service.list_maintenance_records(
        db,
        page=1,
        page_size=20,
        keyword="设备A",
        executor_user_id=operator.id,
        result_summary="完成",
        equipment_id=equipment_a.id,
        start_date=date.today() - timedelta(days=1),
        end_date=date.today() + timedelta(days=1),
    )
    assert total_a == 1
    assert rows_a[0].work_order_id == completed_a_id

    total_b, rows_b = equipment_service.list_maintenance_records(
        db,
        page=1,
        page_size=20,
        keyword="设备B",
        executor_user_id=operator_b.id,
        result_summary="失败",
        equipment_id=equipment_b.id,
        start_date=date.today() - timedelta(days=1),
        end_date=date.today() + timedelta(days=1),
    )
    assert total_b == 1
    assert rows_b[0].work_order_id == completed_b_id
