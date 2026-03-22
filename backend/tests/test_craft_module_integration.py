import base64
import json
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
from app.core.security import get_password_hash  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.product_process_template import ProductProcessTemplate  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.user import User  # noqa: E402


class CraftModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.token = self._login()
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []
        self.order_ids: list[int] = []
        self.user_ids: list[int] = []

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
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
                        "standard_minutes": 15,
                        "is_key_process": True,
                        "step_remark": "关键首工序",
                    }
                ],
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()["data"]

    def _create_order_from_template(self, *, product_id: int, template_id: int) -> dict:
        order_code = f"CRAFT-ROLLBACK-{int(time.time() * 1000)}"
        response = self.client.post(
            "/api/v1/production/orders",
            headers=self._headers(),
            json={
                "order_code": order_code,
                "product_id": product_id,
                "quantity": 10,
                "template_id": template_id,
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.order_ids.append(int(row["id"]))
        return row

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
        self.assertEqual(version_list_response.status_code, 200, version_list_response.text)
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
        self.assertEqual(version_payload["steps"][0]["standard_minutes"], 15)

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
        self.assertEqual(exported_step["standard_minutes"], 15)
        self.assertTrue(exported_step["is_key_process"])
        self.assertEqual(exported_step["step_remark"], "关键首工序")

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
                        "standard_minutes": 20,
                        "is_key_process": True,
                        "step_remark": "直接修改",
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
                        "standard_minutes": 5,
                        "is_key_process": False,
                        "step_remark": "新工序",
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
                        "standard_minutes": 10,
                        "is_key_process": False,
                        "step_remark": "新版本工序",
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

        delete_response = self.client.delete(
            f"/api/v1/craft/templates/{template_id}",
            headers=self._headers(),
        )
        self.assertEqual(delete_response.status_code, 400, delete_response.text)
        self.assertIn("Template is reused by downstream templates", delete_response.text)

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
        self.assertEqual(references_response.json()["data"]["blocking_reference_count"], 1)
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

    def test_create_publish_and_import_follow_draft_gate(self) -> None:
        stage = self._create_stage("G01")
        process = self._create_process(
            stage_id=stage["id"], stage_code=stage["code"], suffix="01"
        )
        product = self._create_product("门禁")

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
                        "standard_minutes": 8,
                        "is_key_process": True,
                        "step_remark": "首工序",
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
        self.assertIn("step_order must start at 1 and remain continuous", gap_response.text)

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
        self.assertEqual(system_master_response.status_code, 200, system_master_response.text)
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
                            "standard_minutes": 12,
                            "is_key_process": True,
                            "step_remark": "系统母版首工序",
                        }
                    ]
                },
            )
            self.assertEqual(
                create_master_response.status_code, 201, create_master_response.text
            )
            system_master_data = create_master_response.json()["data"]
            self.process_ids = [item for item in self.process_ids if item != process["id"]]
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
        self.assertEqual(imported_template["source_system_master_version"], source_version)


if __name__ == "__main__":
    unittest.main()
