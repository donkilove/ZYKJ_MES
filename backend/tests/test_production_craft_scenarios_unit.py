import json
import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from app.db.session import SessionLocal  # noqa: E402
from app.services.perf_sample_seed_service import seed_production_craft_samples  # noqa: E402
from tools.perf.backend_capacity_gate import _load_scenario_config_bundle  # noqa: E402


READ_SUITE = "tools/perf/scenarios/production_craft_read_40_scan.json"
DETAIL_SUITE = "tools/perf/scenarios/production_craft_detail_40_scan.json"
WRITE_SUITE = "tools/perf/scenarios/production_craft_write_40_scan.json"
COMBINED_SUITE = "tools/perf/scenarios/combined_40_scan.json"


def _load_json(path: str) -> dict[str, object]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


class ProductionCraftScenarioSuiteUnitTest(unittest.TestCase):
    def test_seeded_sample_context_exposes_detail_and_write_placeholder_keys(self) -> None:
        db = SessionLocal()
        try:
            context = seed_production_craft_samples(db, run_id="baseline").context
        finally:
            db.close()

        expected_keys = {
            "product_id",
            "stage_id",
            "stage_code",
            "process_id",
            "process_code",
            "secondary_process_id",
            "secondary_process_code",
            "supplier_id",
            "craft_template_id",
            "production_order_id",
            "production_order_code",
            "order_process_id",
            "secondary_order_process_id",
        }
        self.assertTrue(expected_keys.issubset(context.keys()))

    def test_production_craft_detail_suite_uses_sample_placeholders_instead_of_legacy_ids(
        self,
    ) -> None:
        raw = Path(DETAIL_SUITE).read_text(encoding="utf-8")
        self.assertNotIn("/orders/18", raw)
        self.assertNotIn("/templates/1", raw)
        self.assertNotIn("/stages/1/references", raw)
        self.assertNotIn("/processes/1/references", raw)
        self.assertNotIn("/my-orders/18/context", raw)
        self.assertNotIn("/products/1/template-references", raw)
        self.assertIn("{sample:", raw)

        bundle = _load_scenario_config_bundle(DETAIL_SUITE)
        self.assertIn("production-order-detail", bundle.scenarios)
        self.assertIn("craft-template-detail", bundle.scenarios)

    def test_production_craft_write_suite_has_layer_and_sample_contract(self) -> None:
        bundle = _load_scenario_config_bundle(WRITE_SUITE)
        self.assertGreater(len(bundle.scenarios), 0)
        for scenario in bundle.scenarios.values():
            self.assertIn(scenario.layer, {"L1", "L2", "L3"})
            self.assertIsNotNone(scenario.sample_contract)
            assert scenario.sample_contract is not None
            self.assertIn(
                scenario.sample_contract.restore_strategy,
                {"rebuild", "delete"},
            )
            self.assertGreaterEqual(
                len(scenario.sample_contract.baseline_refs)
                + len(scenario.sample_contract.runtime_samples),
                1,
            )

    def test_combined_suite_core_production_craft_scenarios_use_placeholders_and_current_payload_shape(
        self,
    ) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        detail = bundle.scenarios["production-order-detail-18"]
        self.assertEqual(
            detail.path,
            "/api/v1/production/orders/{sample:production_order_id}",
        )

        fa_templates = bundle.scenarios["production-order-first-article-templates-18"]
        self.assertEqual(
            fa_templates.query["order_process_id"],
            "{sample:order_process_id}",
        )

        event_search = bundle.scenarios["production-order-events-search"]
        self.assertEqual(
            event_search.query["order_code"],
            "{sample:production_order_code}",
        )

        craft_stage_create = bundle.scenarios["craft-stage-create"]
        self.assertIn("code", craft_stage_create.json_body)
        self.assertIn("name", craft_stage_create.json_body)
        self.assertNotIn("stage_code", craft_stage_create.json_body)

        craft_process_create = bundle.scenarios["craft-process-create"]
        self.assertIn("code", craft_process_create.json_body)
        self.assertIn("name", craft_process_create.json_body)
        self.assertNotIn("process_code", craft_process_create.json_body)

        craft_template_create = bundle.scenarios["craft-template-create"]
        self.assertIn("steps", craft_template_create.json_body)
        self.assertNotIn("process_code", craft_template_create.json_body)


if __name__ == "__main__":
    unittest.main()
