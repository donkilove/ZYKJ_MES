import sys
import time
import unittest
import urllib.parse
from pathlib import Path
from unittest.mock import MagicMock

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.services.product_service import _list_product_reference_blockers  # noqa: E402


class ProductModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.product_id: int | None = None
        self.order_id: int | None = None
        self.product_ids: list[int] = []
        self.order_ids: list[int] = []
        self.token = self._login()

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
            order_ids = list(dict.fromkeys([*self.order_ids, self.order_id]))
            for order_id in order_ids:
                if order_id is None:
                    continue
                order = db.get(ProductionOrder, order_id)
                if order is not None:
                    db.delete(order)
            if order_ids:
                db.commit()

            product_ids = list(dict.fromkeys([*self.product_ids, self.product_id]))
            for product_id in product_ids:
                if product_id is None:
                    continue
                product = db.get(Product, product_id)
                if product is not None and not product.is_deleted:
                    product.is_deleted = True
            if product_ids:
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
        self.product_ids.append(self.product_id)
        return product

    def _create_order(self, *, product_version: int, status: str) -> str:
        order_code = f"ORD-PRODUCT-{status.upper()}-{int(time.time() * 1000)}"
        db = SessionLocal()
        try:
            order = ProductionOrder(
                order_code=order_code,
                product_id=self.product_id,
                product_version=product_version,
                quantity=1,
                status=status,
            )
            db.add(order)
            db.commit()
            self.order_id = int(order.id)
            self.order_ids.append(self.order_id)
        finally:
            db.close()
        return order_code

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

    def _get_product_detail(self) -> dict:
        response = self.client.get(
            f"/api/v1/products/{self.product_id}",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]

    def _get_effective_parameters(self) -> dict:
        response = self.client.get(
            f"/api/v1/products/{self.product_id}/effective-parameters",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]

    def _get_current_parameters(self) -> dict:
        response = self.client.get(
            f"/api/v1/products/{self.product_id}/parameters",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]

    @staticmethod
    def _find_parameter_value(payload: dict, parameter_name: str) -> str:
        return next(
            item["value"] for item in payload["items"] if item["name"] == parameter_name
        )

    def test_copy_and_activate_keep_effective_parameters_isolated(self) -> None:
        product = self._create_product(suffix="复制生效")
        v1 = int(product["current_version"])

        self._update_chip_value(
            version=v1, chip_value="CHIP-A", remark="初始化 V1.0 芯片参数"
        )

        activate_v1 = self._activate_version(version=v1, expected_effective_version=0)
        self.assertEqual(activate_v1.status_code, 200, activate_v1.text)

        effective_before = self._get_effective_parameters()
        self.assertEqual(effective_before["parameter_scope"], "effective")
        chip_before = next(
            item["value"]
            for item in effective_before["items"]
            if item["name"] == "产品芯片"
        )
        self.assertEqual(chip_before, "CHIP-A")

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        v2 = int(copy_response.json()["data"]["version"])

        self._update_chip_value(
            version=v2, chip_value="CHIP-B", remark="修改 V1.1 芯片参数"
        )

        draft_parameters = self._load_version_parameters(version=v2)
        self.assertEqual(draft_parameters["parameter_scope"], "version")

        effective_still_old = self._get_effective_parameters()
        chip_still_old = next(
            item["value"]
            for item in effective_still_old["items"]
            if item["name"] == "产品芯片"
        )
        self.assertEqual(chip_still_old, "CHIP-A")

        stale_activate = self._activate_version(
            version=v2, expected_effective_version=0
        )
        self.assertEqual(stale_activate.status_code, 400, stale_activate.text)

        activate_v2 = self._activate_version(version=v2, expected_effective_version=1)
        self.assertEqual(activate_v2.status_code, 200, activate_v2.text)

        effective_after = self._get_effective_parameters()
        chip_after = next(
            item["value"]
            for item in effective_after["items"]
            if item["name"] == "产品芯片"
        )
        self.assertEqual(chip_after, "CHIP-B")

    def test_current_parameters_compat_endpoint_returns_version_scope(self) -> None:
        product = self._create_product(suffix="兼容当前参数")
        v1 = int(product["current_version"])

        current_parameters = self._get_current_parameters()
        self.assertEqual(current_parameters["parameter_scope"], "version")
        self.assertEqual(current_parameters["version"], v1)
        for item in current_parameters["items"]:
            if item["name"] == "产品芯片":
                item["value"] = "COMPAT-CHIP"
                break

        update_response = self.client.put(
            f"/api/v1/products/{self.product_id}/parameters",
            headers=self._headers(),
            json={
                "remark": "兼容口径更新当前版本",
                "confirmed": False,
                "items": current_parameters["items"],
            },
        )
        self.assertEqual(update_response.status_code, 200, update_response.text)
        payload = update_response.json()["data"]
        self.assertEqual(payload["parameter_scope"], "version")
        self.assertEqual(payload["version"], v1)

    def test_parameter_versions_endpoint_returns_version_rows(self) -> None:
        product = self._create_product(suffix="版本参数列表")
        v1 = int(product["current_version"])

        self._update_chip_value(version=v1, chip_value="ROW-V1", remark="初始化 V1.0")
        activate_response = self._activate_version(
            version=v1,
            expected_effective_version=0,
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        v2 = int(copy_response.json()["data"]["version"])

        self._update_chip_value(version=v2, chip_value="ROW-V2", remark="修改 V1.1")

        response = self.client.get(
            "/api/v1/products/parameter-versions"
            f"?keyword={urllib.parse.quote(str(product['name']))}",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)

        payload = response.json()["data"]
        version_rows = [
            item
            for item in payload["items"]
            if int(item["product_id"]) == self.product_id
        ]
        self.assertEqual(len(version_rows), 2)
        self.assertEqual(version_rows[0]["version"], v2)
        self.assertEqual(version_rows[1]["version"], v1)
        self.assertEqual(version_rows[0]["version_label"], "V1.1")
        self.assertEqual(version_rows[0]["lifecycle_status"], "draft")
        self.assertTrue(version_rows[0]["is_current_version"])
        self.assertFalse(version_rows[0]["is_effective_version"])
        self.assertEqual(version_rows[0]["product_category"], "贴片")
        self.assertEqual(version_rows[0]["last_modified_parameter"], "产品芯片")
        self.assertIn("created_at", version_rows[0])
        self.assertEqual(version_rows[1]["version_label"], "V1.0")
        self.assertEqual(version_rows[1]["lifecycle_status"], "effective")
        self.assertFalse(version_rows[1]["is_current_version"])
        self.assertTrue(version_rows[1]["is_effective_version"])

    def test_product_detail_endpoint_aggregates_versions_parameters_and_history(
        self,
    ) -> None:
        product = self._create_product(suffix="详情聚合")
        v1 = int(product["current_version"])

        self._update_chip_value(version=v1, chip_value="DETAIL-V1", remark="初始化详情")
        activate_response = self._activate_version(
            version=v1,
            expected_effective_version=0,
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        v2 = int(copy_response.json()["data"]["version"])
        self._update_chip_value(
            version=v2, chip_value="DETAIL-V2", remark="编辑草稿详情"
        )

        detail_response = self.client.get(
            f"/api/v1/products/{self.product_id}/detail",
            headers=self._headers(),
        )
        self.assertEqual(detail_response.status_code, 200, detail_response.text)

        payload = detail_response.json()["data"]
        self.assertEqual(payload["product"]["id"], self.product_id)
        self.assertEqual(payload["detail_parameters"]["parameter_scope"], "effective")
        self.assertEqual(payload["detail_parameters"]["version"], v1)
        self.assertIsNone(payload["detail_parameter_message"])
        self.assertEqual(payload["version_total"], 2)
        self.assertEqual(payload["versions"][0]["version"], v2)
        self.assertGreaterEqual(payload["history_total"], 2)
        self.assertIsNotNone(payload["latest_version_changed_at"])
        self.assertEqual(len(payload["related_info_sections"]), 5)
        self.assertEqual(
            payload["related_info_sections"][0]["code"], "process_templates"
        )
        self.assertGreaterEqual(payload["related_info_sections"][0]["total"], 0)
        self.assertEqual(payload["related_info_sections"][1]["title"], "适用产线")
        self.assertEqual(payload["related_info_sections"][4]["title"], "包装规则")

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
        self.assertTrue(
            any(item.get("version_label") == "V1.1" for item in general_items)
        )

        version_history = self.client.get(
            f"/api/v1/products/{self.product_id}/versions/{v2}/parameter-history?page=1&page_size=20",
            headers=self._headers(),
        )
        self.assertEqual(version_history.status_code, 200, version_history.text)
        self.assertEqual(version_history.json()["data"]["version_label"], "V1.1")
        history_item = general_items[0]
        self.assertEqual(history_item["product_name"], product["name"])
        self.assertEqual(history_item["product_category"], "贴片")
        self.assertIn("change_reason", history_item)
        self.assertIn("before_summary", history_item)
        self.assertIn("after_summary", history_item)

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
        self.assertIn("V1.1", export_effective_text)

    def test_parameter_history_distinguishes_add_edit_delete(self) -> None:
        product = self._create_product(suffix="历史粒度")
        v1 = int(product["current_version"])

        parameters = self._load_version_parameters(version=v1)
        editable_items = [
            item for item in parameters["items"] if item["name"] != "产品名称"
        ]
        self.assertGreaterEqual(len(editable_items), 2)

        edited_name = editable_items[0]["name"]
        deleted_name = editable_items[1]["name"]
        next_items = []
        for item in parameters["items"]:
            if item["name"] == deleted_name:
                continue
            cloned = dict(item)
            if cloned["name"] == edited_name:
                cloned["value"] = "EDIT-VALUE"
            next_items.append(cloned)
        next_items.append(
            {
                "name": "新增参数-历史粒度",
                "category": "基础参数",
                "type": "Text",
                "value": "ADD-VALUE",
                "description": "新增参数",
            }
        )

        update_response = self.client.put(
            f"/api/v1/products/{self.product_id}/versions/{v1}/parameters",
            headers=self._headers(),
            json={
                "remark": "同时新增编辑删除参数",
                "confirmed": False,
                "items": next_items,
            },
        )
        self.assertEqual(update_response.status_code, 200, update_response.text)

        history_response = self.client.get(
            f"/api/v1/products/{self.product_id}/versions/{v1}/parameter-history?page=1&page_size=20",
            headers=self._headers(),
        )
        self.assertEqual(history_response.status_code, 200, history_response.text)
        history_items = history_response.json()["data"]["items"]
        change_type_map = {
            item["change_type"]: item["changed_keys"] for item in history_items
        }

        self.assertIn("add", change_type_map)
        self.assertIn("edit", change_type_map)
        self.assertIn("delete", change_type_map)
        self.assertIn("新增参数-历史粒度", change_type_map["add"])
        self.assertIn(edited_name, change_type_map["edit"])
        self.assertIn(deleted_name, change_type_map["delete"])

    def test_update_product_syncs_parameter_rows_and_revision_snapshots(self) -> None:
        product = self._create_product(suffix="主数据同步")
        v1 = int(product["current_version"])

        activate_response = self._activate_version(
            version=v1, expected_effective_version=0
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        v2 = int(copy_response.json()["data"]["version"])

        update_response = self.client.put(
            f"/api/v1/products/{self.product_id}",
            headers=self._headers(),
            json={
                "name": f"已改名产品{int(time.time() * 1000)}",
                "category": "贴片",
                "remark": "同步产品名称快照",
            },
        )
        self.assertEqual(update_response.status_code, 200, update_response.text)
        new_name = update_response.json()["data"]["name"]

        current_parameters = self._get_current_parameters()
        v1_parameters = self._load_version_parameters(version=v1)
        v2_parameters = self._load_version_parameters(version=v2)

        self.assertEqual(
            self._find_parameter_value(current_parameters, "产品名称"), new_name
        )
        self.assertEqual(
            self._find_parameter_value(v1_parameters, "产品名称"), new_name
        )
        self.assertEqual(
            self._find_parameter_value(v2_parameters, "产品名称"), new_name
        )

    def test_new_product_defaults_to_active_and_requires_category(self) -> None:
        product = self._create_product(suffix="状态联动")
        v1 = int(product["current_version"])

        created_detail = self._get_product_detail()
        self.assertEqual(created_detail["lifecycle_status"], "active")
        self.assertEqual(created_detail["effective_version"], 0)
        self.assertIsNone(created_detail["inactive_reason"])

        missing_category_response = self.client.post(
            "/api/v1/products",
            headers=self._headers(),
            json={
                "name": f"缺少分类{int(time.time() * 1000)}",
                "category": "",
                "remark": "分类必填校验",
            },
        )
        self.assertEqual(missing_category_response.status_code, 422)

        invalid_category_response = self.client.post(
            "/api/v1/products",
            headers=self._headers(),
            json={
                "name": f"非法分类{int(time.time() * 1000)}",
                "category": "非法分类",
                "remark": "分类枚举校验",
            },
        )
        self.assertEqual(invalid_category_response.status_code, 422)

        activate_response = self._activate_version(
            version=v1,
            expected_effective_version=0,
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        activated_detail = self._get_product_detail()
        self.assertEqual(activated_detail["lifecycle_status"], "active")
        self.assertEqual(activated_detail["effective_version"], v1)
        self.assertIsNone(activated_detail["inactive_reason"])

        disable_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/disable",
            headers=self._headers(),
            json={},
        )
        self.assertEqual(disable_response.status_code, 200, disable_response.text)

        disabled_detail = self._get_product_detail()
        self.assertEqual(disabled_detail["lifecycle_status"], "inactive")
        self.assertEqual(disabled_detail["effective_version"], 0)
        self.assertIn("当前无生效版本", disabled_detail["inactive_reason"])

        direct_reactivate = self.client.post(
            f"/api/v1/products/{self.product_id}/lifecycle",
            headers=self._headers(),
            json={
                "target_status": "active",
                "confirmed": False,
                "inactive_reason": None,
            },
        )
        self.assertEqual(direct_reactivate.status_code, 400, direct_reactivate.text)
        self.assertIn("请前往版本管理", direct_reactivate.json()["detail"])

    def test_enable_action_is_independent_from_version_activation(self) -> None:
        product = self._create_product(suffix="独立启停")
        v1 = int(product["current_version"])

        activate_v1 = self._activate_version(version=v1, expected_effective_version=0)
        self.assertEqual(activate_v1.status_code, 200, activate_v1.text)

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        v2 = int(copy_response.json()["data"]["version"])

        inactive_response = self.client.post(
            f"/api/v1/products/{self.product_id}/lifecycle",
            headers=self._headers(),
            json={
                "target_status": "inactive",
                "confirmed": False,
                "inactive_reason": "手动停用验证",
            },
        )
        self.assertEqual(inactive_response.status_code, 200, inactive_response.text)
        inactive_detail = self._get_product_detail()
        self.assertEqual(inactive_detail["lifecycle_status"], "inactive")
        self.assertEqual(inactive_detail["effective_version"], v1)

        activate_while_inactive = self._activate_version(
            version=v2,
            expected_effective_version=v1,
        )
        self.assertEqual(
            activate_while_inactive.status_code, 400, activate_while_inactive.text
        )
        self.assertIn("请先启用产品", activate_while_inactive.json()["detail"])

        enable_response = self.client.post(
            f"/api/v1/products/{self.product_id}/lifecycle",
            headers=self._headers(),
            json={
                "target_status": "active",
                "confirmed": False,
                "inactive_reason": None,
            },
        )
        self.assertEqual(enable_response.status_code, 200, enable_response.text)
        enabled_detail = self._get_product_detail()
        self.assertEqual(enabled_detail["lifecycle_status"], "active")
        self.assertEqual(enabled_detail["effective_version"], v1)

        activate_after_enable = self._activate_version(
            version=v2,
            expected_effective_version=v1,
        )
        self.assertEqual(
            activate_after_enable.status_code, 200, activate_after_enable.text
        )

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

    def test_delete_product_blockers_include_production_and_quality_records(
        self,
    ) -> None:
        db = MagicMock()

        def scalar_result(value: int) -> MagicMock:
            result = MagicMock()
            result.scalar_one.return_value = value
            return result

        db.execute.side_effect = [
            scalar_result(0),
            scalar_result(3),
            scalar_result(2),
            scalar_result(0),
            scalar_result(0),
            scalar_result(0),
            scalar_result(0),
        ]

        blockers = _list_product_reference_blockers(db, product_id=999)

        self.assertIn("存在 3 条生产记录", blockers)
        self.assertIn("存在 2 条首件质检记录", blockers)

    def test_parameter_version_filters_use_real_parameter_contract(self) -> None:
        product = self._create_product(suffix="参数契约筛选")
        v1 = int(product["current_version"])

        response = self.client.get(
            "/api/v1/products/parameter-versions"
            f"?keyword={urllib.parse.quote(str(product['name']))}"
            "&param_name_keyword=产品芯片&param_category_keyword=基础参数",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)

        items = response.json()["data"]["items"]
        target = next(
            item for item in items if int(item["product_id"]) == self.product_id
        )
        self.assertEqual(target["version"], v1)
        self.assertEqual(target["matched_parameter_name"], "产品芯片")
        self.assertEqual(target["matched_parameter_category"], "基础参数")
        self.assertGreaterEqual(int(target["parameter_count"]), 1)

    def test_parameter_query_supports_active_and_effective_contract(self) -> None:
        product = self._create_product(suffix="参数查询启用筛选")
        v1 = int(product["current_version"])

        activate_response = self._activate_version(
            version=v1,
            expected_effective_version=0,
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        matched = self.client.get(
            "/api/v1/products/parameter-query"
            f"?keyword={urllib.parse.quote(str(product['name']))}"
            "&lifecycle_status=active&has_effective_version=true",
            headers=self._headers(),
        )
        self.assertEqual(matched.status_code, 200, matched.text)
        matched_items = matched.json()["data"]["items"]
        self.assertTrue(
            any(int(item["id"]) == self.product_id for item in matched_items)
        )
        matched_row = next(
            item for item in matched_items if int(item["id"]) == self.product_id
        )
        self.assertEqual(matched_row["effective_version_label"], "V1.0")

        missed = self.client.get(
            "/api/v1/products/parameter-query"
            f"?keyword={urllib.parse.quote(str(product['name']))}"
            "&lifecycle_status=inactive&has_effective_version=true",
            headers=self._headers(),
        )
        self.assertEqual(missed.status_code, 200, missed.text)
        self.assertFalse(
            any(
                int(item["id"]) == self.product_id
                for item in missed.json()["data"]["items"]
            )
        )

    def test_delete_draft_version_is_blocked_when_referenced_by_order(self) -> None:
        product = self._create_product(suffix="版本删除保护")
        v1 = int(product["current_version"])

        activate_response = self._activate_version(
            version=v1,
            expected_effective_version=0,
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        copy_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions/{v1}/copy",
            headers=self._headers(),
            json={"source_version": v1},
        )
        self.assertEqual(copy_response.status_code, 201, copy_response.text)
        draft_revision = copy_response.json()["data"]
        draft_version = int(draft_revision["version"])
        draft_version_label = draft_revision["version_label"]

        order_code = f"ORD-VERSION-LOCK-{int(time.time() * 1000)}"
        db = SessionLocal()
        try:
            order = ProductionOrder(
                order_code=order_code,
                product_id=self.product_id,
                product_version=draft_version,
                quantity=1,
                status="completed",
            )
            db.add(order)
            db.commit()
            self.order_id = int(order.id)
        finally:
            db.close()

        blocked_delete = self.client.delete(
            f"/api/v1/products/{self.product_id}/versions/{draft_version}",
            headers=self._headers(),
        )
        self.assertEqual(blocked_delete.status_code, 400, blocked_delete.text)
        detail = blocked_delete.json()["detail"]
        self.assertIn("生产工单", detail)
        self.assertIn(draft_version_label, detail)
        self.assertIn(order_code, detail)

    def test_version_management_endpoints_cover_create_note_compare_impact_export_and_rollback(
        self,
    ) -> None:
        product = self._create_product(suffix="版本管理全链路")
        v1 = int(product["current_version"])

        self._update_chip_value(
            version=v1, chip_value="CHAIN-V1", remark="初始化版本 V1.0"
        )
        activate_response = self._activate_version(
            version=v1,
            expected_effective_version=0,
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        create_version_response = self.client.post(
            f"/api/v1/products/{self.product_id}/versions",
            headers=self._headers(),
            json={},
        )
        self.assertEqual(
            create_version_response.status_code,
            201,
            create_version_response.text,
        )
        created_version = create_version_response.json()["data"]
        v2 = int(created_version["version"])
        self.assertEqual(created_version["version_label"], "V1.1")
        self.assertEqual(created_version["lifecycle_status"], "draft")

        update_note_response = self.client.patch(
            f"/api/v1/products/{self.product_id}/versions/{v2}/note",
            headers=self._headers(),
            json={"note": "版本备注已更新"},
        )
        self.assertEqual(
            update_note_response.status_code, 200, update_note_response.text
        )
        self.assertEqual(update_note_response.json()["data"]["note"], "版本备注已更新")

        self._update_chip_value(
            version=v2, chip_value="CHAIN-V2", remark="编辑版本 V1.1"
        )

        compare_response = self.client.get(
            f"/api/v1/products/{self.product_id}/versions/compare?from_version={v1}&to_version={v2}",
            headers=self._headers(),
        )
        self.assertEqual(compare_response.status_code, 200, compare_response.text)
        compare_payload = compare_response.json()["data"]
        self.assertEqual(compare_payload["from_version"], v1)
        self.assertEqual(compare_payload["to_version"], v2)
        self.assertGreaterEqual(compare_payload["changed_items"], 1)
        self.assertTrue(
            any(item["key"] == "参数:产品芯片" for item in compare_payload["items"])
        )

        pending_order_code = self._create_order(product_version=v1, status="pending")
        impact_response = self.client.get(
            f"/api/v1/products/{self.product_id}/impact-analysis?operation=rollback&target_version={v1}",
            headers=self._headers(),
        )
        self.assertEqual(impact_response.status_code, 200, impact_response.text)
        impact_payload = impact_response.json()["data"]
        self.assertTrue(impact_payload["requires_confirmation"])
        self.assertEqual(impact_payload["pending_orders"], 1)
        self.assertEqual(impact_payload["items"][0]["order_code"], pending_order_code)

        export_response = self.client.get(
            f"/api/v1/products/{self.product_id}/versions/{v2}/export",
            headers=self._headers(),
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        export_text = export_response.content.decode("utf-8-sig")
        self.assertIn("版本号,参数名称", export_text)
        self.assertIn("V1.1", export_text)
        self.assertIn("CHAIN-V2", export_text)

        rollback_response = self.client.post(
            f"/api/v1/products/{self.product_id}/rollback",
            headers=self._headers(),
            json={
                "target_version": v1,
                "confirmed": True,
                "note": "回滚到 V1.0",
            },
        )
        self.assertEqual(rollback_response.status_code, 200, rollback_response.text)
        rollback_payload = rollback_response.json()["data"]
        self.assertEqual(rollback_payload["product"]["current_version"], 3)
        self.assertEqual(rollback_payload["product"]["effective_version"], 3)
        self.assertIn("产品芯片", rollback_payload["changed_keys"])

        versions_response = self.client.get(
            f"/api/v1/products/{self.product_id}/versions",
            headers=self._headers(),
        )
        self.assertEqual(versions_response.status_code, 200, versions_response.text)
        versions_payload = versions_response.json()["data"]
        self.assertEqual(versions_payload["total"], 3)
        self.assertEqual(versions_payload["items"][0]["action"], "rollback")
        self.assertEqual(versions_payload["items"][0]["note"], "回滚到 V1.0")
        self.assertEqual(versions_payload["items"][1]["version"], v2)

    def test_product_list_filters_and_export_share_same_contract(self) -> None:
        matched = self._create_product(suffix="列表导出命中")
        matched_id = int(matched["id"])
        matched_v1 = int(matched["current_version"])

        activate_response = self.client.post(
            f"/api/v1/products/{matched_id}/versions/{matched_v1}/activate",
            headers=self._headers(),
            json={"confirmed": True, "expected_effective_version": 0},
        )
        self.assertEqual(activate_response.status_code, 200, activate_response.text)

        create_version_response = self.client.post(
            f"/api/v1/products/{matched_id}/versions",
            headers=self._headers(),
            json={},
        )
        self.assertEqual(
            create_version_response.status_code,
            201,
            create_version_response.text,
        )
        matched_v2 = int(create_version_response.json()["data"]["version"])
        self._update_chip_value(
            version=matched_v2,
            chip_value="FILTER-CHIP",
            remark="产品列表筛选命中参数",
        )

        other = self._create_product(suffix="列表导出排除")
        other_id = int(other["id"])

        list_response = self.client.get(
            "/api/v1/products"
            f"?keyword={urllib.parse.quote('列表导出')}"
            "&current_version_keyword=V1.1"
            "&current_param_name_keyword=产品芯片"
            "&current_param_category_keyword=基础参数",
            headers=self._headers(),
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        list_items = list_response.json()["data"]["items"]
        self.assertTrue(any(int(item["id"]) == matched_id for item in list_items))
        self.assertFalse(any(int(item["id"]) == other_id for item in list_items))

        export_response = self.client.get(
            "/api/v1/products/export/list"
            f"?keyword={urllib.parse.quote('列表导出')}"
            "&current_version_keyword=V1.1"
            "&current_param_name_keyword=产品芯片"
            "&current_param_category_keyword=基础参数",
            headers=self._headers(),
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        export_text = export_response.content.decode("utf-8-sig")
        self.assertIn(matched["name"], export_text)
        self.assertNotIn(other["name"], export_text)
        self.assertIn("V1.1", export_text)


if __name__ == "__main__":
    unittest.main()
