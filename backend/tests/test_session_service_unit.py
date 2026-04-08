import sys
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import session_service


class SessionServiceUnitTest(unittest.TestCase):
    def test_touch_session_throttles_when_interval_not_elapsed(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        row = SimpleNamespace(
            status="active",
            expires_at=now + timedelta(minutes=10),
            last_active_at=now - timedelta(seconds=10),
            logout_time=None,
        )
        db = MagicMock()

        with (
            patch.object(session_service, "get_session_by_token_id", return_value=row),
            patch.object(session_service, "_now_utc", return_value=now),
            patch.object(
                session_service.settings,
                "session_touch_min_interval_seconds",
                30,
            ),
        ):
            result_row, touched = session_service.touch_session_by_token_id(db, "sid-1")

        self.assertIs(result_row, row)
        self.assertFalse(touched)
        self.assertEqual(row.last_active_at, now - timedelta(seconds=10))
        db.flush.assert_not_called()

    def test_touch_session_updates_when_interval_elapsed(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        row = SimpleNamespace(
            status="active",
            expires_at=now + timedelta(minutes=10),
            last_active_at=now - timedelta(seconds=45),
            logout_time=None,
        )
        db = MagicMock()

        with (
            patch.object(session_service, "get_session_by_token_id", return_value=row),
            patch.object(session_service, "_now_utc", return_value=now),
            patch.object(
                session_service.settings,
                "session_touch_min_interval_seconds",
                30,
            ),
        ):
            result_row, touched = session_service.touch_session_by_token_id(db, "sid-2")

        self.assertIs(result_row, row)
        self.assertTrue(touched)
        self.assertEqual(row.last_active_at, now)
        db.flush.assert_called_once()

    def test_touch_session_marks_expired_when_session_has_timed_out(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        row = SimpleNamespace(
            status="active",
            expires_at=now - timedelta(seconds=1),
            last_active_at=now - timedelta(minutes=5),
            logout_time=None,
        )
        db = MagicMock()

        with (
            patch.object(session_service, "get_session_by_token_id", return_value=row),
            patch.object(session_service, "_now_utc", return_value=now),
        ):
            result_row, touched = session_service.touch_session_by_token_id(db, "sid-3")

        self.assertIs(result_row, row)
        self.assertTrue(touched)
        self.assertEqual(row.status, "expired")
        self.assertEqual(row.logout_time, now)
        db.flush.assert_called_once()


if __name__ == "__main__":
    unittest.main()
