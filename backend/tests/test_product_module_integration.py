import sys
import time
import unittest
import urllib.parse
from pathlib import Path

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402


class ProductModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.product_id: int | None = None
        self.order_id: int | None = None
        self.token = self._login()

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
            if self.order_id is not None:
                order = db.get(ProductionOrder, self.order_id)
                if order is not None:
                    db.delete(order)
                    db.commit()
            if self.product_id is not None:
                product = db.get(Product, self.product_id)
                if product is not None and not product.is_deleted:
                    product.is_deleted = True
                    db.commit()
        finally:
            db.close()

    def _login(self) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def _create_product(self, *, suffix: str) -> dict:
        response = self.client.post(
            "/api/v1/products",
            headers=self._headers(),
            json={
                "name": f"产品模块集成测试{suffix}{int(time.time() * 1000)}",
                "category": "贴片",
                "remark": f"{suffix} 场景",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        product = response.json()["data"]
        self.product_id = int(product["id"])
        return product

    def _load_version_parameters(self, *, version: int) -> dict:
        response = self.client.get(
            f"/api/v1/products/{self.product_id}/versions/{version}/parameters",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]

    def _update_chip_value(self, *, version: int, chip_value: str, remark: str) -> None:
        payload = self._load_version_parameters(version=version)
        for item in payload["items"]:
            if item["name"] == "产品芯片":
                item["value"] = chip_value
                break
        response = self.client.put(
            f"/api/v1/products/{self.product_id}/versions/{version}/parameters",
            headers=self._headers(),
            json={
                "remark": remark,
                "confirmed": False,
                "items": payload["items"],
            },
        )
        self.assertEqual(response.status_code, 200, response.text)

    def _activate_version(self, *, version: int, expected_effective_version: int):
        return self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{version}/activate",
            headers=self._headers(),
            json={
                "confirmed": True,
                "expected_effective_version": expected_effective_version,
            },
        )

    def _get_effective_parameters(self) -> dict:
        response = self.client.get(
            f"/api/v1/products/{self.product_id}/effective-parameters",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]

    def test_copy_and_activate_keep_effective_parameters_isolated(self) -> None:
        product = self._create_product(suffix="复制生效")
        v1 = int(product["current_version"])

        self._update_chip_value(version=v1, chip_value="CHIP-A", remark="初始化 V1.0 芯片参数")

        activate_v1 = self._activate_version(version=v1, expected_effective_version=0)
        self.assertEqual(activate_v1.status_code, 200, activate_v1.text)

        effective_before = self._get_effective_parameters()
        chip_before = next(
            item["value"] for item in effective_before["items"] if item["name"] == "产品芯片"
        )
        self.assertEqual(chip_before, "CHIP-A")

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        v2 = int(copy_response.json()["data"]["version"])

        self._update_chip_value(version=v2, chip_value="CHIP-B", remark="修改 V1.1 芯片参数")

        effective_still_old = self._get_effective_parameters()
        chip_still_old = next(
            item["value"] for item in effective_still_old["items"] if item["name"] == "产品芯片"
        )
        self.assertEqual(chip_still_old, "CHIP-A")

        stale_activate = self._activate_version(version=v2, expected_effective_version=0)
        self.assertEqual(stale_activate.status_code, 400, stale_activate.text)

        activate_v2 = self._activate_version(version=v2, expected_effective_version=1)
        self.assertEqual(activate_v2.status_code, 200, activate_v2.text)

        effective_after = self._get_effective_parameters()
        chip_after = next(
            item["value"] for item in effective_after["items"] if item["name"] == "产品芯片"
        )
        self.assertEqual(chip_after, "CHIP-B")

    def test_history_and_exports_include_version_labels(self) -> None:
        product = self._create_product(suffix="历史导出")
        v1 = int(product["current_version"])

        self._update_chip_value(version=v1, chip_value="CHIP-X", remark="初始化 V1.0")
        response = self._activate_version(version=v1, expected_effective_version=0)
        self.assertEqual(response.status_code, 200, response.text)

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        v2 = int(copy_response.json()["data"]["version"])

        general_history = self.client.get(
            f"/api/v1/products/{self.product_id}/parameter-history?page=1&page_size=20",
            headers=self._headers(),
        )
        self.assertEqual(general_history.status_code, 200, general_history.text)
        general_items = general_history.json()["data"]["items"]
        self.assertTrue(any(item["change_type"] == "copy" for item in general_items))
        self.assertTrue(any(item.get("version_label") == "V1.1" for item in general_items))

        version_history = self.client.get(
            f"/api/v1/products/{self.product_id}/versions/{v2}/parameter-history?page=1&page_size=20",
            headers=self._headers(),
        )
        self.assertEqual(version_history.status_code, 200, version_history.text)
        self.assertEqual(version_history.json()["data"]["version_label"], "V1.1")

        export_list = self.client.get(
            f"/api/v1/products/export/list?keyword={urllib.parse.quote(str(product['name']))}",
            headers=self._headers(),
        )
        self.assertEqual(export_list.status_code, 200, export_list.text)
        export_list_text = export_list.content.decode("utf-8-sig")
        self.assertIn("V1.0", export_list_text)

        export_effective = self.client.get(
            f"/api/v1/products/parameters/export?keyword={urllib.parse.quote(str(product['name']))}",
            headers=self._headers(),
        )
        self.assertEqual(export_effective.status_code, 200, export_effective.text)
        export_effective_text = export_effective.content.decode("utf-8-sig")
        self.assertIn("生效版本", export_effective_text)
        self.assertIn("V1.0", export_effective_text)

    def test_delete_product_is_blocked_when_referenced(self) -> None:
        product = self._create_product(suffix="删除保护")
        v1 = int(product["current_version"])

        db = SessionLocal()
        try:
            order = ProductionOrder(
                order_code=f"ORD-PRODUCT-LOCK-{int(time.time() * 1000)}",
                product_id=self.product_id,
                product_version=v1,
                quantity=1,
                status="completed",
            )
            db.add(order)
            db.commit()
            self.order_id = int(order.id)
        finally:
            db.close()

        blocked_delete = self.client.post(
            f"/api/v1/products/{self.product_id}/delete",
            headers=self._headers(),
            json={"password": "Admin@123456"},
        )
        self.assertEqual(blocked_delete.status_code, 400, blocked_delete.text)
        self.assertIn("生产工单", blocked_delete.json()["detail"])


if __name__ == "__main__":
    unittest.main()
