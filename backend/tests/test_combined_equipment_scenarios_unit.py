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


class CombinedEquipmentScenarioSuiteUnitTest(unittest.TestCase):
    def test_equipment_mutation_scenarios_use_runtime_samples_and_current_payload_shape(
        self,
    ) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        ledger_create = bundle.scenarios["equipment-ledger-create"]
        self.assertEqual(ledger_create.path, "/api/v1/equipment/ledger")
        self.assertIn("code", ledger_create.json_body)
        self.assertIn("name", ledger_create.json_body)
        self.assertIn("location", ledger_create.json_body)
        self.assertNotIn("equipment_code", ledger_create.json_body)

        ledger_update = bundle.scenarios["equipment-ledger-update"]
        self.assertEqual(
            ledger_update.path,
            "/api/v1/equipment/ledger/{sample:equipment_id}",
        )
        self.assertEqual(
            ledger_update.sample_contract.runtime_samples,
            ["equipment:runtime-ledger-ready"],
        )
        self.assertIn("code", ledger_update.json_body)
        self.assertNotIn("equipment_name", ledger_update.json_body)

        ledger_delete = bundle.scenarios["equipment-ledger-delete"]
        self.assertEqual(
            ledger_delete.path,
            "/api/v1/equipment/ledger/{sample:equipment_id}",
        )
        self.assertEqual(
            ledger_delete.sample_contract.runtime_samples,
            ["equipment:runtime-ledger-ready"],
        )

        ledger_toggle = bundle.scenarios["equipment-ledger-toggle"]
        self.assertEqual(
            ledger_toggle.path,
            "/api/v1/equipment/ledger/{sample:equipment_id}/toggle",
        )
        self.assertEqual(
            ledger_toggle.sample_contract.runtime_samples,
            ["equipment:runtime-ledger-ready"],
        )

        ledger_disable = bundle.scenarios["equipment-ledger-disable"]
        self.assertEqual(
            ledger_disable.path,
            "/api/v1/equipment/ledger/{sample:equipment_id}/disable",
        )
        self.assertEqual(
            ledger_disable.sample_contract.runtime_samples,
            ["equipment:runtime-ledger-ready"],
        )

        item_create = bundle.scenarios["equipment-item-create"]
        self.assertEqual(item_create.path, "/api/v1/equipment/items")
        self.assertIn("name", item_create.json_body)
        self.assertIn("default_cycle_days", item_create.json_body)
        self.assertNotIn("equipment_id", item_create.json_body)

        item_update = bundle.scenarios["equipment-item-update"]
        self.assertEqual(
            item_update.path,
            "/api/v1/equipment/items/{sample:maintenance_item_id}",
        )
        self.assertEqual(
            item_update.sample_contract.runtime_samples,
            ["equipment:runtime-item-ready"],
        )
        self.assertIn("name", item_update.json_body)
        self.assertIn("default_duration_minutes", item_update.json_body)

        for scenario_name in (
            "equipment-item-delete",
            "equipment-item-toggle",
            "equipment-items-disable",
        ):
            scenario = bundle.scenarios[scenario_name]
            self.assertIn("{sample:maintenance_item_id}", scenario.path)
            self.assertEqual(
                scenario.sample_contract.runtime_samples,
                ["equipment:runtime-item-ready"],
            )

        plan_create = bundle.scenarios["equipment-plan-create"]
        self.assertEqual(plan_create.path, "/api/v1/equipment/plans")
        self.assertEqual(
            plan_create.sample_contract.runtime_samples,
            ["equipment:runtime-plan-create-ready"],
        )
        self.assertEqual(plan_create.json_body["equipment_id"], "{sample:equipment_id}")
        self.assertEqual(
            plan_create.json_body["item_id"],
            "{sample:maintenance_item_id}",
        )
        self.assertEqual(
            plan_create.json_body["execution_process_code"],
            "{sample:equipment_stage_code}",
        )

        for scenario_name in (
            "equipment-plan-update",
            "equipment-plan-toggle",
            "equipment-plan-delete",
            "equipment-plans-generate",
        ):
            scenario = bundle.scenarios[scenario_name]
            self.assertIn("{sample:maintenance_plan_id}", scenario.path)
            self.assertEqual(
                scenario.sample_contract.runtime_samples,
                ["equipment:runtime-plan-ready"],
            )

        execution_create = bundle.scenarios["equipment-execution-create"]
        self.assertEqual(
            execution_create.path,
            "/api/v1/equipment/plans/{sample:maintenance_plan_id}/generate",
        )
        self.assertEqual(
            execution_create.sample_contract.runtime_samples,
            ["equipment:runtime-plan-ready"],
        )
        self.assertIsNone(execution_create.json_body)

        for scenario_name in (
            "equipment-execution-start",
            "equipment-execution-cancel",
            "equipment-execution-detail",
        ):
            scenario = bundle.scenarios[scenario_name]
            self.assertIn("{sample:maintenance_work_order_id}", scenario.path)
            self.assertEqual(
                scenario.sample_contract.runtime_samples,
                ["equipment:runtime-work-order-pending-ready"],
            )

        execution_complete = bundle.scenarios["equipment-execution-complete"]
        self.assertIn(
            "{sample:maintenance_work_order_id}",
            execution_complete.path,
        )
        self.assertEqual(
            execution_complete.sample_contract.runtime_samples,
            ["equipment:runtime-work-order-in-progress-ready"],
        )
        self.assertEqual(execution_complete.json_body["result_summary"], "完成")

        rule_create = bundle.scenarios["equipment-rule-create"]
        self.assertEqual(rule_create.path, "/api/v1/equipment/rules")
        self.assertIn("rule_code", rule_create.json_body)
        self.assertIn("condition_desc", rule_create.json_body)
        self.assertNotIn("config", rule_create.json_body)

        for scenario_name in (
            "equipment-rule-update",
            "equipment-rule-toggle",
            "equipment-rule-delete",
        ):
            scenario = bundle.scenarios[scenario_name]
            self.assertIn("{sample:equipment_rule_id}", scenario.path)
            self.assertEqual(
                scenario.sample_contract.runtime_samples,
                ["equipment:runtime-rule-ready"],
            )

        runtime_param_create = bundle.scenarios["equipment-runtime-param-create"]
        self.assertEqual(
            runtime_param_create.sample_contract.runtime_samples,
            ["equipment:runtime-ledger-ready"],
        )
        self.assertEqual(
            runtime_param_create.json_body["equipment_id"],
            "{sample:equipment_id}",
        )
        self.assertIn("param_code", runtime_param_create.json_body)
        self.assertNotIn("param_value", runtime_param_create.json_body)

        runtime_param_batch = bundle.scenarios["equipment-runtime-param-batch-create"]
        self.assertEqual(
            runtime_param_batch.path,
            "/api/v1/equipment/runtime-parameters",
        )
        self.assertEqual(
            runtime_param_batch.sample_contract.runtime_samples,
            ["equipment:runtime-ledger-ready"],
        )
        self.assertIn("param_code", runtime_param_batch.json_body)

        for scenario_name in (
            "equipment-runtime-param-update",
            "equipment-runtime-param-delete",
            "equipment-runtime-param-toggle",
        ):
            scenario = bundle.scenarios[scenario_name]
            self.assertIn("{sample:equipment_runtime_parameter_id}", scenario.path)
            self.assertEqual(
                scenario.sample_contract.runtime_samples,
                ["equipment:runtime-param-ready"],
            )

        ledger_detail = bundle.scenarios["equipment-ledger-detail"]
        self.assertEqual(
            ledger_detail.path,
            "/api/v1/equipment/ledger/{sample:equipment_id}/detail",
        )
        self.assertEqual(
            ledger_detail.sample_contract.runtime_samples,
            ["equipment:runtime-ledger-ready"],
        )

        record_detail = bundle.scenarios["equipment-record-detail"]
        self.assertEqual(
            record_detail.path,
            "/api/v1/equipment/records/{sample:maintenance_record_id}/detail",
        )
        self.assertEqual(
            record_detail.sample_contract.runtime_samples,
            ["equipment:runtime-record-ready"],
        )


if __name__ == "__main__":
    unittest.main()
