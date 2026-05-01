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
from app.core import security


class AuthEndpointUnitTest(unittest.TestCase):
    def test_mobile_scan_review_login_uses_seven_day_expiry(self) -> None:
        db = MagicMock()
        now = datetime(2026, 4, 26, 9, 0, tzinfo=UTC)
        user = SimpleNamespace(
            id=21,
            is_active=True,
            is_deleted=False,
            password_hash="hashed-password",
            must_change_password=False,
            last_login_at=None,
            last_login_ip=None,
            last_login_terminal=None,
        )
        session_row = SimpleNamespace(
            session_token_id="sid-scan-mobile",
            login_time=now,
            expires_at=now.replace(day=27),
        )
        form_data = SimpleNamespace(username="scan-user", password="Pwd@123")
        request = SimpleNamespace(
            client=SimpleNamespace(host="192.168.1.88"),
            headers={"user-agent": "pytest-mobile"},
        )

        with (
            patch.object(auth, "get_user_by_username", return_value=user),
            patch.object(auth, "verify_password_cached", return_value=True),
            patch.object(auth, "rehash_password_if_needed", return_value=None),
            patch.object(auth, "create_or_reuse_user_session", return_value=session_row),
            patch.object(auth, "should_record_success_login", return_value=False),
            patch.object(auth, "create_login_log"),
            patch.object(auth, "cleanup_expired_login_logs_if_due"),
            patch.object(auth, "remember_active_session_token"),
            patch.object(auth, "touch_user"),
            patch.object(auth, "create_access_token", return_value="token-mobile") as create_token,
        ):
            result = auth.mobile_scan_review_login(
                form_data=form_data,
                request=request,
                db=db,
            )

        create_token.assert_called_once_with(
            subject="21",
            extra_claims={"sid": "sid-scan-mobile", "login_type": "mobile_scan"},
            expires_minutes=10080,
        )
        self.assertEqual(result.data.access_token, "token-mobile")
        self.assertEqual(result.data.expires_in, 10080 * 60)

    def test_create_access_token_keeps_default_expiry_when_not_overridden(self) -> None:
        with patch.object(security, "settings", autospec=True) as fake_settings:
            fake_settings.jwt_expire_minutes = 120
            fake_settings.jwt_secret_key = "secret"
            fake_settings.jwt_algorithm = "HS256"
            with patch.object(security, "ensure_runtime_settings_secure"):
                token = security.create_access_token(subject="1")

        payload = security.jwt.get_unverified_claims(token)
        self.assertEqual(payload["sub"], "1")

    def test_login_truncates_terminal_info_for_mobile_user_agent(self) -> None:
        db = MagicMock()
        now = datetime(2026, 4, 26, 12, 30, tzinfo=UTC)
        user = SimpleNamespace(
            id=11,
            is_active=True,
            is_deleted=False,
            password_hash="hashed-password",
            must_change_password=False,
            last_login_at=None,
            last_login_ip=None,
            last_login_terminal=None,
        )
        session_row = SimpleNamespace(
            session_token_id="sid-mobile",
            login_time=now,
            expires_at=now.replace(hour=14),
            terminal_info=None,
        )
        long_user_agent = "MicroMessenger/" + ("A" * 400)
        form_data = SimpleNamespace(username="mobile", password="Pwd@123")
        request = SimpleNamespace(
            client=SimpleNamespace(host="192.168.1.88"),
            headers={"user-agent": long_user_agent},
        )

        with (
            patch.object(auth, "get_user_by_username", return_value=user),
            patch.object(auth, "verify_password_cached", return_value=True),
            patch.object(auth, "rehash_password_if_needed", return_value=None),
            patch.object(auth, "create_or_reuse_user_session", return_value=session_row),
            patch.object(auth, "should_record_success_login", return_value=True),
            patch.object(auth, "create_login_log") as create_login_log,
            patch.object(auth, "cleanup_expired_login_logs_if_due"),
            patch.object(auth, "remember_active_session_token"),
            patch.object(auth, "touch_user"),
            patch.object(auth, "create_access_token", return_value="token-mobile"),
        ):
            result = auth.login(form_data=form_data, request=request, db=db)

        self.assertEqual(result.data.access_token, "token-mobile")
        self.assertEqual(len(user.last_login_terminal), 255)
        self.assertTrue(user.last_login_terminal.startswith("MicroMessenger/"))
        create_login_log.assert_called_once()
        self.assertEqual(
            create_login_log.call_args.kwargs["terminal_info"],
            user.last_login_terminal,
        )

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
            patch.object(auth, "rehash_password_if_needed", return_value=None),
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

    def test_login_rehashes_password_when_needed(self) -> None:
        db = MagicMock()
        from datetime import UTC, datetime
        now = datetime(2026, 4, 19, 10, 0, tzinfo=UTC)
        user = SimpleNamespace(
            id=9,
            is_active=True,
            is_deleted=False,
            password_hash="old-hash-rounds12",
            must_change_password=False,
            last_login_at=None,
            last_login_ip=None,
            last_login_terminal=None,
        )
        session_row = SimpleNamespace(
            session_token_id="sid-2",
            login_time=now,
            expires_at=now.replace(hour=12),
        )
        form_data = SimpleNamespace(username="demo2", password="Pwd@123")
        request = SimpleNamespace(
            client=SimpleNamespace(host="127.0.0.1"),
            headers={"user-agent": "pytest"},
        )

        with (
            patch.object(auth, "get_user_by_username", return_value=user),
            patch.object(auth, "verify_password_cached", return_value=True),
            patch.object(auth, "rehash_password_if_needed", return_value="new-hash-rounds10"),
            patch.object(auth, "create_or_reuse_user_session", return_value=session_row),
            patch.object(auth, "should_record_success_login", return_value=False),
            patch.object(auth, "create_login_log"),
            patch.object(auth, "cleanup_expired_login_logs_if_due"),
            patch.object(auth, "remember_active_session_token"),
            patch.object(auth, "touch_user"),
            patch.object(auth, "create_access_token", return_value="token-2"),
        ):
            auth.login(form_data=form_data, request=request, db=db)

        self.assertEqual(user.password_hash, "new-hash-rounds10")

    def test_login_skips_rehash_when_not_needed(self) -> None:
        db = MagicMock()
        from datetime import UTC, datetime
        now = datetime(2026, 4, 19, 10, 0, tzinfo=UTC)
        user = SimpleNamespace(
            id=10,
            is_active=True,
            is_deleted=False,
            password_hash="current-hash-rounds10",
            must_change_password=False,
            last_login_at=None,
            last_login_ip=None,
            last_login_terminal=None,
        )
        session_row = SimpleNamespace(
            session_token_id="sid-3",
            login_time=now,
            expires_at=now.replace(hour=12),
        )
        form_data = SimpleNamespace(username="demo3", password="Pwd@123")
        request = SimpleNamespace(
            client=SimpleNamespace(host="127.0.0.1"),
            headers={"user-agent": "pytest"},
        )
        original_hash = user.password_hash

        with (
            patch.object(auth, "get_user_by_username", return_value=user),
            patch.object(auth, "verify_password_cached", return_value=True),
            patch.object(auth, "rehash_password_if_needed", return_value=None),
            patch.object(auth, "create_or_reuse_user_session", return_value=session_row),
            patch.object(auth, "should_record_success_login", return_value=False),
            patch.object(auth, "create_login_log"),
            patch.object(auth, "cleanup_expired_login_logs_if_due"),
            patch.object(auth, "remember_active_session_token"),
            patch.object(auth, "touch_user"),
            patch.object(auth, "create_access_token", return_value="token-3"),
        ):
            auth.login(form_data=form_data, request=request, db=db)

        self.assertEqual(user.password_hash, original_hash)

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
