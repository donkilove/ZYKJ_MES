import sys
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import authz_service
from app.services import authz_snapshot_service


class _FakeScalarResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def first(self):
        return self._rows[0] if self._rows else None

    def all(self):
        return self._rows


class AuthzServiceUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        authz_service.invalidate_permission_cache()
        authz_service._AUTHZ_DEFAULTS_READY = False
        authz_service._AUTHZ_PERMISSION_REDIS_INIT = True
        authz_service._AUTHZ_PERMISSION_REDIS_CLIENT = None
        authz_service._AUTHZ_PERMISSION_INFLIGHT.clear()
        authz_service._AUTHZ_READ_INFLIGHT.clear()
        authz_snapshot_service._AUTHZ_SNAPSHOT_LOCAL_CACHE.clear()
        authz_snapshot_service._AUTHZ_SNAPSHOT_INFLIGHT.clear()

    def tearDown(self) -> None:
        authz_service.invalidate_permission_cache()
        authz_service._AUTHZ_DEFAULTS_READY = False
        authz_service._AUTHZ_PERMISSION_REDIS_INIT = False
        authz_service._AUTHZ_PERMISSION_REDIS_CLIENT = None
        authz_service._AUTHZ_PERMISSION_INFLIGHT.clear()
        authz_service._AUTHZ_READ_INFLIGHT.clear()
        authz_snapshot_service._AUTHZ_SNAPSHOT_LOCAL_CACHE.clear()
        authz_snapshot_service._AUTHZ_SNAPSHOT_INFLIGHT.clear()

    def test_get_permission_codes_for_role_codes_hits_cache_on_second_call(
        self,
    ) -> None:
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

    def test_get_permission_codes_for_role_codes_recomputes_after_ttl_expired(
        self,
    ) -> None:
        db = MagicMock()
        with (
            patch.object(
                authz_service.settings,
                "authz_permission_cache_redis_enabled",
                False,
            ),
            patch.object(
                authz_service.settings, "authz_permission_cache_ttl_seconds", 1
            ),
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

    def test_get_permission_codes_for_role_codes_coalesces_concurrent_miss(
        self,
    ) -> None:
        db = MagicMock()
        started = threading.Event()
        release = threading.Event()
        results: list[set[str]] = []
        errors: list[Exception] = []

        def fake_query(**_kwargs):
            started.set()
            release.wait(timeout=1)
            return {"page.user"}

        def invoke() -> None:
            try:
                results.append(
                    authz_service.get_permission_codes_for_role_codes(
                        db,
                        role_codes=["operator"],
                    )
                )
            except Exception as exc:  # pragma: no cover - 失败时补证
                errors.append(exc)

        with (
            patch.object(
                authz_service.settings,
                "authz_permission_cache_redis_enabled",
                False,
            ),
            patch.object(authz_service, "ensure_authz_defaults"),
            patch.object(
                authz_service,
                "_query_effective_permission_codes_for_role_codes",
                side_effect=fake_query,
            ) as query_codes,
        ):
            first = threading.Thread(target=invoke)
            second = threading.Thread(target=invoke)
            first.start()
            self.assertTrue(started.wait(timeout=1))
            second.start()
            release.set()
            first.join(timeout=1)
            second.join(timeout=1)

        self.assertEqual(errors, [])
        self.assertEqual(results, [{"page.user"}, {"page.user"}])
        self.assertEqual(query_codes.call_count, 1)

    def test_cache_invalidation_does_not_repeat_authz_default_initialization(
        self,
    ) -> None:
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
                side_effect=[{"page.user"}, {"page.user"}],
            ) as query_codes,
        ):
            first = authz_service.get_permission_codes_for_role_codes(
                db,
                role_codes=["operator"],
            )
            authz_service.invalidate_permission_cache()
            second = authz_service.get_permission_codes_for_role_codes(
                db,
                role_codes=["operator"],
            )

        self.assertEqual(first, {"page.user"})
        self.assertEqual(second, {"page.user"})
        ensure_defaults.assert_called_once_with(db)
        self.assertEqual(query_codes.call_count, 2)

    def test_get_user_permission_codes_skips_default_initialization_on_read_path(
        self,
    ) -> None:
        db = MagicMock()
        user = SimpleNamespace(
            roles=[SimpleNamespace(code="operator", is_enabled=True)]
        )

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
            result = authz_service.get_user_permission_codes(db, user=user)

        self.assertEqual(result, {"page.user"})
        ensure_defaults.assert_not_called()
        query_codes.assert_called_once()

    @staticmethod
    def test_update_role_permission_matrix_invalidates_cache_after_commit() -> None:
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
            patch.object(
                authz_service, "invalidate_permission_cache"
            ) as invalidate_cache,
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

    def test_get_role_permission_matrix_uses_local_read_cache(self) -> None:
        db = MagicMock()
        role_row = SimpleNamespace(code="operator", name="操作员")
        grant_row = SimpleNamespace(
            role_code="operator", permission_code="user.profile.view"
        )
        catalog_row = SimpleNamespace(
            permission_code="user.profile.view",
            permission_name="查看个人资料",
            module_code="user",
            resource_type="action",
            parent_permission_code=None,
            is_enabled=True,
        )
        db.execute.side_effect = [
            _FakeScalarResult([role_row]),
            _FakeScalarResult([grant_row]),
        ]

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(authz_service, "get_authz_module_revision", return_value=3),
            patch.object(
                authz_service, "list_permission_modules", return_value=["user"]
            ),
            patch.object(
                authz_service,
                "_list_catalog_rows_by_module",
                return_value=[catalog_row],
            ) as list_catalog,
            patch.object(authz_service, "_role_sort_key", return_value=0),
            patch.object(
                authz_service,
                "_normalize_permission_codes_with_dependencies",
                return_value=({"user.profile.view"}, [], []),
            ),
        ):
            first = authz_service.get_role_permission_matrix(db, module_code="user")
            second = authz_service.get_role_permission_matrix(db, module_code="user")

        self.assertEqual(first["module_code"], "user")
        self.assertEqual(second["module_code"], "user")
        self.assertEqual(list_catalog.call_count, 1)
        self.assertEqual(db.execute.call_count, 2)

    def test_get_role_permission_matrix_coalesces_concurrent_miss(self) -> None:
        db = MagicMock()
        role_row = SimpleNamespace(code="operator", name="操作员")
        grant_row = SimpleNamespace(
            role_code="operator", permission_code="user.profile.view"
        )
        catalog_row = SimpleNamespace(
            permission_code="user.profile.view",
            permission_name="查看个人资料",
            module_code="user",
            resource_type="action",
            parent_permission_code=None,
            is_enabled=True,
        )
        started = threading.Event()
        release = threading.Event()
        results: list[dict[str, object]] = []
        errors: list[Exception] = []
        db.execute.side_effect = [
            _FakeScalarResult([role_row]),
            _FakeScalarResult([grant_row]),
        ]

        def blocked_catalog(*_args, **_kwargs):
            started.set()
            release.wait(timeout=1)
            return [catalog_row]

        def invoke() -> None:
            try:
                results.append(
                    authz_service.get_role_permission_matrix(db, module_code="user")
                )
            except Exception as exc:  # pragma: no cover - 失败时补证
                errors.append(exc)

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(authz_service, "get_authz_module_revision", return_value=3),
            patch.object(
                authz_service, "list_permission_modules", return_value=["user"]
            ),
            patch.object(
                authz_service,
                "_list_catalog_rows_by_module",
                side_effect=blocked_catalog,
            ) as list_catalog,
            patch.object(authz_service, "_role_sort_key", return_value=0),
            patch.object(
                authz_service,
                "_normalize_permission_codes_with_dependencies",
                return_value=({"user.profile.view"}, [], []),
            ),
        ):
            first = threading.Thread(target=invoke)
            second = threading.Thread(target=invoke)
            first.start()
            self.assertTrue(started.wait(timeout=1))
            second.start()
            release.set()
            first.join(timeout=1)
            second.join(timeout=1)

        self.assertEqual(errors, [])
        self.assertEqual(len(results), 2)
        self.assertEqual(list_catalog.call_count, 1)
        self.assertEqual(db.execute.call_count, 2)

    def test_get_authz_module_revision_map_uses_local_read_cache(self) -> None:
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(
            [SimpleNamespace(module_code="user", revision=2)]
        )

        with patch.object(authz_service, "_ensure_authz_defaults_once"):
            first = authz_service.get_authz_module_revision_map(db)
            second = authz_service.get_authz_module_revision_map(db)

        self.assertEqual(first["user"], 2)
        self.assertEqual(second["user"], 2)
        self.assertEqual(db.execute.call_count, 1)

    def test_list_permission_catalog_rows_uses_local_read_cache(self) -> None:
        db = MagicMock()
        row = (
            "page.user",
            "用户管理页面",
            "user",
            "page",
            None,
            True,
        )
        db.execute.return_value = _FakeScalarResult([row])

        with patch.object(authz_service, "_ensure_authz_defaults_once"):
            first = authz_service.list_permission_catalog_rows(db, module_code=" user ")
            second = authz_service.list_permission_catalog_rows(db, module_code="user")
            third = authz_service.list_permission_catalog_rows(db)

        self.assertEqual(len(first), 1)
        self.assertEqual(len(second), 1)
        self.assertEqual(len(third), 1)
        self.assertEqual(db.execute.call_count, 2)

    def test_list_permission_modules_uses_local_read_cache(self) -> None:
        db = MagicMock()
        rows = [
            SimpleNamespace(module_code="user"),
            SimpleNamespace(module_code="quality"),
            SimpleNamespace(module_code=""),
        ]

        with patch.object(
            authz_service,
            "list_permission_catalog_rows",
            return_value=rows,
        ) as list_rows:
            first = authz_service.list_permission_modules(db)
            second = authz_service.list_permission_modules(db)

        self.assertEqual(first, ["quality", "user"])
        self.assertEqual(second, ["quality", "user"])
        self.assertEqual(list_rows.call_count, 1)

    def test_get_permission_hierarchy_catalog_uses_local_read_cache(self) -> None:
        db = MagicMock()
        module_row = SimpleNamespace(module_code="user")

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(
                authz_service,
                "_authz_read_revision_state",
                return_value=({"user": 3}, "rev-3"),
            ),
            patch.object(
                authz_service,
                "_module_permission_catalog_rows",
                return_value=[module_row],
            ) as module_rows,
            patch.object(
                authz_service,
                "_page_items_for_module",
                return_value=[{"page_code": "user"}],
            ) as page_items,
            patch.object(
                authz_service,
                "_feature_items_for_module",
                return_value=[{"feature_code": "profile"}],
            ) as feature_items,
        ):
            first = authz_service.get_permission_hierarchy_catalog(
                db, module_code="user"
            )
            second = authz_service.get_permission_hierarchy_catalog(
                db, module_code="user"
            )

        self.assertEqual(first["module_code"], "user")
        self.assertEqual(second["module_code"], "user")
        self.assertEqual(module_rows.call_count, 1)
        self.assertEqual(page_items.call_count, 1)
        self.assertEqual(feature_items.call_count, 1)

    def test_get_permission_hierarchy_catalog_cache_invalidates_when_revision_changes(
        self,
    ) -> None:
        db = MagicMock()
        module_row = SimpleNamespace(module_code="user")

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(
                authz_service,
                "_authz_read_revision_state",
                side_effect=[
                    ({"user": 3}, "rev-3"),
                    ({"user": 4}, "rev-4"),
                ],
            ),
            patch.object(
                authz_service,
                "_module_permission_catalog_rows",
                return_value=[module_row],
            ) as module_rows,
            patch.object(
                authz_service,
                "_page_items_for_module",
                return_value=[{"page_code": "user"}],
            ) as page_items,
            patch.object(
                authz_service,
                "_feature_items_for_module",
                return_value=[{"feature_code": "profile"}],
            ) as feature_items,
        ):
            authz_service.get_permission_hierarchy_catalog(db, module_code="user")
            authz_service.get_permission_hierarchy_catalog(db, module_code="user")

        self.assertEqual(module_rows.call_count, 2)
        self.assertEqual(page_items.call_count, 2)
        self.assertEqual(feature_items.call_count, 2)

    def test_get_permission_hierarchy_role_config_uses_local_read_cache(self) -> None:
        db = MagicMock()
        role_row = SimpleNamespace(code="operator", name="操作员")
        db.execute.return_value = _FakeScalarResult([role_row])

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(
                authz_service,
                "_authz_read_revision_state",
                return_value=({"user": 2}, "rev-2"),
            ),
            patch.object(
                authz_service,
                "_hierarchy_permission_codes_for_module",
                return_value={
                    "module_permission_code": "module.user",
                    "page_permission_codes": {"page.user"},
                    "feature_permission_codes": {"feature.user.profile"},
                },
            ),
            patch.object(
                authz_service,
                "_all_hierarchy_permission_codes",
                return_value={"module.user", "page.user", "feature.user.profile"},
            ),
            patch.object(
                authz_service,
                "_role_granted_codes_for_hierarchy",
                return_value={"module.user", "page.user", "feature.user.profile"},
            ) as granted_codes,
            patch.object(authz_service, "_catalog_rows_by_code", return_value={}),
            patch.object(
                authz_service,
                "_effective_permission_codes_from_granted",
                return_value={"page.user", "feature.user.profile"},
            ) as effective_codes,
        ):
            first = authz_service.get_permission_hierarchy_role_config(
                db,
                role_code="operator",
                module_code="user",
            )
            second = authz_service.get_permission_hierarchy_role_config(
                db,
                role_code="operator",
                module_code="user",
            )

        self.assertEqual(first["role_code"], "operator")
        self.assertEqual(second["role_code"], "operator")
        self.assertEqual(db.execute.call_count, 1)
        self.assertEqual(granted_codes.call_count, 1)
        self.assertEqual(effective_codes.call_count, 1)

    def test_get_capability_pack_catalog_uses_local_read_cache(self) -> None:
        db = MagicMock()

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(
                authz_service,
                "_authz_read_revision_state",
                return_value=({"user": 5}, "rev-5"),
            ),
            patch.object(
                authz_service,
                "_normalize_capability_pack_module_code",
                return_value=("user", ["user", "quality"]),
            ) as normalize_module,
            patch.object(
                authz_service,
                "_capability_items_for_module",
                return_value=[{"capability_code": "feature.user.profile"}],
            ) as capability_items,
            patch.object(
                authz_service,
                "_capability_role_template_items",
                return_value=[{"role_code": "operator"}],
            ) as role_templates,
        ):
            first = authz_service.get_capability_pack_catalog(db, module_code="user")
            second = authz_service.get_capability_pack_catalog(db, module_code="user")

        self.assertEqual(first["module_revision"], 5)
        self.assertEqual(second["module_revision"], 5)
        self.assertEqual(normalize_module.call_count, 1)
        self.assertEqual(capability_items.call_count, 1)
        self.assertEqual(role_templates.call_count, 1)

    def test_get_capability_pack_role_config_cache_key_includes_role(self) -> None:
        db = MagicMock()
        operator_config = {
            "role_code": "operator",
            "role_name": "操作员",
            "readonly": False,
            "module_code": "user",
            "module_enabled": True,
            "granted_feature_permission_codes": ["feature.user.profile"],
            "effective_feature_permission_codes": ["feature.user.profile"],
            "effective_page_permission_codes": ["page.user"],
        }
        quality_config = {
            "role_code": "quality_admin",
            "role_name": "质量管理员",
            "readonly": False,
            "module_code": "user",
            "module_enabled": True,
            "granted_feature_permission_codes": ["feature.user.profile"],
            "effective_feature_permission_codes": ["feature.user.profile"],
            "effective_page_permission_codes": ["page.user"],
        }

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(
                authz_service,
                "_authz_read_revision_state",
                return_value=({"user": 6}, "rev-6"),
            ),
            patch.object(
                authz_service,
                "_normalize_capability_pack_module_code",
                return_value=("user", ["user"]),
            ),
            patch.object(
                authz_service,
                "get_permission_hierarchy_role_config",
                side_effect=[operator_config, quality_config],
            ) as get_role_config,
            patch.object(
                authz_service,
                "_visible_capability_permission_codes_for_module",
                return_value={"feature.user.profile"},
            ),
        ):
            first = authz_service.get_capability_pack_role_config(
                db,
                role_code="operator",
                module_code="user",
            )
            second = authz_service.get_capability_pack_role_config(
                db,
                role_code="operator",
                module_code="user",
            )
            third = authz_service.get_capability_pack_role_config(
                db,
                role_code="quality_admin",
                module_code="user",
            )

        self.assertEqual(first["role_code"], "operator")
        self.assertEqual(second["role_code"], "operator")
        self.assertEqual(third["role_code"], "quality_admin")
        self.assertEqual(get_role_config.call_count, 2)

    def test_get_capability_pack_effective_explain_uses_local_read_cache(self) -> None:
        db = MagicMock()
        role_row = SimpleNamespace(code="operator", name="操作员")
        db.execute.return_value = _FakeScalarResult([role_row])

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(
                authz_service,
                "_authz_read_revision_state",
                return_value=({"user": 7}, "rev-7"),
            ),
            patch.object(
                authz_service,
                "_normalize_capability_pack_module_code",
                return_value=("user", ["user"]),
            ),
            patch.object(
                authz_service,
                "_hierarchy_permission_codes_for_module",
                return_value={
                    "module_permission_code": "module.user",
                    "page_permission_codes": {"page.user"},
                    "feature_permission_codes": {"feature.user.profile"},
                },
            ),
            patch.object(
                authz_service,
                "_all_hierarchy_permission_codes",
                return_value={"module.user", "page.user", "feature.user.profile"},
            ),
            patch.object(
                authz_service,
                "_role_granted_codes_for_hierarchy",
                return_value={"module.user", "page.user", "feature.user.profile"},
            ) as granted_codes,
            patch.object(authz_service, "_catalog_rows_by_code", return_value={}),
            patch.object(
                authz_service,
                "_effective_permission_codes_from_granted",
                return_value={"module.user", "page.user", "feature.user.profile"},
            ) as effective_codes,
            patch.object(
                authz_service,
                "_capability_items_for_module",
                return_value=[],
            ) as capability_items,
        ):
            first = authz_service.get_capability_pack_effective_explain(
                db,
                role_code="operator",
                module_code="user",
            )
            second = authz_service.get_capability_pack_effective_explain(
                db,
                role_code="operator",
                module_code="user",
            )

        self.assertEqual(first["role_code"], "operator")
        self.assertEqual(second["role_code"], "operator")
        self.assertEqual(db.execute.call_count, 1)
        self.assertEqual(granted_codes.call_count, 1)
        self.assertEqual(effective_codes.call_count, 1)
        self.assertEqual(capability_items.call_count, 1)

    def test_get_authz_snapshot_uses_short_ttl_cache(self) -> None:
        db = MagicMock()
        user = SimpleNamespace(roles=[SimpleNamespace(code="operator")])
        catalog_row = SimpleNamespace(
            permission_code="page.user",
            module_code="user",
            resource_type=authz_snapshot_service.AUTHZ_RESOURCE_PAGE,
        )

        with (
            patch.object(
                authz_snapshot_service,
                "get_authz_module_revision_map",
                return_value={"user": 1},
            ),
            patch.object(
                authz_snapshot_service,
                "list_permission_catalog_rows",
                return_value=[catalog_row],
            ) as list_catalog_rows,
            patch.object(
                authz_snapshot_service,
                "get_user_permission_codes",
                return_value={"page.user"},
            ) as get_codes,
        ):
            first = authz_snapshot_service.get_authz_snapshot(db, user=user)
            second = authz_snapshot_service.get_authz_snapshot(db, user=user)

        self.assertEqual(first["revision"], 1)
        self.assertEqual(second["revision"], 1)
        self.assertEqual(list_catalog_rows.call_count, 1)
        self.assertEqual(get_codes.call_count, 1)

    def test_get_authz_snapshot_cache_invalidates_when_revision_changes(self) -> None:
        db = MagicMock()
        user = SimpleNamespace(roles=[SimpleNamespace(code="operator")])
        catalog_row = SimpleNamespace(
            permission_code="page.user",
            module_code="user",
            resource_type=authz_snapshot_service.AUTHZ_RESOURCE_PAGE,
        )

        with (
            patch.object(
                authz_snapshot_service,
                "get_authz_module_revision_map",
                side_effect=[{"user": 1}, {"user": 2}],
            ),
            patch.object(
                authz_snapshot_service,
                "list_permission_catalog_rows",
                return_value=[catalog_row],
            ) as list_catalog_rows,
            patch.object(
                authz_snapshot_service,
                "get_user_permission_codes",
                return_value={"page.user"},
            ) as get_codes,
        ):
            first = authz_snapshot_service.get_authz_snapshot(db, user=user)
            second = authz_snapshot_service.get_authz_snapshot(db, user=user)

        self.assertEqual(first["revision"], 1)
        self.assertEqual(second["revision"], 2)
        self.assertEqual(list_catalog_rows.call_count, 2)
        self.assertEqual(get_codes.call_count, 2)

    def test_get_authz_snapshot_coalesces_concurrent_miss(self) -> None:
        db = MagicMock()
        user = SimpleNamespace(roles=[SimpleNamespace(code="operator")])
        catalog_row = SimpleNamespace(
            permission_code="page.user",
            module_code="user",
            resource_type=authz_snapshot_service.AUTHZ_RESOURCE_PAGE,
        )
        started = threading.Event()
        release = threading.Event()
        results: list[dict[str, object]] = []
        errors: list[Exception] = []

        def blocked_catalog(*_args, **_kwargs):
            started.set()
            release.wait(timeout=1)
            return [catalog_row]

        def invoke() -> None:
            try:
                results.append(authz_snapshot_service.get_authz_snapshot(db, user=user))
            except Exception as exc:  # pragma: no cover - 失败时补证
                errors.append(exc)

        with (
            patch.object(
                authz_snapshot_service,
                "get_authz_module_revision_map",
                return_value={"user": 1},
            ),
            patch.object(
                authz_snapshot_service,
                "list_permission_catalog_rows",
                side_effect=blocked_catalog,
            ) as list_catalog_rows,
            patch.object(
                authz_snapshot_service,
                "get_user_permission_codes",
                return_value={"page.user"},
            ) as get_codes,
        ):
            first = threading.Thread(target=invoke)
            second = threading.Thread(target=invoke)
            first.start()
            self.assertTrue(started.wait(timeout=1))
            second.start()
            release.set()
            first.join(timeout=1)
            second.join(timeout=1)

        self.assertEqual(errors, [])
        self.assertEqual(len(results), 2)
        self.assertEqual(list_catalog_rows.call_count, 1)
        self.assertEqual(get_codes.call_count, 1)


if __name__ == "__main__":
    unittest.main()
