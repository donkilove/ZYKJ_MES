import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.authz_catalog import (
    AUTHZ_RESOURCE_ACTION,
    AUTHZ_RESOURCE_FEATURE,
    AUTHZ_RESOURCE_MODULE,
    AUTHZ_RESOURCE_PAGE,
)
from app.core.authz_hierarchy_catalog import module_permission_code
from app.services import (
    authz_cache_service,
    authz_query_service,
    authz_read_service,
    authz_service,
    authz_write_service,
)


class _FakeScalarResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def all(self):
        return self._rows


class AuthzSplitUnitTest(unittest.TestCase):
    def test_permission_cache_key_is_stable(self) -> None:
        first = authz_cache_service._authz_permission_cache_key(
            cache_prefix=authz_service.settings.authz_permission_cache_prefix,
            normalized_roles=["operator", "quality_admin"],
            normalized_module_code="user",
        )
        second = authz_cache_service._authz_permission_cache_key(
            cache_prefix=authz_service.settings.authz_permission_cache_prefix,
            normalized_roles=["operator", "quality_admin"],
            normalized_module_code="user",
        )

        self.assertEqual(first, second)
        self.assertTrue(
            first.startswith(f"{authz_service.settings.authz_permission_cache_prefix}:")
        )

    def test_effective_permission_codes_keep_action_chain_under_module_and_page(self) -> None:
        module_code = "user"
        module_permission = module_permission_code(module_code)
        page_permission = "page.account_settings"
        feature_permission = "feature.user.account_settings.profile_view"
        action_permission = "user.profile.view"
        row_by_code = {
            module_permission: authz_service.PermissionCatalogRow(
                permission_code=module_permission,
                permission_name="用户模块",
                module_code=module_code,
                resource_type=AUTHZ_RESOURCE_MODULE,
                parent_permission_code=None,
                is_enabled=True,
            ),
            page_permission: authz_service.PermissionCatalogRow(
                permission_code=page_permission,
                permission_name="用户页面",
                module_code=module_code,
                resource_type=AUTHZ_RESOURCE_PAGE,
                parent_permission_code=None,
                is_enabled=True,
            ),
            feature_permission: authz_service.PermissionCatalogRow(
                permission_code=feature_permission,
                permission_name="查看个人资料",
                module_code=module_code,
                resource_type=AUTHZ_RESOURCE_FEATURE,
                parent_permission_code=page_permission,
                is_enabled=True,
            ),
            action_permission: authz_service.PermissionCatalogRow(
                permission_code=action_permission,
                permission_name="查看个人资料动作",
                module_code=module_code,
                resource_type=AUTHZ_RESOURCE_ACTION,
                parent_permission_code=page_permission,
                is_enabled=True,
            ),
        }

        effective_codes = authz_query_service._effective_permission_codes_from_granted(
            granted_codes={
                module_permission,
                page_permission,
                feature_permission,
                action_permission,
            },
            row_by_code=row_by_code,
        )

        self.assertIn(page_permission, effective_codes)
        self.assertIn(action_permission, effective_codes)

    def test_build_authz_read_revision_state_is_stable(self) -> None:
        revision_by_module = {"quality": 2, "user": 5}

        first_map, first_token = authz_read_service.build_authz_read_revision_state(
            revision_by_module
        )
        second_map, second_token = authz_read_service.build_authz_read_revision_state(
            {"user": 5, "quality": 2}
        )

        self.assertEqual(first_map, revision_by_module)
        self.assertEqual(second_map, {"user": 5, "quality": 2})
        self.assertEqual(first_token, second_token)

    def test_apply_role_permission_changes_updates_existing_and_missing_rows(self) -> None:
        db = MagicMock()
        existing_row = MagicMock()
        existing_row.permission_code = "perm.old"
        existing_row.granted = False
        db.execute.return_value = _FakeScalarResult([existing_row])

        updated_count = authz_write_service._apply_role_permission_changes(
            db,
            role_code="operator",
            changed_codes=["perm.old", "perm.new"],
            after_granted_codes={"perm.old", "perm.new"},
        )

        self.assertEqual(updated_count, 2)
        self.assertTrue(existing_row.granted)
        db.add.assert_called_once()


if __name__ == "__main__":
    unittest.main()
