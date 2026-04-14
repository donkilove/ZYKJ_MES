import sys
import unittest
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.bootstrap import startup_bootstrap


class StartupBootstrapUnitTest(unittest.TestCase):
    def test_run_startup_bootstrap_rejects_insecure_admin_password(self) -> None:
        with (
            patch.object(startup_bootstrap.settings, "bootstrap_on_startup", True),
            patch.object(
                startup_bootstrap.settings,
                "bootstrap_admin_password",
                "Admin@123456",
            ),
            patch.object(startup_bootstrap, "ensure_database_exists") as ensure_database_exists,
            patch.object(startup_bootstrap, "run_alembic_upgrade") as run_alembic_upgrade,
            patch.object(startup_bootstrap, "seed_startup_data") as seed_startup_data,
        ):
            with self.assertRaisesRegex(ValueError, "管理员"):
                startup_bootstrap.run_startup_bootstrap()

        ensure_database_exists.assert_not_called()
        run_alembic_upgrade.assert_not_called()
        seed_startup_data.assert_not_called()


if __name__ == "__main__":
    unittest.main()
