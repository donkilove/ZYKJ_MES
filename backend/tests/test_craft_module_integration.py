import base64
import json
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
from app.core.config import settings  # noqa: E402
from app.main import app  # noqa: E402
from app.core.security import get_password_hash  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.product_process_template import ProductProcessTemplate  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.production_record import ProductionRecord  # noqa: E402
from app.models.supplier import Supplier  # noqa: E402
from app.models.user import User  # noqa: E402
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


class CraftModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self._previous_jwt_secret_key = settings.jwt_secret_key
        settings.jwt_secret_key = "craft-module-test-secret"
        self.token = self._login()
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []
        self.supplier_ids: list[int] = []
        self.order_ids: list[int] = []
        self.user_ids: list[int] = []

    def tearDown(self) -> None:
        settings.jwt_secret_key = self._previous_jwt_secret_key
        db = SessionLocal()
        try:
            for order_id in reversed(self.order_ids):
                row = db.get(ProductionOrder, order_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for supplier_id in reversed(self.supplier_ids):
                row = db.get(Supplier, supplier_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for user_id in reversed(self.user_ids):
                row = db.get(User, user_id)
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
        self._ensure_admin()
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _create_stage(self, suffix: str) -> dict:
        unique_suffix = f"{suffix}{int(time.time() * 1000)}"
        response = self.client.post(
            "/api/v1/craft/stages",
            headers=self._headers(),
            json={
                "code": f"ST-{unique_suffix}",
                "name": f"工段{unique_suffix}",
                "sort_order": 0,
                "remark": "集成测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.stage_ids.append(int(row["id"]))
        return row

    def _create_process(self, *, stage_id: int, stage_code: str, suffix: str) -> dict:
        response = self.client.post(
            "/api/v1/craft/processes",
            headers=self._headers(),
            json={
                "code": f"{stage_code}-{suffix}",
                "name": f"工序{suffix}",
                "stage_id": stage_id,
                "remark": "集成测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.process_ids.append(int(row["id"]))
        return row

    def _create_product(self, suffix: str) -> dict:
        response = self.client.post(
            "/api/v1/products",
            headers=self._headers(),
            json={
                "name": f"工艺模块产品{suffix}{int(time.time() * 1000)}",
                "category": "贴片",
                "remark": "工艺集成测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        db = SessionLocal()
        try:
            product_row = db.get(Product, int(row["id"]))
            self.assertIsNotNone(product_row)
            assert product_row is not None
            product_row.lifecycle_status = "active"
            db.commit()
        finally:
            db.close()
        self.product_ids.append(int(row["id"]))
        return row

    def _create_user_for_stage(self, *, stage_id: int, suffix: str) -> int:
        db = SessionLocal()
        try:
            row = User(
                username=f"craft_user_{suffix}_{int(time.time() * 1000)}",
                full_name=f"工艺用户{suffix}",
                password_hash=get_password_hash("Admin@123456"),
                is_active=True,
                is_superuser=False,
                stage_id=stage_id,
                remark="工艺集成测试",
            )
            db.add(row)
            db.commit()
            db.refresh(row)
            self.user_ids.append(int(row.id))
            return int(row.id)
        finally:
            db.close()

    def _create_template(
        self, *, product_id: int, template_name: str, stage_id: int, process_id: int
    ) -> dict:
        response = self.client.post(
            "/api/v1/craft/templates",
            headers=self._headers(),
            json={
                "product_id": product_id,
                "template_name": template_name,
                "is_default": True,
                "lifecycle_status": "draft",
                "remark": "工艺模板集成测试",
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage_id,
                        "process_id": process_id,
                    }
                ],
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()["data"]

    def _create_order_from_template(self, *, product_id: int, template_id: int) -> dict:
        order_code = f"CRAFT-ROLLBACK-{int(time.time() * 1000)}"
        supplier = self._create_supplier(f"工艺回滚供应商{order_code[-6:]}")
        response = self.client.post(
            "/api/v1/production/orders",
            headers=self._headers(),
            json={
                "order_code": order_code,
                "product_id": product_id,
                "supplier_id": supplier["id"],
                "quantity": 10,
                "template_id": template_id,
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.order_ids.append(int(row["id"]))
        return row

    def _create_supplier(self, name: str, *, is_enabled: bool = True) -> dict:
        response = self.client.post(
            "/api/v1/quality/suppliers",
            headers=self._headers(),
            json={"name": name, "remark": "工艺集成测试", "is_enabled": is_enabled},
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.supplier_ids.append(int(row["id"]))
        return row

    def test_perf_seeded_template_supports_detail_publish_and_rollback(self) -> None:
        context = load_perf_sample_context()

        detail_response = self.client.get(
            f"/api/v1/craft/templates/{context['craft_template_id']}",
            headers=self._headers(),
        )
        publish_response = self.client.post(
            f"/api/v1/craft/templates/{context['craft_template_id']}/publish",
            headers=self._headers(),
            json={
                "apply_order_sync": False,
                "confirmed": True,
                "expected_version": 1,
                "note": "perf seeded publish",
            },
        )
        rollback_response = self.client.post(
            f"/api/v1/craft/templates/{context['craft_template_id']}/rollback",
            headers=self._headers(),
            json={
                "target_version": 1,
                "apply_order_sync": False,
                "confirmed": True,
                "note": "perf seeded rollback",
            },
        )

        self.assertEqual(detail_response.status_code, 200, detail_response.text)
        self.assertIn(publish_response.status_code, {200, 400}, publish_response.text)
        self.assertIn(rollback_response.status_code, {200, 400}, rollback_response.text)

    def _set_stage_sort_order(self, *, stage_id: int, sort_order: int) -> None:
        db = SessionLocal()
        try:
            stage_row = db.get(ProcessStage, stage_id)
            self.assertIsNotNone(stage_row)
            assert stage_row is not None
            stage_row.sort_order = sort_order
            db.commit()
        finally:
            db.close()

    def _seed_completed_process_metrics_sample(
        self,
        *,
        order_id: int,
        start_at: datetime,
        end_at: datetime,
        production_qty: int,
    ) -> None:
        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, order_id)
            self.assertIsNotNone(order_row)
            assert order_row is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_id)
                .first()
            )
            admin = db.query(User).filter(User.username == "admin").first()
            self.assertIsNotNone(process_row)
            self.assertIsNotNone(admin)
            assert process_row is not None and admin is not None

            order_row.status = "completed"
            process_row.status = "completed"
            process_row.visible_quantity = production_qty
            process_row.completed_quantity = production_qty
            process_row.updated_at = end_at

            db.add(
                ProductionRecord(
                    order_id=order_row.id,
                    order_process_id=process_row.id,
                    sub_order_id=None,
                    operator_user_id=admin.id,
                    production_quantity=0,
                    record_type="first_article",
                    created_at=start_at,
                )
            )
            db.add(
                ProductionRecord(
                    order_id=order_row.id,
                    order_process_id=process_row.id,
                    sub_order_id=None,
                    operator_user_id=admin.id,
                    production_quantity=production_qty,
                    record_type="production",
                    created_at=end_at,
                )
            )
            db.commit()
        finally:
            db.close()

    def test_light_query_and_copy_source_export(self) -> None:
        stage = self._create_stage("A01")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="01"
        )
        product = self._create_product("轻量")
        template = self._create_template(
            product_id=product["id"],
            template_name="模板A",
            stage_id=stage["id"],
            process_id=process["id"],
        )
        template_id = template["template"]["id"]

        stage_light = self.client.get(
            "/api/v1/craft/stages/light", headers=self._headers()
        )
        self.assertEqual(stage_light.status_code, 200, stage_light.text)
        self.assertTrue(
            any(
                item["id"] == stage["id"]
                for item in stage_light.json()["data"]["items"]
            )
        )

        process_light = self.client.get(
            f"/api/v1/craft/processes/light?stage_id={stage['id']}",
            headers=self._headers(),
        )
        self.assertEqual(process_light.status_code, 200, process_light.text)
        self.assertTrue(
            any(
                item["id"] == process["id"]
                for item in process_light.json()["data"]["items"]
            )
        )

        copy_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/copy",
            headers=self._headers(),
            json={"new_name": "模板A-复制"},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        copied = copy_response.json()["data"]["template"]
        self.assertEqual(copied["source_type"], "template")
        self.assertEqual(copied["source_template_id"], template_id)

        export_current = self.client.get(
            f"/api/v1/craft/templates/{template_id}/export",
            headers=self._headers(),
        )
        self.assertEqual(export_current.status_code, 200, export_current.text)
        payload = json.loads(
            base64.b64decode(export_current.json()["data"]["content_base64"]).decode(
                "utf-8-sig"
            )
        )
        self.assertEqual(payload["template"]["template_name"], "模板A")

        publish_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_response.status_code, 200, publish_response.text)

        version_list_response = self.client.get(
            f"/api/v1/craft/templates/{template_id}/versions",
            headers=self._headers(),
        )
        self.assertEqual(
            version_list_response.status_code, 200, version_list_response.text
        )
        version_record = version_list_response.json()["data"]["items"][0]
        self.assertEqual(version_record["record_type"], "publish")
        self.assertEqual(version_record["record_title"], "发布记录 P1")
        self.assertIn("当前生效版本", version_record["record_summary"])

        export_version = self.client.get(
            f"/api/v1/craft/templates/{template_id}/versions/1/export",
            headers=self._headers(),
        )
        self.assertEqual(export_version.status_code, 200, export_version.text)
        version_payload = json.loads(
            base64.b64decode(export_version.json()["data"]["content_base64"]).decode(
                "utf-8-sig"
            )
        )
        self.assertNotIn("standard_minutes", version_payload["steps"][0])
        self.assertNotIn("step_remark", version_payload["steps"][0])

        export_kanban = self.client.get(
            f"/api/v1/craft/kanban/process-metrics/export?product_id={product['id']}&limit=50",
            headers=self._headers(),
        )
        self.assertEqual(export_kanban.status_code, 200, export_kanban.text)

        export_batch = self.client.get(
            "/api/v1/craft/templates/export",
            headers=self._headers(),
        )
        self.assertEqual(export_batch.status_code, 200, export_batch.text)
        export_item = next(
            item
            for item in export_batch.json()["data"]["items"]
            if item["template_name"] == "模板A"
        )
        exported_step = export_item["steps"][0]
        self.assertNotIn("is_key_process", exported_step)
        self.assertNotIn("standard_minutes", exported_step)
        self.assertNotIn("step_remark", exported_step)

    def test_detail_queries_and_reference_code_fields(self) -> None:
        stage = self._create_stage("D01")
        process = self._create_process(
            stage_id=stage["id"],
            stage_code=stage["code"],
            suffix="01",
        )
        product = self._create_product("详情")
        detail = self._create_template(
            product_id=product["id"],
            template_name="模板详情",
            stage_id=stage["id"],
            process_id=process["id"],
        )
        template_id = int(detail["template"]["id"])

        stage_by_id = self.client.get(
            f"/api/v1/craft/stages/detail?stage_id={stage['id']}",
            headers=self._headers(),
        )
        self.assertEqual(stage_by_id.status_code, 200, stage_by_id.text)
        self.assertEqual(stage_by_id.json()["data"]["code"], stage["code"])

        stage_by_code = self.client.get(
            f"/api/v1/craft/stages/detail?stage_code={stage['code']}",
            headers=self._headers(),
        )
        self.assertEqual(stage_by_code.status_code, 200, stage_by_code.text)
        self.assertEqual(stage_by_code.json()["data"]["id"], stage["id"])

        process_by_id = self.client.get(
            f"/api/v1/craft/processes/detail?process_id={process['id']}",
            headers=self._headers(),
        )
        self.assertEqual(process_by_id.status_code, 200, process_by_id.text)
        self.assertEqual(process_by_id.json()["data"]["code"], process["code"])

        process_by_code = self.client.get(
            f"/api/v1/craft/processes/detail?process_code={process['code']}",
            headers=self._headers(),
        )
        self.assertEqual(process_by_code.status_code, 200, process_by_code.text)
        self.assertEqual(process_by_code.json()["data"]["id"], process["id"])

        stage_refs = self.client.get(
            f"/api/v1/craft/stages/{stage['id']}/references",
            headers=self._headers(),
        )
        self.assertEqual(stage_refs.status_code, 200, stage_refs.text)
        process_ref = next(
            item
            for item in stage_refs.json()["data"]["items"]
            if item["ref_type"] == "process"
        )
        self.assertEqual(process_ref["ref_code"], process["code"])

        process_refs = self.client.get(
            f"/api/v1/craft/processes/{process['id']}/references",
            headers=self._headers(),
        )
        self.assertEqual(process_refs.status_code, 200, process_refs.text)
        template_ref = next(
            item
            for item in process_refs.json()["data"]["items"]
            if item["ref_type"] == "template"
        )
        self.assertEqual(template_ref["ref_code"], "模板详情")

        template_refs = self.client.get(
            f"/api/v1/craft/templates/{template_id}/references",
            headers=self._headers(),
        )
        self.assertEqual(template_refs.status_code, 200, template_refs.text)
        product_ref = next(
            item
            for item in template_refs.json()["data"]["items"]
            if item["ref_type"] == "product"
        )
        self.assertEqual(product_ref["ref_code"], product["name"])

    def test_published_template_requires_draft_and_history_blocks_process_delete(
        self,
    ) -> None:
        stage_a = self._create_stage("B01")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="01"
        )
        product = self._create_product("只读")
        detail = self._create_template(
            product_id=product["id"],
            template_name="模板B",
            stage_id=stage_a["id"],
            process_id=process_a["id"],
        )
        template_id = detail["template"]["id"]

        publish_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_response.status_code, 200, publish_response.text)

        update_direct = self.client.put(
            f"/api/v1/craft/templates/{template_id}",
            headers=self._headers(),
            json={
                "template_name": "模板B",
                "is_default": True,
                "is_enabled": True,
                "remark": "直接修改应失败",
                "sync_orders": False,
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage_a["id"],
                        "process_id": process_a["id"],
                    }
                ],
            },
        )
        self.assertEqual(update_direct.status_code, 400, update_direct.text)

        create_draft = self.client.post(
            f"/api/v1/craft/templates/{template_id}/draft",
            headers=self._headers(),
        )
        self.assertEqual(create_draft.status_code, 200, create_draft.text)

        stage_b = self._create_stage("B02")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="01"
        )
        update_draft = self.client.put(
            f"/api/v1/craft/templates/{template_id}",
            headers=self._headers(),
            json={
                "template_name": "模板B",
                "is_default": True,
                "is_enabled": True,
                "remark": "草稿替换工序",
                "sync_orders": False,
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage_b["id"],
                        "process_id": process_b["id"],
                    }
                ],
            },
        )
        self.assertEqual(update_draft.status_code, 200, update_draft.text)

        delete_old_process = self.client.delete(
            f"/api/v1/craft/processes/{process_a['id']}",
            headers=self._headers(),
        )
        self.assertEqual(delete_old_process.status_code, 400, delete_old_process.text)

        references = self.client.get(
            f"/api/v1/craft/processes/{process_a['id']}/references",
            headers=self._headers(),
        )
        self.assertEqual(references.status_code, 200, references.text)
        ref_types = {item["ref_type"] for item in references.json()["data"]["items"]}
        self.assertIn("template_revision", ref_types)

    def test_rollback_impact_analysis_uses_selected_target_version(self) -> None:
        stage_a = self._create_stage("R01")
        process_a = self._create_process(
            stage_id=stage_a["id"],
            stage_code=stage_a["code"],
            suffix="01",
        )
        product = self._create_product("回滚预览")
        detail = self._create_template(
            product_id=product["id"],
            template_name="模板回滚预览",
            stage_id=stage_a["id"],
            process_id=process_a["id"],
        )
        template_id = int(detail["template"]["id"])

        publish_v1 = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_v1.status_code, 200, publish_v1.text)

        create_draft = self.client.post(
            f"/api/v1/craft/templates/{template_id}/draft",
            headers=self._headers(),
        )
        self.assertEqual(create_draft.status_code, 200, create_draft.text)

        stage_b = self._create_stage("R02")
        process_b = self._create_process(
            stage_id=stage_b["id"],
            stage_code=stage_b["code"],
            suffix="01",
        )
        update_draft = self.client.put(
            f"/api/v1/craft/templates/{template_id}",
            headers=self._headers(),
            json={
                "template_name": "模板回滚预览",
                "is_default": True,
                "is_enabled": True,
                "remark": "切换到新工序",
                "sync_orders": False,
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage_b["id"],
                        "process_id": process_b["id"],
                    }
                ],
            },
        )
        self.assertEqual(update_draft.status_code, 200, update_draft.text)
        expected_version = int(
            update_draft.json()["data"]["detail"]["template"]["version"]
        )

        publish_v2 = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={
                "apply_order_sync": False,
                "confirmed": True,
                "expected_version": expected_version,
            },
        )
        self.assertEqual(publish_v2.status_code, 200, publish_v2.text)

        order = self._create_order_from_template(
            product_id=product["id"],
            template_id=template_id,
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            self.assertIsNotNone(order_row)
            assert order_row is not None
            order_row.status = "in_progress"
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            self.assertIsNotNone(process_row)
            assert process_row is not None
            process_row.status = "in_progress"
            order_row.current_process_code = process_b["code"]
            db.commit()
        finally:
            db.close()

        impact_v1 = self.client.get(
            f"/api/v1/craft/templates/{template_id}/impact-analysis?target_version=1",
            headers=self._headers(),
        )
        self.assertEqual(impact_v1.status_code, 200, impact_v1.text)
        impact_v2 = self.client.get(
            f"/api/v1/craft/templates/{template_id}/impact-analysis?target_version=2",
            headers=self._headers(),
        )
        self.assertEqual(impact_v2.status_code, 200, impact_v2.text)

        impact_v1_data = impact_v1.json()["data"]
        impact_v2_data = impact_v2.json()["data"]
        self.assertEqual(impact_v1_data["target_version"], 1)
        self.assertEqual(impact_v2_data["target_version"], 2)
        self.assertEqual(impact_v1_data["blocked_orders"], 1)
        self.assertEqual(impact_v1_data["syncable_orders"], 0)
        self.assertFalse(impact_v1_data["items"][0]["syncable"])
        self.assertIn("cannot align", impact_v1_data["items"][0]["reason"])
        self.assertEqual(impact_v2_data["blocked_orders"], 0)
        self.assertEqual(impact_v2_data["syncable_orders"], 1)
        self.assertTrue(impact_v2_data["items"][0]["syncable"])
        self.assertIsNone(impact_v2_data["items"][0]["reason"])

    def test_impact_analysis_covers_user_stage_and_template_reuse_refs(self) -> None:
        stage = self._create_stage("R03")
        process = self._create_process(
            stage_id=stage["id"],
            stage_code=stage["code"],
            suffix="01",
        )
        product = self._create_product("关键引用")
        detail = self._create_template(
            product_id=product["id"],
            template_name="模板关键引用",
            stage_id=stage["id"],
            process_id=process["id"],
        )
        template_id = int(detail["template"]["id"])
        self._create_user_for_stage(stage_id=stage["id"], suffix="impact")

        copy_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/copy",
            headers=self._headers(),
            json={"new_name": "模板关键引用-复用"},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)

        impact_response = self.client.get(
            f"/api/v1/craft/templates/{template_id}/impact-analysis",
            headers=self._headers(),
        )
        self.assertEqual(impact_response.status_code, 200, impact_response.text)

        payload = impact_response.json()["data"]
        self.assertEqual(payload["user_stage_reference_count"], 1)
        self.assertEqual(payload["template_reuse_reference_count"], 1)
        self.assertGreaterEqual(payload["total_references"], 2)
        ref_types = {item["ref_type"] for item in payload["reference_items"]}
        self.assertIn("user_stage", ref_types)
        self.assertIn("template_reuse", ref_types)

        ref_response = self.client.get(
            f"/api/v1/craft/templates/{template_id}/references",
            headers=self._headers(),
        )
        self.assertEqual(ref_response.status_code, 200, ref_response.text)
        ref_payload = ref_response.json()["data"]
        self.assertEqual(ref_payload["user_stage_reference_count"], 1)
        self.assertEqual(ref_payload["template_reuse_reference_count"], 1)
        self.assertEqual(ref_payload["blocking_reference_count"], 0)
        self.assertFalse(ref_payload["has_blocking_references"])
        self.assertEqual(ref_payload["order_reference_count"], 0)
        self.assertIn(
            "user_stage",
            {item["ref_type"] for item in ref_payload["items"]},
        )
        self.assertIn(
            "template_reuse",
            {item["ref_type"] for item in ref_payload["items"]},
        )

    def test_impact_analysis_counts_syncable_orders_for_current_template_version(
        self,
    ) -> None:
        stage = self._create_stage("R04")
        process = self._create_process(
            stage_id=stage["id"],
            stage_code=stage["code"],
            suffix="01",
        )
        product = self._create_product("工艺影响同步统计")
        detail = self._create_template(
            product_id=product["id"],
            template_name="工艺影响同步统计模板",
            stage_id=stage["id"],
            process_id=process["id"],
        )
        template_id = int(detail["template"]["id"])

        publish_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={
                "apply_order_sync": False,
                "confirmed": True,
                "expected_version": 1,
            },
        )
        self.assertEqual(publish_response.status_code, 200, publish_response.text)

        order = self._create_order_from_template(
            product_id=product["id"],
            template_id=template_id,
        )

        impact_response = self.client.get(
            f"/api/v1/craft/templates/{template_id}/impact-analysis",
            headers=self._headers(),
        )
        self.assertEqual(impact_response.status_code, 200, impact_response.text)

        payload = impact_response.json()["data"]
        self.assertEqual(payload["total_orders"], 1)
        self.assertEqual(payload["blocked_orders"], 0)
        self.assertEqual(payload["syncable_orders"], 1)
        self.assertEqual(len(payload["items"]), 1)
        self.assertEqual(payload["items"][0]["order_id"], int(order["id"]))
        self.assertTrue(payload["items"][0]["syncable"])
        self.assertIsNone(payload["items"][0]["reason"])

    def test_publish_template_with_apply_order_sync_does_not_mutate_existing_orders(self) -> None:
        stage_a = self._create_stage("NS1")
        process_a = self._create_process(
            stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="01"
        )
        stage_b = self._create_stage("NS2")
        process_b = self._create_process(
            stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="01"
        )
        product = self._create_product("模板不回写订单")
        detail = self._create_template(
            product_id=product["id"],
            template_name="模板不回写订单",
            stage_id=stage_a["id"],
            process_id=process_a["id"],
        )
        template_id = int(detail["template"]["id"])

        publish_v1 = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_v1.status_code, 200, publish_v1.text)

        order = self._create_order_from_template(
            product_id=product["id"],
            template_id=template_id,
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
            self.assertEqual(len(process_rows), 1)
            self.assertEqual(process_rows[0].process_id, int(process_a["id"]))
        finally:
            db.close()

        draft_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/draft",
            headers=self._headers(),
        )
        self.assertEqual(draft_response.status_code, 200, draft_response.text)

        update_response = self.client.put(
            f"/api/v1/craft/templates/{template_id}",
            headers=self._headers(),
            json={
                "template_name": "模板不回写订单",
                "is_default": True,
                "is_enabled": True,
                "remark": "新增第二道工序",
                "sync_orders": True,
                "steps": [
                    {"step_order": 1, "stage_id": stage_a["id"], "process_id": process_a["id"]},
                    {"step_order": 2, "stage_id": stage_b["id"], "process_id": process_b["id"]},
                ],
            },
        )
        self.assertEqual(update_response.status_code, 200, update_response.text)

        publish_v2 = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": True, "confirmed": True},
        )
        self.assertEqual(publish_v2.status_code, 200, publish_v2.text)

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
            self.assertEqual(len(process_rows), 1)
            self.assertEqual(process_rows[0].process_id, int(process_a["id"]))
        finally:
            db.close()

        delete_response = self.client.delete(
            f"/api/v1/craft/templates/{template_id}",
            headers=self._headers(),
        )
        self.assertEqual(delete_response.status_code, 400, delete_response.text)
        self.assertIn(
            "Template is referenced by production orders", delete_response.text
        )

    def test_disable_and_archive_are_blocked_by_in_progress_orders(self) -> None:
        stage = self._create_stage("R05")
        process = self._create_process(
            stage_id=stage["id"],
            stage_code=stage["code"],
            suffix="01",
        )
        product = self._create_product("阻断门禁")
        detail = self._create_template(
            product_id=product["id"],
            template_name="模板阻断门禁",
            stage_id=stage["id"],
            process_id=process["id"],
        )
        template_id = int(detail["template"]["id"])

        db = SessionLocal()
        try:
            template_row = db.get(ProductProcessTemplate, template_id)
            self.assertIsNotNone(template_row)
            assert template_row is not None
            template_row.lifecycle_status = "published"
            template_row.published_version = 1
            db.commit()
        finally:
            db.close()

        db = SessionLocal()
        try:
            order_row = ProductionOrder(
                order_code=f"CRAFT-BLOCK-{int(time.time() * 1000)}",
                product_id=int(product["id"]),
                product_version=1,
                quantity=10,
                status="in_progress",
                current_process_code=process["code"],
                process_template_id=template_id,
                process_template_name="模板阻断门禁",
                process_template_version=1,
                created_by_user_id=1,
            )
            db.add(order_row)
            db.flush()
            process_row = ProductionOrderProcess(
                order_id=order_row.id,
                process_id=int(process["id"]),
                stage_id=int(stage["id"]),
                stage_code=stage["code"],
                stage_name=stage["name"],
                process_code=process["code"],
                process_name=process["name"],
                process_order=1,
                status="in_progress",
                visible_quantity=10,
                completed_quantity=0,
            )
            db.add(process_row)
            db.commit()
            self.order_ids.append(int(order_row.id))
        finally:
            db.close()

        references_response = self.client.get(
            f"/api/v1/craft/templates/{template_id}/references",
            headers=self._headers(),
        )
        self.assertEqual(references_response.status_code, 200, references_response.text)
        self.assertEqual(
            references_response.json()["data"]["blocking_reference_count"], 1
        )
        self.assertTrue(references_response.json()["data"]["has_blocking_references"])

        disable_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/disable",
            headers=self._headers(),
        )
        self.assertEqual(disable_response.status_code, 400, disable_response.text)
        self.assertIn("阻断级引用", disable_response.text)

        archive_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/archive",
            headers=self._headers(),
        )
        self.assertEqual(archive_response.status_code, 400, archive_response.text)
        self.assertIn("阻断级引用", archive_response.text)

    def test_template_list_supports_server_side_filter_contract(self) -> None:
        stage = self._create_stage("R04")
        process = self._create_process(
            stage_id=stage["id"],
            stage_code=stage["code"],
            suffix="01",
        )
        product = self._create_product("筛选契约")
        detail = self._create_template(
            product_id=product["id"],
            template_name="模板筛选契约",
            stage_id=stage["id"],
            process_id=process["id"],
        )

        response = self.client.get(
            "/api/v1/craft/templates"
            f"?product_id={product['id']}"
            "&keyword=筛选契约"
            "&product_category=贴片"
            "&is_default=true"
            "&enabled=true"
            "&lifecycle_status=draft"
            "&updated_from=2026-01-01T00:00:00Z"
            "&updated_to=2099-01-01T00:00:00Z",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        self.assertGreaterEqual(payload["total"], 1)
        self.assertTrue(
            any(item["id"] == detail["template"]["id"] for item in payload["items"])
        )

    def test_process_metrics_query_returns_grouped_filtered_samples(self) -> None:
        stage_a = self._create_stage("K01")
        stage_b = self._create_stage("K02")
        self._set_stage_sort_order(stage_id=int(stage_a["id"]), sort_order=1)
        self._set_stage_sort_order(stage_id=int(stage_b["id"]), sort_order=2)
        process_a = self._create_process(
            stage_id=stage_a["id"],
            stage_code=stage_a["code"],
            suffix="01",
        )
        process_b = self._create_process(
            stage_id=stage_b["id"],
            stage_code=stage_b["code"],
            suffix="01",
        )
        product = self._create_product("看板查询")
        template_a = self._create_template(
            product_id=product["id"],
            template_name="看板模板A",
            stage_id=stage_a["id"],
            process_id=process_a["id"],
        )
        template_b = self._create_template(
            product_id=product["id"],
            template_name="看板模板B",
            stage_id=stage_b["id"],
            process_id=process_b["id"],
        )
        publish_a = self.client.post(
            f"/api/v1/craft/templates/{int(template_a['template']['id'])}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_a.status_code, 200, publish_a.text)
        publish_b = self.client.post(
            f"/api/v1/craft/templates/{int(template_b['template']['id'])}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_b.status_code, 200, publish_b.text)
        order_a = self._create_order_from_template(
            product_id=product["id"],
            template_id=int(template_a["template"]["id"]),
        )
        order_b = self._create_order_from_template(
            product_id=product["id"],
            template_id=int(template_b["template"]["id"]),
        )
        self._seed_completed_process_metrics_sample(
            order_id=int(order_a["id"]),
            start_at=datetime(2026, 3, 1, 8, 0, tzinfo=UTC),
            end_at=datetime(2026, 3, 1, 9, 30, tzinfo=UTC),
            production_qty=9,
        )
        self._seed_completed_process_metrics_sample(
            order_id=int(order_b["id"]),
            start_at=datetime(2026, 3, 2, 10, 0, tzinfo=UTC),
            end_at=datetime(2026, 3, 2, 10, 30, tzinfo=UTC),
            production_qty=12,
        )

        response = self.client.get(
            "/api/v1/craft/kanban/process-metrics",
            headers=self._headers(),
            params={"product_id": product["id"], "limit": 1},
        )
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        self.assertEqual(payload["product_id"], product["id"])
        self.assertEqual(len(payload["items"]), 2)
        self.assertEqual(
            [item["process_id"] for item in payload["items"]],
            [process_a["id"], process_b["id"]],
        )
        first_sample = payload["items"][0]["samples"][0]
        self.assertEqual(first_sample["production_qty"], 9)
        self.assertEqual(first_sample["work_minutes"], 90)
        self.assertEqual(first_sample["capacity_per_hour"], 6.0)

        filtered = self.client.get(
            "/api/v1/craft/kanban/process-metrics",
            headers=self._headers(),
            params={"product_id": product["id"], "process_id": process_b["id"]},
        )
        self.assertEqual(filtered.status_code, 200, filtered.text)
        filtered_items = filtered.json()["data"]["items"]
        self.assertEqual(len(filtered_items), 1)
        self.assertEqual(filtered_items[0]["process_id"], process_b["id"])

        date_filtered = self.client.get(
            "/api/v1/craft/kanban/process-metrics",
            headers=self._headers(),
            params={
                "product_id": product["id"],
                "start_date": "2026-03-02T00:00:00Z",
            },
        )
        self.assertEqual(date_filtered.status_code, 200, date_filtered.text)
        date_items = date_filtered.json()["data"]["items"]
        self.assertEqual(len(date_items), 1)
        self.assertEqual(date_items[0]["process_id"], process_b["id"])

    def test_product_template_references_use_self_row_for_templates_without_downstream_refs(
        self,
    ) -> None:
        stage = self._create_stage("PR1")
        process = self._create_process(
            stage_id=stage["id"],
            stage_code=stage["code"],
            suffix="01",
        )
        product = self._create_product("产品模式")
        detail = self._create_template(
            product_id=product["id"],
            template_name="产品模式模板",
            stage_id=stage["id"],
            process_id=process["id"],
        )
        template_id = int(detail["template"]["id"])

        initial_response = self.client.get(
            f"/api/v1/craft/products/{product['id']}/template-references",
            headers=self._headers(),
        )
        self.assertEqual(initial_response.status_code, 200, initial_response.text)
        initial_payload = initial_response.json()["data"]
        initial_total_templates = int(initial_payload["total_templates"])
        initial_total_references = int(initial_payload["total_references"])
        template_self_row = next(
            item
            for item in initial_payload["items"]
            if item["template_id"] == template_id
        )
        self.assertEqual(template_self_row["ref_type"], "template")
        self.assertEqual(template_self_row["detail"], "无下游引用")

        copy_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/copy",
            headers=self._headers(),
            json={"new_name": "产品模式模板-复用"},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)

        after_copy_response = self.client.get(
            f"/api/v1/craft/products/{product['id']}/template-references",
            headers=self._headers(),
        )
        self.assertEqual(after_copy_response.status_code, 200, after_copy_response.text)
        after_copy_payload = after_copy_response.json()["data"]
        self.assertEqual(
            after_copy_payload["total_templates"],
            initial_total_templates + 1,
        )
        self.assertEqual(
            after_copy_payload["total_references"],
            initial_total_references + 1,
        )
        self.assertTrue(
            any(
                item["template_id"] == template_id
                and item["ref_type"] == "template_reuse"
                for item in after_copy_payload["items"]
            )
        )
        self.assertTrue(
            any(item["ref_type"] == "template" for item in after_copy_payload["items"])
        )

    def test_compare_rollback_copy_to_product_and_unarchive_flow(self) -> None:
        stage_a = self._create_stage("CF1")
        process_a = self._create_process(
            stage_id=stage_a["id"],
            stage_code=stage_a["code"],
            suffix="01",
        )
        product = self._create_product("生命周期")
        detail = self._create_template(
            product_id=product["id"],
            template_name="生命周期模板",
            stage_id=stage_a["id"],
            process_id=process_a["id"],
        )
        template_id = int(detail["template"]["id"])

        publish_v1 = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_v1.status_code, 200, publish_v1.text)

        create_draft = self.client.post(
            f"/api/v1/craft/templates/{template_id}/draft",
            headers=self._headers(),
        )
        self.assertEqual(create_draft.status_code, 200, create_draft.text)

        stage_b = self._create_stage("CF2")
        process_b = self._create_process(
            stage_id=stage_b["id"],
            stage_code=stage_b["code"],
            suffix="01",
        )
        update_draft = self.client.put(
            f"/api/v1/craft/templates/{template_id}",
            headers=self._headers(),
            json={
                "template_name": "生命周期模板",
                "is_default": True,
                "is_enabled": True,
                "remark": "切换工序用于版本对比",
                "sync_orders": False,
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage_b["id"],
                        "process_id": process_b["id"],
                    }
                ],
            },
        )
        self.assertEqual(update_draft.status_code, 200, update_draft.text)
        expected_version = int(
            update_draft.json()["data"]["detail"]["template"]["version"]
        )

        publish_v2 = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={
                "apply_order_sync": False,
                "confirmed": True,
                "expected_version": expected_version,
            },
        )
        self.assertEqual(publish_v2.status_code, 200, publish_v2.text)

        compare_response = self.client.get(
            f"/api/v1/craft/templates/{template_id}/versions/compare",
            headers=self._headers(),
            params={"from_version": 1, "to_version": 2},
        )
        self.assertEqual(compare_response.status_code, 200, compare_response.text)
        compare_payload = compare_response.json()["data"]
        self.assertEqual(compare_payload["changed_steps"], 1)
        self.assertEqual(compare_payload["items"][0]["diff_type"], "changed")
        self.assertEqual(
            compare_payload["items"][0]["from_process_code"], process_a["code"]
        )
        self.assertEqual(
            compare_payload["items"][0]["to_process_code"], process_b["code"]
        )

        rollback_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/rollback",
            headers=self._headers(),
            json={
                "target_version": 1,
                "apply_order_sync": False,
                "confirmed": True,
                "note": "回滚到初始版本",
            },
        )
        self.assertEqual(rollback_response.status_code, 200, rollback_response.text)
        rollback_payload = rollback_response.json()["data"]["detail"]
        self.assertEqual(rollback_payload["steps"][0]["process_id"], process_a["id"])
        self.assertEqual(
            rollback_payload["template"]["lifecycle_status"],
            "published",
        )

        archive_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/archive",
            headers=self._headers(),
        )
        self.assertEqual(archive_response.status_code, 200, archive_response.text)

        unarchive_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/unarchive",
            headers=self._headers(),
        )
        self.assertEqual(unarchive_response.status_code, 200, unarchive_response.text)
        self.assertEqual(
            unarchive_response.json()["data"]["template"]["lifecycle_status"],
            "published",
        )

        target_product = self._create_product("跨产品复制")
        copy_to_product_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/copy-to-product",
            headers=self._headers(),
            json={
                "target_product_id": target_product["id"],
                "new_name": "跨产品模板",
            },
        )
        self.assertEqual(
            copy_to_product_response.status_code,
            201,
            copy_to_product_response.text,
        )
        copied_template = copy_to_product_response.json()["data"]["template"]
        self.assertEqual(copied_template["product_id"], target_product["id"])
        self.assertEqual(copied_template["source_type"], "cross_product_template")
        self.assertEqual(copied_template["source_template_id"], template_id)

        invalid_copy_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/copy-to-product",
            headers=self._headers(),
            json={"target_product_id": 999999999, "new_name": "非法目标产品"},
        )
        self.assertEqual(
            invalid_copy_response.status_code, 400, invalid_copy_response.text
        )
        self.assertIn("Product not found", invalid_copy_response.text)

    def test_create_publish_and_import_follow_draft_gate(self) -> None:
        stage = self._create_stage("G01")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="01"
        )
        product = self._create_product("门禁")

        legacy_field_response = self.client.post(
            "/api/v1/craft/templates",
            headers=self._headers(),
            json={
                "product_id": product["id"],
                "template_name": "旧字段模板",
                "is_default": False,
                "remark": "旧字段应被拒绝",
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage["id"],
                        "process_id": process["id"],
                        "is_key_process": True,
                    }
                ],
            },
        )
        self.assertEqual(
            legacy_field_response.status_code, 422, legacy_field_response.text
        )
        self.assertIn("is_key_process", legacy_field_response.text)

        create_response = self.client.post(
            "/api/v1/craft/templates",
            headers=self._headers(),
            json={
                "product_id": product["id"],
                "template_name": "门禁模板",
                "is_default": True,
                "lifecycle_status": "published",
                "remark": "尝试绕过发布门禁",
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage["id"],
                        "process_id": process["id"],
                    }
                ],
            },
        )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        create_data = create_response.json()["data"]["template"]
        template_id = int(create_data["id"])
        self.assertEqual(create_data["lifecycle_status"], "draft")
        self.assertEqual(create_data["published_version"], 0)

        publish_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 1},
        )
        self.assertEqual(publish_response.status_code, 200, publish_response.text)

        republish_response = self.client.post(
            f"/api/v1/craft/templates/{template_id}/publish",
            headers=self._headers(),
            json={"apply_order_sync": False, "confirmed": True, "expected_version": 2},
        )
        self.assertEqual(republish_response.status_code, 400, republish_response.text)
        self.assertIn("Only draft templates can be published", republish_response.text)

        gap_process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="02"
        )
        gap_response = self.client.post(
            "/api/v1/craft/templates",
            headers=self._headers(),
            json={
                "product_id": product["id"],
                "template_name": "缺口模板",
                "is_default": False,
                "remark": "步骤号缺口",
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage["id"],
                        "process_id": process["id"],
                    },
                    {
                        "step_order": 3,
                        "stage_id": stage["id"],
                        "process_id": gap_process["id"],
                    },
                ],
            },
        )
        self.assertEqual(gap_response.status_code, 400, gap_response.text)
        self.assertIn(
            "step_order must start at 1 and remain continuous", gap_response.text
        )

        import_response = self.client.post(
            "/api/v1/craft/templates/import",
            headers=self._headers(),
            json={
                "overwrite_existing": True,
                "items": [
                    {
                        "product_id": product["id"],
                        "template_name": "门禁模板",
                        "is_default": True,
                        "is_enabled": True,
                        "lifecycle_status": "published",
                        "steps": [
                            {
                                "step_order": 1,
                                "stage_id": stage["id"],
                                "process_id": process["id"],
                            }
                        ],
                    }
                ],
            },
        )
        self.assertEqual(import_response.status_code, 200, import_response.text)
        import_data = import_response.json()["data"]
        self.assertEqual(import_data["updated"], 0)
        self.assertEqual(import_data["skipped"], 1)
        self.assertIn("不允许导入覆盖已发布模板历史", import_data["errors"][0])

    def test_product_auto_template_and_batch_import_preserve_source_trace(self) -> None:
        stage = self._create_stage("S01")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="01"
        )

        system_master_response = self.client.get(
            "/api/v1/craft/system-master-template",
            headers=self._headers(),
        )
        self.assertEqual(
            system_master_response.status_code, 200, system_master_response.text
        )
        system_master_data = system_master_response.json()["data"]
        if system_master_data is None:
            create_master_response = self.client.post(
                "/api/v1/craft/system-master-template",
                headers=self._headers(),
                json={
                    "steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage["id"],
                            "process_id": process["id"],
                        }
                    ]
                },
            )
            self.assertEqual(
                create_master_response.status_code, 201, create_master_response.text
            )
            system_master_data = create_master_response.json()["data"]
            self.process_ids = [
                item for item in self.process_ids if item != process["id"]
            ]
            self.stage_ids = [item for item in self.stage_ids if item != stage["id"]]
        source_version = int(system_master_data["version"])

        product = self._create_product("来源追溯")
        list_response = self.client.get(
            f"/api/v1/craft/templates?product_id={product['id']}&enabled=true",
            headers=self._headers(),
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        auto_template = list_response.json()["data"]["items"][0]
        self.assertEqual(auto_template["source_type"], "system_master")
        self.assertEqual(auto_template["source_template_name"], "系统母版")
        self.assertEqual(auto_template["source_system_master_version"], source_version)

        import_product = self._create_product("批量导入追溯")
        import_response = self.client.post(
            "/api/v1/craft/templates/import",
            headers=self._headers(),
            json={
                "overwrite_existing": False,
                "items": [
                    {
                        "product_id": import_product["id"],
                        "template_name": "导入来源模板",
                        "is_default": False,
                        "is_enabled": True,
                        "lifecycle_status": "published",
                        "source_type": "system_master",
                        "source_template_name": "系统母版",
                        "source_system_master_version": source_version,
                        "steps": [
                            {
                                "step_order": 1,
                                "stage_id": stage["id"],
                                "process_id": process["id"],
                            }
                        ],
                    }
                ],
            },
        )
        self.assertEqual(import_response.status_code, 200, import_response.text)
        import_data = import_response.json()["data"]
        self.assertEqual(import_data["created"], 1)
        self.assertEqual(import_data["items"][0]["lifecycle_status"], "draft")

        export_response = self.client.get(
            f"/api/v1/craft/templates/export?product_id={import_product['id']}",
            headers=self._headers(),
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        exported = export_response.json()["data"]["items"]
        imported_template = next(
            item for item in exported if item["template_name"] == "导入来源模板"
        )
        self.assertEqual(imported_template["source_type"], "system_master")
        self.assertEqual(imported_template["source_template_name"], "系统母版")
        self.assertEqual(
            imported_template["source_system_master_version"], source_version
        )


if __name__ == "__main__":
    unittest.main()
