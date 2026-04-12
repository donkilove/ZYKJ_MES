import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.models.role import Role
from app.services import bootstrap_seed_service


class _FakeScalarResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def all(self):
        return self._rows


class BootstrapSeedServiceUnitTest(unittest.TestCase):
    def test_ensure_roles_reenables_disabled_builtin_role(self) -> None:
        db = MagicMock()
        disabled_system_admin = Role(
            code=ROLE_SYSTEM_ADMIN,
            name="旧系统管理员",
            is_builtin=False,
            is_enabled=False,
            is_deleted=True,
            role_type="custom",
        )
        db.execute.return_value = _FakeScalarResult([disabled_system_admin])

        roles_by_code = bootstrap_seed_service._ensure_roles(db)

        repaired = roles_by_code[ROLE_SYSTEM_ADMIN]
        self.assertTrue(repaired.is_builtin)
        self.assertTrue(repaired.is_enabled)
        self.assertFalse(repaired.is_deleted)
        self.assertEqual(repaired.role_type, "builtin")


if __name__ == "__main__":
    unittest.main()
