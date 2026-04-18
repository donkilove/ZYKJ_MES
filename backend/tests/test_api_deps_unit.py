import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import HTTPException


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import deps
from app.core.authz_catalog import PERM_AUTHZ_PERMISSION_CATALOG_VIEW


class ApiDepsUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        deps._AUTH_USER_CACHE.clear()
        deps._PERMISSION_DECISION_CACHE.clear()
        deps._SESSION_PERMISSION_DECISION_CACHE.clear()
        deps._AUTHZ_CACHE_GENERATION = 0

    def tearDown(self) -> None:
        deps._AUTH_USER_CACHE.clear()
        deps._PERMISSION_DECISION_CACHE.clear()
        deps._SESSION_PERMISSION_DECISION_CACHE.clear()
        deps._AUTHZ_CACHE_GENERATION = 0

    def test_get_current_user_skips_commit_when_session_not_touched(self) -> None:
        db = MagicMock()
        user = SimpleNamespace(id=7, is_deleted=False, is_active=True)
        session_row = SimpleNamespace(status="active", user_id=7)

        with (
            patch.object(deps, "decode_access_token", return_value={"sub": "7", "sid": "sid-1"}),
            patch.object(
                deps,
                "touch_session_by_token_id",
                return_value=(session_row, False),
            ) as touch_session,
            patch.object(deps, "get_user_for_auth", return_value=user) as get_user_for_auth,
            patch.object(deps, "touch_user") as touch_user,
        ):
            result = deps.get_current_user(token="token", db=db)

        self.assertIs(result, user)
        touch_session.assert_called_once_with(db, "sid-1", allow_cached_active=True)
        get_user_for_auth.assert_called_once_with(db, 7)
        db.commit.assert_not_called()
        touch_user.assert_called_once_with(7)

    def test_get_current_user_rejects_invalid_session_before_loading_user(self) -> None:
        db = MagicMock()
        session_row = SimpleNamespace(status="forced_offline", user_id=7)

        with (
            patch.object(deps, "decode_access_token", return_value={"sub": "7", "sid": "sid-1"}),
            patch.object(
                deps,
                "touch_session_by_token_id",
                return_value=(session_row, False),
            ) as touch_session,
            patch.object(deps, "get_user_for_auth") as get_user_for_auth,
        ):
            with self.assertRaises(HTTPException) as context:
                deps.get_current_user(token="token", db=db)

        self.assertEqual(context.exception.status_code, 401)
        touch_session.assert_called_once_with(db, "sid-1", allow_cached_active=True)
        get_user_for_auth.assert_not_called()
        db.commit.assert_not_called()

    def test_require_permission_fast_reuses_session_permission_decision_cache(self) -> None:
        db = MagicMock()
        user = SimpleNamespace(
            id=7,
            is_deleted=False,
            is_active=True,
            roles=[SimpleNamespace(code="system_admin", is_enabled=True)],
        )
        session_row = SimpleNamespace(status="active", user_id=7)
        request = SimpleNamespace(
            method="GET",
            url=SimpleNamespace(path="/api/v1/authz/permissions/catalog"),
        )
        dependency = deps.require_permission_fast(PERM_AUTHZ_PERMISSION_CATALOG_VIEW)

        with (
            patch.object(deps, "decode_access_token", return_value={"sub": "7", "sid": "sid-1"}),
            patch.object(
                deps,
                "touch_session_by_token_id",
                return_value=(session_row, False),
            ) as touch_session,
            patch.object(deps, "get_user_for_auth", return_value=user) as get_user_for_auth,
            patch.object(
                deps,
                "get_user_permission_codes",
                return_value={PERM_AUTHZ_PERMISSION_CATALOG_VIEW},
            ) as get_user_permission_codes,
            patch.object(deps, "touch_user") as touch_user,
        ):
            dependency(token="token", request=request, db=db)
            dependency(token="token", request=request, db=db)

        self.assertEqual(touch_session.call_count, 2)
        get_user_for_auth.assert_called_once_with(db, 7)
        get_user_permission_codes.assert_called_once_with(db, user=user)
        self.assertEqual(touch_user.call_count, 2)

    def test_allow_auth_user_cache_allows_generic_gets_but_excludes_equipment(self) -> None:
        production_request = SimpleNamespace(
            method="GET",
            url=SimpleNamespace(path="/api/v1/production/orders/18"),
        )
        equipment_request = SimpleNamespace(
            method="GET",
            url=SimpleNamespace(path="/api/v1/equipment/ledger"),
        )
        production_my_orders_request = SimpleNamespace(
            method="GET",
            url=SimpleNamespace(path="/api/v1/production/my-orders"),
        )
        post_request = SimpleNamespace(
            method="POST",
            url=SimpleNamespace(path="/api/v1/production/orders"),
        )

        self.assertTrue(deps._allow_auth_user_cache(production_request, "sid-1"))
        self.assertFalse(deps._allow_auth_user_cache(equipment_request, "sid-1"))
        self.assertFalse(
            deps._allow_auth_user_cache(production_my_orders_request, "sid-1")
        )
        self.assertFalse(deps._allow_auth_user_cache(post_request, "sid-1"))
        self.assertFalse(deps._allow_auth_user_cache(production_request, None))

    def test_sync_permission_decision_caches_with_generation_clears_local_entries(self) -> None:
        deps._PERMISSION_DECISION_CACHE["role|perm"] = (999.0, False)
        deps._SESSION_PERMISSION_DECISION_CACHE["sid|perm"] = (999.0, False)
        deps._AUTHZ_CACHE_GENERATION = 1

        with patch.object(
            deps.authz_cache_service,
            "_authz_cache_generation_value",
            return_value=2,
        ):
            deps._sync_permission_decision_caches_with_generation()

        self.assertEqual(deps._PERMISSION_DECISION_CACHE, {})
        self.assertEqual(deps._SESSION_PERMISSION_DECISION_CACHE, {})


if __name__ == "__main__":
    unittest.main()
