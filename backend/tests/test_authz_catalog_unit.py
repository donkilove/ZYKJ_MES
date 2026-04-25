import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core import authz_hierarchy_catalog
from app.core.authz_catalog import ACTION_PERMISSION_CATALOG


class AuthzCatalogUnitTest(unittest.TestCase):
    def test_quality_features_cover_trend_and_supplier_read_paths(self) -> None:
        features = {
            item.permission_code: set(item.action_permission_codes)
            for item in authz_hierarchy_catalog.FEATURE_DEFINITIONS
            if item.module_code == "quality"
        }

        all_quality_actions = set().union(*features.values())

        self.assertIn("quality.trend", all_quality_actions)
        self.assertIn("quality.suppliers.list", all_quality_actions)
        self.assertIn("quality.suppliers.detail", all_quality_actions)

    def test_first_article_scan_review_permission_is_in_quality_catalog(self) -> None:
        action_codes = {
            item.permission_code for item in ACTION_PERMISSION_CATALOG
        }
        feature_by_code = {
            item.permission_code: item
            for item in authz_hierarchy_catalog.FEATURE_DEFINITIONS
        }

        self.assertIn("quality.first_articles.scan_review", action_codes)
        self.assertIn(
            "feature.quality.first_articles.scan_review",
            feature_by_code,
        )
        self.assertIn(
            "quality.first_articles.scan_review",
            feature_by_code[
                "feature.quality.first_articles.scan_review"
            ].action_permission_codes,
        )


if __name__ == "__main__":
    unittest.main()
