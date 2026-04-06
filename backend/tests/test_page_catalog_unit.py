import sys
import unittest
from pathlib import Path

from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.page_catalog import PAGE_CATALOG, PAGE_TYPE_SIDEBAR
from app.main import app


class PageCatalogUnitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def _login(self) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def test_sidebar_order_matches_expected_navigation_order(self) -> None:
        sidebar_codes = [
            item["code"]
            for item in sorted(
                (
                    entry
                    for entry in PAGE_CATALOG
                    if entry["page_type"] == PAGE_TYPE_SIDEBAR
                ),
                key=lambda entry: entry["sort_order"],
            )
        ]

        self.assertEqual(
            sidebar_codes,
            [
                "home",
                "user",
                "product",
                "craft",
                "quality",
                "production",
                "equipment",
                "message",
            ],
        )

    def test_page_catalog_endpoint_requires_authentication(self) -> None:
        response = self.client.get("/api/v1/ui/page-catalog")

        self.assertEqual(response.status_code, 401, response.text)

    def test_page_catalog_endpoint_returns_full_home_shell_catalog(self) -> None:
        token = self._login()

        response = self.client.get(
            "/api/v1/ui/page-catalog",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual(payload["code"], 0)
        self.assertEqual(payload["message"], "ok")

        items = payload["data"]["items"]
        self.assertEqual(len(items), len(PAGE_CATALOG))
        self.assertEqual(
            [item["code"] for item in items],
            [item["code"] for item in PAGE_CATALOG],
        )

        item_by_code = {item["code"]: item for item in items}
        self.assertTrue(item_by_code["home"]["always_visible"])
        self.assertEqual(item_by_code["account_settings"]["parent_code"], "user")
        self.assertEqual(item_by_code["message_center"]["parent_code"], "message")


if __name__ == "__main__":
    unittest.main()
