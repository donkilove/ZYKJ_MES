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
    def setUp(self) -> None:
        session_service._LOGIN_LOG_CLEANUP_NEXT_AT = 0.0
        session_service._SESSION_CLEANUP_NEXT_AT = 0.0
        session_service._SESSION_ACTIVE_LOCAL_CACHE.clear()
        session_service._SUCCESS_LOGIN_LOG_LOCAL_CACHE.clear()
        session_service._PRIMARY_ROLE_META_LOCAL_CACHE.clear()

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

    def test_touch_session_uses_hard_floor_of_thirty_seconds(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        row = SimpleNamespace(
            status="active",
            expires_at=now + timedelta(minutes=10),
            last_active_at=now - timedelta(seconds=20),
            logout_time=None,
        )
        db = MagicMock()

        with (
            patch.object(session_service, "get_session_by_token_id", return_value=row),
            patch.object(session_service, "_now_utc", return_value=now),
            patch.object(
                session_service.settings,
                "session_touch_min_interval_seconds",
                5,
            ),
        ):
            result_row, touched = session_service.touch_session_by_token_id(db, "sid-4")

        self.assertIs(result_row, row)
        self.assertFalse(touched)
        db.flush.assert_not_called()

    def test_touch_session_uses_local_cache_when_allowed(self) -> None:
        db = MagicMock()

        with (
            patch.object(session_service, "_get_cached_active_session", return_value=True),
            patch.object(session_service, "get_session_by_token_id") as get_session,
        ):
            result_row, touched = session_service.touch_session_by_token_id(
                db,
                "sid-cached",
                allow_cached_active=True,
            )

        self.assertEqual(result_row.status, "active")
        self.assertFalse(touched)
        get_session.assert_not_called()

    def test_create_user_session_does_not_flush_immediately(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        db = MagicMock()
        user = SimpleNamespace(id=7)

        with (
            patch.object(session_service, "_now_utc", return_value=now),
            patch.object(session_service, "_session_expire_at", return_value=now + timedelta(hours=1)),
        ):
            row = session_service.create_user_session(
                db,
                user=user,
                ip_address="127.0.0.1",
                terminal_info="pytest",
            )

        self.assertEqual(row.user_id, 7)
        self.assertTrue(row.session_token_id)
        db.add.assert_called_once()
        db.flush.assert_not_called()

    def test_create_login_log_does_not_flush_immediately(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        db = MagicMock()

        with patch.object(session_service, "_now_utc", return_value=now):
            row = session_service.create_login_log(
                db,
                username="demo",
                user_id=7,
                success=True,
                ip_address="127.0.0.1",
                terminal_info="pytest",
                session_token_id="sid-1",
            )

        self.assertEqual(row.username, "demo")
        self.assertEqual(row.session_token_id, "sid-1")
        db.add.assert_called_once()
        db.flush.assert_not_called()

    def test_create_or_reuse_user_session_reuses_latest_active_row(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        db = MagicMock()
        user = SimpleNamespace(id=7)
        existing_row = SimpleNamespace(
            session_token_id="sid-existing",
            login_time=now - timedelta(minutes=3),
            last_active_at=now - timedelta(minutes=1),
            expires_at=now + timedelta(minutes=10),
            login_ip="127.0.0.1",
            terminal_info="pytest",
        )

        with (
            patch.object(
                session_service,
                "get_reusable_active_session",
                return_value=existing_row,
            ),
            patch.object(session_service, "_now_utc", return_value=now),
            patch.object(
                session_service,
                "_session_expire_at",
                return_value=now + timedelta(hours=1),
            ),
        ):
            row = session_service.create_or_reuse_user_session(
                db,
                user=user,
                ip_address="127.0.0.1",
                terminal_info="pytest",
            )

        self.assertIs(row, existing_row)
        self.assertEqual(row.login_time, now)
        self.assertEqual(row.last_active_at, now)
        self.assertEqual(row.expires_at, now + timedelta(hours=1))
        db.add.assert_not_called()

    def test_should_record_success_login_throttles_same_user_context(self) -> None:
        with patch.object(
            session_service.time,
            "monotonic",
            side_effect=[10.0, 15.0, 71.0],
        ):
            first = session_service.should_record_success_login(
                user_id=7,
                ip_address="127.0.0.1",
                terminal_info="pytest",
            )
            second = session_service.should_record_success_login(
                user_id=7,
                ip_address="127.0.0.1",
                terminal_info="pytest",
            )
            third = session_service.should_record_success_login(
                user_id=7,
                ip_address="127.0.0.1",
                terminal_info="pytest",
            )

        self.assertTrue(first)
        self.assertFalse(second)
        self.assertTrue(third)

    def test_cleanup_expired_login_logs_if_due_throttles_repeated_calls(self) -> None:
        db = MagicMock()

        with (
            patch.object(session_service.time, "monotonic", side_effect=[10.0, 15.0]),
            patch.object(session_service, "delete_expired_login_logs", return_value=3) as cleanup,
        ):
            first = session_service.cleanup_expired_login_logs_if_due(
                db,
                min_interval_seconds=30,
            )
            second = session_service.cleanup_expired_login_logs_if_due(
                db,
                min_interval_seconds=30,
            )

        self.assertEqual(first, 3)
        self.assertEqual(second, 0)
        cleanup.assert_called_once_with(db)

    def test_cleanup_expired_sessions_if_due_throttles_repeated_calls(self) -> None:
        db = MagicMock()

        with (
            patch.object(session_service.time, "monotonic", side_effect=[10.0, 15.0]),
            patch.object(session_service, "cleanup_expired_sessions", return_value=2) as cleanup,
        ):
            first = session_service.cleanup_expired_sessions_if_due(
                db,
                min_interval_seconds=30,
            )
            second = session_service.cleanup_expired_sessions_if_due(
                db,
                min_interval_seconds=30,
            )

        self.assertEqual(first, 2)
        self.assertEqual(second, 0)
        cleanup.assert_called_once_with(db)

    def test_get_user_current_session_uses_throttled_cleanup(self) -> None:
        db = MagicMock()
        session_row = SimpleNamespace(session_token_id="sid-1")

        with (
            patch.object(session_service, "cleanup_expired_sessions_if_due") as cleanup,
            patch.object(
                session_service,
                "get_session_by_token_id",
                return_value=session_row,
            ) as get_by_sid,
        ):
            row = session_service.get_user_current_session(db, session_token_id="sid-1")

        self.assertIs(row, session_row)
        cleanup.assert_called_once_with(db)
        get_by_sid.assert_called_once_with(db, "sid-1")

    def test_get_current_session_projection_returns_lightweight_projection(self) -> None:
        db = MagicMock()
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        execute_result = MagicMock()
        execute_result.mappings.return_value.first.return_value = {
            "session_token_id": "sid-1",
            "user_id": 7,
            "login_time": now - timedelta(minutes=3),
            "last_active_at": now - timedelta(seconds=10),
            "expires_at": now + timedelta(minutes=10),
            "status": "active",
        }
        db.execute.return_value = execute_result

        row = session_service.get_current_session_projection(db, session_token_id="sid-1")

        self.assertIsInstance(row, session_service.CurrentSessionProjection)
        assert row is not None
        self.assertEqual(row.session_token_id, "sid-1")
        self.assertEqual(row.user_id, 7)
        self.assertEqual(row.status, "active")

    def test_touch_session_caps_cache_ttl_to_remaining_lifetime(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        row = SimpleNamespace(
            status="active",
            expires_at=now + timedelta(seconds=4),
            last_active_at=now - timedelta(seconds=60),
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
            patch.object(session_service, "remember_active_session_token") as remember,
        ):
            result_row, touched = session_service.touch_session_by_token_id(
                db,
                "sid-remaining",
            )

        self.assertIs(result_row, row)
        self.assertTrue(touched)
        self.assertEqual(remember.call_count, 1)
        ttl_seconds = remember.call_args.kwargs["ttl_seconds"]
        self.assertLessEqual(ttl_seconds, 4)
        self.assertGreaterEqual(ttl_seconds, 1)

    def test_list_online_sessions_returns_projection_payload(self) -> None:
        db = MagicMock()
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        total_result = MagicMock()
        total_result.scalar_one.return_value = 1
        rows_result = MagicMock()
        rows_result.mappings.return_value.all.return_value = [
            {
                "session_id": 11,
                "session_token_id": "sid-11",
                "session_user_id": 7,
                "login_time": now - timedelta(minutes=3),
                "last_active_at": now - timedelta(seconds=15),
                "expires_at": now + timedelta(minutes=20),
                "login_ip": "127.0.0.1",
                "terminal_info": "pytest",
                "session_status": "active",
                "username": "demo",
                "stage_id": 3,
                "stage_name": "裁剪段",
            }
        ]
        db.execute.side_effect = [total_result, rows_result]

        with (
            patch.object(session_service, "cleanup_expired_sessions_if_due") as cleanup,
            patch.object(
                session_service,
                "_list_primary_role_meta_by_user_ids",
                return_value={7: ("operator", "操作员")},
            ) as list_roles,
        ):
            total, rows = session_service.list_online_sessions(
                db,
                page=1,
                page_size=20,
                keyword="demo",
                status_filter="active",
            )

        self.assertEqual(total, 1)
        self.assertEqual(len(rows), 1)
        self.assertIsInstance(rows[0], session_service.OnlineSessionProjection)
        self.assertEqual(rows[0].id, 11)
        self.assertEqual(rows[0].session_token_id, "sid-11")
        self.assertEqual(rows[0].user_id, 7)
        self.assertEqual(rows[0].username, "demo")
        self.assertEqual(rows[0].role_code, "operator")
        self.assertEqual(rows[0].role_name, "操作员")
        self.assertEqual(rows[0].stage_id, 3)
        self.assertEqual(rows[0].stage_name, "裁剪段")
        self.assertEqual(rows[0].ip_address, "127.0.0.1")
        self.assertEqual(rows[0].terminal_info, "pytest")
        self.assertEqual(rows[0].status, "active")
        cleanup.assert_called_once_with(db)
        list_roles.assert_called_once_with(db, [7])
        self.assertEqual(db.execute.call_count, 2)

    def test_list_online_sessions_projection_allows_empty_role_and_stage(self) -> None:
        db = MagicMock()
        now = datetime(2026, 4, 8, 12, 0, tzinfo=UTC)
        total_result = MagicMock()
        total_result.scalar_one.return_value = 1
        rows_result = MagicMock()
        rows_result.mappings.return_value.all.return_value = [
            {
                "session_id": 21,
                "session_token_id": "sid-21",
                "session_user_id": 9,
                "login_time": now - timedelta(minutes=5),
                "last_active_at": now - timedelta(seconds=20),
                "expires_at": now + timedelta(minutes=10),
                "login_ip": None,
                "terminal_info": None,
                "session_status": "active",
                "username": "no-role-user",
                "stage_id": None,
                "stage_name": None,
            }
        ]
        db.execute.side_effect = [total_result, rows_result]

        with (
            patch.object(session_service, "cleanup_expired_sessions_if_due"),
            patch.object(
                session_service,
                "_list_primary_role_meta_by_user_ids",
                return_value={},
            ) as list_roles,
        ):
            _, rows = session_service.list_online_sessions(
                db,
                page=1,
                page_size=20,
            )

        self.assertEqual(len(rows), 1)
        self.assertIsNone(rows[0].role_code)
        self.assertIsNone(rows[0].role_name)
        self.assertIsNone(rows[0].stage_id)
        self.assertIsNone(rows[0].stage_name)
        list_roles.assert_called_once_with(db, [9])

    def test_list_primary_role_meta_by_user_ids_uses_local_cache(self) -> None:
        db = MagicMock()
        db.execute.return_value.all.return_value = [(7, "operator", "操作员")]

        with patch.object(session_service.time, "monotonic", side_effect=[10.0, 11.0]):
            first = session_service._list_primary_role_meta_by_user_ids(db, [7, 7])
            second = session_service._list_primary_role_meta_by_user_ids(db, [7])

        self.assertEqual(first, {7: ("operator", "操作员")})
        self.assertEqual(second, {7: ("operator", "操作员")})
        db.execute.assert_called_once()


if __name__ == "__main__":
    unittest.main()
