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

        async def fake_request_scenario(*, client, base_url, scenario, token):
            captured["token"] = token
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
                )
            )

        self.assertTrue(success)
        self.assertEqual(status, "200")
        self.assertEqual(latency_ms, 1.23)
        self.assertEqual(captured["token"], "production-token")

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


if __name__ == "__main__":
    unittest.main()
