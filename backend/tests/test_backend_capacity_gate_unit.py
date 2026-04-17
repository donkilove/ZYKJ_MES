import asyncio
import json
import shutil
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
TEST_RUNTIME_DIR = REPO_ROOT / ".tmp_runtime" / "pytest_backend_capacity_gate"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.perf import backend_capacity_gate
from tools.perf.write_gate.sample_runtime import SampleExecutionResult


class BackendCapacityGateUnitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        TEST_RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(TEST_RUNTIME_DIR, ignore_errors=True)

    def _write_config(self, file_name: str, payload: dict[str, object]) -> Path:
        config_path = TEST_RUNTIME_DIR / file_name
        config_path.write_text(
            json.dumps(payload, ensure_ascii=False),
            encoding="utf-8",
        )
        return config_path

    def test_load_scenario_config_bundle_supports_token_pools_and_binding(self) -> None:
        config = {
            "token_pools": [
                {
                    "name": "pool-production",
                    "login_user_prefix": "loadtest_production_",
                    "token_count": 8,
                },
                {
                    "name": "pool-quality",
                    "login_user_prefix": "loadtest_quality_",
                },
            ],
            "scenarios": [
                {
                    "name": "production-orders-read",
                    "method": "GET",
                    "path": "/api/v1/production/orders",
                    "token_pool": "pool-production",
                },
                {
                    "name": "quality-trend-read",
                    "method": "GET",
                    "path": "/api/v1/quality/trend",
                    "token_pool": "pool-quality",
                },
            ],
        }

        config_path = self._write_config(
            "scenario_config_bundle_supports_token_pools.json",
            config,
        )
        self.addCleanup(config_path.unlink, missing_ok=True)

        bundle = backend_capacity_gate._load_scenario_config_bundle(str(config_path))

        self.assertEqual(
            bundle.token_pools["pool-production"].login_user_prefix,
            "loadtest_production_",
        )
        self.assertEqual(bundle.token_pools["pool-production"].token_count, 8)
        self.assertEqual(
            bundle.scenarios["production-orders-read"].token_pool,
            "pool-production",
        )
        self.assertEqual(
            bundle.scenarios["quality-trend-read"].token_pool,
            "pool-quality",
        )

    def test_load_scenario_config_bundle_supports_layer_and_sample_contract(self) -> None:
        config = {
            "scenarios": [
                {
                    "name": "write-contract",
                    "method": "POST",
                    "path": "/api/v1/production/orders",
                    "layer": "L1",
                    "sample_contract": {
                        "baseline_refs": ["baseline-a", "baseline-b"],
                        "runtime_samples": ["runtime-x", "runtime-y"],
                        "state_assertions": ["assert-1", "assert-2"],
                        "restore_strategy": "rebuild",
                    },
                }
            ]
        }

        config_path = self._write_config(
            "scenario_config_supports_layer_and_sample_contract.json",
            config,
        )
        self.addCleanup(config_path.unlink, missing_ok=True)

        bundle = backend_capacity_gate._load_scenario_config_bundle(str(config_path))

        self.assertEqual(bundle.scenarios["write-contract"].layer, "L1")
        self.assertEqual(
            bundle.scenarios["write-contract"].sample_contract.baseline_refs,
            ["baseline-a", "baseline-b"],
        )
        self.assertEqual(
            bundle.scenarios["write-contract"].sample_contract.runtime_samples,
            ["runtime-x", "runtime-y"],
        )
        self.assertEqual(
            bundle.scenarios["write-contract"].sample_contract.state_assertions,
            ["assert-1", "assert-2"],
        )
        self.assertEqual(
            bundle.scenarios["write-contract"].sample_contract.restore_strategy,
            "rebuild",
        )

    def test_load_scenario_config_bundle_rejects_invalid_restore_strategy(self) -> None:
        config = {
            "scenarios": [
                {
                    "name": "write-contract",
                    "method": "POST",
                    "path": "/api/v1/production/orders",
                    "layer": "L1",
                    "sample_contract": {
                        "baseline_refs": ["baseline-a"],
                        "runtime_samples": ["runtime-x"],
                        "state_assertions": ["assert-1"],
                        "restore_strategy": 123,
                    },
                }
            ]
        }

        config_path = self._write_config(
            "scenario_config_invalid_restore_strategy.json",
            config,
        )
        self.addCleanup(config_path.unlink, missing_ok=True)

        with self.assertRaisesRegex(ValueError, "restore_strategy must be a string"):
            backend_capacity_gate._load_scenario_config_bundle(str(config_path))

    def test_build_scenario_runtime_rejects_unknown_token_pool_binding(self) -> None:
        config = {
            "scenarios": [
                {
                    "name": "production-orders-read",
                    "method": "GET",
                    "path": "/api/v1/production/orders",
                    "token_pool": "pool-production",
                }
            ]
        }

        config_path = self._write_config(
            "scenario_config_unknown_token_pool.json",
            config,
        )
        self.addCleanup(config_path.unlink, missing_ok=True)
        args = SimpleNamespace(
            scenario_config_file=str(config_path),
            login_user_prefix="loadtest_",
            password="Admin@123456",
            token_count=40,
            token_file=None,
        )

        with self.assertRaisesRegex(ValueError, "unknown token pools"):
            backend_capacity_gate._build_scenario_runtime(args)

    def test_execute_scenario_uses_named_token_pool(self) -> None:
        scenario_registry = {
            "production-orders-read": backend_capacity_gate.ScenarioSpec(
                name="production-orders-read",
                method="GET",
                path="/api/v1/production/orders",
                requires_auth=True,
                token_pool="pool-production",
            )
        }
        captured: dict[str, str | None] = {}

        async def fake_request_scenario(*, client, base_url, scenario, token, sample_context):
            captured["token"] = token
            captured["sample_context"] = sample_context
            return True, "200", 1.23

        with (
            patch.object(
                backend_capacity_gate,
                "_request_scenario",
                new=AsyncMock(side_effect=fake_request_scenario),
            ),
            patch.object(
                backend_capacity_gate.random,
                "choice",
                side_effect=lambda values: values[0],
            ),
        ):
            success, status, latency_ms = asyncio.run(
                backend_capacity_gate._execute_scenario(
                    scenario="production-orders-read",
                    scenario_registry=scenario_registry,
                    client=object(),
                    base_url="http://127.0.0.1:8000",
                    token_pools={
                        "default": ["default-token"],
                        "pool-production": ["production-token"],
                    },
                    login_usernames_by_pool={"default": ["loadtest_1"]},
                    password="Admin@123456",
                    sample_context={},
                )
            )

        self.assertTrue(success)
        self.assertEqual(status, "200")
        self.assertEqual(latency_ms, 1.23)
        self.assertEqual(captured["token"], "production-token")
        self.assertEqual(captured["sample_context"], {})

    def test_full_89_read_process_scenarios_bind_user_admin_pool(self) -> None:
        args = SimpleNamespace(
            scenario_config_file="tools/perf/scenarios/full_89_read_40_scan.json",
            login_user_prefix="ltadm",
            password="Admin@123456",
            token_count=20,
            token_file=None,
        )

        registry, _ = backend_capacity_gate._build_scenario_runtime(args)

        self.assertEqual(
            registry["processes-list"].token_pool,
            "pool-user-admin",
        )
        self.assertEqual(
            registry["processes-detail-query"].token_pool,
            "pool-user-admin",
        )

    def test_write_gate_cli_output_contains_layer_summary_and_restore_rate(self) -> None:
        scenario_registry = {
            "production-order-create": backend_capacity_gate.ScenarioSpec(
                name="production-order-create",
                method="POST",
                path="/api/v1/production/orders",
                layer="L1",
            ),
            "quality-supplier-create": backend_capacity_gate.ScenarioSpec(
                name="quality-supplier-create",
                method="POST",
                path="/api/v1/quality/suppliers",
                layer="L2",
            ),
        }
        payload = backend_capacity_gate._build_write_gate_summary_from_metrics(
            scenario_metrics={
                "production-order-create": {
                    "success_rate": 1.0,
                    "error_rate": 0.0,
                    "p95_ms": 180,
                    "status_counts": {"201": 1},
                },
                "quality-supplier-create": {
                    "success_rate": 0.0,
                    "error_rate": 1.0,
                    "p95_ms": 90,
                    "status_counts": {"422": 1},
                },
            },
            scenario_registry=scenario_registry,
        )

        self.assertIn("by_layer", payload)
        self.assertEqual(
            payload["by_layer"]["L1"]["restore_success_rate"],
            1.0,
        )
        self.assertEqual(payload["by_layer"]["L2"]["error_types"]["422"], 1)

    def test_filter_token_pools_skips_unused_default_pool(self) -> None:
        scenario_registry = {
            "production-orders-read": backend_capacity_gate.ScenarioSpec(
                name="production-orders-read",
                method="GET",
                path="/api/v1/production/orders",
                requires_auth=True,
                token_pool="pool-production",
            )
        }
        token_pools = {
            "default": backend_capacity_gate.TokenPoolSpec(
                name="default",
                login_user_prefix="loadtest_",
                password="Admin@123456",
                token_count=20,
            ),
            "pool-production": backend_capacity_gate.TokenPoolSpec(
                name="pool-production",
                login_user_prefix="ltprd",
                password="Admin@123456",
                token_count=4,
            ),
        }

        filtered = backend_capacity_gate._filter_token_pool_specs_for_scenarios(
            scenarios=["production-orders-read"],
            scenario_registry=scenario_registry,
            token_pool_specs=token_pools,
        )

        self.assertEqual(list(filtered.keys()), ["pool-production"])

    def test_materialize_request_supports_sample_placeholders(self) -> None:
        scenario = backend_capacity_gate.ScenarioSpec(
            name="production-order-detail",
            method="GET",
            path="/api/v1/production/orders/{sample:production_order_id}",
            query={"template_id": "{sample:craft_template_id}"},
            json_body={"stage_id": "{sample:stage_id}"},
        )

        prepared = backend_capacity_gate._materialize_scenario_request(
            scenario,
            {
                "production_order_id": 18,
                "craft_template_id": 21,
                "stage_id": 7,
            },
        )

        self.assertEqual(prepared.path, "/api/v1/production/orders/18")
        self.assertEqual(prepared.query["template_id"], 21)
        self.assertEqual(prepared.json_body["stage_id"], 7)

    def test_execute_write_gate_contract_runs_prepare_and_restore_handlers(self) -> None:
        with patch.object(
            backend_capacity_gate,
            "_build_write_sample_runtime",
            return_value=SimpleNamespace(
                execute_contract=lambda **kwargs: SampleExecutionResult(
                    scenario_name=kwargs["scenario_name"],
                    prepare_calls=["order:create-ready"],
                    restore_calls=["order:create-ready"],
                    failed=False,
                )
            ),
        ):
            result = backend_capacity_gate._execute_write_gate_contract(
                scenario_name="production-order-create",
                contract=backend_capacity_gate.SampleContract(
                    baseline_refs=["product:PERF-PRODUCT-STD-01"],
                    runtime_samples=["order:create-ready"],
                    restore_strategy="rebuild",
                ),
                sample_context={"product_id": 1},
                api_client=object(),
            )

        self.assertEqual(result.prepare_calls, ["order:create-ready"])
        self.assertEqual(result.restore_calls, ["order:create-ready"])
        self.assertFalse(result.failed)


if __name__ == "__main__":
    unittest.main()
