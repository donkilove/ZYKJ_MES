import json
import sys
import unittest
from collections import Counter
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
TOOLS_DIR = REPO_ROOT / "tools"

if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import graphify_curate
import graphify_navigation


RULES_PATH = TOOLS_DIR / "graphify_rules.json"


class GraphifyGovernanceToolsUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rules = json.loads(RULES_PATH.read_text(encoding="utf-8"))

    def test_name_communities_skips_ui_noise_entity_for_business_domain(self) -> None:
        communities = {0}
        comm_domain = {0: Counter({"equipment": 10, "frontend-core": 3})}
        comm_entities = {
            0: Counter(
                {
                    "Spacer": 50,
                    "EquipmentLedgerListResult": 12,
                    "EquipmentLedgerPage": 8,
                }
            )
        }

        name_map, _canonical = graphify_curate._name_communities(
            communities, comm_domain, comm_entities, self.rules
        )

        self.assertEqual(name_map[0], "设备管理 - EquipmentLedgerListResult")

    def test_name_communities_maps_tests_domain_without_expectlater_noise(self) -> None:
        communities = {1}
        comm_domain = {1: Counter({"tests": 20, "frontend-core": 9, "authz": 5})}
        comm_entities = {
            1: Counter(
                {
                    "expectLater": 40,
                    "RoleManagementPage": 12,
                    "AuthzSnapshotResult": 10,
                }
            )
        }

        name_map, _canonical = graphify_curate._name_communities(
            communities, comm_domain, comm_entities, self.rules
        )

        self.assertNotIn("expectLater", name_map[1])
        self.assertIn("测试支撑", name_map[1])

    def test_build_supplementary_chain_adds_service_page_and_test_for_equipment_ledger_item(self) -> None:
        graph = {
            "nodes": [
                {
                    "id": "frontend_model_equipment_ledger_item",
                    "label": "EquipmentLedgerItem",
                    "source_file": r"frontend\lib\features\equipment\models\equipment_models.dart",
                    "domain_tag": "equipment",
                },
                {
                    "id": "backend_schema_equipment",
                    "label": "EquipmentLedgerItem",
                    "source_file": r"backend\app\schemas\equipment.py",
                    "domain_tag": "equipment",
                },
                {
                    "id": "frontend_service_equipment",
                    "label": "EquipmentService",
                    "source_file": r"frontend\lib\features\equipment\services\equipment_service.dart",
                    "domain_tag": "equipment",
                },
                {
                    "id": "frontend_page_equipment",
                    "label": "EquipmentLedgerPage",
                    "source_file": r"frontend\lib\features\equipment\presentation\equipment_ledger_page.dart",
                    "domain_tag": "equipment",
                },
                {
                    "id": "frontend_test_equipment",
                    "label": "_buildEquipmentLedgerItem",
                    "source_file": r"frontend\test\widgets\equipment_module_pages_test.dart",
                    "domain_tag": "tests",
                },
            ]
        }

        chain = graphify_navigation._build_supplementary_chain(
            graph=graph,
            obj_name="EquipmentLedgerItem",
            main_node=graph["nodes"][0],
            node_map={n["id"]: n for n in graph["nodes"]},
            rules=self.rules,
        )

        self.assertIn("后端 Schema/DTO", chain)
        self.assertIn("前端 Service", chain)
        self.assertIn("前端页面/Widget", chain)
        self.assertIn("测试覆盖", chain)

    def test_build_supplementary_chain_adds_page_and_test_for_app_session(self) -> None:
        graph = {
            "nodes": [
                {
                    "id": "frontend_model_app_session",
                    "label": "AppSession",
                    "source_file": r"frontend\lib\core\models\app_session.dart",
                    "domain_tag": "frontend-core",
                },
                {
                    "id": "frontend_service_auth",
                    "label": "AuthService",
                    "source_file": r"frontend\lib\features\auth\services\auth_service.dart",
                    "domain_tag": "frontend-core",
                },
                {
                    "id": "frontend_page_main",
                    "label": "MainShellPage",
                    "source_file": r"frontend\lib\main.dart",
                    "domain_tag": "frontend-core",
                },
                {
                    "id": "frontend_test_app_session",
                    "label": "AppSession",
                    "source_file": r"frontend\test\widgets\main_shell_page_test.dart",
                    "domain_tag": "tests",
                },
            ]
        }

        chain = graphify_navigation._build_supplementary_chain(
            graph=graph,
            obj_name="AppSession",
            main_node=graph["nodes"][0],
            node_map={n["id"]: n for n in graph["nodes"]},
            rules=self.rules,
        )

        self.assertIn("前端 Service", chain)
        self.assertIn("前端页面/Widget", chain)
        self.assertIn("测试覆盖", chain)


if __name__ == "__main__":
    unittest.main()
