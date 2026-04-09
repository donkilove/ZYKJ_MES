import importlib
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core import config as config_module
from app.db import session as session_module


class DbSessionConfigUnitTest(unittest.TestCase):
    def tearDown(self) -> None:
        importlib.reload(session_module)

    def test_non_sqlite_engine_applies_explicit_pool_budget(self) -> None:
        fake_settings = SimpleNamespace(
            database_url="postgresql+psycopg2://demo:demo@127.0.0.1:5432/demo",
            db_pool_size=6,
            db_max_overflow=4,
            db_pool_timeout_seconds=5,
            db_pool_recycle_seconds=1800,
        )

        with (
            patch.object(config_module, "settings", fake_settings),
            patch("sqlalchemy.create_engine") as create_engine_mock,
        ):
            importlib.reload(session_module)

        _, kwargs = create_engine_mock.call_args
        self.assertEqual(kwargs["pool_size"], 6)
        self.assertEqual(kwargs["max_overflow"], 4)
        self.assertEqual(kwargs["pool_timeout"], 5)
        self.assertEqual(kwargs["pool_recycle"], 1800)
        self.assertTrue(kwargs["pool_pre_ping"])
        self.assertTrue(kwargs["future"])

    def test_sqlite_engine_skips_queue_pool_specific_kwargs(self) -> None:
        fake_settings = SimpleNamespace(
            database_url="sqlite:///./test.db",
            db_pool_size=6,
            db_max_overflow=4,
            db_pool_timeout_seconds=5,
            db_pool_recycle_seconds=1800,
        )

        with (
            patch.object(config_module, "settings", fake_settings),
            patch("sqlalchemy.create_engine") as create_engine_mock,
        ):
            importlib.reload(session_module)

        _, kwargs = create_engine_mock.call_args
        self.assertNotIn("pool_size", kwargs)
        self.assertNotIn("max_overflow", kwargs)
        self.assertNotIn("pool_timeout", kwargs)
        self.assertNotIn("pool_recycle", kwargs)
        self.assertTrue(kwargs["pool_pre_ping"])
        self.assertTrue(kwargs["future"])


if __name__ == "__main__":
    unittest.main()
