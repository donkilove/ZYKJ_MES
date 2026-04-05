import sys
import unittest
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.page_catalog import PAGE_CATALOG, PAGE_TYPE_SIDEBAR


class PageCatalogUnitTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
