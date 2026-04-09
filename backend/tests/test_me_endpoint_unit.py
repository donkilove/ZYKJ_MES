import json
import sys
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from fastapi.responses import Response


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api.v1.endpoints import me


class MeEndpointUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        me._ME_SESSION_RESPONSE_CACHE.clear()

    def tearDown(self) -> None:
        me._ME_SESSION_RESPONSE_CACHE.clear()

    def test_get_my_profile_reads_stage_name_locally(self) -> None:
        db = MagicMock()
        stage_result = MagicMock()
        stage_result.scalar_one_or_none.return_value = "装配段"
        db.execute.return_value = stage_result
        now = datetime.now(UTC)
        role = SimpleNamespace(code="operator", name="操作工")
        current_user = SimpleNamespace(
            id=7,
            username="demo",
            full_name="Demo User",
            roles=[role],
            stage_id=3,
            is_active=True,
            created_at=now,
            last_login_at=now,
            last_login_ip="127.0.0.1",
            password_changed_at=now,
        )

        result = me.get_my_profile(current_user=current_user, db=db)

        db.execute.assert_called_once()
        stage_result.scalar_one_or_none.assert_called_once_with()
        self.assertEqual(result.data.id, 7)
        self.assertEqual(result.data.role_code, "operator")
        self.assertEqual(result.data.stage_name, "装配段")

    def test_get_my_session_rejects_invalid_token(self) -> None:
        db = MagicMock()

        with (
            patch.object(me, "decode_access_token", side_effect=ValueError("bad token")),
            patch.object(me, "get_current_session_projection") as get_current_session_projection,
        ):
            with self.assertRaises(HTTPException) as context:
                me.get_my_session(token="invalid", db=db)

        self.assertEqual(context.exception.status_code, 401)
        get_current_session_projection.assert_not_called()

    def test_get_my_session_rejects_missing_sid(self) -> None:
        db = MagicMock()

        with (
            patch.object(me, "decode_access_token", return_value={"sub": "7"}),
            patch.object(me, "get_current_session_projection") as get_current_session_projection,
        ):
            with self.assertRaises(HTTPException) as context:
                me.get_my_session(token="token", db=db)

        self.assertEqual(context.exception.status_code, 404)
        get_current_session_projection.assert_not_called()

    def test_get_my_session_rejects_when_session_mismatch(self) -> None:
        db = MagicMock()
        session_row = SimpleNamespace(
            user_id=8,
            status="active",
            expires_at=datetime.now(UTC) + timedelta(minutes=10),
        )

        with (
            patch.object(me, "decode_access_token", return_value={"sub": "7", "sid": "sid-1"}),
            patch.object(me, "get_current_session_projection", return_value=session_row),
        ):
            with self.assertRaises(HTTPException) as context:
                me.get_my_session(token="token", db=db)

        self.assertEqual(context.exception.status_code, 404)

    def test_get_my_session_rejects_expired_session(self) -> None:
        db = MagicMock()
        session_row = SimpleNamespace(
            user_id=7,
            status="active",
            expires_at=datetime.now(UTC) - timedelta(seconds=1),
        )

        with (
            patch.object(me, "decode_access_token", return_value={"sub": "7", "sid": "sid-1"}),
            patch.object(me, "get_current_session_projection", return_value=session_row),
        ):
            with self.assertRaises(HTTPException) as context:
                me.get_my_session(token="token", db=db)

        self.assertEqual(context.exception.status_code, 404)

    def test_get_my_session_returns_current_session(self) -> None:
        db = MagicMock()
        now = datetime.now(UTC)
        session_row = SimpleNamespace(
            session_token_id="sid-1",
            user_id=7,
            status="active",
            login_time=now - timedelta(minutes=1),
            last_active_at=now - timedelta(seconds=5),
            expires_at=now + timedelta(minutes=10),
        )

        with (
            patch.object(me, "decode_access_token", return_value={"sub": "7", "sid": "sid-1"}),
            patch.object(me, "get_current_session_projection", return_value=session_row),
        ):
            result = me.get_my_session(token="token", db=db)

        self.assertIsInstance(result, Response)
        payload = json.loads(result.body.decode("utf-8"))
        self.assertEqual(payload["data"]["session_token_id"], "sid-1")
        self.assertGreater(payload["data"]["remaining_seconds"], 0)
        self.assertEqual(payload["data"]["status"], "active")

    def test_get_my_session_uses_endpoint_cache(self) -> None:
        db = MagicMock()
        now = datetime.now(UTC)
        session_row = SimpleNamespace(
            session_token_id="sid-1",
            user_id=7,
            status="active",
            login_time=now - timedelta(minutes=1),
            last_active_at=now - timedelta(seconds=5),
            expires_at=now + timedelta(minutes=10),
        )

        with (
            patch.object(me, "decode_access_token", return_value={"sub": "7", "sid": "sid-1"}),
            patch.object(
                me,
                "get_current_session_projection",
                return_value=session_row,
            ) as get_session,
        ):
            first = me.get_my_session(token="token", db=db)
            second = me.get_my_session(token="token", db=db)

        self.assertIsInstance(first, Response)
        self.assertIsInstance(second, Response)
        get_session.assert_called_once_with(db, session_token_id="sid-1")


if __name__ == "__main__":
    unittest.main()
