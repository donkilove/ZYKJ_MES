import base64
import csv
import io
import json
import sys
import time
import unittest
from datetime import UTC, date, datetime
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import text


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.main import app  # noqa: E402
from app.core.security import get_password_hash  # noqa: E402
from app.models.daily_verification_code import DailyVerificationCode  # noqa: E402
from app.models.first_article_record import FirstArticleRecord  # noqa: E402
from app.models.first_article_template import FirstArticleTemplate  # noqa: E402
from app.models.order_sub_order_pipeline_instance import (  # noqa: E402
    ProcessPipelineInstance,
)
from app.models.order_event_log import OrderEventLog  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.production_assist_authorization import (  # noqa: E402
    ProductionAssistAuthorization,
)
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.production_record import ProductionRecord  # noqa: E402
from app.models.production_scrap_statistics import (  # noqa: E402
    ProductionScrapStatistics,
)
from app.models.production_sub_order import ProductionSubOrder  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon  # noqa: E402
from app.models.repair_order import RepairOrder  # noqa: E402
from app.models.supplier import Supplier  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.authz_service import replace_role_permissions_for_module  # noqa: E402
from app.services.bootstrap_seed_service import seed_initial_data  # noqa: E402
from app.services.perf_sample_seed_service import seed_production_craft_samples  # noqa: E402


PERF_CONTEXT_PATH = BACKEND_DIR.parent / ".tmp_runtime" / "production_craft_samples.json"


def load_perf_sample_context() -> dict[str, int | str]:
    db = SessionLocal()
    try:
        context = seed_production_craft_samples(db, run_id="baseline").context
    finally:
        db.close()
    PERF_CONTEXT_PATH.parent.mkdir(parents=True, exist_ok=True)
    PERF_CONTEXT_PATH.write_text(
        json.dumps(context, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return context


class ProductionModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self._previous_jwt_secret_key = settings.jwt_secret_key
        settings.jwt_secret_key = "production-module-test-secret"
        self._ensure_admin()
        self.token = self._login()
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []
        self.supplier_ids: list[int] = []
        self.order_ids: list[int] = []
        self.repair_order_ids: list[int] = []
        self.scrap_statistics_ids: list[int] = []
        self.user_ids: list[int] = []
        self.role_ids: list[int] = []

    def tearDown(self) -> None:
        settings.jwt_secret_key = self._previous_jwt_secret_key
        db = SessionLocal()
        try:
            for scrap_id in reversed(self.scrap_statistics_ids):
                row = db.get(ProductionScrapStatistics, scrap_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for repair_order_id in reversed(self.repair_order_ids):
                row = db.get(RepairOrder, repair_order_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for order_id in reversed(self.order_ids):
                row = db.get(ProductionOrder, order_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for user_id in reversed(self.user_ids):
                row = db.get(User, user_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for role_id in reversed(self.role_ids):
                row = db.get(Role, role_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for supplier_id in reversed(self.supplier_ids):
                row = db.get(Supplier, supplier_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for product_id in reversed(self.product_ids):
                row = db.get(Product, product_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for process_id in reversed(self.process_ids):
                row = db.get(Process, process_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for stage_id in reversed(self.stage_ids):
                row = db.get(ProcessStage, stage_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
        finally:
            db.close()

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def _ensure_admin(self) -> None:
        db = SessionLocal()
        try:
            seed_initial_data(
                db,
                admin_username="admin",
                admin_password="Admin@123456",
            )
        finally:
            db.close()

    def _login(self) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _login_as(self, *, username: str, password: str = "Admin@123456") -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": username, "password": password},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _admin_user(self) -> User:
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.username == "admin").first()
            assert user is not None
            db.expunge(user)
            return user
        finally:
            db.close()

    def _create_stage(self, suffix: str) -> dict:
        unique = f"PRD-ST-{suffix}-{int(time.time() * 1000)}"
        response = self.client.post(
            "/api/v1/craft/stages",
            headers=self._headers(),
            json={
                "code": unique,
                "name": unique,
                "sort_order": 0,
                "remark": "生产集成测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.stage_ids.append(int(row["id"]))
        return row

    def _create_process(self, *, stage_id: int, stage_code: str, suffix: str) -> dict:
        serial = "01" if suffix.endswith("1") or suffix in {"A", "B"} else "02"
        unique = f"{stage_code}-{serial}"
        response = self.client.post(
            "/api/v1/craft/processes",
            headers=self._headers(),
            json={
                "code": unique,
                "name": unique,
                "stage_id": stage_id,
                "remark": "生产集成测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.process_ids.append(int(row["id"]))
        return row

    def _create_product(self, suffix: str) -> dict:
        unique = f"生产模块产品{suffix}{int(time.time() * 1000)}"
        response = self.client.post(
            "/api/v1/products",
            headers=self._headers(),
            json={"name": unique, "category": "贴片", "remark": "生产集成测试"},
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.product_ids.append(int(row["id"]))
        return row

    def _activate_product(self, product: dict) -> dict:
        version = int(product.get("current_version", 1))
        expected_effective_version = int(product.get("effective_version", 0) or 0)
        with patch("app.api.v1.endpoints.products.create_message_for_users"):
            response = self.client.post(
                f"/api/v1/products/{product['id']}/versions/{version}/activate",
                headers=self._headers(),
                json={
                    "confirmed": True,
                    "expected_effective_version": expected_effective_version,
                },
            )
        self.assertEqual(response.status_code, 200, response.text)
        activated = response.json()["data"]

        detail_response = self.client.get(
            f"/api/v1/products/{product['id']}",
            headers=self._headers(),
        )
        self.assertEqual(detail_response.status_code, 200, detail_response.text)
        detail = detail_response.json()["data"]
        self.assertEqual(detail["lifecycle_status"], "active")
        self.assertEqual(int(detail["effective_version"]), version)
        return activated

    def _create_order(self, *, product_id: int, steps: list[dict]) -> dict:
        order_code = f"PO-IT-{int(time.time() * 1000)}"
        supplier = self._create_supplier(f"订单供应商{order_code[-6:]}")
        with patch("app.services.production_order_service.create_message_for_users"):
            response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": order_code,
                    "product_id": product_id,
                    "supplier_id": supplier["id"],
                    "quantity": 10,
                    "process_steps": steps,
                },
            )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.order_ids.append(int(row["id"]))
        return row

    def test_perf_seeded_order_supports_detail_first_article_and_end_production(self) -> None:
        context = load_perf_sample_context()

        detail_response = self.client.get(
            f"/api/v1/production/orders/{context['production_order_id']}",
            headers=self._headers(),
        )
        templates_response = self.client.get(
            f"/api/v1/production/orders/{context['production_order_id']}/first-article/templates",
            params={"order_process_id": context["order_process_id"]},
            headers=self._headers(),
        )
        parameters_response = self.client.get(
            f"/api/v1/production/orders/{context['production_order_id']}/first-article/parameters",
            params={"order_process_id": context["order_process_id"]},
            headers=self._headers(),
        )

        self.assertEqual(detail_response.status_code, 200, detail_response.text)
        self.assertEqual(templates_response.status_code, 200, templates_response.text)
        self.assertEqual(parameters_response.status_code, 200, parameters_response.text)

    def _create_supplier(self, name: str, *, is_enabled: bool = True) -> dict:
        response = self.client.post(
            "/api/v1/quality/suppliers",
            headers=self._headers(),
            json={"name": name, "remark": "生产集成测试", "is_enabled": is_enabled},
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.supplier_ids.append(int(row["id"]))
        return row

    def _create_active_user(self, suffix: str) -> User:
        db = SessionLocal()
        try:
            row = User(
                username=f"production_user_{suffix}_{int(time.time() * 1000)}",
                full_name=f"生产参与人-{suffix}",
                password_hash="test-password-hash",
                is_active=True,
                is_superuser=False,
                remark="生产集成测试",
            )
            db.add(row)
            db.commit()
            db.refresh(row)
            db.expunge(row)
            self.user_ids.append(int(row.id))
            return row
        finally:
            db.close()

    def _create_role(self, suffix: str) -> Role:
        db = SessionLocal()
        try:
            row = Role(
                code=f"production_it_{suffix}_{int(time.time() * 1000)}",
                name=f"生产集成角色-{suffix}",
                role_type="custom",
                is_enabled=True,
                is_builtin=False,
                is_deleted=False,
            )
            db.add(row)
            db.commit()
            db.refresh(row)
            db.expunge(row)
            self.role_ids.append(int(row.id))
            return row
        finally:
            db.close()

    def _create_user_with_permissions(
        self,
        *,
        suffix: str,
        permission_codes: list[str],
    ) -> User:
        role = self._create_role(suffix)
        db = SessionLocal()
        try:
            row = User(
                username=f"production_perm_{suffix}_{int(time.time() * 1000)}",
                full_name=f"生产权限用户-{suffix}",
                password_hash=get_password_hash("Admin@123456"),
                is_active=True,
                is_superuser=False,
                remark="生产集成测试",
            )
            row.roles.append(db.merge(role))
            db.add(row)
            db.commit()
            db.refresh(row)
            db.expunge(row)
            self.user_ids.append(int(row.id))
            replace_role_permissions_for_module(
                db,
                role_code=role.code,
                module_code="production",
                granted_permission_codes=permission_codes,
                operator=None,
                remark="生产模块集成测试授权",
            )
            db.commit()
            return row
        finally:
            db.close()

    def _ensure_admin_visible_sub_order(self, order_id: int) -> None:
        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, order_id)
            admin = db.query(User).filter(User.username == "admin").first()
            assert order_row is not None and admin is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .first()
            )
            assert process_row is not None
            if process_row.visible_quantity <= 0:
                process_row.visible_quantity = order_row.quantity
            if not order_row.current_process_code:
                order_row.current_process_code = process_row.process_code
            existing_sub_order = (
                db.query(ProductionSubOrder)
                .filter(
                    ProductionSubOrder.order_process_id == process_row.id,
                    ProductionSubOrder.operator_user_id == admin.id,
                    ProductionSubOrder.is_visible.is_(True),
                )
                .first()
            )
            if existing_sub_order is None:
                db.add(
                    ProductionSubOrder(
                        order_process_id=process_row.id,
                        operator_user_id=admin.id,
                        assigned_quantity=order_row.quantity,
                        completed_quantity=0,
                        status="pending",
                        is_visible=True,
                    )
                )
            db.commit()
        finally:
            db.close()

    def _create_scrap_statistics(
        self,
        *,
        order_id: int,
        order_code: str,
        product_id: int,
        product_name: str,
        process_id: int,
        process_code: str,
        process_name: str,
        scrap_reason: str,
    ) -> int:
        db = SessionLocal()
        try:
            row = ProductionScrapStatistics(
                order_id=order_id,
                order_code=order_code,
                product_id=product_id,
                product_name=product_name,
                process_id=process_id,
                process_code=process_code,
                process_name=process_name,
                operator_username="admin",
                scrap_reason=scrap_reason,
                scrap_quantity=1,
                last_scrap_time=datetime.now(UTC),
                progress="pending_apply",
            )
            db.add(row)
            db.commit()
            db.refresh(row)
            self.scrap_statistics_ids.append(row.id)
            return row.id
        finally:
            db.close()

    def test_end_production_blocks_when_report_plus_defect_exceeds_visible_quantity(
        self,
    ) -> None:
        stage = self._create_stage("A")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="A"
        )
        product = self._create_product("数量口径")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            assert process_row is not None
            admin = db.query(User).filter(User.username == "admin").first()
            assert admin is not None
            process_row.status = "in_progress"
            process_row.visible_quantity = 6
            process_row.completed_quantity = 0
            sub_order = ProductionSubOrder(
                order_process_id=process_row.id,
                operator_user_id=admin.id,
                assigned_quantity=6,
                completed_quantity=0,
                status="in_progress",
                is_visible=True,
            )
            db.add(sub_order)
            db.commit()
        finally:
            db.close()

        response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/end-production",
            headers=self._headers(),
            json={
                "order_process_id": process_row.id,
                "quantity": 5,
                "defect_items": [
                    {"phenomenon": "毛刺", "quantity": 2},
                ],
            },
        )
        self.assertEqual(response.status_code, 409, response.text)
        self.assertIn("Max producible quantity is 6", response.text)

    def test_end_production_releases_partial_completed_quantity_to_next_process(
        self,
    ) -> None:
        stage_a = self._create_stage("SEQ1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="SEQ1"
        )
        stage_b = self._create_stage("SEQ2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="SEQ2"
        )
        product = self._create_product("顺序放行")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            admin = db.query(User).filter(User.username == "admin").first()
            assert admin is not None
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(process_rows), 2)
            first_process, second_process = process_rows

            order_row.quantity = 1000
            order_row.status = "in_progress"
            order_row.current_process_code = first_process.process_code

            first_process.status = "in_progress"
            first_process.visible_quantity = 1000
            first_process.completed_quantity = 0

            second_process.status = "pending"
            second_process.visible_quantity = 0
            second_process.completed_quantity = 0

            first_sub_order = (
                db.query(ProductionSubOrder)
                .filter(
                    ProductionSubOrder.order_process_id == first_process.id,
                    ProductionSubOrder.operator_user_id == admin.id,
                )
                .first()
            )
            if first_sub_order is None:
                first_sub_order = ProductionSubOrder(
                    order_process_id=first_process.id,
                    operator_user_id=admin.id,
                    assigned_quantity=1000,
                    completed_quantity=0,
                    status="in_progress",
                    is_visible=True,
                )
                db.add(first_sub_order)
            else:
                first_sub_order.assigned_quantity = 1000
                first_sub_order.completed_quantity = 0
                first_sub_order.status = "in_progress"
                first_sub_order.is_visible = True

            second_sub_order = (
                db.query(ProductionSubOrder)
                .filter(
                    ProductionSubOrder.order_process_id == second_process.id,
                    ProductionSubOrder.operator_user_id == admin.id,
                )
                .first()
            )
            if second_sub_order is None:
                second_sub_order = ProductionSubOrder(
                    order_process_id=second_process.id,
                    operator_user_id=admin.id,
                    assigned_quantity=0,
                    completed_quantity=0,
                    status="done",
                    is_visible=False,
                )
                db.add(second_sub_order)
            else:
                second_sub_order.assigned_quantity = 0
                second_sub_order.completed_quantity = 0
                second_sub_order.status = "done"
                second_sub_order.is_visible = False
            db.commit()
        finally:
            db.close()

        response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/end-production",
            headers=self._headers(),
            json={
                "order_process_id": first_process.id,
                "quantity": 500,
            },
        )
        self.assertEqual(response.status_code, 200, response.text)

        db = SessionLocal()
        try:
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(order["id"]))
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(process_rows), 2)
            first_process, second_process = process_rows
            second_sub_order = (
                db.query(ProductionSubOrder)
                .filter(ProductionSubOrder.order_process_id == second_process.id)
                .first()
            )
            self.assertIsNotNone(second_sub_order)
            assert second_sub_order is not None

            self.assertEqual(first_process.completed_quantity, 500)
            self.assertEqual(first_process.status, "partial")
            self.assertEqual(second_process.visible_quantity, 500)
            self.assertEqual(second_sub_order.assigned_quantity, 500)
            self.assertTrue(second_sub_order.is_visible)
        finally:
            db.close()

    def test_create_order_requires_valid_supplier(self) -> None:
        stage = self._create_stage("SUP0")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="SUP0"
        )
        product = self._create_product("供应商校验")
        self._activate_product(product)

        missing_response = self.client.post(
            "/api/v1/production/orders",
            headers=self._headers(),
            json={
                "order_code": f"PO-MISS-{int(time.time() * 1000)}",
                "product_id": product["id"],
                "quantity": 10,
                "process_steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage["id"],
                        "process_id": process["id"],
                    }
                ],
            },
        )
        self.assertEqual(missing_response.status_code, 422, missing_response.text)

        invalid_response = self.client.post(
            "/api/v1/production/orders",
            headers=self._headers(),
            json={
                "order_code": f"PO-BAD-{int(time.time() * 1000)}",
                "product_id": product["id"],
                "supplier_id": 999999,
                "quantity": 10,
                "process_steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage["id"],
                        "process_id": process["id"],
                    }
                ],
            },
        )
        self.assertEqual(invalid_response.status_code, 400, invalid_response.text)
        self.assertIn("供应商不存在或已停用", invalid_response.text)

    def test_delete_order_keeps_event_log_snapshot(self) -> None:
        stage = self._create_stage("B")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="B"
        )
        product = self._create_product("删除追溯")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        delete_response = self.client.delete(
            f"/api/v1/production/orders/{order['id']}",
            headers=self._headers(),
        )
        self.assertEqual(delete_response.status_code, 200, delete_response.text)

        db = SessionLocal()
        try:
            log_row = (
                db.query(OrderEventLog)
                .filter(
                    OrderEventLog.order_code_snapshot == order["order_code"],
                    OrderEventLog.event_type == "order_deleted",
                )
                .order_by(OrderEventLog.id.desc())
                .first()
            )
            self.assertIsNotNone(log_row)
            assert log_row is not None
            self.assertIsNone(log_row.order_id)
            self.assertEqual(log_row.order_status_snapshot, "pending")
        finally:
            db.close()

        trace_response = self.client.get(
            f"/api/v1/production/order-events/search?order_code={order['order_code']}&event_type=order_deleted&operator_username=admin",
            headers=self._headers(),
        )
        self.assertEqual(trace_response.status_code, 200, trace_response.text)
        trace_items = trace_response.json()["data"]["items"]
        self.assertEqual(len(trace_items), 1)
        self.assertEqual(trace_items[0]["event_type"], "order_deleted")
        self.assertEqual(trace_items[0]["operator_username"], "admin")
        self.order_ids.remove(int(order["id"]))

    def test_complete_order_requires_current_user_password(self) -> None:
        stage = self._create_stage("CMP1")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="CMP1"
        )
        product = self._create_product("结束订单密码")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/complete",
            headers=self._headers(),
            json={"password": "bad-password"},
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertIn("当前登录密码错误", response.text)

    def test_complete_order_succeeds_with_current_user_password(self) -> None:
        stage = self._create_stage("CMP2")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="CMP2"
        )
        product = self._create_product("结束订单成功")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        db = SessionLocal()
        try:
            admin = db.query(User).filter(User.username == "admin").first()
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(order["id"]))
                .first()
            )
            assert admin is not None and process_row is not None
            existing_sub_order = (
                db.query(ProductionSubOrder)
                .filter(
                    ProductionSubOrder.order_process_id == process_row.id,
                    ProductionSubOrder.operator_user_id == admin.id,
                )
                .first()
            )
            if existing_sub_order is None:
                db.add(
                    ProductionSubOrder(
                        order_process_id=process_row.id,
                        operator_user_id=admin.id,
                        completed_quantity=0,
                        status="pending",
                    )
                )
            db.commit()
        finally:
            db.close()

        response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/complete",
            headers=self._headers(),
            json={"password": "Admin@123456"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["data"]["status"], "completed")

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            self.assertIsNotNone(order_row)
            assert order_row is not None
            self.assertEqual(order_row.status, "completed")
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            assert process_row is not None
            sub_orders = (
                db.query(ProductionSubOrder)
                .filter(ProductionSubOrder.order_process_id == process_row.id)
                .all()
            )
            for sub_order in sub_orders:
                self.assertEqual(sub_order.status, "done")
        finally:
            db.close()

    def test_create_assist_authorization_effective_immediately(self) -> None:
        stage = self._create_stage("AST1")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="AST1"
        )
        product = self._create_product("代班即时生效")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        db = SessionLocal()
        try:
            admin = db.query(User).filter(User.username == "admin").first()
            assert admin is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(order["id"]))
                .first()
            )
            assert process_row is not None
            sub_order = ProductionSubOrder(
                order_process_id=process_row.id,
                operator_user_id=admin.id,
                assigned_quantity=10,
                completed_quantity=0,
                status="in_progress",
                is_visible=True,
            )
            db.add(sub_order)
            db.commit()
        finally:
            db.close()

        response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/assist-authorizations",
            headers=self._headers(),
            json={
                "order_process_id": process_row.id,
                "target_operator_user_id": admin.id,
                "helper_user_id": admin.id,
                "reason": "临时代班",
            },
        )

        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(response.json()["data"]["status"], "approved")

        db = SessionLocal()
        try:
            row = (
                db.query(ProductionAssistAuthorization)
                .filter(ProductionAssistAuthorization.order_id == int(order["id"]))
                .order_by(ProductionAssistAuthorization.id.desc())
                .first()
            )
            self.assertIsNotNone(row)
            assert row is not None
            self.assertEqual(row.status, "approved")
            self.assertIsNone(row.reviewed_at)
            self.assertIsNone(row.reviewer_user_id)
        finally:
            db.close()

    def test_production_stats_and_today_realtime_cover_core_aggregations(self) -> None:
        baseline_overview = self.client.get(
            "/api/v1/production/stats/overview",
            headers=self._headers(),
        )
        self.assertEqual(baseline_overview.status_code, 200, baseline_overview.text)
        baseline_payload = baseline_overview.json()["data"]

        stage_a = self._create_stage("STAT1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="STAT1"
        )
        stage_b = self._create_stage("STAT2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="STAT2"
        )
        product_main = self._create_product("生产统计主产品")
        self._activate_product(product_main)
        product_other = self._create_product("生产统计辅产品")
        self._activate_product(product_other)
        operator_user = self._create_active_user("stats_operator")

        order_in_progress = self._create_order(
            product_id=product_main["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )
        order_pending = self._create_order(
            product_id=product_main["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                }
            ],
        )
        order_completed = self._create_order(
            product_id=product_other["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                }
            ],
        )

        db = SessionLocal()
        try:
            admin = db.query(User).filter(User.username == "admin").first()
            assert admin is not None
            in_progress_row = db.get(ProductionOrder, int(order_in_progress["id"]))
            pending_row = db.get(ProductionOrder, int(order_pending["id"]))
            completed_row = db.get(ProductionOrder, int(order_completed["id"]))
            assert in_progress_row is not None
            assert pending_row is not None
            assert completed_row is not None

            in_progress_processes = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == in_progress_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            pending_process = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == pending_row.id)
                .first()
            )
            completed_process = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == completed_row.id)
                .first()
            )
            assert len(in_progress_processes) == 2
            assert pending_process is not None
            assert completed_process is not None

            in_progress_row.status = "in_progress"
            in_progress_row.current_process_code = in_progress_processes[1].process_code
            in_progress_processes[0].status = "completed"
            in_progress_processes[0].visible_quantity = 10
            in_progress_processes[0].completed_quantity = 10
            in_progress_processes[1].status = "partial"
            in_progress_processes[1].visible_quantity = 10
            in_progress_processes[1].completed_quantity = 4

            pending_row.status = "pending"
            pending_row.current_process_code = pending_process.process_code
            pending_process.status = "pending"
            pending_process.visible_quantity = 0
            pending_process.completed_quantity = 0

            completed_row.status = "completed"
            completed_row.current_process_code = completed_process.process_code
            completed_process.status = "completed"
            completed_process.visible_quantity = 8
            completed_process.completed_quantity = 8

            db.add_all(
                [
                    ProductionRecord(
                        order_id=in_progress_row.id,
                        order_process_id=in_progress_processes[0].id,
                        sub_order_id=None,
                        operator_user_id=int(operator_user.id),
                        production_quantity=6,
                        record_type="production",
                    ),
                    ProductionRecord(
                        order_id=in_progress_row.id,
                        order_process_id=in_progress_processes[1].id,
                        sub_order_id=None,
                        operator_user_id=admin.id,
                        production_quantity=4,
                        record_type="production",
                    ),
                    ProductionRecord(
                        order_id=completed_row.id,
                        order_process_id=completed_process.id,
                        sub_order_id=None,
                        operator_user_id=int(operator_user.id),
                        production_quantity=8,
                        record_type="production",
                    ),
                ]
            )
            db.commit()
        finally:
            db.close()

        overview_response = self.client.get(
            "/api/v1/production/stats/overview",
            headers=self._headers(),
        )
        self.assertEqual(overview_response.status_code, 200, overview_response.text)
        overview_payload = overview_response.json()["data"]
        self.assertEqual(
            overview_payload["total_orders"], baseline_payload["total_orders"] + 3
        )
        self.assertEqual(
            overview_payload["pending_orders"], baseline_payload["pending_orders"] + 1
        )
        self.assertEqual(
            overview_payload["in_progress_orders"],
            baseline_payload["in_progress_orders"] + 1,
        )
        self.assertEqual(
            overview_payload["completed_orders"],
            baseline_payload["completed_orders"] + 1,
        )
        self.assertEqual(
            overview_payload["total_quantity"], baseline_payload["total_quantity"] + 30
        )
        self.assertEqual(
            overview_payload["finished_quantity"],
            baseline_payload["finished_quantity"] + 12,
        )

        process_response = self.client.get(
            "/api/v1/production/stats/processes",
            headers=self._headers(),
        )
        self.assertEqual(process_response.status_code, 200, process_response.text)
        process_items = process_response.json()["data"]["items"]
        process_a_item = next(
            item for item in process_items if item["process_code"] == process_a["code"]
        )
        self.assertEqual(process_a_item["total_orders"], 3)
        self.assertEqual(process_a_item["pending_orders"], 1)
        self.assertEqual(process_a_item["completed_orders"], 2)
        self.assertEqual(process_a_item["total_visible_quantity"], 18)
        self.assertEqual(process_a_item["total_completed_quantity"], 18)
        process_b_item = next(
            item for item in process_items if item["process_code"] == process_b["code"]
        )
        self.assertEqual(process_b_item["partial_orders"], 1)
        self.assertEqual(process_b_item["total_visible_quantity"], 10)
        self.assertEqual(process_b_item["total_completed_quantity"], 4)

        operator_response = self.client.get(
            "/api/v1/production/stats/operators",
            headers=self._headers(),
        )
        self.assertEqual(operator_response.status_code, 200, operator_response.text)
        operator_items = operator_response.json()["data"]["items"]
        operator_item = next(
            item
            for item in operator_items
            if item["operator_user_id"] == int(operator_user.id)
            and item["process_code"] == process_a["code"]
        )
        self.assertEqual(operator_item["production_records"], 2)
        self.assertEqual(operator_item["production_quantity"], 14)
        self.assertTrue(operator_item["last_production_at"])

        realtime_response = self.client.get(
            "/api/v1/production/data/today-realtime",
            headers=self._headers(),
            params={
                "product_ids": f"{product_main['id']},{product_other['id']}",
            },
        )
        self.assertEqual(realtime_response.status_code, 200, realtime_response.text)
        realtime_payload = realtime_response.json()["data"]
        self.assertEqual(realtime_payload["stat_mode"], "main_order")
        self.assertEqual(realtime_payload["summary"]["total_products"], 2)
        self.assertEqual(realtime_payload["summary"]["total_quantity"], 12)
        self.assertEqual(
            [row["product_name"] for row in realtime_payload["table_rows"]],
            [product_other["name"], product_main["name"]],
        )
        self.assertEqual(
            [row["quantity"] for row in realtime_payload["table_rows"]],
            [8, 4],
        )

        filtered_realtime = self.client.get(
            "/api/v1/production/data/today-realtime",
            headers=self._headers(),
            params={
                "stat_mode": "sub_order",
                "product_ids": str(product_main["id"]),
                "stage_ids": str(stage_a["id"]),
                "process_ids": str(process_a["id"]),
                "operator_user_ids": str(int(operator_user.id)),
                "order_status": "in_progress",
            },
        )
        self.assertEqual(filtered_realtime.status_code, 200, filtered_realtime.text)
        filtered_payload = filtered_realtime.json()["data"]
        self.assertEqual(filtered_payload["summary"]["total_products"], 1)
        self.assertEqual(filtered_payload["summary"]["total_quantity"], 6)
        self.assertEqual(
            filtered_payload["table_rows"][0]["product_id"], product_main["id"]
        )
        self.assertEqual(filtered_payload["table_rows"][0]["quantity"], 6)

    def test_assist_authorization_list_enforces_scope_and_filters(self) -> None:
        stage = self._create_stage("ASTL")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="ASTL"
        )
        product = self._create_product("代班记录列表")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )
        limited_user = self._create_user_with_permissions(
            suffix="assist_limited",
            permission_codes=["production.assist_authorizations.list"],
        )
        full_user = self._create_user_with_permissions(
            suffix="assist_full",
            permission_codes=["feature.production.assist.records.view"],
        )
        helper_user = self._create_active_user("assist_helper")
        target_user = self._create_active_user("assist_target")
        other_requester = self._create_active_user("assist_requester")

        db = SessionLocal()
        try:
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(order["id"]))
                .first()
            )
            assert process_row is not None
            db.add_all(
                [
                    ProductionAssistAuthorization(
                        order_id=int(order["id"]),
                        order_process_id=process_row.id,
                        target_operator_user_id=int(target_user.id),
                        requester_user_id=int(limited_user.id),
                        helper_user_id=int(helper_user.id),
                        status="approved",
                        reason="白班代班",
                        created_at=datetime(2026, 4, 1, 8, 0, tzinfo=UTC),
                    ),
                    ProductionAssistAuthorization(
                        order_id=int(order["id"]),
                        order_process_id=process_row.id,
                        target_operator_user_id=int(target_user.id),
                        requester_user_id=int(other_requester.id),
                        helper_user_id=int(target_user.id),
                        status="pending",
                        reason="夜班代班",
                        created_at=datetime(2026, 4, 2, 8, 0, tzinfo=UTC),
                    ),
                ]
            )
            db.commit()
        finally:
            db.close()

        limited_headers = {
            "Authorization": f"Bearer {self._login_as(username=limited_user.username)}"
        }
        limited_response = self.client.get(
            "/api/v1/production/assist-authorizations",
            headers=limited_headers,
        )
        self.assertEqual(limited_response.status_code, 200, limited_response.text)
        limited_payload = limited_response.json()["data"]
        self.assertEqual(limited_payload["total"], 1)
        self.assertEqual(len(limited_payload["items"]), 1)
        self.assertEqual(
            limited_payload["items"][0]["requester_user_id"], int(limited_user.id)
        )
        self.assertEqual(limited_payload["items"][0]["status"], "approved")

        full_headers = {
            "Authorization": f"Bearer {self._login_as(username=full_user.username)}"
        }
        full_response = self.client.get(
            "/api/v1/production/assist-authorizations",
            headers=full_headers,
            params={
                "order_code": order["order_code"],
                "process_name": process["name"],
                "helper_username": helper_user.username,
                "status": "approved",
            },
        )
        self.assertEqual(full_response.status_code, 200, full_response.text)
        full_payload = full_response.json()["data"]
        self.assertEqual(full_payload["total"], 1)
        self.assertEqual(
            full_payload["items"][0]["helper_user_id"], int(helper_user.id)
        )
        self.assertEqual(full_payload["items"][0]["process_name"], process["name"])

        full_all_response = self.client.get(
            "/api/v1/production/assist-authorizations",
            headers=full_headers,
        )
        self.assertEqual(full_all_response.status_code, 200, full_all_response.text)
        self.assertEqual(full_all_response.json()["data"]["total"], 2)

    def test_order_list_supports_pipeline_and_date_filters(self) -> None:
        stage = self._create_stage("ORDL")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="ORDL"
        )
        product = self._create_product("订单过滤产品")
        self._activate_product(product)
        matched_order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )
        other_order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        db = SessionLocal()
        try:
            matched_row = db.get(ProductionOrder, int(matched_order["id"]))
            other_row = db.get(ProductionOrder, int(other_order["id"]))
            assert matched_row is not None and other_row is not None
            matched_row.status = "in_progress"
            matched_row.pipeline_enabled = True
            matched_row.start_date = date(2026, 4, 1)
            matched_row.due_date = date(2026, 4, 12)
            other_row.status = "pending"
            other_row.pipeline_enabled = False
            other_row.start_date = date(2026, 5, 1)
            other_row.due_date = date(2026, 5, 12)
            db.commit()
        finally:
            db.close()

        response = self.client.get(
            "/api/v1/production/orders",
            headers=self._headers(),
            params={
                "status": "in_progress",
                "pipeline_enabled": "true",
                "start_date_from": "2026-04-01",
                "start_date_to": "2026-04-02",
                "due_date_to": "2026-04-15",
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        self.assertEqual(payload["total"], 1)
        self.assertEqual(payload["items"][0]["id"], matched_order["id"])
        self.assertTrue(payload["items"][0]["pipeline_enabled"])

        invalid_status_response = self.client.get(
            "/api/v1/production/orders",
            headers=self._headers(),
            params={"status": "bad_status"},
        )
        self.assertEqual(
            invalid_status_response.status_code, 400, invalid_status_response.text
        )
        self.assertIn("Invalid order status", invalid_status_response.text)

    def test_create_and_update_order_allow_duplicate_process_codes(self) -> None:
        stage = self._create_stage("DUP0")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="DUP0"
        )
        product = self._create_product("重复工序路线")
        self._activate_product(product)
        supplier = self._create_supplier(f"重复工序供应商{int(time.time() * 1000)}")
        order_code = f"PO-DUP-{int(time.time() * 1000)}"

        with patch("app.services.production_order_service.create_message_for_users"):
            create_response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": order_code,
                    "product_id": product["id"],
                    "supplier_id": supplier["id"],
                    "quantity": 10,
                    "process_codes": [process["code"], process["code"]],
                },
            )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        created_order = create_response.json()["data"]
        self.order_ids.append(int(created_order["id"]))

        db = SessionLocal()
        try:
            created_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(created_order["id"]))
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(created_rows), 2)
            self.assertEqual(
                [row.process_code for row in created_rows],
                [process["code"], process["code"]],
            )
        finally:
            db.close()

        with patch("app.services.production_order_service.create_message_for_users"):
            update_response = self.client.put(
                f"/api/v1/production/orders/{created_order['id']}",
                headers=self._headers(),
                json={
                    "product_id": product["id"],
                    "supplier_id": supplier["id"],
                    "quantity": 12,
                    "process_codes": [
                        process["code"],
                        process["code"],
                        process["code"],
                    ],
                },
            )
        self.assertEqual(update_response.status_code, 200, update_response.text)

        db = SessionLocal()
        try:
            updated_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(created_order["id"]))
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(updated_rows), 3)
            self.assertEqual(
                [row.process_code for row in updated_rows],
                [process["code"], process["code"], process["code"]],
            )
        finally:
            db.close()

    def test_delete_supplier_fails_when_referenced_by_order(self) -> None:
        stage = self._create_stage("SUP1")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="SUP1"
        )
        product = self._create_product("删除供应商阻断")
        self._activate_product(product)
        supplier = self._create_supplier(f"引用供应商{int(time.time() * 1000)}")

        with patch("app.services.production_order_service.create_message_for_users"):
            create_response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": f"PO-SUP-{int(time.time() * 1000)}",
                    "product_id": product["id"],
                    "supplier_id": supplier["id"],
                    "quantity": 10,
                    "process_steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage["id"],
                            "process_id": process["id"],
                        }
                    ],
                },
            )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        self.order_ids.append(int(create_response.json()["data"]["id"]))

        delete_response = self.client.delete(
            f"/api/v1/quality/suppliers/{supplier['id']}",
            headers=self._headers(),
        )
        self.assertEqual(delete_response.status_code, 409, delete_response.text)
        self.assertIn("供应商已被生产订单引用，无法删除", delete_response.text)

    def test_order_reads_supplier_snapshot_after_supplier_rename(self) -> None:
        stage = self._create_stage("SUP2")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="SUP2"
        )
        product = self._create_product("供应商快照")
        self._activate_product(product)
        supplier = self._create_supplier(f"快照供应商{int(time.time() * 1000)}")

        with patch("app.services.production_order_service.create_message_for_users"):
            create_response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": f"PO-SNAP-{int(time.time() * 1000)}",
                    "product_id": product["id"],
                    "supplier_id": supplier["id"],
                    "quantity": 10,
                    "process_steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage["id"],
                            "process_id": process["id"],
                        }
                    ],
                },
            )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        order = create_response.json()["data"]
        self.order_ids.append(int(order["id"]))
        original_name = supplier["name"]

        rename_response = self.client.put(
            f"/api/v1/quality/suppliers/{supplier['id']}",
            headers=self._headers(),
            json={
                "name": f"{original_name}-已改名",
                "remark": "生产集成测试",
                "is_enabled": True,
            },
        )
        self.assertEqual(rename_response.status_code, 200, rename_response.text)

        list_response = self.client.get(
            "/api/v1/production/orders",
            headers=self._headers(),
            params={"keyword": order["order_code"]},
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        list_item = list_response.json()["data"]["items"][0]
        self.assertEqual(list_item["supplier_id"], supplier["id"])
        self.assertEqual(list_item["supplier_name"], original_name)

        detail_response = self.client.get(
            f"/api/v1/production/orders/{order['id']}",
            headers=self._headers(),
        )
        self.assertEqual(detail_response.status_code, 200, detail_response.text)
        detail_order = detail_response.json()["data"]["order"]
        self.assertEqual(detail_order["supplier_id"], supplier["id"])
        self.assertEqual(detail_order["supplier_name"], original_name)

    def test_update_pending_order_allows_current_disabled_supplier_only(self) -> None:
        stage = self._create_stage("SUP3")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="SUP3"
        )
        product = self._create_product("停用供应商保留")
        self._activate_product(product)
        current_supplier = self._create_supplier(f"当前供应商{int(time.time() * 1000)}")
        other_disabled_supplier = self._create_supplier(
            f"其他停用供应商{int(time.time() * 1000)}",
            is_enabled=False,
        )

        with patch("app.services.production_order_service.create_message_for_users"):
            create_response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": f"PO-UPD-{int(time.time() * 1000)}",
                    "product_id": product["id"],
                    "supplier_id": current_supplier["id"],
                    "quantity": 10,
                    "process_steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage["id"],
                            "process_id": process["id"],
                        }
                    ],
                },
            )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        order = create_response.json()["data"]
        self.order_ids.append(int(order["id"]))

        disable_response = self.client.put(
            f"/api/v1/quality/suppliers/{current_supplier['id']}",
            headers=self._headers(),
            json={
                "name": current_supplier["name"],
                "remark": "生产集成测试",
                "is_enabled": False,
            },
        )
        self.assertEqual(disable_response.status_code, 200, disable_response.text)

        with patch("app.services.production_order_service.create_message_for_users"):
            keep_response = self.client.put(
                f"/api/v1/production/orders/{order['id']}",
                headers=self._headers(),
                json={
                    "product_id": product["id"],
                    "supplier_id": current_supplier["id"],
                    "quantity": 12,
                    "process_steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage["id"],
                            "process_id": process["id"],
                        }
                    ],
                },
            )
        self.assertEqual(keep_response.status_code, 200, keep_response.text)
        keep_order = keep_response.json()["data"]
        self.assertEqual(keep_order["supplier_id"], current_supplier["id"])
        self.assertEqual(keep_order["supplier_name"], current_supplier["name"])
        self.assertEqual(keep_order["quantity"], 12)

        switch_response = self.client.put(
            f"/api/v1/production/orders/{order['id']}",
            headers=self._headers(),
            json={
                "product_id": product["id"],
                "supplier_id": other_disabled_supplier["id"],
                "quantity": 12,
                "process_steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage["id"],
                        "process_id": process["id"],
                    }
                ],
            },
        )
        self.assertEqual(switch_response.status_code, 400, switch_response.text)
        self.assertIn("供应商不存在或已停用", switch_response.text)

    def test_my_orders_contract_includes_supplier_due_date_and_remark(self) -> None:
        stage = self._create_stage("MYORD")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="MYORD"
        )
        product = self._create_product("我的工单契约")
        self._activate_product(product)
        supplier = self._create_supplier(f"我的工单供应商{int(time.time() * 1000)}")

        due_date = "2026-04-18"
        remark = "订单查询备注"
        with patch("app.services.production_order_service.create_message_for_users"):
            create_response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": f"PO-MY-{int(time.time() * 1000)}",
                    "product_id": product["id"],
                    "supplier_id": supplier["id"],
                    "quantity": 10,
                    "due_date": due_date,
                    "remark": remark,
                    "process_steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage["id"],
                            "process_id": process["id"],
                        }
                    ],
                },
            )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        order = create_response.json()["data"]
        self.order_ids.append(int(order["id"]))
        self._ensure_admin_visible_sub_order(int(order["id"]))

        list_response = self.client.get(
            "/api/v1/production/my-orders",
            headers=self._headers(),
            params={"keyword": order["order_code"]},
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        list_items = list_response.json()["data"]["items"]
        self.assertEqual(len(list_items), 1)
        list_item = list_items[0]
        self.assertEqual(list_item["supplier_name"], supplier["name"])
        self.assertEqual(list_item["due_date"], due_date)
        self.assertEqual(list_item["remark"], remark)

        context_response = self.client.get(
            f"/api/v1/production/my-orders/{order['id']}/context",
            headers=self._headers(),
        )
        self.assertEqual(context_response.status_code, 200, context_response.text)
        context_item = context_response.json()["data"]["item"]
        self.assertEqual(context_item["supplier_name"], supplier["name"])
        self.assertEqual(context_item["due_date"], due_date)
        self.assertEqual(context_item["remark"], remark)

    def test_my_orders_keyword_matches_supplier_name(self) -> None:
        stage = self._create_stage("MYSUP")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="MYSUP"
        )
        product = self._create_product("供应商搜索")
        self._activate_product(product)
        supplier = self._create_supplier(f"关键字供应商{int(time.time() * 1000)}")

        with patch("app.services.production_order_service.create_message_for_users"):
            create_response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": f"PO-SUP-{int(time.time() * 1000)}",
                    "product_id": product["id"],
                    "supplier_id": supplier["id"],
                    "quantity": 10,
                    "process_steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage["id"],
                            "process_id": process["id"],
                        }
                    ],
                },
            )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        order = create_response.json()["data"]
        self.order_ids.append(int(order["id"]))
        self._ensure_admin_visible_sub_order(int(order["id"]))

        list_response = self.client.get(
            "/api/v1/production/my-orders",
            headers=self._headers(),
            params={"keyword": supplier["name"]},
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        list_items = list_response.json()["data"]["items"]
        self.assertEqual(len(list_items), 1)
        self.assertEqual(list_items[0]["order_id"], order["id"])

    def test_my_orders_keyword_matches_current_process_name(self) -> None:
        stage = self._create_stage("MYPROC")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="MYPROC"
        )
        product = self._create_product("工序搜索")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )
        self._ensure_admin_visible_sub_order(int(order["id"]))

        list_response = self.client.get(
            "/api/v1/production/my-orders",
            headers=self._headers(),
            params={"keyword": process["name"]},
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        list_items = list_response.json()["data"]["items"]
        self.assertEqual(len(list_items), 1)
        self.assertEqual(list_items[0]["order_id"], order["id"])
        self.assertEqual(list_items[0]["current_process_name"], process["name"])

    def test_my_orders_backfills_historical_release_visibility_on_query(self) -> None:
        stage_a = self._create_stage("MYBF1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="MYBF1"
        )
        stage_b = self._create_stage("MYBF2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="MYBF2"
        )
        product = self._create_product("历史放行回填")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            admin = db.query(User).filter(User.username == "admin").first()
            assert admin is not None
            second_process = db.get(Process, int(process_b["id"]))
            assert second_process is not None
            if all(row.id != second_process.id for row in admin.processes):
                admin.processes.append(second_process)

            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(process_rows), 2)
            first_process_row = process_rows[0]
            second_process_row = process_rows[1]
            first_process_row.completed_quantity = 5
            first_process_row.status = "partial"
            second_process_row.visible_quantity = 0
            second_process_row.completed_quantity = 0
            second_process_row.status = "pending"

            db.add(
                ProductionSubOrder(
                    order_process_id=second_process_row.id,
                    operator_user_id=admin.id,
                    assigned_quantity=0,
                    completed_quantity=0,
                    status="done",
                    is_visible=False,
                )
            )
            db.commit()
        finally:
            db.close()

        list_response = self.client.get(
            "/api/v1/production/my-orders",
            headers=self._headers(),
            params={"keyword": order["order_code"]},
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        list_items = list_response.json()["data"]["items"]
        self.assertEqual(len(list_items), 1)
        self.assertEqual(list_items[0]["order_id"], order["id"])
        self.assertEqual(list_items[0]["current_process_code"], process_b["code"])
        self.assertEqual(list_items[0]["visible_quantity"], 5)
        self.assertEqual(list_items[0]["user_assigned_quantity"], 5)

        db = SessionLocal()
        try:
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(order["id"]))
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            second_process_row = process_rows[1]
            self.assertEqual(second_process_row.visible_quantity, 5)
            second_sub_order = (
                db.query(ProductionSubOrder)
                .filter(
                    ProductionSubOrder.order_process_id == second_process_row.id,
                    ProductionSubOrder.operator_user_id == admin.id,
                )
                .first()
            )
            assert second_sub_order is not None
            self.assertEqual(second_sub_order.assigned_quantity, 5)
            self.assertTrue(second_sub_order.is_visible)
            self.assertEqual(second_sub_order.status, "pending")
        finally:
            db.close()

    def test_my_orders_proxy_backfills_historical_release_visibility_on_query(
        self,
    ) -> None:
        stage_a = self._create_stage("MYPX1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="MYPX1"
        )
        stage_b = self._create_stage("MYPX2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="MYPX2"
        )
        product = self._create_product("代理历史放行回填")
        self._activate_product(product)
        proxy_operator = self._create_active_user("proxy_backfill")
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            proxy_operator_row = db.get(User, int(proxy_operator.id))
            assert proxy_operator_row is not None
            second_process = db.get(Process, int(process_b["id"]))
            assert second_process is not None
            if all(row.id != second_process.id for row in proxy_operator_row.processes):
                proxy_operator_row.processes.append(second_process)

            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(process_rows), 2)
            first_process_row = process_rows[0]
            second_process_row = process_rows[1]
            first_process_row.completed_quantity = 5
            first_process_row.status = "partial"
            second_process_row.visible_quantity = 0
            second_process_row.completed_quantity = 0
            second_process_row.status = "pending"

            db.add(
                ProductionSubOrder(
                    order_process_id=second_process_row.id,
                    operator_user_id=int(proxy_operator.id),
                    assigned_quantity=0,
                    completed_quantity=0,
                    status="done",
                    is_visible=False,
                )
            )
            db.commit()
        finally:
            db.close()

    def test_first_article_allows_operator_added_to_process_after_process_started(self) -> None:
        stage = self._create_stage("FAADD")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="FAADD"
        )
        operator_a = self._create_user_with_permissions(
            suffix="faadda",
            permission_codes=[
                "production.execution.first_article",
                "production.my_orders.list",
                "production.my_orders.context",
            ],
        )
        operator_a_token = self._login_as(username=operator_a.username)
        operator_b = self._create_user_with_permissions(
            suffix="faaddb",
            permission_codes=[
                "production.execution.first_article",
                "production.my_orders.list",
                "production.my_orders.context",
            ],
        )
        operator_b_token = self._login_as(username=operator_b.username)

        product = self._create_product("首件后新增操作员")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )
        self.order_ids.append(int(order["id"]))

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            admin = db.query(User).filter(User.username == "admin").first()
            assert order_row is not None
            assert admin is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            assert process_row is not None
            process_row_id = int(process_row.id)
            today_code = (
                db.query(DailyVerificationCode)
                .filter(DailyVerificationCode.verify_date == date.today())
                .first()
            )
            if today_code is None:
                today_code = DailyVerificationCode(
                    verify_date=date.today(),
                    code="code-1",
                    created_by_user_id=admin.id,
                )
                db.add(today_code)
            else:
                today_code.code = "code-1"
            existing_a = (
                db.query(ProductionSubOrder)
                .filter(
                    ProductionSubOrder.order_process_id == process_row_id,
                    ProductionSubOrder.operator_user_id == int(operator_a.id),
                )
                .first()
            )
            if existing_a is None:
                db.add(
                    ProductionSubOrder(
                        order_process_id=process_row_id,
                        operator_user_id=int(operator_a.id),
                        completed_quantity=0,
                        status="pending",
                    )
                )
            db.commit()
        finally:
            db.close()

        first_article_a = self.client.post(
            f"/api/v1/production/orders/{order['id']}/first-article",
            headers={"Authorization": f"Bearer {operator_a_token}"},
            json={
                "order_process_id": process_row_id,
                "verification_code": "code-1",
            },
        )
        self.assertEqual(first_article_a.status_code, 200, first_article_a.text)

        db = SessionLocal()
        try:
            operator_b_row = db.get(User, int(operator_b.id))
            process_def = db.get(Process, int(process["id"]))
            assert operator_b_row is not None and process_def is not None
            if all(row.id != process_def.id for row in operator_b_row.processes):
                operator_b_row.processes.append(process_def)
            db.commit()
        finally:
            db.close()

        first_article_b = self.client.post(
            f"/api/v1/production/orders/{order['id']}/first-article",
            headers={"Authorization": f"Bearer {operator_b_token}"},
            json={
                "order_process_id": process_row_id,
                "verification_code": "code-1",
            },
        )
        self.assertEqual(first_article_b.status_code, 200, first_article_b.text)

    def test_complete_repair_order_accepts_multiple_return_allocations(self) -> None:
        stage_a = self._create_stage("C1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="C1"
        )
        stage_b = self._create_stage("C2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="C2"
        )
        product = self._create_product("多回流")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(process_rows), 2)
            repair_row = RepairOrder(
                repair_order_code=f"RW-IT-{int(time.time() * 1000)}",
                source_order_id=order_row.id,
                source_order_code=order_row.order_code,
                product_id=order_row.product_id,
                product_name=order_row.product.name if order_row.product else None,
                source_order_process_id=process_rows[1].id,
                source_process_code=process_rows[1].process_code,
                source_process_name=process_rows[1].process_name,
                sender_user_id=None,
                sender_username="admin",
                production_quantity=2,
                repair_quantity=2,
                repaired_quantity=0,
                scrap_quantity=0,
                repair_time=process_rows[1].created_at,
                status="in_repair",
            )
            db.add(repair_row)
            db.commit()
            self.repair_order_ids.append(repair_row.id)
            repair_order_id = repair_row.id
            target_process_ids = [process_rows[0].id, process_rows[1].id]
        finally:
            db.close()

        response = self.client.post(
            f"/api/v1/production/repair-orders/{repair_order_id}/complete",
            headers=self._headers(),
            json={
                "cause_items": [
                    {
                        "phenomenon": "毛刺",
                        "reason": "调整刀具",
                        "quantity": 2,
                        "is_scrap": False,
                    }
                ],
                "scrap_replenished": False,
                "return_allocations": [
                    {"target_order_process_id": target_process_ids[0], "quantity": 1},
                    {"target_order_process_id": target_process_ids[1], "quantity": 1},
                ],
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["data"]["status"], "completed")

    def test_complete_repair_order_closes_pending_scrap_and_keeps_production_detail_trace(
        self,
    ) -> None:
        stage = self._create_stage("CP1")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="CP1"
        )
        product = self._create_product("维修闭环")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            admin = db.query(User).filter(User.username == "admin").first()
            assert process_row is not None and admin is not None
            production_record = ProductionRecord(
                order_id=order_row.id,
                order_process_id=process_row.id,
                sub_order_id=None,
                operator_user_id=admin.id,
                production_quantity=6,
                record_type="production",
            )
            db.add(production_record)
            db.flush()
            repair_row = RepairOrder(
                repair_order_code=f"RW-IT-{int(time.time() * 1000)}",
                source_order_id=order_row.id,
                source_order_code=order_row.order_code,
                product_id=order_row.product_id,
                product_name=order_row.product.name if order_row.product else None,
                source_order_process_id=process_row.id,
                source_process_code=process_row.process_code,
                source_process_name=process_row.process_name,
                sender_user_id=admin.id,
                sender_username=admin.username,
                production_quantity=6,
                repair_quantity=2,
                repaired_quantity=0,
                scrap_quantity=0,
                scrap_replenished=False,
                repair_time=datetime(2026, 3, 6, 9, 0, tzinfo=UTC),
                status="in_repair",
            )
            db.add(repair_row)
            db.flush()
            defect_row = RepairDefectPhenomenon(
                repair_order_id=repair_row.id,
                production_record_id=production_record.id,
                order_id=order_row.id,
                order_code=order_row.order_code,
                product_id=order_row.product_id,
                product_name=order_row.product.name if order_row.product else "",
                process_id=process_row.id,
                process_code=process_row.process_code,
                process_name=process_row.process_name,
                phenomenon="毛刺",
                quantity=2,
                operator_user_id=admin.id,
                operator_username=admin.username,
                production_time=datetime(2026, 3, 6, 9, 0, tzinfo=UTC),
            )
            db.add(defect_row)
            scrap_row = ProductionScrapStatistics(
                order_id=order_row.id,
                order_code=order_row.order_code,
                product_id=order_row.product_id,
                product_name=order_row.product.name if order_row.product else "",
                process_id=process_row.id,
                process_code=process_row.process_code,
                process_name=process_row.process_name,
                operator_user_id=admin.id,
                operator_username=admin.username,
                scrap_reason="刀具偏移",
                scrap_quantity=1,
                last_scrap_time=datetime(2026, 3, 6, 9, 30, tzinfo=UTC),
                progress="pending_apply",
            )
            db.add(scrap_row)
            db.commit()
            db.refresh(repair_row)
            db.refresh(scrap_row)
            self.repair_order_ids.append(int(repair_row.id))
            self.scrap_statistics_ids.append(int(scrap_row.id))
            repair_order_id = int(repair_row.id)
            scrap_id = int(scrap_row.id)
            production_record_id = int(production_record.id)
        finally:
            db.close()

        response = self.client.post(
            f"/api/v1/production/repair-orders/{repair_order_id}/complete",
            headers=self._headers(),
            json={
                "cause_items": [
                    {
                        "phenomenon": "毛刺",
                        "reason": "刀具偏移",
                        "quantity": 1,
                        "is_scrap": True,
                    },
                    {
                        "phenomenon": "毛刺",
                        "reason": "复磨后回流",
                        "quantity": 1,
                        "is_scrap": False,
                    },
                ],
                "scrap_replenished": False,
                "return_allocations": [
                    {
                        "target_order_process_id": process_row.id,
                        "quantity": 1,
                    }
                ],
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["data"]["status"], "completed")

        db = SessionLocal()
        try:
            scrap_row = db.get(ProductionScrapStatistics, scrap_id)
            assert scrap_row is not None
            self.assertEqual(scrap_row.progress, "applied")
            self.assertIsNotNone(scrap_row.applied_at)
        finally:
            db.close()

        scrap_response = self.client.get(
            f"/api/v1/production/scrap-statistics/{scrap_id}",
            headers=self._headers(),
        )
        self.assertEqual(scrap_response.status_code, 200, scrap_response.text)
        scrap_payload = scrap_response.json()["data"]
        self.assertEqual(scrap_payload["progress"], "applied")
        self.assertIsNotNone(scrap_payload["applied_at"])
        self.assertEqual(
            scrap_payload["related_repair_orders"][0]["status"], "completed"
        )

        repair_response = self.client.get(
            f"/api/v1/production/repair-orders/{repair_order_id}/detail",
            headers=self._headers(),
        )
        self.assertEqual(repair_response.status_code, 200, repair_response.text)
        repair_payload = repair_response.json()["data"]
        self.assertEqual(repair_payload["status"], "completed")
        self.assertEqual(
            repair_payload["defect_rows"][0]["production_record_id"],
            production_record_id,
        )
        self.assertEqual(
            repair_payload["defect_rows"][0]["production_record_quantity"], 6
        )

    def test_pipeline_instances_support_business_filters_and_process_name(self) -> None:
        stage_a = self._create_stage("D1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="D1"
        )
        stage_b = self._create_stage("D2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="D2"
        )
        product = self._create_product("并行追踪")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(process_rows), 2)
            admin = db.query(User).filter(User.username == "admin").first()
            assert admin is not None
            for process_row in process_rows:
                db.add(
                    ProductionSubOrder(
                        order_process_id=process_row.id,
                        operator_user_id=admin.id,
                        assigned_quantity=5,
                        completed_quantity=0,
                        status="pending",
                        is_visible=True,
                    )
                )
            db.commit()
        finally:
            db.close()

        enable_response = self.client.put(
            f"/api/v1/production/orders/{order['id']}/pipeline-mode",
            headers=self._headers(),
            json={
                "enabled": True,
                "process_codes": [process_a["code"], process_b["code"]],
            },
        )
        self.assertEqual(enable_response.status_code, 200, enable_response.text)

        list_response = self.client.get(
            "/api/v1/production/pipeline-instances",
            headers=self._headers(),
            params={
                "order_id": order["id"],
                "process_keyword": process_a["name"],
            },
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        items = list_response.json()["data"]["items"]
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["process_code"], process_a["code"])
        self.assertEqual(items[0]["process_name"], process_a["name"])
        self.assertTrue(items[0]["pipeline_link_id"])

        instance_no = items[0]["pipeline_instance_no"]
        no_response = self.client.get(
            "/api/v1/production/pipeline-instances",
            headers=self._headers(),
            params={
                "order_id": order["id"],
                "pipeline_instance_no": instance_no[-8:],
            },
        )
        self.assertEqual(no_response.status_code, 200, no_response.text)
        no_items = no_response.json()["data"]["items"]
        self.assertEqual(len(no_items), 1)
        self.assertEqual(no_items[0]["pipeline_instance_no"], instance_no)
        sub_order_id = items[0]["sub_order_id"]

        sub_order_response = self.client.get(
            "/api/v1/production/pipeline-instances",
            headers=self._headers(),
            params={
                "order_id": order["id"],
                "sub_order_id": sub_order_id,
            },
        )
        self.assertEqual(sub_order_response.status_code, 200, sub_order_response.text)
        sub_order_items = sub_order_response.json()["data"]["items"]
        self.assertEqual(len(sub_order_items), 1)
        self.assertEqual(sub_order_items[0]["sub_order_id"], sub_order_id)

    def test_pipeline_execution_requires_explicit_instance_binding_and_sequence(
        self,
    ) -> None:
        stage_a = self._create_stage("P1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="P1"
        )
        stage_b = self._create_stage("P2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="P2"
        )
        product = self._create_product("并行绑定")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            admin = db.query(User).filter(User.username == "admin").first()
            assert admin is not None
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            self.assertEqual(len(process_rows), 2)
            for process_row in process_rows:
                db.add(
                    ProductionSubOrder(
                        order_process_id=process_row.id,
                        operator_user_id=admin.id,
                        assigned_quantity=5,
                        completed_quantity=0,
                        status="pending",
                        is_visible=True,
                    )
                )
            today_code = (
                db.query(DailyVerificationCode)
                .filter(DailyVerificationCode.verify_date == date.today())
                .first()
            )
            if today_code is None:
                today_code = DailyVerificationCode(
                    verify_date=date.today(),
                    code="code-1",
                    created_by_user_id=admin.id,
                )
                db.add(today_code)
            else:
                today_code.code = "code-1"
            db.commit()
        finally:
            db.close()

        enable_response = self.client.put(
            f"/api/v1/production/orders/{order['id']}/pipeline-mode",
            headers=self._headers(),
            json={
                "enabled": True,
                "process_codes": [process_a["code"], process_b["code"]],
            },
        )
        self.assertEqual(enable_response.status_code, 200, enable_response.text)

        list_response = self.client.get(
            "/api/v1/production/pipeline-instances",
            headers=self._headers(),
            params={"order_id": order["id"]},
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        items = list_response.json()["data"]["items"]
        first_instance = next(
            item for item in items if item["process_code"] == process_a["code"]
        )
        second_instance = next(
            item for item in items if item["process_code"] == process_b["code"]
        )
        self.assertEqual(
            first_instance["pipeline_link_id"], second_instance["pipeline_link_id"]
        )

        missing_binding_response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/first-article",
            headers=self._headers(),
            json={
                "order_process_id": second_instance["order_process_id"],
                "verification_code": "code-1",
            },
        )
        self.assertEqual(missing_binding_response.status_code, 400)
        self.assertIn(
            "Pipeline instance binding is required", missing_binding_response.text
        )

        blocked_response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/first-article",
            headers=self._headers(),
            json={
                "order_process_id": second_instance["order_process_id"],
                "pipeline_instance_id": second_instance["id"],
                "verification_code": "code-1",
            },
        )
        self.assertEqual(blocked_response.status_code, 409)
        self.assertIn("previous pipeline instance progress", blocked_response.text)

        db = SessionLocal()
        try:
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(order["id"]))
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            previous_process = process_rows[0]
            current_process = process_rows[1]
            previous_process.completed_quantity = 1
            previous_process.status = "partial"
            current_process.visible_quantity = 1
            previous_sub_order = (
                db.query(ProductionSubOrder)
                .filter(ProductionSubOrder.order_process_id == previous_process.id)
                .first()
            )
            assert previous_sub_order is not None
            previous_sub_order.completed_quantity = 1
            previous_sub_order.status = "pending"
            previous_instance = (
                db.query(ProcessPipelineInstance)
                .filter(
                    ProcessPipelineInstance.order_process_id
                    == previous_process.id,
                    ProcessPipelineInstance.pipeline_seq
                    == int(second_instance["pipeline_seq"]),
                )
                .first()
            )
            assert previous_instance is not None
            previous_instance.pipeline_link_id = "BROKEN-LINK"
            db.commit()
        finally:
            db.close()

        mismatched_link_response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/first-article",
            headers=self._headers(),
            json={
                "order_process_id": second_instance["order_process_id"],
                "pipeline_instance_id": second_instance["id"],
                "verification_code": "code-1",
            },
        )
        self.assertEqual(mismatched_link_response.status_code, 409)
        self.assertIn("missing or inactive", mismatched_link_response.text)

        db = SessionLocal()
        try:
            previous_process = (
                db.query(ProductionOrderProcess)
                .filter(
                    ProductionOrderProcess.order_id == int(order["id"]),
                    ProductionOrderProcess.process_order == 1,
                )
                .first()
            )
            assert previous_process is not None
            previous_instance = (
                db.query(ProcessPipelineInstance)
                .filter(
                    ProcessPipelineInstance.order_process_id
                    == previous_process.id,
                    ProcessPipelineInstance.pipeline_seq
                    == int(second_instance["pipeline_seq"]),
                )
                .first()
            )
            assert previous_instance is not None
            previous_instance.pipeline_link_id = second_instance["pipeline_link_id"]
            db.commit()
        finally:
            db.close()

        first_article_response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/first-article",
            headers=self._headers(),
            json={
                "order_process_id": second_instance["order_process_id"],
                "pipeline_instance_id": second_instance["id"],
                "verification_code": "code-1",
            },
        )
        self.assertEqual(
            first_article_response.status_code, 200, first_article_response.text
        )

        missing_report_binding = self.client.post(
            f"/api/v1/production/orders/{order['id']}/end-production",
            headers=self._headers(),
            json={
                "order_process_id": second_instance["order_process_id"],
                "quantity": 1,
            },
        )
        self.assertEqual(missing_report_binding.status_code, 400)
        self.assertIn(
            "Pipeline instance binding is required", missing_report_binding.text
        )

        report_response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/end-production",
            headers=self._headers(),
            json={
                "order_process_id": second_instance["order_process_id"],
                "pipeline_instance_id": second_instance["id"],
                "quantity": 1,
            },
        )
        self.assertEqual(report_response.status_code, 200, report_response.text)

    def test_manual_production_export_uses_chinese_order_status_label(self) -> None:
        stage = self._create_stage("M1")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="M1"
        )
        product = self._create_product("手工导出")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            order_row.status = "in_progress"
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            admin = db.query(User).filter(User.username == "admin").first()
            assert process_row is not None and admin is not None
            db.add(
                ProductionRecord(
                    order_id=order_row.id,
                    order_process_id=process_row.id,
                    sub_order_id=None,
                    operator_user_id=admin.id,
                    production_quantity=3,
                    record_type="production",
                    created_at=datetime(2026, 3, 5, 9, 0, tzinfo=UTC),
                )
            )
            db.commit()
        finally:
            db.close()

        response = self.client.post(
            "/api/v1/production/data/manual/export",
            headers=self._headers(),
            json={
                "stat_mode": "main_order",
                "start_date": "2026-03-01",
                "end_date": "2026-03-31",
                "order_status": "all",
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        csv_text = base64.b64decode(response.json()["data"]["content_base64"]).decode(
            "utf-8-sig"
        )
        rows = list(csv.reader(io.StringIO(csv_text)))
        self.assertEqual(rows[1][9], "生产中")

    def test_first_article_rich_submission_and_queries_work(self) -> None:
        stage = self._create_stage("FA1")
        process = self._create_process(
            stage_id=stage["id"],
            stage_code=stage["code"],
            suffix="FA1",
        )
        product = self._create_product("富首件")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )
        participant_a = self._create_active_user("A")
        participant_b = self._create_active_user("B")

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            admin = db.query(User).filter(User.username == "admin").first()
            assert process_row is not None and admin is not None

            today_code = (
                db.query(DailyVerificationCode)
                .filter(DailyVerificationCode.verify_date == date.today())
                .first()
            )
            if today_code is None:
                today_code = DailyVerificationCode(
                    verify_date=date.today(),
                    code="code-fa1",
                    created_by_user_id=admin.id,
                )
                db.add(today_code)
            else:
                today_code.code = "code-fa1"

            template = FirstArticleTemplate(
                product_id=order_row.product_id,
                process_code=process_row.process_code,
                template_name="首件模板-FA1",
                check_content="模板检验内容",
                test_value="模板测试值",
                is_enabled=True,
            )
            db.add(
                ProductionSubOrder(
                    order_process_id=process_row.id,
                    operator_user_id=admin.id,
                    assigned_quantity=10,
                    completed_quantity=0,
                    status="pending",
                    is_visible=True,
                )
            )
            db.add(template)
            db.commit()
            db.refresh(template)
            process_id = int(process_row.id)
            template_id = int(template.id)
        finally:
            db.close()

        template_response = self.client.get(
            f"/api/v1/production/orders/{order['id']}/first-article/templates",
            headers=self._headers(),
            params={"order_process_id": process_id},
        )
        self.assertEqual(template_response.status_code, 200, template_response.text)
        self.assertEqual(
            template_response.json()["data"]["items"][0]["id"], template_id
        )

        participant_response = self.client.get(
            f"/api/v1/production/orders/{order['id']}/first-article/participant-users",
            headers=self._headers(),
        )
        self.assertEqual(
            participant_response.status_code, 200, participant_response.text
        )
        participant_ids = {
            int(item["id"]) for item in participant_response.json()["data"]["items"]
        }
        self.assertIn(participant_a.id, participant_ids)
        self.assertIn(participant_b.id, participant_ids)

        parameter_response = self.client.get(
            f"/api/v1/production/orders/{order['id']}/first-article/parameters",
            headers=self._headers(),
            params={"order_process_id": process_id},
        )
        self.assertEqual(parameter_response.status_code, 200, parameter_response.text)
        self.assertGreater(parameter_response.json()["data"]["total"], 0)

        submit_response = self.client.post(
            f"/api/v1/production/orders/{order['id']}/first-article",
            headers=self._headers(),
            json={
                "order_process_id": process_id,
                "template_id": template_id,
                "check_content": "实测检验内容",
                "test_value": "9.86",
                "result": "failed",
                "participant_user_ids": [participant_a.id, participant_b.id],
                "verification_code": "code-fa1",
                "remark": "首件富表单提交",
            },
        )
        self.assertEqual(submit_response.status_code, 200, submit_response.text)

        db = SessionLocal()
        try:
            record = (
                db.query(FirstArticleRecord)
                .filter(FirstArticleRecord.order_id == int(order["id"]))
                .order_by(FirstArticleRecord.id.desc())
                .first()
            )
            assert record is not None
            self.assertEqual(record.template_id, template_id)
            self.assertEqual(record.check_content, "实测检验内容")
            self.assertEqual(record.test_value, "9.86")
            self.assertEqual(record.result, "failed")
            participant_ids = {item.user_id for item in record.participants}
            self.assertEqual(participant_ids, {participant_a.id, participant_b.id})
        finally:
            db.close()

    def test_scrap_and_repair_detail_include_applied_and_report_trace(self) -> None:
        stage = self._create_stage("R1")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="R1"
        )
        product = self._create_product("维修追溯")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            admin = db.query(User).filter(User.username == "admin").first()
            assert process_row is not None and admin is not None
            production_record = ProductionRecord(
                order_id=order_row.id,
                order_process_id=process_row.id,
                sub_order_id=None,
                operator_user_id=admin.id,
                production_quantity=6,
                record_type="production",
            )
            db.add(production_record)
            db.flush()
            repair_order = RepairOrder(
                repair_order_code=f"RW-IT-{int(time.time() * 1000)}",
                source_order_id=order_row.id,
                source_order_code=order_row.order_code,
                product_id=order_row.product_id,
                product_name=order_row.product.name,
                source_order_process_id=process_row.id,
                source_process_code=process_row.process_code,
                source_process_name=process_row.process_name,
                sender_user_id=admin.id,
                sender_username=admin.username,
                production_quantity=6,
                repair_quantity=2,
                repaired_quantity=1,
                scrap_quantity=1,
                scrap_replenished=False,
                repair_time=datetime(2026, 3, 5, 9, 0, tzinfo=UTC),
                status="completed",
                completed_at=datetime(2026, 3, 5, 10, 0, tzinfo=UTC),
                repair_operator_user_id=admin.id,
                repair_operator_username=admin.username,
            )
            db.add(repair_order)
            db.flush()
            db.add(
                RepairDefectPhenomenon(
                    repair_order_id=repair_order.id,
                    production_record_id=production_record.id,
                    order_id=order_row.id,
                    order_code=order_row.order_code,
                    product_id=order_row.product_id,
                    product_name=order_row.product.name,
                    process_id=process_row.id,
                    process_code=process_row.process_code,
                    process_name=process_row.process_name,
                    phenomenon="毛刺",
                    quantity=2,
                    operator_user_id=admin.id,
                    operator_username=admin.username,
                    production_time=datetime(2026, 3, 5, 9, 0, tzinfo=UTC),
                )
            )
            scrap_row = ProductionScrapStatistics(
                order_id=order_row.id,
                order_code=order_row.order_code,
                product_id=order_row.product_id,
                product_name=order_row.product.name,
                process_id=process_row.id,
                process_code=process_row.process_code,
                process_name=process_row.process_name,
                operator_user_id=admin.id,
                operator_username=admin.username,
                scrap_reason="毛刺报废",
                scrap_quantity=1,
                last_scrap_time=datetime(2026, 3, 5, 10, 0, tzinfo=UTC),
                progress="applied",
                applied_at=datetime(2026, 3, 5, 10, 30, tzinfo=UTC),
            )
            db.add(scrap_row)
            db.commit()
            db.refresh(repair_order)
            db.refresh(scrap_row)
            self.repair_order_ids.append(int(repair_order.id))
            self.scrap_statistics_ids.append(int(scrap_row.id))
            repair_order_id = int(repair_order.id)
            scrap_id = int(scrap_row.id)
            production_record_id = int(production_record.id)
        finally:
            db.close()

        scrap_response = self.client.get(
            f"/api/v1/production/scrap-statistics/{scrap_id}",
            headers=self._headers(),
        )
        self.assertEqual(scrap_response.status_code, 200, scrap_response.text)
        self.assertEqual(scrap_response.json()["data"]["progress"], "applied")
        self.assertEqual(
            datetime.fromisoformat(
                scrap_response.json()["data"]["applied_at"].replace("Z", "+00:00")
            ).astimezone(UTC),
            datetime(2026, 3, 5, 10, 30, tzinfo=UTC),
        )

        repair_response = self.client.get(
            f"/api/v1/production/repair-orders/{repair_order_id}/detail",
            headers=self._headers(),
        )
        self.assertEqual(repair_response.status_code, 200, repair_response.text)
        defect_payload = repair_response.json()["data"]["defect_rows"][0]
        self.assertEqual(defect_payload["production_record_id"], production_record_id)
        self.assertEqual(defect_payload["production_record_quantity"], 6)

    def test_order_export_uses_business_labels_and_current_process(self) -> None:
        stage_a = self._create_stage("X1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="X1"
        )
        stage_b = self._create_stage("X2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="X2"
        )
        product = self._create_product("导出台账")
        self._activate_product(product)
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                },
                {
                    "step_order": 2,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                },
            ],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_rows = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .order_by(ProductionOrderProcess.process_order.asc())
                .all()
            )
            process_rows[0].status = "completed"
            process_rows[0].completed_quantity = order_row.quantity
            process_rows[1].status = "in_progress"
            process_rows[1].visible_quantity = order_row.quantity
            process_rows[1].completed_quantity = 3
            order_row.status = "in_progress"
            order_row.current_process_code = process_rows[1].process_code
            order_row.pipeline_enabled = True
            db.commit()
        finally:
            db.close()

        export_response = self.client.post(
            "/api/v1/production/orders/export",
            headers=self._headers(),
            json={"keyword": order["order_code"]},
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        content_base64 = export_response.json()["data"]["content_base64"]
        csv_text = base64.b64decode(content_base64).decode("utf-8-sig")
        rows = list(csv.reader(io.StringIO(csv_text)))
        self.assertEqual(
            rows[0],
            [
                "订单号",
                "产品名称",
                "产品版本",
                "数量",
                "当前状态",
                "当前工序",
                "工艺模板",
                "模板版本",
                "并行模式",
                "开始日期",
                "交期",
                "创建人",
                "更新时间",
            ],
        )
        self.assertEqual(rows[1][0], order["order_code"])
        self.assertEqual(rows[1][4], "生产中")
        self.assertEqual(rows[1][5], process_b["name"])
        self.assertEqual(rows[1][8], "开启")

    def test_my_order_export_matches_query_filters_and_csv_columns(self) -> None:
        stage_a = self._create_stage("Q1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="Q1"
        )
        stage_b = self._create_stage("Q2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="Q2"
        )
        matched_product = self._create_product("查询导出命中")
        self._activate_product(matched_product)
        other_product = self._create_product("查询导出未命中")
        self._activate_product(other_product)
        matched_order = self._create_order(
            product_id=matched_product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                }
            ],
        )
        other_order = self._create_order(
            product_id=other_product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                }
            ],
        )
        self._ensure_admin_visible_sub_order(int(matched_order["id"]))
        self._ensure_admin_visible_sub_order(int(other_order["id"]))

        db = SessionLocal()
        try:
            matched_order_row = db.get(ProductionOrder, int(matched_order["id"]))
            other_order_row = db.get(ProductionOrder, int(other_order["id"]))
            assert matched_order_row is not None and other_order_row is not None
            matched_process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == matched_order_row.id)
                .first()
            )
            other_process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == other_order_row.id)
                .first()
            )
            assert matched_process_row is not None and other_process_row is not None

            matched_order_row.status = "in_progress"
            matched_order_row.current_process_code = matched_process_row.process_code
            matched_order_row.due_date = date(2026, 3, 18)
            matched_order_row.remark = "查询页导出备注"
            matched_order_row.updated_at = datetime(2026, 3, 5, 9, 30, tzinfo=UTC)
            matched_process_row.status = "in_progress"
            matched_process_row.visible_quantity = matched_order_row.quantity

            other_order_row.status = "pending"
            other_order_row.current_process_code = other_process_row.process_code
            other_process_row.status = "pending"
            other_process_row.visible_quantity = other_order_row.quantity
            db.commit()
            matched_process_id = int(matched_process_row.id)
        finally:
            db.close()

        export_response = self.client.post(
            "/api/v1/production/my-orders/export",
            headers=self._headers(),
            json={
                "keyword": "PO-IT-",
                "view_mode": "own",
                "order_status": "in_progress",
                "current_process_id": matched_process_id,
            },
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        export_data = export_response.json()["data"]
        self.assertEqual(export_data["exported_count"], 1)

        csv_text = base64.b64decode(export_data["content_base64"]).decode("utf-8-sig")
        rows = list(csv.reader(io.StringIO(csv_text)))
        self.assertEqual(
            rows[0],
            [
                "订单编号",
                "产品型号",
                "供应商",
                "工序",
                "数量概况",
                "状态",
                "交货日期",
                "备注",
                "工单视角",
                "操作员",
                "更新时间",
            ],
        )
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1][0], matched_order["order_code"])
        self.assertEqual(rows[1][1], matched_product["name"])
        self.assertTrue(rows[1][2])
        self.assertEqual(rows[1][3], process_a["name"])
        self.assertEqual(rows[1][4], "可见10 / 分配10 / 完成0")
        self.assertEqual(rows[1][5], "生产中")
        self.assertEqual(rows[1][6], "2026-03-18")
        self.assertEqual(rows[1][7], "查询页导出备注")
        self.assertEqual(rows[1][8], "我的工单")
        self.assertEqual(rows[1][9], "admin")
        self.assertTrue(rows[1][10].startswith("2026-03-05 "))
        self.assertTrue(rows[1][10].endswith(":30:00"))

    def test_scrap_statistics_support_exact_product_and_process_filters(self) -> None:
        stage_a = self._create_stage("E1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="E1"
        )
        stage_b = self._create_stage("E2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="E2"
        )
        matched_product = self._create_product("报废精确匹配")
        self._activate_product(matched_product)
        other_product = self._create_product("报废精确匹配其他")
        self._activate_product(other_product)
        matched_order = self._create_order(
            product_id=matched_product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_a["id"],
                    "process_id": process_a["id"],
                }
            ],
        )
        other_order = self._create_order(
            product_id=other_product["id"],
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage_b["id"],
                    "process_id": process_b["id"],
                }
            ],
        )

        db = SessionLocal()
        try:
            matched_process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(matched_order["id"]))
                .first()
            )
            other_process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == int(other_order["id"]))
                .first()
            )
            assert matched_process_row is not None
            assert other_process_row is not None
            matched_process_id = matched_process_row.id
            other_process_id = other_process_row.id
        finally:
            db.close()

        matched_scrap_id = self._create_scrap_statistics(
            order_id=int(matched_order["id"]),
            order_code=matched_order["order_code"],
            product_id=int(matched_product["id"]),
            product_name=matched_product["name"],
            process_id=matched_process_id,
            process_code=process_a["code"],
            process_name=process_a["name"],
            scrap_reason="定位不良",
        )
        self._create_scrap_statistics(
            order_id=int(other_order["id"]),
            order_code=other_order["order_code"],
            product_id=int(other_product["id"]),
            product_name=other_product["name"],
            process_id=other_process_id,
            process_code=process_b["code"],
            process_name=process_b["name"],
            scrap_reason="毛刺",
        )

        list_response = self.client.get(
            "/api/v1/production/scrap-statistics",
            headers=self._headers(),
            params={
                "product_name": matched_product["name"],
                "process_code": process_a["code"],
            },
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        list_data = list_response.json()["data"]
        self.assertEqual(list_data["total"], 1)
        self.assertEqual(len(list_data["items"]), 1)
        self.assertEqual(list_data["items"][0]["id"], matched_scrap_id)
        self.assertEqual(list_data["items"][0]["product_name"], matched_product["name"])
        self.assertEqual(list_data["items"][0]["process_code"], process_a["code"])

        export_response = self.client.post(
            "/api/v1/production/scrap-statistics/export",
            headers=self._headers(),
            json={
                "product_name": matched_product["name"],
                "process_code": process_a["code"],
            },
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        export_data = export_response.json()["data"]
        self.assertEqual(export_data["exported_count"], 1)


if __name__ == "__main__":
    unittest.main()
