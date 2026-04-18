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


class CombinedAuthScenarioSuiteUnitTest(unittest.TestCase):
    def test_combined_suite_uses_isolated_auth_and_readonly_token_pools(self) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        self.assertIn("pool-readonly", bundle.token_pools)
        self.assertIn("pool-auth-logout", bundle.token_pools)
        self.assertIn("pool-auth-password", bundle.token_pools)

        self.assertEqual(bundle.scenarios["messages-detail-1"].token_pool, "pool-readonly")
        self.assertEqual(bundle.scenarios["messages-list"].token_pool, "pool-readonly")
        self.assertEqual(bundle.scenarios["messages-read-all"].token_pool, "pool-readonly")
        self.assertEqual(bundle.scenarios["ui-page-catalog"].token_pool, "pool-readonly")

        self.assertEqual(bundle.scenarios["messages-announcements"].token_pool, "pool-admin")
        self.assertEqual(bundle.scenarios["messages-maintenance-run"].token_pool, "pool-admin")
        self.assertEqual(bundle.scenarios["auth-logout"].token_pool, "pool-auth-logout")
        self.assertEqual(bundle.scenarios["me-password-update"].token_pool, "pool-auth-password")

    def test_combined_suite_auth_login_and_password_update_use_valid_current_contract(
        self,
    ) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        auth_login = bundle.scenarios["auth-login"]
        self.assertEqual(auth_login.form_body["username"], "ltadm1")
        self.assertEqual(auth_login.form_body["password"], "Admin@123456")

        password_update = bundle.scenarios["me-password-update"]
        self.assertEqual(password_update.json_body["old_password"], "Admin@123456")
        self.assertEqual(
            password_update.json_body["confirm_password"],
            password_update.json_body["new_password"],
        )

    def test_combined_suite_registration_scenarios_use_current_contract(self) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        register = bundle.scenarios["auth-register"]
        self.assertEqual(register.path, "/api/v1/auth/register")
        self.assertEqual(register.json_body["account"], "nu{RANDOM_SHORT}")
        self.assertNotIn("username", register.json_body)
        self.assertEqual(register.success_statuses, {202})

        request_create = bundle.scenarios["auth-register-request-create"]
        self.assertEqual(request_create.path, "/api/v1/auth/register")
        self.assertEqual(request_create.json_body["account"], "rq{RANDOM_SHORT}")
        self.assertEqual(request_create.success_statuses, {202})

        request_detail = bundle.scenarios["auth-register-requests-detail"]
        self.assertEqual(
            request_detail.path,
            "/api/v1/auth/register-requests/{sample:registration_request_id}",
        )
        self.assertEqual(
            request_detail.sample_contract.runtime_samples,
            ["auth:runtime-registration-request-ready"],
        )

        request_approve = bundle.scenarios["auth-register-request-approve"]
        self.assertEqual(
            request_approve.path,
            "/api/v1/auth/register-requests/{sample:registration_request_id}/approve",
        )
        self.assertEqual(
            request_approve.sample_contract.runtime_samples,
            ["auth:runtime-registration-request-ready"],
        )

        request_reject = bundle.scenarios["auth-register-request-reject"]
        self.assertEqual(
            request_reject.path,
            "/api/v1/auth/register-requests/{sample:registration_request_id}/reject",
        )
        self.assertEqual(
            request_reject.sample_contract.runtime_samples,
            ["auth:runtime-registration-request-ready"],
        )

    def test_combined_suite_message_contract_uses_current_routes(self) -> None:
        bundle = _load_scenario_config_bundle(COMBINED_SUITE)

        self.assertNotIn("auth-refresh-token", bundle.scenarios)
        self.assertNotIn("production-order-events-export", bundle.scenarios)
        self.assertNotIn("quality-defect-analysis-create", bundle.scenarios)

        message_read = bundle.scenarios["messages-message-read"]
        self.assertEqual(
            message_read.path,
            "/api/v1/messages/{sample:readonly_message_id}/read",
        )
        self.assertEqual(
            message_read.sample_contract.runtime_samples,
            ["message:runtime-readonly-message-ready"],
        )

        message_create = bundle.scenarios["messages-message-create"]
        self.assertEqual(message_create.path, "/api/v1/messages/announcements")
        self.assertEqual(message_create.token_pool, "pool-admin")
        self.assertEqual(message_create.json_body["range_type"], "users")
        self.assertIn("user_ids", message_create.json_body)
        self.assertEqual(message_create.success_statuses, {200})

        announcements = bundle.scenarios["messages-announcements"]
        self.assertEqual(announcements.path, "/api/v1/messages/announcements")
        self.assertEqual(announcements.token_pool, "pool-admin")
        self.assertEqual(announcements.success_statuses, {200})

        bootstrap_admin = bundle.scenarios["auth-bootstrap-admin"]
        self.assertEqual(bootstrap_admin.path, "/api/v1/auth/bootstrap-admin")
        self.assertEqual(bootstrap_admin.success_statuses, {200})


if __name__ == "__main__":
    unittest.main()
