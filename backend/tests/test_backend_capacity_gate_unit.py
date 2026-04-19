import asyncio
import json
import shutil
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from sqlalchemy.pool import NullPool


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
TEST_RUNTIME_DIR = REPO_ROOT / ".tmp_runtime" / "pytest_backend_capacity_gate"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.perf import backend_capacity_gate
from tools.perf.write_gate import sample_registry as sample_registry_module
from tools.perf.write_gate.sample_registry import build_sample_registry
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

    def test_build_login_usernames_for_pool_uses_token_count(self) -> None:
        spec = backend_capacity_gate.TokenPoolSpec(
            name="pool-admin",
            login_user_prefix="ltadm",
            password="Admin@123456",
            token_count=2,
        )

        usernames = backend_capacity_gate._build_login_usernames_for_pool(spec)

        self.assertEqual(usernames, ["ltadm1", "ltadm2"])

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

    def test_materialize_request_supports_random_short_placeholder(self) -> None:
        scenario = backend_capacity_gate.ScenarioSpec(
            name="user-create",
            method="POST",
            path="/api/v1/users",
            json_body={"username": "u{RANDOM_SHORT}"},
        )

        prepared = backend_capacity_gate._materialize_scenario_request(
            scenario,
            {},
        )

        self.assertTrue(str(prepared.json_body["username"]).startswith("u"))
        self.assertEqual(len(str(prepared.json_body["username"])), 7)

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

    def test_build_sample_registry_contains_runtime_handlers_for_write_suite(self) -> None:
        registry = build_sample_registry(
            sample_context={
                "product_id": 1,
                "stage_id": 2,
                "process_id": 3,
                "secondary_process_id": 4,
                "supplier_id": 5,
                "craft_template_id": 6,
                "admin_user_id": 7,
            },
            api_client=object(),
        )

        self.assertTrue(
            {
                "order:create-ready",
                "craft:template-draft-ready",
                "craft:template-published-ready",
                "craft:template-archived-ready",
                "craft:stage-delete-ready",
                "craft:process-create-ready",
                "craft:process-runtime-ready",
                "craft:system-master-ready",
                "product:runtime-version-create-ready",
                "product:runtime-draft-version-ready",
                "product:runtime-effective-version-ready",
                "equipment:runtime-ledger-ready",
                "equipment:runtime-item-ready",
                "equipment:runtime-plan-create-ready",
                "equipment:runtime-plan-ready",
                "equipment:runtime-rule-ready",
                "equipment:runtime-param-ready",
                "equipment:runtime-work-order-pending-ready",
                "equipment:runtime-work-order-in-progress-ready",
                "equipment:runtime-record-ready",
                "quality:runtime-supplier-ready",
                "quality:runtime-first-article-failed-ready",
                "quality:runtime-repair-order-ready",
                "quality:runtime-scrap-ready",
                "auth:runtime-registration-request-ready",
                "message:runtime-readonly-message-ready",
                "user:runtime-role-ready",
                "user:runtime-user-ready",
                "user:runtime-deleted-user-ready",
                "user:runtime-session-user-ready",
                "production:runtime-order-pending-ready",
                "production:runtime-order-in-progress-ready",
            }.issubset(registry)
        )

    def test_perf_sample_registry_uses_dedicated_null_pool_session_factory(self) -> None:
        with patch.object(
            sample_registry_module,
            "create_engine",
        ) as create_engine_mock:
            session_factory = sample_registry_module._build_perf_session_factory(
                "postgresql+psycopg2://demo:demo@127.0.0.1:5432/demo"
            )

        self.assertIsNotNone(session_factory)
        _, kwargs = create_engine_mock.call_args
        self.assertIs(kwargs["poolclass"], NullPool)
        self.assertTrue(kwargs["pool_pre_ping"])
        self.assertTrue(kwargs["future"])

    def test_execute_scenario_runs_write_gate_around_request_with_local_sample_context(
        self,
    ) -> None:
        scenario_registry = {
            "production-order-first-article": backend_capacity_gate.ScenarioSpec(
                name="production-order-first-article",
                method="POST",
                path="/api/v1/production/orders/{sample:production_order_id}/first-article",
                sample_contract=backend_capacity_gate.SampleContract(
                    runtime_samples=["production:runtime-order-pending-ready"],
                    restore_strategy="delete",
                ),
            )
        }
        shared_sample_context = {
            "production_order_id": 18,
            "baseline_marker": "baseline",
        }
        event_log: list[tuple[str, dict[str, object]]] = []

        class FakeRuntime:
            def prepare_contract(self, contract, sample_context):
                del contract
                event_log.append(("prepare", dict(sample_context)))
                sample_context["production_order_id"] = 501
                sample_context["runtime_marker"] = "prepared"
                return ["production:runtime-order-pending-ready"]

            def restore_contract(self, contract, sample_context):
                del contract
                event_log.append(("restore", dict(sample_context)))
                return ["production:runtime-order-pending-ready"]

        async def fake_request_scenario(
            *,
            client,
            base_url,
            scenario,
            token,
            sample_context,
        ):
            del client, base_url, scenario, token
            event_log.append(("request", dict(sample_context)))
            return True, "200", 12.3

        with (
            patch.object(
                backend_capacity_gate,
                "_build_write_sample_runtime",
                return_value=FakeRuntime(),
            ),
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
                    scenario="production-order-first-article",
                    scenario_registry=scenario_registry,
                    client=object(),
                    base_url="http://127.0.0.1:8000",
                    token_pools={"default": ["token-1"]},
                    login_usernames_by_pool={},
                    password="Admin@123456",
                    sample_context=shared_sample_context,
                )
            )

        self.assertTrue(success)
        self.assertEqual(status, "200")
        self.assertEqual(latency_ms, 12.3)
        self.assertEqual(
            event_log,
            [
                ("prepare", {"production_order_id": 18, "baseline_marker": "baseline"}),
                (
                    "request",
                    {
                        "production_order_id": 501,
                        "baseline_marker": "baseline",
                        "runtime_marker": "prepared",
                    },
                ),
                (
                    "restore",
                    {
                        "production_order_id": 501,
                        "baseline_marker": "baseline",
                        "runtime_marker": "prepared",
                    },
                ),
            ],
        )
        self.assertEqual(
            shared_sample_context,
            {
                "production_order_id": 18,
                "baseline_marker": "baseline",
            },
        )

    def test_execute_scenario_offloads_runtime_prepare_and_restore_to_thread(self) -> None:
        scenario_registry = {
            "production-order-update": backend_capacity_gate.ScenarioSpec(
                name="production-order-update",
                method="PUT",
                path="/api/v1/production/orders/{sample:production_order_id}",
                sample_contract=backend_capacity_gate.SampleContract(
                    runtime_samples=["production:runtime-order-pending-ready"],
                    restore_strategy="rebuild",
                ),
            )
        }
        runtime = SimpleNamespace(
            prepare_contract=lambda contract, sample_context: None,
            restore_contract=lambda contract, sample_context: None,
        )
        to_thread_calls: list[object] = []

        async def fake_to_thread(func, *args, **kwargs):
            del args, kwargs
            to_thread_calls.append(func)
            return func(
                scenario_registry["production-order-update"].sample_contract,
                {"production_order_id": 18},
            )

        async def fake_request_scenario(
            *,
            client,
            base_url,
            scenario,
            token,
            sample_context,
        ):
            del client, base_url, scenario, token, sample_context
            return True, "200", 1.0

        with (
            patch.object(
                backend_capacity_gate,
                "_build_write_sample_runtime",
                return_value=runtime,
            ),
            patch.object(
                backend_capacity_gate.asyncio,
                "to_thread",
                new=AsyncMock(side_effect=fake_to_thread),
            ),
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
            asyncio.run(
                backend_capacity_gate._execute_scenario(
                    scenario="production-order-update",
                    scenario_registry=scenario_registry,
                    client=object(),
                    base_url="http://127.0.0.1:8000",
                    token_pools={"default": ["token-1"]},
                    login_usernames_by_pool={},
                    password="Admin@123456",
                    sample_context={"production_order_id": 18},
                )
            )

        self.assertEqual(
            to_thread_calls,
            [runtime.prepare_contract, runtime.restore_contract],
        )


if __name__ == "__main__":
    unittest.main()
