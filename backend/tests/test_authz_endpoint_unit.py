import json
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api.v1.endpoints import authz as authz_endpoint


class AuthzEndpointUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        authz_endpoint._AUTHZ_ENDPOINT_RESPONSE_CACHE.clear()

    def tearDown(self) -> None:
        authz_endpoint._AUTHZ_ENDPOINT_RESPONSE_CACHE.clear()

    def test_permissions_catalog_response_cache_uses_revision_key(self) -> None:
        db = MagicMock()
        row = SimpleNamespace(
            permission_code="page.user",
            permission_name="用户页面",
            module_code="user",
            resource_type="page",
            parent_permission_code=None,
            is_enabled=True,
        )

        with (
            patch.object(
                authz_endpoint,
                "get_authz_module_revision_map",
                side_effect=[{"user": 3}, {"user": 3}, {"user": 4}],
            ),
            patch.object(
                authz_endpoint,
                "list_permission_catalog_rows",
                return_value=[row],
            ) as list_rows,
        ):
            first = authz_endpoint.get_permission_catalog_api(module="user", db=db, _=None)
            second = authz_endpoint.get_permission_catalog_api(module="user", db=db, _=None)
            third = authz_endpoint.get_permission_catalog_api(module="user", db=db, _=None)

        self.assertEqual(list_rows.call_count, 2)
        first_payload = json.loads(first.body.decode("utf-8"))
        second_payload = json.loads(second.body.decode("utf-8"))
        third_payload = json.loads(third.body.decode("utf-8"))
        self.assertEqual(first_payload["data"]["items"][0]["permission_code"], "page.user")
        self.assertEqual(second_payload["data"]["items"][0]["permission_code"], "page.user")
        self.assertEqual(third_payload["data"]["items"][0]["permission_code"], "page.user")

    def test_hierarchy_catalog_response_cache_uses_revision_key(self) -> None:
        db = MagicMock()
        hierarchy_payload = {
            "module_code": "user",
            "module_codes": ["user"],
            "module_permission_code": "module.user",
            "module_name": "用户",
            "pages": [],
            "features": [],
        }

        with (
            patch.object(
                authz_endpoint,
                "get_authz_module_revision_map",
                side_effect=[{"user": 7}, {"user": 7}, {"user": 8}],
            ),
            patch.object(
                authz_endpoint,
                "get_permission_hierarchy_catalog",
                return_value=hierarchy_payload,
            ) as get_catalog,
        ):
            first = authz_endpoint.get_permission_hierarchy_catalog_api(
                module="user",
                db=db,
                _=None,
            )
            second = authz_endpoint.get_permission_hierarchy_catalog_api(
                module="user",
                db=db,
                _=None,
            )
            third = authz_endpoint.get_permission_hierarchy_catalog_api(
                module="user",
                db=db,
                _=None,
            )

        self.assertEqual(get_catalog.call_count, 2)
        first_payload = json.loads(first.body.decode("utf-8"))
        second_payload = json.loads(second.body.decode("utf-8"))
        third_payload = json.loads(third.body.decode("utf-8"))
        self.assertEqual(first_payload["data"]["module_code"], "user")
        self.assertEqual(second_payload["data"]["module_code"], "user")
        self.assertEqual(third_payload["data"]["module_code"], "user")


if __name__ == "__main__":
    unittest.main()
