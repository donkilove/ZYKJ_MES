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


class CraftModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.token = self._login()
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
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
        self.product_ids.append(int(row["id"]))
        return row

    def _create_template(self, *, product_id: int, template_name: str, stage_id: int, process_id: int) -> dict:
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

    def test_light_query_and_copy_source_export(self) -> None:
        stage = self._create_stage("A01")
        process = self._create_process(stage_id=stage["id"], stage_code=stage["code"], suffix="01")
        product = self._create_product("轻量")
        template = self._create_template(
            product_id=product["id"],
            template_name="模板A",
            stage_id=stage["id"],
            process_id=process["id"],
        )
        template_id = template["template"]["id"]

        stage_light = self.client.get("/api/v1/craft/stages/light", headers=self._headers())
        self.assertEqual(stage_light.status_code, 200, stage_light.text)
        self.assertTrue(any(item["id"] == stage["id"] for item in stage_light.json()["data"]["items"]))

        process_light = self.client.get(
            f"/api/v1/craft/processes/light?stage_id={stage['id']}",
            headers=self._headers(),
        )
        self.assertEqual(process_light.status_code, 200, process_light.text)
        self.assertTrue(any(item["id"] == process["id"] for item in process_light.json()["data"]["items"]))

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
            base64.b64decode(export_current.json()["data"]["content_base64"]).decode("utf-8-sig")
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
            base64.b64decode(export_version.json()["data"]["content_base64"]).decode("utf-8-sig")
        )
        self.assertEqual(version_payload["steps"][0]["standard_minutes"], 15)

    def test_published_template_requires_draft_and_history_blocks_process_delete(self) -> None:
        stage_a = self._create_stage("B01")
        process_a = self._create_process(stage_id=stage_a["id"], stage_code=stage_a["code"], suffix="01")
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
        process_b = self._create_process(stage_id=stage_b["id"], stage_code=stage_b["code"], suffix="01")
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


if __name__ == "__main__":
    unittest.main()
