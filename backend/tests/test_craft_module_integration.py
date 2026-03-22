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
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402


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

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
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

        export_batch = self.client.get(
            "/api/v1/craft/templates/export",
            headers=self._headers(),
        )
        self.assertEqual(export_batch.status_code, 200, export_batch.text)
        exported_step = export_batch.json()["data"]["items"][0]["steps"][0]
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


if __name__ == "__main__":
    unittest.main()
