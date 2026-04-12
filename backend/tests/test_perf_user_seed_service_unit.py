import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.role import Role
from app.services import perf_user_seed_service


class _FakeScalarResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def first(self):
        return self._rows[0] if self._rows else None

    def all(self):
        return self._rows


class PerfUserSeedServiceUnitTest(unittest.TestCase):
    def test_default_pool_specs_generate_short_usernames(self) -> None:
        accounts = perf_user_seed_service.build_perf_user_account_specs(
            perf_user_seed_service.DEFAULT_PERF_USER_POOL_SPECS
        )

        self.assertGreaterEqual(len(accounts), 6)
        self.assertTrue(all(len(item.username) <= 10 for item in accounts))
        self.assertIn("pool-production", {item.pool_name for item in accounts})
        self.assertIn("pool-quality", {item.pool_name for item in accounts})

    def test_build_perf_user_account_specs_rejects_too_long_generated_username(self) -> None:
        pool_specs = [
            perf_user_seed_service.PerfUserPoolSpec(
                pool_name="pool-bad",
                role_code=ROLE_PRODUCTION_ADMIN,
                username_prefix="verylongname",
                count=1,
            )
        ]

        with self.assertRaisesRegex(ValueError, "用户名长度"):
            perf_user_seed_service.build_perf_user_account_specs(pool_specs)

    def test_seed_perf_capacity_users_requires_enabled_stage_for_operator_pool(self) -> None:
        db = MagicMock()
        pool_specs = [
            perf_user_seed_service.PerfUserPoolSpec(
                pool_name="pool-operator",
                role_code=ROLE_OPERATOR,
                username_prefix="ltopr",
                count=1,
                requires_stage=True,
            )
        ]

        with patch.object(
            perf_user_seed_service,
            "get_roles_by_codes",
            return_value=([SimpleNamespace(code=ROLE_OPERATOR, is_enabled=True)], []),
        ):
            db.execute.return_value = _FakeScalarResult([])
            with self.assertRaisesRegex(ValueError, "operator.*阶段"):
                perf_user_seed_service.seed_perf_capacity_users(
                    db,
                    password="Admin@123456",
                    pool_specs=pool_specs,
                )

    def test_seed_perf_capacity_users_creates_missing_users(self) -> None:
        db = MagicMock()
        production_role = Role(code=ROLE_PRODUCTION_ADMIN, name="生产管理员")
        operator_role = Role(code=ROLE_OPERATOR, name="操作员")
        operator_stage = ProcessStage(id=7, code="stage-7", name="测试工序")
        operator_process = Process(
            id=11,
            code="proc-11",
            name="测试流程",
            stage_id=7,
        )
        pool_specs = [
            perf_user_seed_service.PerfUserPoolSpec(
                pool_name="pool-production",
                role_code=ROLE_PRODUCTION_ADMIN,
                username_prefix="ltprd",
                count=1,
            ),
            perf_user_seed_service.PerfUserPoolSpec(
                pool_name="pool-operator",
                role_code=ROLE_OPERATOR,
                username_prefix="ltopr",
                count=1,
                requires_stage=True,
            ),
        ]

        with (
            patch.object(
                perf_user_seed_service,
                "get_roles_by_codes",
                return_value=([production_role, operator_role], []),
            ),
            patch.object(
                perf_user_seed_service,
                "get_user_by_username",
                return_value=None,
            ),
        ):
            db.execute.side_effect = [
                _FakeScalarResult([operator_stage]),
                _FakeScalarResult([operator_process]),
            ]
            result = perf_user_seed_service.seed_perf_capacity_users(
                db,
                password="Admin@123456",
                pool_specs=pool_specs,
            )

        self.assertEqual(result.created_count, 2)
        self.assertEqual(result.updated_count, 0)
        self.assertEqual(sorted(result.usernames), ["ltopr1", "ltprd1"])
        self.assertEqual(db.add.call_count, 2)
        created_users = [call.args[0] for call in db.add.call_args_list]
        self.assertEqual(created_users[0].username, "ltprd1")
        self.assertEqual(created_users[0].roles, [production_role])
        self.assertEqual(created_users[1].username, "ltopr1")
        self.assertEqual(created_users[1].roles, [operator_role])
        self.assertEqual(created_users[1].stage_id, 7)
        self.assertEqual(created_users[1].processes, [operator_process])
        db.commit.assert_called_once()


if __name__ == "__main__":
    unittest.main()
