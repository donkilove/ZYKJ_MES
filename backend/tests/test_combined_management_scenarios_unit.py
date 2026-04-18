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


class CombinedManagementScenarioSuiteUnitTest(unittest.TestCase):
    def test_combined_suite_user_admin_payloads_follow_current_schema(self) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        user_create = bundle.scenarios["users-user-create"]
        self.assertEqual(user_create.json_body["role_code"], "system_admin")
        self.assertEqual(user_create.json_body["username"], "u{RANDOM_SHORT}")

        user_update = bundle.scenarios["users-user-update"]
        self.assertEqual(user_update.json_body["role_code"], "system_admin")
        self.assertEqual(
            user_update.path,
            "/api/v1/users/{sample:runtime_user_id}",
        )
        self.assertEqual(
            user_update.sample_contract.runtime_samples,
            ["user:runtime-user-ready"],
        )

        user_enable = bundle.scenarios["users-user-enable"]
        self.assertEqual(user_enable.json_body["remark"], "perf enable")
        self.assertEqual(
            user_enable.path,
            "/api/v1/users/{sample:runtime_user_id}/enable",
        )
        self.assertEqual(
            user_enable.sample_contract.runtime_samples,
            ["user:runtime-user-ready"],
        )

        user_disable = bundle.scenarios["users-user-disable"]
        self.assertEqual(user_disable.json_body["remark"], "perf disable")
        self.assertEqual(
            user_disable.path,
            "/api/v1/users/{sample:runtime_user_id}/disable",
        )
        self.assertEqual(
            user_disable.sample_contract.runtime_samples,
            ["user:runtime-user-ready"],
        )

        reset_password = bundle.scenarios["users-user-reset-password"]
        self.assertEqual(reset_password.json_body["password"], "NewTest123")
        self.assertEqual(reset_password.json_body["remark"], "perf reset")
        self.assertEqual(
            reset_password.path,
            "/api/v1/users/{sample:runtime_user_id}/reset-password",
        )
        self.assertEqual(
            reset_password.sample_contract.runtime_samples,
            ["user:runtime-user-ready"],
        )

        user_delete = bundle.scenarios["users-user-delete"]
        self.assertEqual(user_delete.json_body["remark"], "perf delete")
        self.assertEqual(
            user_delete.path,
            "/api/v1/users/{sample:runtime_user_id}",
        )
        self.assertEqual(
            user_delete.sample_contract.runtime_samples,
            ["user:runtime-user-ready"],
        )

        user_restore = bundle.scenarios["users-user-restore"]
        self.assertEqual(user_restore.json_body["remark"], "perf restore")
        self.assertEqual(
            user_restore.path,
            "/api/v1/users/{sample:runtime_deleted_user_id}/restore",
        )
        self.assertEqual(
            user_restore.sample_contract.runtime_samples,
            ["user:runtime-deleted-user-ready"],
        )

        export_task = bundle.scenarios["users-export-task-create"]
        self.assertEqual(export_task.json_body["format"], "csv")
        self.assertEqual(export_task.json_body["deleted_scope"], "active")
        self.assertEqual(export_task.success_statuses, {200})

    def test_combined_suite_authz_and_admin_payloads_follow_current_schema(self) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        role_matrix = bundle.scenarios["authz-role-permission-matrix-update"]
        self.assertEqual(role_matrix.json_body["module_code"], "user")
        self.assertTrue(role_matrix.json_body["dry_run"])
        self.assertIn("role_items", role_matrix.json_body)

        hierarchy_preview = bundle.scenarios["authz-hierarchy-preview"]
        self.assertEqual(hierarchy_preview.json_body["module_code"], "user")
        self.assertIn("role_items", hierarchy_preview.json_body)

        role_permission_update = bundle.scenarios["authz-role-permissions-role-update"]
        self.assertEqual(
            role_permission_update.path,
            "/api/v1/authz/role-permissions/system_admin",
        )
        self.assertEqual(role_permission_update.json_body["module_code"], "user")
        self.assertEqual(role_permission_update.success_statuses, {410})

        hierarchy_role_update = bundle.scenarios["authz-hierarchy-role-config-update"]
        self.assertEqual(
            hierarchy_role_update.path,
            "/api/v1/authz/hierarchy/role-config/system_admin",
        )
        self.assertEqual(hierarchy_role_update.json_body["module_code"], "user")
        self.assertTrue(hierarchy_role_update.json_body["dry_run"])

        capability_role_update = bundle.scenarios["authz-capability-packs-role-config-update"]
        self.assertEqual(
            capability_role_update.path,
            "/api/v1/authz/capability-packs/role-config/system_admin",
        )
        self.assertEqual(capability_role_update.json_body["module_code"], "user")
        self.assertTrue(capability_role_update.json_body["dry_run"])

        legacy_permission_update = bundle.scenarios["authz-permission-update"]
        self.assertEqual(
            legacy_permission_update.path,
            "/api/v1/authz/role-permissions/system_admin",
        )
        self.assertEqual(legacy_permission_update.json_body["module_code"], "user")
        self.assertEqual(legacy_permission_update.success_statuses, {410})

        legacy_role_permission_update = bundle.scenarios["authz-role-permission-update"]
        self.assertEqual(
            legacy_role_permission_update.path,
            "/api/v1/authz/role-permissions/matrix",
        )
        self.assertEqual(legacy_role_permission_update.json_body["module_code"], "user")
        self.assertTrue(legacy_role_permission_update.json_body["dry_run"])
        self.assertIn("role_items", legacy_role_permission_update.json_body)

        legacy_hierarchy_update = bundle.scenarios["authz-hierarchy-config-update"]
        self.assertEqual(
            legacy_hierarchy_update.path,
            "/api/v1/authz/hierarchy/role-config/system_admin",
        )
        self.assertEqual(legacy_hierarchy_update.json_body["module_code"], "user")
        self.assertTrue(legacy_hierarchy_update.json_body["dry_run"])

        capability_pack_create = bundle.scenarios["authz-capability-pack-create"]
        self.assertEqual(
            capability_pack_create.path,
            "/api/v1/authz/capability-packs/role-config/system_admin",
        )
        self.assertEqual(capability_pack_create.json_body["module_code"], "user")
        self.assertTrue(capability_pack_create.json_body["dry_run"])

        capability_pack_update = bundle.scenarios["authz-capability-pack-update"]
        self.assertEqual(
            capability_pack_update.path,
            "/api/v1/authz/capability-packs/role-config/system_admin",
        )
        self.assertEqual(capability_pack_update.json_body["module_code"], "user")
        self.assertTrue(capability_pack_update.json_body["dry_run"])

        capability_pack_role_update = bundle.scenarios["authz-capability-pack-role-config-update"]
        self.assertEqual(
            capability_pack_role_update.path,
            "/api/v1/authz/capability-packs/role-config/system_admin",
        )
        self.assertEqual(capability_pack_role_update.json_body["module_code"], "user")
        self.assertTrue(capability_pack_role_update.json_body["dry_run"])

        batch_apply = bundle.scenarios["authz-capability-packs-batch-apply"]
        self.assertEqual(batch_apply.path, "/api/v1/authz/capability-packs/batch-apply")
        self.assertEqual(batch_apply.json_body["module_code"], "user")
        self.assertIn("role_items", batch_apply.json_body)
        self.assertIn("remark", batch_apply.json_body)

        approve_request = bundle.scenarios["auth-register-request-approve"]
        self.assertEqual(
            approve_request.json_body["account"],
            "{sample:registration_request_account}",
        )
        self.assertEqual(approve_request.json_body["role_code"], "system_admin")

        reject_request = bundle.scenarios["auth-register-request-reject"]
        self.assertEqual(reject_request.json_body["reason"], "Rejected")

        announcements = bundle.scenarios["messages-announcements"]
        self.assertEqual(announcements.json_body["range_type"], "users")
        self.assertEqual(announcements.json_body["user_ids"], [1])

        role_update = bundle.scenarios["roles-role-update"]
        self.assertEqual(
            role_update.path,
            "/api/v1/roles/{sample:runtime_role_id}",
        )
        self.assertEqual(
            role_update.json_body["code"],
            "{sample:runtime_role_code}",
        )
        self.assertEqual(
            role_update.sample_contract.runtime_samples,
            ["user:runtime-role-ready"],
        )

        for scenario_name in ("roles-role-enable", "roles-role-disable", "roles-role-delete"):
            scenario = bundle.scenarios[scenario_name]
            self.assertIn("{sample:runtime_role_id}", scenario.path)
            self.assertEqual(
                scenario.sample_contract.runtime_samples,
                ["user:runtime-role-ready"],
            )

        force_offline = bundle.scenarios["sessions-force-offline"]
        self.assertEqual(
            force_offline.json_body["session_token_id"],
            "{sample:runtime_session_token_id}",
        )
        self.assertEqual(
            force_offline.sample_contract.runtime_samples,
            ["user:runtime-session-user-ready"],
        )

        process_create = bundle.scenarios["processes-process-create"]
        self.assertEqual(process_create.path, "/api/v1/processes")
        self.assertEqual(
            process_create.json_body,
            {
                "code": "{sample:runtime_process_code}",
                "name": "测试工序",
                "stage_id": "{sample:stage_id}",
            },
        )
        self.assertEqual(
            process_create.sample_contract.runtime_samples,
            ["order:create-ready", "craft:process-create-ready"],
        )

        process_update = bundle.scenarios["processes-process-update"]
        self.assertEqual(
            process_update.path,
            "/api/v1/processes/{sample:runtime_process_id}",
        )
        self.assertEqual(
            process_update.json_body,
            {
                "code": "{sample:runtime_process_code}",
                "name": "更新后的工序",
                "stage_id": "{sample:stage_id}",
                "is_enabled": True,
            },
        )
        self.assertEqual(
            process_update.sample_contract.runtime_samples,
            ["order:create-ready", "craft:process-runtime-ready"],
        )

        system_master_create = bundle.scenarios["craft-system-master-template-create"]
        self.assertEqual(
            system_master_create.sample_contract.runtime_samples,
            ["order:create-ready"],
        )

        system_master_update = bundle.scenarios["craft-system-master-template-update"]
        self.assertEqual(
            system_master_update.sample_contract.runtime_samples,
            ["order:create-ready", "craft:system-master-ready"],
        )


if __name__ == "__main__":
    unittest.main()
