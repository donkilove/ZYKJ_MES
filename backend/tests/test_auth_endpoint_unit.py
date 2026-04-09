import sys
import unittest
from datetime import UTC, datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api.v1.endpoints import auth


class AuthEndpointUnitTest(unittest.TestCase):
    def test_login_success_uses_throttled_log_cleanup_helper(self) -> None:
        db = MagicMock()
        now = datetime(2026, 4, 9, 1, 0, tzinfo=UTC)
        user = SimpleNamespace(
            id=7,
            is_active=True,
            is_deleted=False,
            password_hash="hashed-password",
            must_change_password=False,
            last_login_at=None,
            last_login_ip=None,
            last_login_terminal=None,
        )
        session_row = SimpleNamespace(
            session_token_id="sid-1",
            login_time=now,
            expires_at=now.replace(hour=2),
        )
        form_data = SimpleNamespace(username="demo", password="Pwd@123")
        request = SimpleNamespace(
            client=SimpleNamespace(host="127.0.0.1"),
            headers={"user-agent": "pytest"},
        )

        with (
            patch.object(auth, "get_user_by_username", return_value=user),
            patch.object(auth, "verify_password_cached", return_value=True),
            patch.object(auth, "create_or_reuse_user_session", return_value=session_row),
            patch.object(auth, "should_record_success_login", return_value=True),
            patch.object(auth, "create_login_log") as create_login_log,
            patch.object(auth, "cleanup_expired_login_logs_if_due") as cleanup_logs,
            patch.object(auth, "remember_active_session_token") as remember_active,
            patch.object(auth, "touch_user") as touch_user,
            patch.object(auth, "create_access_token", return_value="token-1"),
        ):
            result = auth.login(form_data=form_data, request=request, db=db)

        cleanup_logs.assert_called_once_with(db)
        create_login_log.assert_called_once()
        db.commit.assert_called_once()
        remember_active.assert_called_once_with(
            "sid-1",
            expires_at=session_row.expires_at,
        )
        touch_user.assert_called_once_with(7)
        self.assertEqual(result.data.access_token, "token-1")
        self.assertEqual(user.last_login_at, now)

    def test_get_current_login_user_reads_stage_name_locally(self) -> None:
        db = MagicMock()
        stage_result = MagicMock()
        stage_result.scalar_one_or_none.return_value = "装配段"
        db.execute.return_value = stage_result
        role = SimpleNamespace(code="operator", name="操作工")
        current_user = SimpleNamespace(
            id=7,
            username="demo",
            full_name="Demo User",
            roles=[role],
            stage_id=3,
        )

        result = auth.get_current_login_user(current_user=current_user, db=db)

        db.execute.assert_called_once()
        stage_result.scalar_one_or_none.assert_called_once_with()
        self.assertEqual(result.data.id, 7)
        self.assertEqual(result.data.role_code, "operator")
        self.assertEqual(result.data.stage_name, "装配段")


if __name__ == "__main__":
    unittest.main()
