import sys
import time
import unittest
from unittest.mock import patch
from datetime import UTC, date, datetime
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import select


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.core.security import get_password_hash  # noqa: E402
from app.models.audit_log import AuditLog  # noqa: E402
from app.models.equipment import Equipment  # noqa: E402
from app.models.maintenance_item import MaintenanceItem  # noqa: E402
from app.models.maintenance_plan import MaintenancePlan  # noqa: E402
from app.models.maintenance_record import MaintenanceRecord  # noqa: E402
from app.models.maintenance_work_order import MaintenanceWorkOrder  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.equipment_runtime_parameter import EquipmentRuntimeParameter  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.user import User  # noqa: E402
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
    generate_due_work_orders_for_today,
    generate_work_order_for_plan,
    get_equipment_detail,
    get_maintenance_plan_by_id,
    list_maintenance_records,
    toggle_equipment,
    toggle_maintenance_item,
    update_maintenance_item,
)
from app.services.authz_service import (  # noqa: E402
    get_permission_codes_for_role_codes,
    get_role_permission_items,
    replace_role_permissions_for_module,
)
from app.services.equipment_rule_service import (  # noqa: E402
    create_runtime_parameter,
    list_runtime_parameters,
)


class EquipmentModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.db = SessionLocal()
        self._suffix = str(int(time.time() * 1000000))
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.equipment_ids: list[int] = []
        self.item_ids: list[int] = []
        self.runtime_parameter_ids: list[int] = []
        self.plan_ids: list[int] = []
        self.work_order_ids: list[int] = []
        self.record_ids: list[int] = []
        self.user_ids: list[int] = []
        self.role_ids: list[int] = []
        self.token = self._login()
        self.admin_user = (
            self.db.execute(select(User).where(User.username == "admin"))
            .scalars()
            .first()
        )
        assert self.admin_user is not None

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
            for user_id in reversed(self.user_ids):
                row = self.db.get(User, user_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for role_id in reversed(self.role_ids):
                row = self.db.get(Role, role_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for equipment_id in reversed(self.equipment_ids):
                row = self.db.get(Equipment, equipment_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for process_id in reversed(self.process_ids):
                row = self.db.get(Process, process_id)
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

    def _login(self) -> str:
        return self._login_as(username="admin", password="Admin@123456")

    def _login_as(self, *, username: str, password: str) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": username, "password": password},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _headers(self, token: str | None = None) -> dict[str, str]:
        return {"Authorization": f"Bearer {token or self.token}"}

    def _create_role(self, suffix: str) -> Role:
        row = Role(
            code=f"equipment_it_{suffix}_{int(time.time() * 1000)}",
            name=f"设备集成角色-{suffix}",
            role_type="custom",
            is_enabled=True,
            is_builtin=False,
            is_deleted=False,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.role_ids.append(int(row.id))
        return row

    def _create_process(self, *, stage: ProcessStage, label: str) -> Process:
        row = Process(
            code=f"equipment_process_{label}_{self._suffix}",
            name=f"设备测试工序-{label}-{self._suffix}",
            stage_id=stage.id,
            is_enabled=True,
            remark="设备模块集成测试",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.process_ids.append(int(row.id))
        return row

    def _create_user_with_permissions(
        self,
        *,
        suffix: str,
        permission_codes: list[str],
        processes: list[Process] | None = None,
    ) -> User:
        role = self._create_role(suffix)
        row = User(
            username=f"equipment_perm_{suffix}_{int(time.time() * 1000)}",
            full_name=f"设备权限用户-{suffix}",
            password_hash=get_password_hash("Admin@123456"),
            is_active=True,
            is_superuser=False,
            remark="设备模块集成测试",
        )
        row.roles.append(role)
        for process in processes or []:
            row.processes.append(process)
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.user_ids.append(int(row.id))
        replace_role_permissions_for_module(
            self.db,
            role_code=role.code,
            module_code="equipment",
            granted_permission_codes=permission_codes,
            operator=None,
            remark="设备模块集成测试授权",
        )
        self.db.commit()
        return row

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

    def _granted_equipment_permission_codes(self, *, role_code: str) -> list[str]:
        _, items = get_role_permission_items(
            self.db,
            role_code=role_code,
            module_code="equipment",
        )
        return [str(item["permission_code"]) for item in items if item["granted"]]

    def test_owner_option_permissions_follow_plan_and_record_features(self) -> None:
        plan_role_code = "maintenance_staff"
        record_role_code = "quality_admin"
        plan_before = self._granted_equipment_permission_codes(role_code=plan_role_code)
        record_before = self._granted_equipment_permission_codes(
            role_code=record_role_code
        )

        try:
            replace_role_permissions_for_module(
                self.db,
                role_code=plan_role_code,
                module_code="equipment",
                granted_permission_codes=["feature.equipment.plans.manage"],
                operator=None,
                remark="设备模块 RBAC 回归测试：保养计划默认执行人候选",
            )
            plan_codes = get_permission_codes_for_role_codes(
                self.db,
                role_codes=[plan_role_code],
                module_code="equipment",
            )
            self.assertIn("equipment.plan_owner_options.list", plan_codes)
            self.assertNotIn("equipment.record_executor_options.list", plan_codes)
            self.assertNotIn("equipment.admin_owners.list", plan_codes)

            replace_role_permissions_for_module(
                self.db,
                role_code=record_role_code,
                module_code="equipment",
                granted_permission_codes=["feature.equipment.records.view"],
                operator=None,
                remark="设备模块 RBAC 回归测试：保养记录执行人筛选候选",
            )
            record_codes = get_permission_codes_for_role_codes(
                self.db,
                role_codes=[record_role_code],
                module_code="equipment",
            )
            self.assertIn("equipment.record_executor_options.list", record_codes)
            self.assertNotIn("equipment.plan_owner_options.list", record_codes)
            self.assertNotIn("equipment.admin_owners.list", record_codes)
        finally:
            replace_role_permissions_for_module(
                self.db,
                role_code=plan_role_code,
                module_code="equipment",
                granted_permission_codes=plan_before,
                operator=None,
                remark="恢复设备模块 RBAC 回归测试前权限",
            )
            replace_role_permissions_for_module(
                self.db,
                role_code=record_role_code,
                module_code="equipment",
                granted_permission_codes=record_before,
                operator=None,
                remark="恢复设备模块 RBAC 回归测试前权限",
            )

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
            source_execution_process_code=hidden_stage.code,
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

        with self.assertRaisesRegex(ValueError, "Access denied"):
            ensure_work_order_view_permission(
                row=work_order,
                current_user_role_codes=["quality_admin"],
                current_user_stage_codes=[visible_stage.code],
            )

        ensure_work_order_view_permission(
            row=work_order,
            current_user_role_codes=["production_admin"],
            current_user_stage_codes=[visible_stage.code],
        )

        quality_total, quality_rows = list_maintenance_records(
            self.db,
            page=1,
            page_size=20,
            keyword=None,
            executor_user_id=None,
            result_summary=None,
            equipment_id=None,
            current_user_role_codes=["quality_admin"],
            current_user_stage_codes=[visible_stage.code],
            start_date=None,
            end_date=None,
        )
        self.assertEqual(quality_total, 0)
        self.assertEqual(quality_rows, [])

        prod_total, prod_rows = list_maintenance_records(
            self.db,
            page=1,
            page_size=20,
            keyword=None,
            executor_user_id=None,
            result_summary=None,
            equipment_id=None,
            current_user_role_codes=["production_admin"],
            current_user_stage_codes=[visible_stage.code],
            start_date=None,
            end_date=None,
        )
        self.assertEqual(prod_total, 1)
        self.assertEqual(len(prod_rows), 1)

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

    def test_equipment_detail_respects_plan_execution_record_visibility(self) -> None:
        visible_stage = self._ensure_stage("product_testing", "成品测试")
        hidden_stage = self._ensure_stage("laser_marking", "激光打标")
        equipment = self._create_equipment("DETAIL-SCOPE")
        visible_item = self._create_item("DETAIL-VISIBLE", default_cycle_days=10)
        hidden_item = self._create_item("DETAIL-HIDDEN", default_cycle_days=10)
        visible_plan = self._create_plan(
            equipment=equipment,
            item=visible_item,
            stage_code=visible_stage.code,
            cycle_days=10,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 12),
        )
        hidden_plan = self._create_plan(
            equipment=equipment,
            item=hidden_item,
            stage_code=hidden_stage.code,
            cycle_days=10,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 13),
        )
        visible_work_order, _ = generate_work_order_for_plan(self.db, row=visible_plan)
        hidden_work_order, _ = generate_work_order_for_plan(self.db, row=hidden_plan)
        self.work_order_ids.extend(
            [int(visible_work_order.id), int(hidden_work_order.id)]
        )

        hidden_record = MaintenanceRecord(
            work_order_id=hidden_work_order.id,
            source_plan_id=hidden_plan.id,
            source_plan_cycle_days=hidden_plan.cycle_days,
            source_plan_start_date=hidden_plan.start_date,
            source_equipment_id=equipment.id,
            source_equipment_code=equipment.code,
            source_equipment_name=equipment.name,
            source_item_id=hidden_item.id,
            source_item_name=hidden_item.name,
            source_execution_process_code=hidden_stage.code,
            due_date=hidden_work_order.due_date,
            executor_user_id=None,
            executor_username="tester",
            completed_at=datetime.now(UTC),
            result_summary="完成",
            result_remark="隐藏工段记录",
            attachment_link=None,
        )
        self.db.add(hidden_record)
        self.db.commit()
        self.db.refresh(hidden_record)
        self.record_ids.append(int(hidden_record.id))

        scoped_detail = get_equipment_detail(
            self.db,
            equipment.id,
            current_user_role_codes=["operator"],
            current_user_stage_codes=[visible_stage.code],
            can_view_plans=True,
            can_view_executions=True,
            can_view_records=True,
        )
        assert scoped_detail is not None
        (
            _,
            scoped_plan_count,
            scoped_work_order_count,
            plans_scope_limited,
            executions_scope_limited,
            records_scope_limited,
            scoped_plans,
            scoped_work_orders,
            scoped_records,
        ) = scoped_detail
        self.assertEqual(scoped_plan_count, 1)
        self.assertEqual(scoped_work_order_count, 1)
        self.assertEqual([plan.id for plan in scoped_plans], [visible_plan.id])
        self.assertEqual(
            [row.id for row in scoped_work_orders], [visible_work_order.id]
        )
        self.assertEqual(scoped_records, [])
        self.assertTrue(plans_scope_limited)
        self.assertTrue(executions_scope_limited)
        self.assertTrue(records_scope_limited)

        hidden_detail = get_equipment_detail(
            self.db,
            equipment.id,
            current_user_role_codes=["operator"],
            current_user_stage_codes=[visible_stage.code],
            can_view_plans=False,
            can_view_executions=False,
            can_view_records=False,
        )
        assert hidden_detail is not None
        self.assertEqual(hidden_detail[1], 0)
        self.assertEqual(hidden_detail[2], 0)
        self.assertEqual(hidden_detail[6], [])
        self.assertEqual(hidden_detail[7], [])
        self.assertEqual(hidden_detail[8], [])

        quality_detail = get_equipment_detail(
            self.db,
            equipment.id,
            current_user_role_codes=["quality_admin"],
            current_user_stage_codes=[visible_stage.code],
            can_view_plans=True,
            can_view_executions=True,
            can_view_records=True,
        )
        assert quality_detail is not None
        self.assertEqual(quality_detail[1], 1)
        self.assertEqual(quality_detail[2], 1)
        self.assertEqual([plan.id for plan in quality_detail[6]], [visible_plan.id])
        self.assertEqual(
            [row.id for row in quality_detail[7]],
            [visible_work_order.id],
        )
        self.assertEqual(quality_detail[8], [])
        self.assertTrue(quality_detail[3])
        self.assertTrue(quality_detail[4])
        self.assertTrue(quality_detail[5])

        production_detail = get_equipment_detail(
            self.db,
            equipment.id,
            current_user_role_codes=["production_admin"],
            current_user_stage_codes=[visible_stage.code],
            can_view_plans=True,
            can_view_executions=True,
            can_view_records=True,
        )
        assert production_detail is not None
        self.assertEqual(production_detail[1], 2)
        self.assertEqual(production_detail[2], 2)
        self.assertEqual(len(production_detail[6]), 2)
        self.assertEqual(len(production_detail[7]), 2)
        self.assertEqual(len(production_detail[8]), 1)
        self.assertFalse(production_detail[3])
        self.assertFalse(production_detail[4])
        self.assertFalse(production_detail[5])

    def test_auto_generate_persists_summary_and_plan_traces(self) -> None:
        success_stage = self._ensure_stage("product_testing", "成品测试")
        failing_stage = self._ensure_stage("laser_marking", "激光打标")
        equipment = self._create_equipment("AUTO")
        success_item = self._create_item("AUTO-SUCCESS", default_cycle_days=7)
        existing_item = self._create_item("AUTO-EXISTING", default_cycle_days=7)
        failing_item = self._create_item("AUTO-FAIL", default_cycle_days=7)
        success_plan = self._create_plan(
            equipment=equipment,
            item=success_item,
            stage_code=success_stage.code,
            cycle_days=7,
            start_date=date(2026, 3, 1),
            next_due_date=date.today(),
        )
        existing_plan = self._create_plan(
            equipment=equipment,
            item=existing_item,
            stage_code=success_stage.code,
            cycle_days=7,
            start_date=date(2026, 3, 1),
            next_due_date=date.today(),
        )
        failing_plan = self._create_plan(
            equipment=equipment,
            item=failing_item,
            stage_code=failing_stage.code,
            cycle_days=7,
            start_date=date(2026, 3, 1),
            next_due_date=date.today(),
        )
        existing_work_order, _ = generate_work_order_for_plan(
            self.db, row=existing_plan
        )
        self.work_order_ids.append(int(existing_work_order.id))
        existing_plan.next_due_date = date.today()
        self.db.commit()

        original_generate = generate_work_order_for_plan

        def _patched_generate_work_order_for_plan(db, *, row):
            if row.id == failing_plan.id:
                raise ValueError("模拟失败：计划工段缺失")
            return original_generate(db, row=row)

        with (
            patch(
                "tests.test_equipment_module_integration.generate_work_order_for_plan",
                side_effect=_patched_generate_work_order_for_plan,
            ),
            patch(
                "app.services.equipment_service.generate_work_order_for_plan",
                side_effect=_patched_generate_work_order_for_plan,
            ),
        ):
            total, created, existing, failed, new_orders, traces = (
                generate_due_work_orders_for_today(self.db, include_new_orders=True)
            )

        self.work_order_ids.extend(
            [
                int(work_order.id)
                for work_order in new_orders
                if work_order.id not in self.work_order_ids
            ]
        )
        self.assertEqual(total, 3)
        self.assertEqual(created, 1)
        self.assertEqual(existing, 1)
        self.assertEqual(failed, 1)
        self.assertEqual(len(new_orders), 1)
        trace_by_plan = {trace.plan_id: trace for trace in traces}
        self.assertEqual(trace_by_plan[success_plan.id].result, "created")
        self.assertEqual(trace_by_plan[existing_plan.id].result, "skipped_existing")
        self.assertEqual(trace_by_plan[failing_plan.id].result, "failed")
        failure_message = trace_by_plan[failing_plan.id].message
        assert failure_message is not None
        self.assertIn("模拟失败", failure_message)

        audit_rows = (
            self.db.execute(
                select(AuditLog).where(
                    AuditLog.action_code.in_(
                        [
                            "equipment.maintenance.auto_generate.run",
                            "equipment.maintenance.auto_generate.plan",
                        ]
                    )
                )
            )
            .scalars()
            .all()
        )
        summary_rows = [
            row
            for row in audit_rows
            if row.action_code == "equipment.maintenance.auto_generate.run"
        ]
        detail_rows = [
            row
            for row in audit_rows
            if row.action_code == "equipment.maintenance.auto_generate.plan"
            and row.target_id
            in {str(success_plan.id), str(existing_plan.id), str(failing_plan.id)}
        ]
        self.assertTrue(summary_rows)
        self.assertEqual(len(detail_rows), 3)
        latest_summary = max(summary_rows, key=lambda row: row.id)
        assert latest_summary.after_data is not None
        self.assertEqual(latest_summary.after_data["created_count"], 1)
        self.assertEqual(latest_summary.after_data["existing_count"], 1)
        self.assertEqual(latest_summary.after_data["failed_count"], 1)

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
        work_order.attachment_link = (
            "https://example.com/work-order/equipment-detail.pdf"
        )
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
                source_execution_process_code=stage.code,
                due_date=work_order.due_date,
                executor_user_id=None,
                executor_username="tester",
                completed_at=datetime(2026, 3, 31, tzinfo=UTC),
                result_summary="完成",
                result_remark="完成测试",
                attachment_link="https://example.com/work-order/equipment-detail.pdf",
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
        self.assertEqual(work_order_detail.attachment_name, "equipment-detail.pdf")
        self.assertEqual(
            record_detail.source_plan_summary, work_order_detail.source_plan_summary
        )
        self.assertEqual(record_detail.attachment_name, "equipment-detail.pdf")
        self.assertEqual(record_detail.source_equipment_name, equipment.name)
        self.assertEqual(record_detail.source_execution_process_code, stage.code)
        self.assertEqual(record_detail.source_equipment_code, equipment.code)

        self.db.delete(work_order)
        self.db.commit()
        self.work_order_ids.remove(int(work_order.id))

        standalone_detail = _build_record_detail(self.db, record)
        self.assertEqual(standalone_detail.source_execution_process_code, stage.code)

    def test_equipment_api_ledger_items_plans_generate_and_permission_boundaries(
        self,
    ) -> None:
        stage = self._ensure_stage("laser_marking", "激光打标")
        admin_headers = self._headers()

        ledger_response = self.client.post(
            "/api/v1/equipment/ledger",
            headers=admin_headers,
            json={
                "code": f"EQ-API-{self._suffix}",
                "name": f"设备 API 台账-{self._suffix}",
                "model": "MODEL-API",
                "location": "API 车间",
                "owner_name": "admin",
                "remark": "设备模块 API 集成测试",
            },
        )
        self.assertEqual(ledger_response.status_code, 201, ledger_response.text)
        equipment_id = int(ledger_response.json()["data"]["id"])
        self.equipment_ids.append(equipment_id)

        ledger_list_response = self.client.get(
            "/api/v1/equipment/ledger",
            headers=admin_headers,
            params={"keyword": f"EQ-API-{self._suffix}"},
        )
        self.assertEqual(
            ledger_list_response.status_code, 200, ledger_list_response.text
        )
        self.assertEqual(ledger_list_response.json()["data"]["total"], 1)

        ledger_update_response = self.client.put(
            f"/api/v1/equipment/ledger/{equipment_id}",
            headers=admin_headers,
            json={
                "code": f"EQ-API-{self._suffix}",
                "name": f"设备 API 台账已更新-{self._suffix}",
                "model": "MODEL-API-2",
                "location": "更新车间",
                "owner_name": "admin",
                "remark": "更新后",
            },
        )
        self.assertEqual(
            ledger_update_response.status_code, 200, ledger_update_response.text
        )
        self.assertEqual(
            ledger_update_response.json()["data"]["location"],
            "更新车间",
        )

        ledger_toggle_response = self.client.post(
            f"/api/v1/equipment/ledger/{equipment_id}/toggle",
            headers=admin_headers,
            json={"enabled": False},
        )
        self.assertEqual(
            ledger_toggle_response.status_code, 200, ledger_toggle_response.text
        )
        self.assertFalse(ledger_toggle_response.json()["data"]["is_enabled"])

        item_response = self.client.post(
            "/api/v1/equipment/items",
            headers=admin_headers,
            json={
                "name": f"设备 API 项目-{self._suffix}",
                "default_cycle_days": 14,
                "category": "点检",
                "default_duration_minutes": 35,
                "standard_description": "API 项目创建",
            },
        )
        self.assertEqual(item_response.status_code, 201, item_response.text)
        item_id = int(item_response.json()["data"]["id"])
        self.item_ids.append(item_id)

        item_list_response = self.client.get(
            "/api/v1/equipment/items",
            headers=admin_headers,
            params={"category": "点检", "keyword": self._suffix},
        )
        self.assertEqual(item_list_response.status_code, 200, item_list_response.text)
        self.assertGreaterEqual(item_list_response.json()["data"]["total"], 1)

        item_update_response = self.client.put(
            f"/api/v1/equipment/items/{item_id}",
            headers=admin_headers,
            json={
                "name": f"设备 API 项目已更新-{self._suffix}",
                "default_cycle_days": 21,
                "category": "保养",
                "default_duration_minutes": 45,
                "standard_description": "API 项目更新",
            },
        )
        self.assertEqual(
            item_update_response.status_code, 200, item_update_response.text
        )
        self.assertEqual(item_update_response.json()["data"]["category"], "保养")

        item_toggle_response = self.client.post(
            f"/api/v1/equipment/items/{item_id}/toggle",
            headers=admin_headers,
            json={"enabled": False},
        )
        self.assertEqual(
            item_toggle_response.status_code, 200, item_toggle_response.text
        )
        self.assertFalse(item_toggle_response.json()["data"]["is_enabled"])

        self.client.post(
            f"/api/v1/equipment/ledger/{equipment_id}/toggle",
            headers=admin_headers,
            json={"enabled": True},
        )
        self.client.post(
            f"/api/v1/equipment/items/{item_id}/toggle",
            headers=admin_headers,
            json={"enabled": True},
        )

        plan_response = self.client.post(
            "/api/v1/equipment/plans",
            headers=admin_headers,
            json={
                "equipment_id": equipment_id,
                "item_id": item_id,
                "cycle_days": 10,
                "execution_process_code": stage.code,
                "estimated_duration_minutes": 60,
                "start_date": "2026-03-01",
                "next_due_date": "2026-03-10",
                "default_executor_user_id": None,
            },
        )
        self.assertEqual(plan_response.status_code, 201, plan_response.text)
        plan_id = int(plan_response.json()["data"]["id"])
        self.plan_ids.append(plan_id)

        plan_list_response = self.client.get(
            "/api/v1/equipment/plans",
            headers=admin_headers,
            params={
                "equipment_id": equipment_id,
                "execution_process_code": stage.code,
            },
        )
        self.assertEqual(plan_list_response.status_code, 200, plan_list_response.text)
        self.assertEqual(plan_list_response.json()["data"]["total"], 1)

        plan_update_response = self.client.put(
            f"/api/v1/equipment/plans/{plan_id}",
            headers=admin_headers,
            json={
                "equipment_id": equipment_id,
                "item_id": item_id,
                "cycle_days": 12,
                "execution_process_code": stage.code,
                "estimated_duration_minutes": 75,
                "start_date": "2026-03-01",
                "next_due_date": "2026-03-12",
                "default_executor_user_id": None,
            },
        )
        self.assertEqual(
            plan_update_response.status_code, 200, plan_update_response.text
        )
        self.assertEqual(plan_update_response.json()["data"]["cycle_days"], 12)

        plan_toggle_response = self.client.post(
            f"/api/v1/equipment/plans/{plan_id}/toggle",
            headers=admin_headers,
            json={"enabled": False},
        )
        self.assertEqual(
            plan_toggle_response.status_code, 200, plan_toggle_response.text
        )
        self.assertFalse(plan_toggle_response.json()["data"]["is_enabled"])

        plan_toggle_back_response = self.client.post(
            f"/api/v1/equipment/plans/{plan_id}/toggle",
            headers=admin_headers,
            json={"enabled": True},
        )
        self.assertEqual(
            plan_toggle_back_response.status_code,
            200,
            plan_toggle_back_response.text,
        )

        self.client.post(
            f"/api/v1/equipment/ledger/{equipment_id}/toggle",
            headers=admin_headers,
            json={"enabled": False},
        )
        generate_disabled_response = self.client.post(
            f"/api/v1/equipment/plans/{plan_id}/generate",
            headers=admin_headers,
        )
        self.assertEqual(
            generate_disabled_response.status_code,
            400,
            generate_disabled_response.text,
        )
        self.assertIn("Equipment is disabled", generate_disabled_response.text)

        self.client.post(
            f"/api/v1/equipment/ledger/{equipment_id}/toggle",
            headers=admin_headers,
            json={"enabled": True},
        )
        generate_response = self.client.post(
            f"/api/v1/equipment/plans/{plan_id}/generate",
            headers=admin_headers,
        )
        self.assertEqual(generate_response.status_code, 200, generate_response.text)
        self.assertTrue(generate_response.json()["data"]["created"])
        self.work_order_ids.append(
            int(generate_response.json()["data"]["work_order_id"])
        )

        delete_plan_response = self.client.delete(
            f"/api/v1/equipment/plans/{plan_id}",
            headers=admin_headers,
        )
        self.assertEqual(
            delete_plan_response.status_code, 400, delete_plan_response.text
        )

        disposable_equipment = self._create_equipment("API-DELETE")
        disposable_item = self._create_item("API-DELETE", default_cycle_days=9)
        disposable_plan = self._create_plan(
            equipment=disposable_equipment,
            item=disposable_item,
            stage_code=stage.code,
            cycle_days=9,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 9),
        )
        delete_plan_ok_response = self.client.delete(
            f"/api/v1/equipment/plans/{disposable_plan.id}",
            headers=admin_headers,
        )
        self.assertEqual(
            delete_plan_ok_response.status_code, 200, delete_plan_ok_response.text
        )
        self.plan_ids.remove(int(disposable_plan.id))

        delete_item_ok_response = self.client.delete(
            f"/api/v1/equipment/items/{disposable_item.id}",
            headers=admin_headers,
        )
        self.assertEqual(
            delete_item_ok_response.status_code, 200, delete_item_ok_response.text
        )
        self.item_ids.remove(int(disposable_item.id))

        delete_equipment_ok_response = self.client.delete(
            f"/api/v1/equipment/ledger/{disposable_equipment.id}",
            headers=admin_headers,
        )
        self.assertEqual(
            delete_equipment_ok_response.status_code,
            200,
            delete_equipment_ok_response.text,
        )
        self.equipment_ids.remove(int(disposable_equipment.id))

        limited_user = self._create_user_with_permissions(
            suffix="api_readonly",
            permission_codes=[
                "equipment.ledger.list",
                "equipment.items.list",
                "equipment.plans.list",
            ],
        )
        limited_headers = self._headers(
            self._login_as(username=limited_user.username, password="Admin@123456")
        )

        readonly_ledger_response = self.client.get(
            "/api/v1/equipment/ledger",
            headers=limited_headers,
        )
        self.assertEqual(
            readonly_ledger_response.status_code, 200, readonly_ledger_response.text
        )

        readonly_create_response = self.client.post(
            "/api/v1/equipment/ledger",
            headers=limited_headers,
            json={
                "code": f"EQ-DENY-{self._suffix}",
                "name": f"越权台账-{self._suffix}",
                "model": "DENY",
                "location": "禁止区域",
                "owner_name": "readonly",
                "remark": "不应允许",
            },
        )
        self.assertEqual(
            readonly_create_response.status_code, 403, readonly_create_response.text
        )

        readonly_generate_response = self.client.post(
            f"/api/v1/equipment/plans/{plan_id}/generate",
            headers=limited_headers,
        )
        self.assertEqual(
            readonly_generate_response.status_code,
            403,
            readonly_generate_response.text,
        )

    def test_equipment_api_rules_and_runtime_parameters_crud_filters_and_permissions(
        self,
    ) -> None:
        equipment = self._create_equipment("RULEAPI")
        admin_headers = self._headers()

        create_rule_response = self.client.post(
            "/api/v1/equipment/rules",
            headers=admin_headers,
            json={
                "equipment_id": equipment.id,
                "equipment_type": "冲压机",
                "rule_code": f"RULE-{self._suffix}",
                "rule_name": f"规则-{self._suffix}",
                "rule_type": "点检",
                "condition_desc": "温度超过阈值",
                "is_enabled": True,
                "effective_at": None,
                "remark": "规则创建",
            },
        )
        self.assertEqual(
            create_rule_response.status_code, 200, create_rule_response.text
        )
        rule_id = int(create_rule_response.json()["data"]["id"])

        list_rule_response = self.client.get(
            "/api/v1/equipment/rules",
            headers=admin_headers,
            params={
                "equipment_id": equipment.id,
                "keyword": self._suffix,
                "is_enabled": True,
            },
        )
        self.assertEqual(list_rule_response.status_code, 200, list_rule_response.text)
        self.assertEqual(list_rule_response.json()["data"]["total"], 1)

        update_rule_response = self.client.put(
            f"/api/v1/equipment/rules/{rule_id}",
            headers=admin_headers,
            json={
                "equipment_id": equipment.id,
                "equipment_type": "冲压机",
                "rule_code": f"RULE-{self._suffix}",
                "rule_name": f"规则已更新-{self._suffix}",
                "rule_type": "保养",
                "condition_desc": "振动超过阈值",
                "is_enabled": True,
                "effective_at": None,
                "remark": "规则更新",
            },
        )
        self.assertEqual(
            update_rule_response.status_code, 200, update_rule_response.text
        )
        self.assertEqual(update_rule_response.json()["data"]["rule_type"], "保养")

        toggle_rule_response = self.client.patch(
            f"/api/v1/equipment/rules/{rule_id}/toggle",
            headers=admin_headers,
            json={"enabled": False},
        )
        self.assertEqual(
            toggle_rule_response.status_code, 200, toggle_rule_response.text
        )
        self.assertFalse(toggle_rule_response.json()["data"]["is_enabled"])

        create_param_response = self.client.post(
            "/api/v1/equipment/runtime-parameters",
            headers=admin_headers,
            json={
                "equipment_id": equipment.id,
                "equipment_type": "冲压机",
                "param_code": f"PARAM-{self._suffix}",
                "param_name": f"参数-{self._suffix}",
                "unit": "mm",
                "standard_value": 1.1,
                "upper_limit": 2.2,
                "lower_limit": 0.8,
                "effective_at": None,
                "is_enabled": True,
                "remark": "参数创建",
            },
        )
        self.assertEqual(
            create_param_response.status_code, 200, create_param_response.text
        )
        param_id = int(create_param_response.json()["data"]["id"])
        self.runtime_parameter_ids.append(param_id)

        list_param_response = self.client.get(
            "/api/v1/equipment/runtime-parameters",
            headers=admin_headers,
            params={
                "equipment_id": equipment.id,
                "equipment_type": "冲压机",
                "keyword": self._suffix,
                "is_enabled": True,
            },
        )
        self.assertEqual(list_param_response.status_code, 200, list_param_response.text)
        self.assertEqual(list_param_response.json()["data"]["total"], 1)

        update_param_response = self.client.put(
            f"/api/v1/equipment/runtime-parameters/{param_id}",
            headers=admin_headers,
            json={
                "equipment_id": equipment.id,
                "equipment_type": "冲压机",
                "param_code": f"PARAM-{self._suffix}",
                "param_name": f"参数已更新-{self._suffix}",
                "unit": "bar",
                "standard_value": 1.5,
                "upper_limit": 2.5,
                "lower_limit": 1.0,
                "effective_at": None,
                "is_enabled": True,
                "remark": "参数更新",
            },
        )
        self.assertEqual(
            update_param_response.status_code, 200, update_param_response.text
        )
        self.assertEqual(update_param_response.json()["data"]["unit"], "bar")

        toggle_param_response = self.client.patch(
            f"/api/v1/equipment/runtime-parameters/{param_id}/toggle",
            headers=admin_headers,
            json={"enabled": False},
        )
        self.assertEqual(
            toggle_param_response.status_code, 200, toggle_param_response.text
        )
        self.assertFalse(toggle_param_response.json()["data"]["is_enabled"])

        limited_user = self._create_user_with_permissions(
            suffix="rule_readonly",
            permission_codes=[
                "equipment.rules.list",
                "equipment.runtime_parameters.list",
            ],
        )
        limited_headers = self._headers(
            self._login_as(username=limited_user.username, password="Admin@123456")
        )

        readonly_rules_response = self.client.get(
            "/api/v1/equipment/rules",
            headers=limited_headers,
        )
        self.assertEqual(
            readonly_rules_response.status_code, 200, readonly_rules_response.text
        )

        readonly_rule_create_response = self.client.post(
            "/api/v1/equipment/rules",
            headers=limited_headers,
            json={
                "equipment_id": equipment.id,
                "equipment_type": "冲压机",
                "rule_code": f"RULE-DENY-{self._suffix}",
                "rule_name": f"越权规则-{self._suffix}",
                "rule_type": "点检",
                "condition_desc": "不应允许",
                "is_enabled": True,
                "effective_at": None,
                "remark": "越权",
            },
        )
        self.assertEqual(
            readonly_rule_create_response.status_code,
            403,
            readonly_rule_create_response.text,
        )

        readonly_param_toggle_response = self.client.patch(
            f"/api/v1/equipment/runtime-parameters/{param_id}/toggle",
            headers=limited_headers,
            json={"enabled": True},
        )
        self.assertEqual(
            readonly_param_toggle_response.status_code,
            403,
            readonly_param_toggle_response.text,
        )

        delete_rule_response = self.client.delete(
            f"/api/v1/equipment/rules/{rule_id}",
            headers=admin_headers,
        )
        self.assertEqual(
            delete_rule_response.status_code, 200, delete_rule_response.text
        )

        delete_param_response = self.client.delete(
            f"/api/v1/equipment/runtime-parameters/{param_id}",
            headers=admin_headers,
        )
        self.assertEqual(
            delete_param_response.status_code, 200, delete_param_response.text
        )
        self.runtime_parameter_ids.remove(param_id)

    def test_equipment_api_executions_records_actions_and_scope_boundaries(
        self,
    ) -> None:
        visible_stage = self._ensure_stage("product_testing", "成品测试")
        hidden_stage = self._ensure_stage("laser_marking", "激光打标")
        visible_process = self._create_process(stage=visible_stage, label="visible")
        equipment = self._create_equipment("EXECAPI")
        visible_item = self._create_item("EXEC-VISIBLE", default_cycle_days=8)
        cancel_item = self._create_item("EXEC-CANCEL", default_cycle_days=9)
        hidden_item = self._create_item("EXEC-HIDDEN", default_cycle_days=7)
        visible_plan = self._create_plan(
            equipment=equipment,
            item=visible_item,
            stage_code=visible_stage.code,
            cycle_days=8,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 8),
        )
        cancel_plan = self._create_plan(
            equipment=equipment,
            item=cancel_item,
            stage_code=visible_stage.code,
            cycle_days=9,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 9),
        )
        hidden_plan = self._create_plan(
            equipment=equipment,
            item=hidden_item,
            stage_code=hidden_stage.code,
            cycle_days=7,
            start_date=date(2026, 3, 1),
            next_due_date=date(2026, 3, 7),
        )
        visible_work_order, _ = generate_work_order_for_plan(self.db, row=visible_plan)
        cancel_work_order_row, _ = generate_work_order_for_plan(
            self.db, row=cancel_plan
        )
        hidden_work_order, _ = generate_work_order_for_plan(self.db, row=hidden_plan)
        self.work_order_ids.extend(
            [
                int(visible_work_order.id),
                int(cancel_work_order_row.id),
                int(hidden_work_order.id),
            ]
        )

        scoped_user = self._create_user_with_permissions(
            suffix="exec_scope",
            permission_codes=[
                "equipment.executions.list",
                "equipment.executions.start",
                "equipment.executions.complete",
                "equipment.executions.cancel",
                "equipment.records.list",
            ],
            processes=[visible_process],
        )
        scoped_headers = self._headers(
            self._login_as(username=scoped_user.username, password="Admin@123456")
        )

        executions_response = self.client.get(
            "/api/v1/equipment/executions",
            headers=scoped_headers,
            params={"status": "overdue", "stage_code": visible_stage.code},
        )
        self.assertEqual(executions_response.status_code, 200, executions_response.text)
        self.assertEqual(executions_response.json()["data"]["total"], 2)

        hidden_detail_response = self.client.get(
            f"/api/v1/equipment/executions/{hidden_work_order.id}/detail",
            headers=scoped_headers,
        )
        self.assertEqual(
            hidden_detail_response.status_code, 403, hidden_detail_response.text
        )

        hidden_start_response = self.client.post(
            f"/api/v1/equipment/executions/{hidden_work_order.id}/start",
            headers=scoped_headers,
        )
        self.assertEqual(
            hidden_start_response.status_code, 403, hidden_start_response.text
        )

        start_response = self.client.post(
            f"/api/v1/equipment/executions/{visible_work_order.id}/start",
            headers=scoped_headers,
        )
        self.assertEqual(start_response.status_code, 200, start_response.text)
        self.assertEqual(start_response.json()["data"]["status"], "in_progress")

        complete_response = self.client.post(
            f"/api/v1/equipment/executions/{visible_work_order.id}/complete",
            headers=scoped_headers,
            json={
                "result_summary": "完成",
                "result_remark": "API 完成",
                "attachment_link": "https://example.com/equipment/exec-complete.pdf",
            },
        )
        self.assertEqual(complete_response.status_code, 200, complete_response.text)
        self.assertEqual(complete_response.json()["data"]["status"], "done")

        visible_detail_response = self.client.get(
            f"/api/v1/equipment/executions/{visible_work_order.id}/detail",
            headers=scoped_headers,
        )
        self.assertEqual(
            visible_detail_response.status_code, 200, visible_detail_response.text
        )
        self.assertEqual(
            visible_detail_response.json()["data"]["source_execution_process_code"],
            visible_stage.code,
        )
        self.assertIn(
            "计划#",
            visible_detail_response.json()["data"]["source_plan_summary"],
        )

        cancel_response = self.client.post(
            f"/api/v1/equipment/executions/{cancel_work_order_row.id}/cancel",
            headers=scoped_headers,
        )
        self.assertEqual(cancel_response.status_code, 200, cancel_response.text)
        self.assertEqual(cancel_response.json()["data"]["status"], "cancelled")

        records_response = self.client.get(
            "/api/v1/equipment/records",
            headers=scoped_headers,
            params={"result_summary": "完成", "equipment_id": equipment.id},
        )
        self.assertEqual(records_response.status_code, 200, records_response.text)
        self.assertEqual(records_response.json()["data"]["total"], 1)
        record_id = int(records_response.json()["data"]["items"][0]["id"])
        self.record_ids.append(record_id)

        record_detail_response = self.client.get(
            f"/api/v1/equipment/records/{record_id}/detail",
            headers=scoped_headers,
        )
        self.assertEqual(
            record_detail_response.status_code, 200, record_detail_response.text
        )
        self.assertEqual(
            record_detail_response.json()["data"]["source_execution_process_code"],
            visible_stage.code,
        )

        hidden_record = MaintenanceRecord(
            work_order_id=hidden_work_order.id,
            source_plan_id=hidden_plan.id,
            source_plan_cycle_days=hidden_plan.cycle_days,
            source_plan_start_date=hidden_plan.start_date,
            source_equipment_id=equipment.id,
            source_equipment_code=equipment.code,
            source_equipment_name=equipment.name,
            source_item_id=hidden_item.id,
            source_item_name=hidden_item.name,
            source_execution_process_code=hidden_stage.code,
            due_date=hidden_work_order.due_date,
            executor_user_id=None,
            executor_username="hidden-user",
            completed_at=datetime.now(UTC),
            result_summary="完成",
            result_remark="隐藏记录",
            attachment_link=None,
        )
        self.db.add(hidden_record)
        self.db.commit()
        self.db.refresh(hidden_record)
        self.record_ids.append(int(hidden_record.id))

        hidden_record_detail_response = self.client.get(
            f"/api/v1/equipment/records/{hidden_record.id}/detail",
            headers=scoped_headers,
        )
        self.assertEqual(
            hidden_record_detail_response.status_code,
            403,
            hidden_record_detail_response.text,
        )

        invalid_date_response = self.client.get(
            "/api/v1/equipment/records",
            headers=scoped_headers,
            params={"start_date": "2026-03-10", "end_date": "2026-03-01"},
        )
        self.assertEqual(
            invalid_date_response.status_code, 400, invalid_date_response.text
        )

        readonly_user = self._create_user_with_permissions(
            suffix="record_readonly",
            permission_codes=["equipment.records.list"],
            processes=[visible_process],
        )
        readonly_headers = self._headers(
            self._login_as(username=readonly_user.username, password="Admin@123456")
        )
        readonly_cancel_response = self.client.post(
            f"/api/v1/equipment/executions/{cancel_work_order_row.id}/cancel",
            headers=readonly_headers,
        )
        self.assertEqual(
            readonly_cancel_response.status_code,
            403,
            readonly_cancel_response.text,
        )


if __name__ == "__main__":
    unittest.main()
