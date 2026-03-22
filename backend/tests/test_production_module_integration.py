import sys
import time
import unittest
from datetime import UTC, datetime
from pathlib import Path

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.order_event_log import OrderEventLog  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.production_scrap_statistics import (  # noqa: E402
    ProductionScrapStatistics,
)
from app.models.production_sub_order import ProductionSubOrder  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.repair_order import RepairOrder  # noqa: E402
from app.models.user import User  # noqa: E402


class ProductionModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.token = self._login()
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []
        self.order_ids: list[int] = []
        self.repair_order_ids: list[int] = []
        self.scrap_statistics_ids: list[int] = []

    def tearDown(self) -> None:
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

    def _login(self) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
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
        response = self.client.post(
            "/api/v1/production/orders",
            headers=self._headers(),
            json={
                "order_code": order_code,
                "product_id": product_id,
                "quantity": 10,
                "process_steps": steps,
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.order_ids.append(int(row["id"]))
        return row

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

        instance_no = items[0]["pipeline_sub_order_no"]
        no_response = self.client.get(
            "/api/v1/production/pipeline-instances",
            headers=self._headers(),
            params={
                "order_id": order["id"],
                "pipeline_sub_order_no": instance_no[-8:],
            },
        )
        self.assertEqual(no_response.status_code, 200, no_response.text)
        no_items = no_response.json()["data"]["items"]
        self.assertEqual(len(no_items), 1)
        self.assertEqual(no_items[0]["pipeline_sub_order_no"], instance_no)
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
