import sys
import time
import unittest
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from app.db.session import SessionLocal
from app.core.config import settings
from app.main import app
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.production_order import ProductionOrder
from app.models.product import Product
from app.models.supplier import Supplier
from tools.perf.backend_capacity_gate import (
    ScenarioSpec,
    _load_scenario_config_bundle,
    _materialize_scenario_request,
)
from tools.perf.write_gate.sample_runtime import WriteSampleRuntime


@dataclass(slots=True)
class WriteGateRunResult:
    success_rate: float
    error_types: dict[str, int]
    restore_success_rate: float


class NoOpSampleHandler:
    def prepare(self) -> None:
        return None

    def restore(self, strategy: str | None) -> None:
        return None


class ProductionOrderCreateSampleHandler:
    def __init__(self, test_case: "WriteGateIntegrationTest") -> None:
        self.test_case = test_case

    def prepare(self) -> None:
        suffix = str(int(time.time() * 1000))
        stage = self.test_case._create_stage(suffix)
        process = self.test_case._create_process(stage_id=stage["id"], stage_code=stage["code"], suffix=suffix)
        product = self.test_case._create_product(suffix)
        self.test_case._activate_product(product)
        supplier = self.test_case._create_supplier(f"写门禁供应商{suffix}")
        self.test_case.context.update(
            {
                "production_stage": stage,
                "production_process": process,
                "production_product": product,
                "production_supplier": supplier,
            }
        )

    def restore(self, strategy: str | None) -> None:
        self.test_case._cleanup_created_records()


class SupplierCreateSampleHandler:
    def __init__(self, test_case: "WriteGateIntegrationTest") -> None:
        self.test_case = test_case

    def prepare(self) -> None:
        return None

    def restore(self, strategy: str | None) -> None:
        self.test_case._cleanup_created_records()


class WriteGateIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.context: dict[str, object] = {}
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []
        self.supplier_ids: list[int] = []
        self.order_ids: list[int] = []
        self._previous_jwt_secret_key = settings.jwt_secret_key
        settings.jwt_secret_key = "write-gate-test-secret"
        self.token = self._login()
        bundle = _load_scenario_config_bundle(
            "tools/perf/scenarios/write_operations_40_scan.json"
        )
        self.scenarios = bundle.scenarios

    def tearDown(self) -> None:
        settings.jwt_secret_key = self._previous_jwt_secret_key
        self._cleanup_created_records()

    def _cleanup_created_records(self) -> None:
        db = SessionLocal()
        try:
            for order_id in reversed(self.order_ids):
                row = db.get(ProductionOrder, order_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            self.order_ids.clear()
            for supplier_id in reversed(self.supplier_ids):
                row = db.get(Supplier, supplier_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            self.supplier_ids.clear()
            for product_id in reversed(self.product_ids):
                row = db.get(Product, product_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            self.product_ids.clear()
            for process_id in reversed(self.process_ids):
                row = db.get(Process, process_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            self.process_ids.clear()
            for stage_id in reversed(self.stage_ids):
                row = db.get(ProcessStage, stage_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            self.stage_ids.clear()
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

    def _create_stage(self, suffix: str) -> dict:
        response = self.client.post(
            "/api/v1/craft/stages",
            headers=self._headers(),
            json={
                "code": f"WG-ST-{suffix}",
                "name": f"WG-ST-{suffix}",
                "sort_order": 0,
                "remark": "写门禁集成测试",
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
                "code": f"{stage_code}-01",
                "name": f"{stage_code}-01",
                "stage_id": stage_id,
                "remark": f"写门禁工序{suffix}",
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
                "name": f"写门禁产品{suffix}",
                "category": "贴片",
                "remark": "写门禁集成测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.product_ids.append(int(row["id"]))
        return row

    def _activate_product(self, product: dict) -> None:
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

    def _create_supplier(self, name: str) -> dict:
        response = self.client.post(
            "/api/v1/quality/suppliers",
            headers=self._headers(),
            json={"name": name, "remark": "写门禁集成测试", "is_enabled": True},
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.supplier_ids.append(int(row["id"]))
        return row

    def _run_write_gate_scenario(
        self,
        name: str,
        *,
        concurrency: int,
        duration_seconds: int,
    ) -> WriteGateRunResult:
        _ = concurrency
        _ = duration_seconds
        scenario = self.scenarios[name]
        registry = {
            "order:create-ready": ProductionOrderCreateSampleHandler(self),
            "order:line-items-ready": NoOpSampleHandler(),
            "supplier:create-ready": SupplierCreateSampleHandler(self),
        }
        runtime = WriteSampleRuntime(registry=registry)
        contract = scenario.sample_contract
        assert contract is not None
        restore_calls: list[str] = []
        try:
            runtime.prepare_contract(contract)
            if name == "production-order-create":
                process = self.context["production_process"]
                product = self.context["production_product"]
                supplier = self.context["production_supplier"]
                response = self.client.post(
                    scenario.path,
                    headers=self._headers(),
                    json={
                        "order_code": f"WG-ORDER-{int(time.time() * 1000)}",
                        "product_id": product["id"],
                        "supplier_id": supplier["id"],
                        "quantity": 10,
                        "process_steps": [
                            {
                                "step_order": 1,
                                "stage_id": self.context["production_stage"]["id"],
                                "process_id": process["id"],
                            }
                        ],
                    },
                )
                if response.status_code == 201:
                    self.order_ids.append(int(response.json()["data"]["id"]))
            elif name == "quality-supplier-create":
                response = self.client.post(
                    scenario.path,
                    headers=self._headers(),
                    json={
                        "name": f"WG-SUPPLIER-{int(time.time() * 1000)}",
                        "remark": "写门禁集成测试",
                        "is_enabled": True,
                    },
                )
                if response.status_code == 201:
                    self.supplier_ids.append(int(response.json()["data"]["id"]))
            else:
                self.fail(f"Unsupported scenario {name}")

            success = response.status_code in scenario.success_statuses
            error_types = {} if success else {str(response.status_code): 1}
            if name == "production-order-create":
                self.assertTrue(self.order_ids)
            if name == "quality-supplier-create":
                self.assertTrue(self.supplier_ids)
            return WriteGateRunResult(
                success_rate=1.0 if success else 0.0,
                error_types=error_types,
                restore_success_rate=0.0,
            )
        finally:
            restore_calls = runtime.restore_contract(contract)
            restore_success_rate = 1.0 if restore_calls else 0.0
            self.context["last_restore_success_rate"] = restore_success_rate

    def test_write_gate_can_prepare_execute_assert_and_restore_order_create(self) -> None:
        result = self._run_write_gate_scenario(
            "production-order-create",
            concurrency=2,
            duration_seconds=3,
        )

        self.assertEqual(result.success_rate, 1.0)
        self.assertEqual(result.error_types, {})
        self.assertEqual(self.context["last_restore_success_rate"], 1.0)

    def test_write_gate_can_restore_quality_supplier_create(self) -> None:
        result = self._run_write_gate_scenario(
            "quality-supplier-create",
            concurrency=2,
            duration_seconds=3,
        )

        self.assertEqual(result.success_rate, 1.0)
        self.assertEqual(result.error_types, {})
        self.assertEqual(self.context["last_restore_success_rate"], 1.0)

    def test_capacity_gate_can_resolve_production_craft_placeholders_from_sample_context(
        self,
    ) -> None:
        scenario = ScenarioSpec(
            name="production-order-create",
            method="POST",
            path="/api/v1/production/orders/{sample:production_order_id}",
            json_body={
                "product_id": "{sample:product_id}",
                "supplier_id": "{sample:supplier_id}",
                "process_steps": [
                    {
                        "stage_id": "{sample:stage_id}",
                        "process_id": "{sample:process_id}",
                    }
                ],
            },
        )

        prepared = _materialize_scenario_request(
            scenario,
            {
                "production_order_id": 18,
                "product_id": 11,
                "supplier_id": 12,
                "stage_id": 13,
                "process_id": 14,
            },
        )

        self.assertEqual(prepared.path, "/api/v1/production/orders/18")
        self.assertEqual(prepared.json_body["product_id"], 11)
        self.assertEqual(prepared.json_body["process_steps"][0]["process_id"], 14)


if __name__ == "__main__":
    unittest.main()
