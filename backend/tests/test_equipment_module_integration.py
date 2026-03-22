import sys
import time
import unittest
from datetime import UTC, date, datetime
from pathlib import Path

from sqlalchemy import select


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.models.equipment import Equipment  # noqa: E402
from app.models.maintenance_item import MaintenanceItem  # noqa: E402
from app.models.maintenance_plan import MaintenancePlan  # noqa: E402
from app.models.maintenance_record import MaintenanceRecord  # noqa: E402
from app.models.maintenance_work_order import MaintenanceWorkOrder  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.equipment_runtime_parameter import EquipmentRuntimeParameter  # noqa: E402
from app.api.v1.endpoints.equipment import (  # noqa: E402
    _build_record_detail,
    _build_source_plan_summary,
    _build_work_order_detail,
)
from app.schemas.equipment_rule import EquipmentRuntimeParameterUpsertRequest  # noqa: E402
from app.services.equipment_service import (  # noqa: E402
    create_equipment,
    create_maintenance_item,
    create_maintenance_plan,
    delete_equipment,
    delete_maintenance_item,
    delete_maintenance_plan,
    ensure_maintenance_record_view_permission,
    ensure_work_order_view_permission,
    generate_work_order_for_plan,
    get_maintenance_plan_by_id,
    list_maintenance_records,
    toggle_equipment,
    toggle_maintenance_item,
    update_maintenance_item,
)
from app.services.equipment_rule_service import (  # noqa: E402
    create_runtime_parameter,
    list_runtime_parameters,
)


class EquipmentModuleIntegrationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = SessionLocal()
        self._suffix = str(int(time.time() * 1000000))
        self.stage_ids: list[int] = []
        self.equipment_ids: list[int] = []
        self.item_ids: list[int] = []
        self.runtime_parameter_ids: list[int] = []
        self.plan_ids: list[int] = []
        self.work_order_ids: list[int] = []
        self.record_ids: list[int] = []

    def tearDown(self) -> None:
        try:
            self.db.rollback()
            for record_id in reversed(self.record_ids):
                row = self.db.get(MaintenanceRecord, record_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for work_order_id in reversed(self.work_order_ids):
                row = self.db.get(MaintenanceWorkOrder, work_order_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for plan_id in reversed(self.plan_ids):
                row = self.db.get(MaintenancePlan, plan_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for item_id in reversed(self.item_ids):
                row = self.db.get(MaintenanceItem, item_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for parameter_id in reversed(self.runtime_parameter_ids):
                row = self.db.get(EquipmentRuntimeParameter, parameter_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for equipment_id in reversed(self.equipment_ids):
                row = self.db.get(Equipment, equipment_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for stage_id in reversed(self.stage_ids):
                row = self.db.get(ProcessStage, stage_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
        finally:
            self.db.close()

    def _ensure_stage(self, code: str, name: str) -> ProcessStage:
        existing = (
            self.db.execute(select(ProcessStage).where(ProcessStage.code == code))
            .scalars()
            .first()
        )
        if existing is not None:
            return existing

        row = ProcessStage(
            code=code,
            name=f"{name}-{self._suffix}",
            sort_order=0,
            remark="设备模块集成测试",
            is_enabled=True,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.stage_ids.append(int(row.id))
        return row

    def _create_equipment(self, label: str) -> Equipment:
        row = create_equipment(
            self.db,
            code=f"EQ-{label}-{self._suffix}",
            name=f"设备-{label}-{self._suffix}",
            model="MODEL-A",
            location="A区",
            owner_name="tester",
            remark="设备模块集成测试",
        )
        self.equipment_ids.append(int(row.id))
        return row

    def _create_item(
        self, label: str, *, default_cycle_days: int = 30
    ) -> MaintenanceItem:
        row = create_maintenance_item(
            self.db,
            name=f"保养项目-{label}-{self._suffix}",
            default_cycle_days=default_cycle_days,
            category="点检",
            default_duration_minutes=60,
            standard_description="设备模块集成测试",
        )
        self.item_ids.append(int(row.id))
        return row

    def _create_plan(
        self,
        *,
        equipment: Equipment,
        item: MaintenanceItem,
        stage_code: str,
        cycle_days: int,
        start_date: date,
        next_due_date: date,
    ) -> MaintenancePlan:
        row = create_maintenance_plan(
            self.db,
            equipment_id=equipment.id,
            item_id=item.id,
            cycle_days=cycle_days,
            execution_process_code=stage_code,
            estimated_duration_minutes=45,
            start_date=start_date,
            next_due_date=next_due_date,
            default_executor_user_id=None,
        )
        self.plan_ids.append(int(row.id))
        return row

    def _create_runtime_parameter(
        self,
        label: str,
        *,
        equipment_id: int | None = None,
        equipment_type: str | None = None,
        is_enabled: bool = True,
    ) -> EquipmentRuntimeParameter:
        row = create_runtime_parameter(
            self.db,
            payload=EquipmentRuntimeParameterUpsertRequest(
                equipment_id=equipment_id,
                equipment_type=equipment_type,
                param_code=f"PARAM-{label}-{self._suffix}",
                param_name=f"参数-{label}-{self._suffix}",
                unit="mm",
                standard_value=1.0,
                upper_limit=2.0,
                lower_limit=0.5,
                effective_at=None,
                is_enabled=is_enabled,
                remark="设备模块集成测试",
            ),
        )
        self.db.commit()
        self.db.refresh(row)
        self.runtime_parameter_ids.append(int(row.id))
        return row

    def test_item_default_cycle_change_does_not_override_plan_cycle(self) -> None:
        stage = self._ensure_stage("laser_marking", "激光打标")
        equipment = self._create_equipment("CYCLE")
        item = self._create_item("CYCLE", default_cycle_days=30)
        plan = self._create_plan(
            equipment=equipment,
            item=item,
            stage_code=stage.code,
            cycle_days=45,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 15),
        )

        update_maintenance_item(
            self.db,
            row=item,
            name=item.name,
            default_cycle_days=10,
            category=item.category,
            default_duration_minutes=item.default_duration_minutes,
            standard_description=item.standard_description,
        )
        refreshed_plan = get_maintenance_plan_by_id(self.db, plan.id)
        assert refreshed_plan is not None
        self.assertEqual(refreshed_plan.cycle_days, 45)

        work_order, created = generate_work_order_for_plan(self.db, row=refreshed_plan)
        self.work_order_ids.append(int(work_order.id))
        self.assertTrue(created)
        self.assertEqual(work_order.source_plan_cycle_days, 45)

        refreshed_plan = get_maintenance_plan_by_id(self.db, plan.id)
        assert refreshed_plan is not None
        self.assertEqual(refreshed_plan.next_due_date, date(2026, 4, 29))

    def test_generate_work_order_requires_enabled_equipment_and_item(self) -> None:
        stage = self._ensure_stage("laser_marking", "激光打标")
        equipment = self._create_equipment("ENABLE")
        item = self._create_item("ENABLE", default_cycle_days=20)
        plan = self._create_plan(
            equipment=equipment,
            item=item,
            stage_code=stage.code,
            cycle_days=20,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 10),
        )

        toggle_equipment(self.db, row=equipment, enabled=False)
        refreshed_plan = get_maintenance_plan_by_id(self.db, plan.id)
        assert refreshed_plan is not None
        with self.assertRaisesRegex(ValueError, "Equipment is disabled"):
            generate_work_order_for_plan(self.db, row=refreshed_plan)

        toggle_equipment(self.db, row=equipment, enabled=True)
        toggle_maintenance_item(self.db, row=item, enabled=False)
        refreshed_plan = get_maintenance_plan_by_id(self.db, plan.id)
        assert refreshed_plan is not None
        with self.assertRaisesRegex(ValueError, "Maintenance item is disabled"):
            generate_work_order_for_plan(self.db, row=refreshed_plan)

    def test_work_order_and_record_visibility_follow_stage_scope(self) -> None:
        hidden_stage = self._ensure_stage("laser_marking", "激光打标")
        visible_stage = self._ensure_stage("product_testing", "成品测试")
        equipment = self._create_equipment("SCOPE")
        item = self._create_item("SCOPE", default_cycle_days=15)
        plan = self._create_plan(
            equipment=equipment,
            item=item,
            stage_code=hidden_stage.code,
            cycle_days=15,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 12),
        )
        work_order, _ = generate_work_order_for_plan(self.db, row=plan)
        self.work_order_ids.append(int(work_order.id))

        record = MaintenanceRecord(
            work_order_id=work_order.id,
            source_plan_id=plan.id,
            source_plan_cycle_days=plan.cycle_days,
            source_plan_start_date=plan.start_date,
            source_equipment_id=equipment.id,
            source_equipment_code=equipment.code,
            source_equipment_name=equipment.name,
            source_item_id=item.id,
            source_item_name=item.name,
            due_date=work_order.due_date,
            executor_user_id=None,
            executor_username="tester",
            completed_at=datetime.now(UTC),
            result_summary="完成",
            result_remark="完成测试",
            attachment_link=None,
        )
        self.db.add(record)
        self.db.commit()
        self.db.refresh(record)
        self.record_ids.append(int(record.id))

        with self.assertRaisesRegex(ValueError, "Access denied"):
            ensure_work_order_view_permission(
                row=work_order,
                current_user_role_codes=["operator"],
                current_user_stage_codes=[visible_stage.code],
            )

        ensure_work_order_view_permission(
            row=work_order,
            current_user_role_codes=["operator"],
            current_user_stage_codes=[hidden_stage.code],
        )

        hidden_total, hidden_rows = list_maintenance_records(
            self.db,
            page=1,
            page_size=20,
            keyword=None,
            executor_user_id=None,
            result_summary=None,
            equipment_id=None,
            current_user_role_codes=["operator"],
            current_user_stage_codes=[visible_stage.code],
            start_date=None,
            end_date=None,
        )
        self.assertEqual(hidden_total, 0)
        self.assertEqual(hidden_rows, [])

        visible_total, visible_rows = list_maintenance_records(
            self.db,
            page=1,
            page_size=20,
            keyword=None,
            executor_user_id=None,
            result_summary=None,
            equipment_id=None,
            current_user_role_codes=["operator"],
            current_user_stage_codes=[hidden_stage.code],
            start_date=None,
            end_date=None,
        )
        self.assertEqual(visible_total, 1)
        self.assertEqual(len(visible_rows), 1)

        with self.assertRaisesRegex(ValueError, "Access denied"):
            ensure_maintenance_record_view_permission(
                self.db,
                row=record,
                current_user_role_codes=["operator"],
                current_user_stage_codes=[visible_stage.code],
            )

        ensure_maintenance_record_view_permission(
            self.db,
            row=record,
            current_user_role_codes=["operator"],
            current_user_stage_codes=[hidden_stage.code],
        )

    def test_cancelled_work_orders_do_not_block_deletion(self) -> None:
        stage = self._ensure_stage("laser_marking", "激光打标")
        equipment = self._create_equipment("DELETE")
        item = self._create_item("DELETE", default_cycle_days=12)
        plan = self._create_plan(
            equipment=equipment,
            item=item,
            stage_code=stage.code,
            cycle_days=12,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 8),
        )
        work_order, _ = generate_work_order_for_plan(self.db, row=plan)
        self.work_order_ids.append(int(work_order.id))

        work_order.status = "cancelled"
        self.db.commit()
        self.db.refresh(work_order)

        refreshed_plan = get_maintenance_plan_by_id(self.db, plan.id)
        assert refreshed_plan is not None
        delete_maintenance_plan(self.db, row=refreshed_plan)
        self.assertIsNone(self.db.get(MaintenancePlan, plan.id))

        refreshed_work_order = self.db.get(MaintenanceWorkOrder, work_order.id)
        assert refreshed_work_order is not None
        self.assertIsNone(refreshed_work_order.plan_id)

        delete_equipment(self.db, row=equipment)
        refreshed_work_order = self.db.get(MaintenanceWorkOrder, work_order.id)
        assert refreshed_work_order is not None
        self.assertIsNone(refreshed_work_order.equipment_id)

        delete_maintenance_item(self.db, row=item)
        refreshed_work_order = self.db.get(MaintenanceWorkOrder, work_order.id)
        assert refreshed_work_order is not None
        self.assertIsNone(refreshed_work_order.item_id)

    def test_runtime_parameter_filters_support_equipment_type_scope(self) -> None:
        equipment = self._create_equipment("PARAM")
        self._create_runtime_parameter(
            "SAME-SCOPE",
            equipment_id=equipment.id,
            equipment_type="冲压机",
            is_enabled=True,
        )
        self._create_runtime_parameter(
            "TYPE-ONLY",
            equipment_id=None,
            equipment_type="冲压机",
            is_enabled=True,
        )
        self._create_runtime_parameter(
            "OTHER-TYPE",
            equipment_id=None,
            equipment_type="焊接机",
            is_enabled=True,
        )
        self._create_runtime_parameter(
            "DISABLED",
            equipment_id=equipment.id,
            equipment_type="冲压机",
            is_enabled=False,
        )

        result = list_runtime_parameters(
            self.db,
            equipment_id=equipment.id,
            equipment_type="冲压机",
            is_enabled=True,
            page=1,
            page_size=20,
        )

        self.assertEqual(result.total, 1)
        self.assertEqual(result.items[0].equipment_id, equipment.id)
        self.assertEqual(result.items[0].equipment_type, "冲压机")
        self.assertTrue(result.items[0].is_enabled)

    def test_detail_snapshots_include_plan_summary_and_record_source_context(
        self,
    ) -> None:
        stage = self._ensure_stage("laser_marking", "激光打标")
        equipment = self._create_equipment("DETAIL")
        item = self._create_item("DETAIL", default_cycle_days=30)
        plan = self._create_plan(
            equipment=equipment,
            item=item,
            stage_code=stage.code,
            cycle_days=30,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 31),
        )
        work_order, _ = generate_work_order_for_plan(self.db, row=plan)
        self.work_order_ids.append(int(work_order.id))

        work_order.result_summary = "完成"
        work_order.result_remark = "完成测试"
        work_order.completed_at = datetime(2026, 3, 31, tzinfo=UTC)
        self.db.add(
            MaintenanceRecord(
                work_order_id=work_order.id,
                source_plan_id=plan.id,
                source_plan_cycle_days=plan.cycle_days,
                source_plan_start_date=plan.start_date,
                source_equipment_id=equipment.id,
                source_equipment_code=equipment.code,
                source_equipment_name=equipment.name,
                source_item_id=item.id,
                source_item_name=item.name,
                due_date=work_order.due_date,
                executor_user_id=None,
                executor_username="tester",
                completed_at=datetime(2026, 3, 31, tzinfo=UTC),
                result_summary="完成",
                result_remark="完成测试",
                attachment_link=None,
            )
        )
        self.db.commit()

        record = (
            self.db.execute(
                select(MaintenanceRecord).where(
                    MaintenanceRecord.work_order_id == work_order.id
                )
            )
            .scalars()
            .one()
        )
        self.record_ids.append(int(record.id))

        work_order_detail = _build_work_order_detail(self.db, work_order)
        record_detail = _build_record_detail(self.db, record)

        self.assertEqual(
            _build_source_plan_summary(
                source_plan_id=plan.id,
                source_plan_cycle_days=plan.cycle_days,
                source_plan_start_date=plan.start_date,
            ),
            f"计划#{plan.id} / 周期30天 / 起始2026-03-01",
        )
        self.assertEqual(
            work_order_detail.source_plan_summary,
            f"计划#{plan.id} / 周期30天 / 起始2026-03-01",
        )
        self.assertEqual(
            record_detail.source_plan_summary, work_order_detail.source_plan_summary
        )
        self.assertEqual(record_detail.source_equipment_name, equipment.name)
        self.assertEqual(record_detail.source_execution_process_code, stage.code)
        self.assertEqual(record_detail.source_equipment_code, equipment.code)


if __name__ == "__main__":
    unittest.main()
