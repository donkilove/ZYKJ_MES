import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.perf.backend_capacity_gate import _load_scenario_config_bundle  # noqa: E402


COMBINED_SUITE = "tools/perf/scenarios/combined_40_scan.json"


class CombinedQualityScenarioSuiteUnitTest(unittest.TestCase):
    def test_quality_runtime_samples_cover_supplier_first_article_repair_and_scrap(
        self,
    ) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        supplier_update = bundle.scenarios["quality-supplier-update"]
        self.assertEqual(
            supplier_update.path,
            "/api/v1/quality/suppliers/{sample:supplier_id}",
        )
        self.assertEqual(
            supplier_update.sample_contract.runtime_samples,
            ["quality:runtime-supplier-ready"],
        )

        supplier_delete = bundle.scenarios["quality-supplier-delete"]
        self.assertEqual(
            supplier_delete.path,
            "/api/v1/quality/suppliers/{sample:supplier_id}",
        )
        self.assertEqual(
            supplier_delete.sample_contract.runtime_samples,
            ["quality:runtime-supplier-ready"],
        )

        first_article_create = bundle.scenarios["quality-first-article-create"]
        self.assertEqual(
            first_article_create.path,
            "/api/v1/quality/first-articles/{sample:quality_first_article_id}/disposition",
        )
        self.assertEqual(
            first_article_create.sample_contract.runtime_samples,
            ["quality:runtime-first-article-failed-ready"],
        )

        first_article_disposition = bundle.scenarios["quality-first-article-disposition"]
        self.assertEqual(
            first_article_disposition.path,
            "/api/v1/quality/first-articles/{sample:quality_first_article_id}/disposition",
        )
        self.assertEqual(
            first_article_disposition.sample_contract.runtime_samples,
            ["quality:runtime-first-article-failed-ready"],
        )

        first_article_detail = bundle.scenarios["quality-first-article-detail"]
        self.assertEqual(
            first_article_detail.path,
            "/api/v1/quality/first-articles/{sample:quality_first_article_id}",
        )
        self.assertEqual(
            first_article_detail.sample_contract.runtime_samples,
            ["quality:runtime-first-article-failed-ready"],
        )

        first_article_disposition_detail = bundle.scenarios[
            "quality-first-article-disposition-detail"
        ]
        self.assertEqual(
            first_article_disposition_detail.path,
            "/api/v1/quality/first-articles/{sample:quality_first_article_id}/disposition-detail",
        )
        self.assertEqual(
            first_article_disposition_detail.sample_contract.runtime_samples,
            ["quality:runtime-first-article-failed-ready"],
        )

        repair_create = bundle.scenarios["quality-repair-order-create"]
        self.assertEqual(
            repair_create.path,
            "/api/v1/quality/repair-orders/{sample:quality_repair_order_id}/complete",
        )
        self.assertEqual(
            repair_create.sample_contract.runtime_samples,
            ["quality:runtime-repair-order-ready"],
        )
        self.assertIn("cause_items", repair_create.json_body)
        self.assertEqual(
            repair_create.json_body["return_allocations"][0]["target_order_process_id"],
            "{sample:quality_order_process_id}",
        )

        repair_complete = bundle.scenarios["quality-repair-order-complete"]
        self.assertEqual(
            repair_complete.path,
            "/api/v1/quality/repair-orders/{sample:quality_repair_order_id}/complete",
        )
        self.assertEqual(
            repair_complete.sample_contract.runtime_samples,
            ["quality:runtime-repair-order-ready"],
        )
        self.assertIn("cause_items", repair_complete.json_body)

        repair_detail = bundle.scenarios["quality-repair-order-detail"]
        self.assertEqual(
            repair_detail.path,
            "/api/v1/quality/repair-orders/{sample:quality_repair_order_id}/detail",
        )
        self.assertEqual(
            repair_detail.sample_contract.runtime_samples,
            ["quality:runtime-repair-order-ready"],
        )

        repair_summary = bundle.scenarios["quality-repair-order-phenomena-summary"]
        self.assertEqual(
            repair_summary.path,
            "/api/v1/quality/repair-orders/{sample:quality_repair_order_id}/phenomena-summary",
        )
        self.assertEqual(
            repair_summary.sample_contract.runtime_samples,
            ["quality:runtime-repair-order-ready"],
        )

        scrap_detail = bundle.scenarios["quality-scrap-statistics-detail"]
        self.assertEqual(
            scrap_detail.path,
            "/api/v1/quality/scrap-statistics/{sample:quality_scrap_id}",
        )
        self.assertEqual(
            scrap_detail.sample_contract.runtime_samples,
            ["quality:runtime-scrap-ready"],
        )


if __name__ == "__main__":
    unittest.main()
