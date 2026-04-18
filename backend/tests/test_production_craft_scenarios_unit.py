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
            "product_current_version",
            "product_effective_version",
            "stage_id",
            "stage_code",
            "process_id",
            "process_code",
            "secondary_process_id",
            "secondary_process_code",
            "supplier_id",
            "craft_template_id",
            "first_article_template_id",
            "verification_code",
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

    def test_combined_suite_reuses_seeded_product_supplier_and_template_placeholders(
        self,
    ) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        self.assertEqual(
            bundle.scenarios["quality-supplier-detail-1"].path,
            "/api/v1/quality/suppliers/{sample:supplier_id}",
        )
        self.assertEqual(
            bundle.scenarios["products-detail-1"].path,
            "/api/v1/products/{sample:product_id}",
        )
        self.assertEqual(
            bundle.scenarios["products-detail-1-includes-versions"].path,
            "/api/v1/products/{sample:product_id}/versions",
        )
        self.assertEqual(
            bundle.scenarios["products-detail-1-version-1-params"].path,
            "/api/v1/products/{sample:product_id}/versions/1/parameters",
        )
        self.assertEqual(
            bundle.scenarios["craft-template-versions"].path,
            "/api/v1/craft/templates/{sample:craft_template_id}/versions",
        )
        self.assertEqual(
            bundle.scenarios["craft-template-version-export"].path,
            "/api/v1/craft/templates/{sample:craft_template_id}/versions/1/export",
        )
        self.assertEqual(
            bundle.scenarios["craft-template-versions-compare"].path,
            "/api/v1/craft/templates/{sample:craft_template_id}/versions/compare",
        )
        self.assertEqual(
            bundle.scenarios["craft-template-export"].path,
            "/api/v1/craft/templates/{sample:craft_template_id}/export",
        )

    def test_combined_suite_production_craft_write_contract_matches_runtime_handlers(
        self,
    ) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        update_order = bundle.scenarios["production-order-update"]
        assert update_order.sample_contract is not None
        self.assertEqual(
            update_order.sample_contract.runtime_samples,
            ["production:runtime-order-pending-ready"],
        )

        first_article = bundle.scenarios["production-order-first-article"]
        assert first_article.sample_contract is not None
        self.assertEqual(
            first_article.sample_contract.runtime_samples,
            ["production:runtime-order-pending-ready"],
        )
        self.assertEqual(
            first_article.json_body["template_id"],
            "{sample:first_article_template_id}",
        )
        self.assertEqual(
            first_article.json_body["verification_code"],
            "{sample:verification_code}",
        )
        self.assertEqual(
            first_article.json_body["effective_operator_user_id"],
            "{sample:runtime_operator_user_id}",
        )

        end_production = bundle.scenarios["production-order-end-production"]
        assert end_production.sample_contract is not None
        self.assertEqual(
            end_production.sample_contract.runtime_samples,
            ["production:runtime-order-in-progress-ready"],
        )
        self.assertEqual(
            end_production.json_body["effective_operator_user_id"],
            "{sample:runtime_operator_user_id}",
        )

        assist = bundle.scenarios["production-assist-authorization-create"]
        assert assist.sample_contract is not None
        self.assertEqual(
            assist.sample_contract.runtime_samples,
            ["production:runtime-order-pending-ready"],
        )
        self.assertEqual(
            assist.json_body["target_operator_user_id"],
            "{sample:runtime_operator_user_id}",
        )

        order_delete = bundle.scenarios["production-order-delete"]
        assert order_delete.sample_contract is not None
        self.assertEqual(
            order_delete.path,
            "/api/v1/production/orders/{sample:production_order_id}",
        )
        self.assertEqual(
            order_delete.sample_contract.runtime_samples,
            ["production:runtime-order-pending-ready"],
        )

        order_complete = bundle.scenarios["production-order-complete"]
        assert order_complete.sample_contract is not None
        self.assertEqual(
            order_complete.path,
            "/api/v1/production/orders/{sample:production_order_id}/complete",
        )
        self.assertEqual(
            order_complete.sample_contract.runtime_samples,
            ["production:runtime-order-pending-ready"],
        )
        self.assertEqual(order_complete.json_body["password"], "Admin@123456")

        repair_detail = bundle.scenarios["production-repair-order-detail"]
        assert repair_detail.sample_contract is not None
        self.assertEqual(
            repair_detail.path,
            "/api/v1/production/repair-orders/{sample:quality_repair_order_id}/detail",
        )
        self.assertEqual(
            repair_detail.sample_contract.runtime_samples,
            ["quality:runtime-repair-order-ready"],
        )

        repair_phenomena = bundle.scenarios["production-repair-order-phenomena-summary"]
        assert repair_phenomena.sample_contract is not None
        self.assertEqual(
            repair_phenomena.path,
            "/api/v1/production/repair-orders/{sample:quality_repair_order_id}/phenomena-summary",
        )
        self.assertEqual(
            repair_phenomena.sample_contract.runtime_samples,
            ["quality:runtime-repair-order-ready"],
        )

        scrap_detail = bundle.scenarios["production-scrap-statistics-detail"]
        assert scrap_detail.sample_contract is not None
        self.assertEqual(
            scrap_detail.path,
            "/api/v1/production/scrap-statistics/{sample:quality_scrap_id}",
        )
        self.assertEqual(
            scrap_detail.sample_contract.runtime_samples,
            ["quality:runtime-scrap-ready"],
        )

        craft_update = bundle.scenarios["craft-template-update"]
        assert craft_update.sample_contract is not None
        self.assertEqual(
            craft_update.sample_contract.runtime_samples,
            ["craft:template-draft-ready"],
        )
        self.assertEqual(
            craft_update.json_body["template_name"],
            "{sample:craft_template_name}",
        )

        craft_publish = bundle.scenarios["craft-template-publish"]
        assert craft_publish.sample_contract is not None
        self.assertEqual(
            craft_publish.sample_contract.runtime_samples,
            ["craft:template-draft-ready"],
        )

        craft_rollback = bundle.scenarios["craft-template-rollback"]
        assert craft_rollback.sample_contract is not None
        self.assertEqual(
            craft_rollback.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )

        craft_draft = bundle.scenarios["craft-template-draft"]
        assert craft_draft.sample_contract is not None
        self.assertEqual(
            craft_draft.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )

        craft_version_export = bundle.scenarios["craft-template-version-export"]
        assert craft_version_export.sample_contract is not None
        self.assertEqual(
            craft_version_export.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )

        craft_versions_compare = bundle.scenarios["craft-template-versions-compare"]
        assert craft_versions_compare.sample_contract is not None
        self.assertEqual(
            craft_versions_compare.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )
        self.assertEqual(craft_versions_compare.query["from_version"], "1")
        self.assertEqual(craft_versions_compare.query["to_version"], "1")

        craft_process_create = bundle.scenarios["craft-process-create"]
        assert craft_process_create.sample_contract is not None
        self.assertEqual(
            craft_process_create.sample_contract.runtime_samples,
            ["craft:process-create-ready"],
        )
        self.assertEqual(
            craft_process_create.json_body["code"],
            "{sample:runtime_process_code}",
        )

        craft_process_update = bundle.scenarios["craft-process-update"]
        assert craft_process_update.sample_contract is not None
        self.assertEqual(
            craft_process_update.path,
            "/api/v1/craft/processes/{sample:runtime_process_id}",
        )
        self.assertEqual(
            craft_process_update.sample_contract.runtime_samples,
            ["craft:process-runtime-ready"],
        )
        self.assertEqual(
            craft_process_update.json_body["code"],
            "{sample:runtime_process_code}",
        )

        craft_process_delete = bundle.scenarios["craft-process-delete"]
        assert craft_process_delete.sample_contract is not None
        self.assertEqual(
            craft_process_delete.path,
            "/api/v1/craft/processes/{sample:runtime_process_id}",
        )
        self.assertEqual(
            craft_process_delete.sample_contract.runtime_samples,
            ["craft:process-runtime-ready"],
        )

        system_master_create = bundle.scenarios["craft-system-master-template-create"]
        self.assertEqual(
            system_master_create.json_body["steps"][0]["stage_id"],
            "{sample:stage_id}",
        )
        self.assertEqual(
            system_master_create.json_body["steps"][0]["process_id"],
            "{sample:process_id}",
        )
        self.assertEqual(system_master_create.success_statuses, {201, 400})

        system_master_update = bundle.scenarios["craft-system-master-template-update"]
        assert system_master_update.sample_contract is not None
        self.assertEqual(
            system_master_update.sample_contract.runtime_samples,
            ["craft:system-master-ready"],
        )
        self.assertEqual(
            system_master_update.json_body["steps"][0]["stage_id"],
            "{sample:stage_id}",
        )

        template_enable = bundle.scenarios["craft-template-enable"]
        assert template_enable.sample_contract is not None
        self.assertEqual(
            template_enable.path,
            "/api/v1/craft/templates/{sample:craft_template_id}/enable",
        )
        self.assertEqual(
            template_enable.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )

        template_disable = bundle.scenarios["craft-template-disable"]
        assert template_disable.sample_contract is not None
        self.assertEqual(
            template_disable.path,
            "/api/v1/craft/templates/{sample:craft_template_id}/disable",
        )
        self.assertEqual(
            template_disable.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )

        template_copy = bundle.scenarios["craft-template-copy"]
        assert template_copy.sample_contract is not None
        self.assertEqual(
            template_copy.path,
            "/api/v1/craft/templates/{sample:craft_template_id}/copy",
        )
        self.assertEqual(
            template_copy.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )

        template_copy_to_product = bundle.scenarios["craft-template-copy-to-product"]
        assert template_copy_to_product.sample_contract is not None
        self.assertEqual(
            template_copy_to_product.path,
            "/api/v1/craft/templates/{sample:craft_template_id}/copy-to-product",
        )
        self.assertEqual(
            template_copy_to_product.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )
        self.assertEqual(
            template_copy_to_product.json_body["target_product_id"],
            "{sample:product_id}",
        )

        system_master_copy = bundle.scenarios["craft-system-master-copy-to-product"]
        self.assertEqual(
            system_master_copy.json_body["product_id"],
            "{sample:product_id}",
        )
        self.assertIn("new_name", system_master_copy.json_body)

        template_delete = bundle.scenarios["craft-template-delete"]
        assert template_delete.sample_contract is not None
        self.assertEqual(
            template_delete.path,
            "/api/v1/craft/templates/{sample:craft_template_id}",
        )
        self.assertEqual(
            template_delete.sample_contract.runtime_samples,
            ["craft:template-draft-ready"],
        )

        template_import = bundle.scenarios["craft-template-import"]
        self.assertGreater(len(template_import.json_body["items"]), 0)
        self.assertEqual(
            template_import.json_body["items"][0]["product_id"],
            "{sample:product_id}",
        )

        template_archive = bundle.scenarios["craft-template-archive"]
        assert template_archive.sample_contract is not None
        self.assertEqual(
            template_archive.path,
            "/api/v1/craft/templates/{sample:craft_template_id}/archive",
        )
        self.assertEqual(
            template_archive.sample_contract.runtime_samples,
            ["craft:template-published-ready"],
        )

        template_unarchive = bundle.scenarios["craft-template-unarchive"]
        assert template_unarchive.sample_contract is not None
        self.assertEqual(
            template_unarchive.path,
            "/api/v1/craft/templates/{sample:craft_template_id}/unarchive",
        )
        self.assertEqual(
            template_unarchive.sample_contract.runtime_samples,
            ["craft:template-archived-ready"],
        )


if __name__ == "__main__":
    unittest.main()
