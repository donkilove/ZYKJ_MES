import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core import authz_hierarchy_catalog


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


if __name__ == "__main__":
    unittest.main()
