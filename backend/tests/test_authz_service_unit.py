import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import authz_service


class _FakeScalarResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def all(self):
        return self._rows


class AuthzServiceUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        authz_service.invalidate_permission_cache()
        authz_service._AUTHZ_PERMISSION_REDIS_INIT = True
        authz_service._AUTHZ_PERMISSION_REDIS_CLIENT = None

    def tearDown(self) -> None:
        authz_service.invalidate_permission_cache()
        authz_service._AUTHZ_PERMISSION_REDIS_INIT = False
        authz_service._AUTHZ_PERMISSION_REDIS_CLIENT = None

    def test_get_permission_codes_for_role_codes_hits_cache_on_second_call(self) -> None:
        db = MagicMock()
        with (
            patch.object(
                authz_service.settings,
                "authz_permission_cache_redis_enabled",
                False,
            ),
            patch.object(authz_service, "ensure_authz_defaults") as ensure_defaults,
            patch.object(
                authz_service,
                "_query_effective_permission_codes_for_role_codes",
                return_value={"page.user"},
            ) as query_codes,
        ):
            first = authz_service.get_permission_codes_for_role_codes(
                db,
                role_codes=["quality_admin", "operator"],
            )
            second = authz_service.get_permission_codes_for_role_codes(
                db,
                role_codes=["operator", "quality_admin"],
            )

        self.assertEqual(first, {"page.user"})
        self.assertEqual(second, {"page.user"})
        ensure_defaults.assert_called_once()
        query_codes.assert_called_once()

    def test_get_permission_codes_for_role_codes_recomputes_after_ttl_expired(self) -> None:
        db = MagicMock()
        with (
            patch.object(
                authz_service.settings,
                "authz_permission_cache_redis_enabled",
                False,
            ),
            patch.object(authz_service.settings, "authz_permission_cache_ttl_seconds", 1),
            patch.object(authz_service, "ensure_authz_defaults"),
            patch.object(
                authz_service,
                "_query_effective_permission_codes_for_role_codes",
                side_effect=[{"page.user"}, {"page.user"}],
            ) as query_codes,
            patch.object(
                authz_service.time,
                "monotonic",
                side_effect=[0.0, 2.0, 2.0, 2.0],
            ),
        ):
            authz_service.get_permission_codes_for_role_codes(
                db,
                role_codes=["operator"],
            )
            authz_service.get_permission_codes_for_role_codes(
                db,
                role_codes=["operator"],
            )

        self.assertEqual(query_codes.call_count, 2)

    def test_update_role_permission_matrix_invalidates_cache_after_commit(self) -> None:
        db = MagicMock()
        role_row = SimpleNamespace(code="operator", name="操作员")
        catalog_row = SimpleNamespace(
            permission_code="page.account_settings.view",
            module_code="user",
            parent_permission_code=None,
        )
        db.execute.side_effect = [
            _FakeScalarResult([role_row]),
            _FakeScalarResult([]),
        ]

        with (
            patch.object(authz_service, "ensure_authz_defaults"),
            patch.object(
                authz_service,
                "_list_catalog_rows_by_module",
                return_value=[catalog_row],
            ),
            patch.object(authz_service, "_role_sort_key", return_value=0),
            patch.object(
                authz_service,
                "_normalize_requested_permission_codes",
                return_value={"page.account_settings.view"},
            ),
            patch.object(
                authz_service,
                "_guard_role_permission_codes",
                side_effect=lambda **kwargs: kwargs["permission_codes"],
            ),
            patch.object(
                authz_service,
                "_normalize_permission_codes_with_dependencies",
                side_effect=[
                    (set(), [], []),
                    ({"page.account_settings.view"}, [], []),
                ],
            ),
            patch.object(authz_service, "_bump_authz_module_revision"),
            patch.object(authz_service, "invalidate_permission_cache") as invalidate_cache,
        ):
            authz_service.update_role_permission_matrix(
                db,
                module_code="user",
                role_items=[
                    {
                        "role_code": "operator",
                        "granted_permission_codes": ["page.account_settings.view"],
                    }
                ],
                dry_run=False,
                operator=None,
            )

        db.commit.assert_called_once()
        invalidate_cache.assert_called_once()


if __name__ == "__main__":
    unittest.main()
