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


class CombinedProductsScenarioSuiteUnitTest(unittest.TestCase):
    def test_combined_suite_reuses_seeded_product_paths_for_extended_products_views(
        self,
    ) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        self.assertEqual(
            bundle.scenarios["products-detail-v2"].path,
            "/api/v1/products/{sample:product_id}/detail",
        )
        self.assertEqual(
            bundle.scenarios["products-effective-parameters"].path,
            "/api/v1/products/{sample:product_id}/effective-parameters",
        )
        self.assertEqual(
            bundle.scenarios["products-impact-analysis"].path,
            "/api/v1/products/{sample:product_id}/impact-analysis",
        )
        self.assertEqual(
            bundle.scenarios["products-impact-analysis"].query["operation"],
            "lifecycle",
        )
        self.assertEqual(
            bundle.scenarios["products-impact-analysis"].query["target_status"],
            "inactive",
        )
        self.assertEqual(
            bundle.scenarios["products-parameter-history"].path,
            "/api/v1/products/{sample:product_id}/parameter-history",
        )
        self.assertEqual(
            bundle.scenarios["products-parameters"].path,
            "/api/v1/products/{sample:product_id}/parameters",
        )
        self.assertEqual(
            bundle.scenarios["products-versions-compare"].path,
            "/api/v1/products/{sample:product_id}/versions/compare",
        )
        self.assertEqual(
            bundle.scenarios["products-version-export"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_effective_version}/export",
        )
        self.assertEqual(
            bundle.scenarios["products-version-parameter-history"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_effective_version}/parameter-history",
        )
        self.assertEqual(
            bundle.scenarios["products-template-references-1"].path,
            "/api/v1/craft/products/{sample:product_id}/template-references",
        )
        self.assertEqual(
            bundle.scenarios["products-template-references-1"].sample_contract.runtime_samples,
            ["product:runtime-effective-version-ready"],
        )

    def test_combined_suite_product_mutations_use_seeded_product_context(self) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        self.assertEqual(
            bundle.scenarios["products-versions-create"].path,
            "/api/v1/products/{sample:product_id}/versions",
        )
        self.assertIsNone(bundle.scenarios["products-versions-create"].json_body)
        self.assertEqual(
            bundle.scenarios["products-versions-create"].sample_contract.runtime_samples,
            ["product:runtime-version-create-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-rollback"].path,
            "/api/v1/products/{sample:product_id}/rollback",
        )
        self.assertEqual(
            bundle.scenarios["products-rollback"].sample_contract.runtime_samples,
            ["product:runtime-draft-version-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-version-disable"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_effective_version}/disable",
        )
        self.assertEqual(
            bundle.scenarios["products-version-disable"].sample_contract.runtime_samples,
            ["product:runtime-effective-version-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-version-note"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_current_version}/note",
        )
        self.assertEqual(
            bundle.scenarios["products-version-note"].sample_contract.runtime_samples,
            ["product:runtime-draft-version-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-version-delete"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_current_version}",
        )
        self.assertEqual(
            bundle.scenarios["products-version-delete"].sample_contract.runtime_samples,
            ["product:runtime-draft-version-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-version-activate"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_current_version}/activate",
        )
        self.assertEqual(
            bundle.scenarios["products-version-activate"].sample_contract.runtime_samples,
            ["product:runtime-draft-version-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-version-copy"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_effective_version}/copy",
        )
        self.assertEqual(
            bundle.scenarios["products-version-copy"].sample_contract.runtime_samples,
            ["product:runtime-version-create-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-version-parameters"].path,
            "/api/v1/products/{sample:product_id}/versions/{sample:product_current_version}/parameters",
        )
        self.assertEqual(
            bundle.scenarios["products-version-parameters"].sample_contract.runtime_samples,
            ["product:runtime-draft-version-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-product-delete"].path,
            "/api/v1/products/{sample:product_id}/delete",
        )
        self.assertEqual(
            bundle.scenarios["products-product-delete"].json_body,
            {"password": "Admin@123456"},
        )
        self.assertEqual(
            bundle.scenarios["products-product-delete"].sample_contract.runtime_samples,
            ["product:runtime-version-create-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-product-update"].path,
            "/api/v1/products/{sample:product_id}",
        )
        self.assertEqual(
            bundle.scenarios["products-product-update"].json_body,
            {
                "name": "更新后的产品",
                "category": "贴片",
                "remark": "Updated product",
            },
        )
        self.assertEqual(
            bundle.scenarios["products-product-update"].sample_contract.runtime_samples,
            ["product:runtime-version-create-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-parameter-version-create"].path,
            "/api/v1/products/{sample:product_id}/versions",
        )
        self.assertIsNone(bundle.scenarios["products-parameter-version-create"].json_body)
        self.assertEqual(
            bundle.scenarios["products-parameter-version-create"].sample_contract.runtime_samples,
            ["product:runtime-version-create-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-parameter-update"].path,
            "/api/v1/products/{sample:product_id}/parameters",
        )
        self.assertEqual(
            bundle.scenarios["products-parameter-update"].sample_contract.runtime_samples,
            ["product:runtime-draft-version-ready"],
        )
        self.assertEqual(
            bundle.scenarios["products-parameter-update"].json_body,
            {
                "remark": "perf parameter update",
                "confirmed": False,
                "items": [
                    {
                        "name": "产品名称",
                        "category": "基础参数",
                        "type": "Text",
                        "value": "{sample:product_name}",
                        "description": "",
                    },
                    {
                        "name": "产品芯片",
                        "category": "基础参数",
                        "type": "Text",
                        "value": "PERF-UPDATED-CHIP",
                        "description": "性能压测参数更新",
                    },
                ],
            },
        )
        self.assertEqual(
            bundle.scenarios["products-lifecycle"].path,
            "/api/v1/products/{sample:product_id}/lifecycle",
        )
        self.assertEqual(
            bundle.scenarios["products-lifecycle"].json_body,
            {
                "target_status": "inactive",
                "confirmed": True,
                "note": "Load test lifecycle",
                "inactive_reason": "perf lifecycle check",
            },
        )
        self.assertEqual(
            bundle.scenarios["products-lifecycle"].sample_contract.runtime_samples,
            ["product:runtime-effective-version-ready"],
        )
        self.assertIn(
            "items",
            bundle.scenarios["products-version-parameters"].json_body,
        )
        self.assertNotIn(
            "parameters",
            bundle.scenarios["products-version-parameters"].json_body,
        )


if __name__ == "__main__":
    unittest.main()
