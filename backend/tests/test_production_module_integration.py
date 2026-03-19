import sys
import time
import unittest
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

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
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
            json={"code": unique, "name": unique, "sort_order": 0, "remark": "生产集成测试"},
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.stage_ids.append(int(row["id"]))
        return row

    def _create_process(self, *, stage_id: int, stage_code: str, suffix: str) -> dict:
        serial = '01' if suffix.endswith('1') or suffix in {'A', 'B'} else '02'
        unique = f"{stage_code}-{serial}"
        response = self.client.post(
            "/api/v1/craft/processes",
            headers=self._headers(),
            json={"code": unique, "name": unique, "stage_id": stage_id, "remark": "生产集成测试"},
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

    def test_end_production_blocks_when_report_plus_defect_exceeds_visible_quantity(self) -> None:
        stage = self._create_stage("A")
        process = self._create_process(stage_id=stage["id"], stage_code=stage["code"], suffix="A")
        product = self._create_product("数量口径")
        order = self._create_order(
            product_id=product["id"],
            steps=[{"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}],
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            assert order_row is not None
            process_row = db.query(ProductionOrderProcess).filter(ProductionOrderProcess.order_id == order_row.id).first()
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
        process = self._create_process(stage_id=stage["id"], stage_code=stage["code"], suffix="B")
        product = self._create_product("删除追溯")
        order = self._create_order(
            product_id=product["id"],
            steps=[{"step_order": 1, "stage_id": stage["id"], "process_id": process["id"]}],
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
        self.order_ids.remove(int(order["id"]))

    def test_complete_repair_order_accepts_multiple_return_allocations(self) -> None:
        stage_a = self._create_stage("C1")
        process_a = self._create_process(stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="C1")
        stage_b = self._create_stage("C2")
        process_b = self._create_process(stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="C2")
        product = self._create_product("多回流")
        order = self._create_order(
            product_id=product["id"],
            steps=[
                {"step_order": 1, "stage_id": stage_a["id"], "process_id": process_a["id"]},
                {"step_order": 2, "stage_id": stage_b["id"], "process_id": process_b["id"]},
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
                    {"phenomenon": "毛刺", "reason": "调整刀具", "quantity": 2, "is_scrap": False}
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


if __name__ == "__main__":
    unittest.main()
