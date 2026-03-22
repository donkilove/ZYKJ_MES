import unittest
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import sys

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services.quality_service import (
    export_quality_stats_csv,
    get_quality_operator_stats,
    get_quality_overview,
    get_quality_process_stats,
)


def _build_related_totals() -> dict:
    return {
        "scrap_by_product": {},
        "scrap_by_process": {"GX-01": 2},
        "scrap_by_operator": {"id:9": 2},
        "scrap_total": {"all": 2},
        "repair_by_product": {},
        "repair_by_process": {"GX-01": 1},
        "repair_by_operator": {"id:9": 1},
        "repair_total": {"all": 1},
        "defect_by_product": {},
        "defect_by_process": {"GX-01": 2},
        "defect_by_operator": {"id:9": 2},
        "defect_total": {"all": 2},
        "process_name_by_code": {"GX-01": "检验"},
        "operator_meta_by_key": {
            "id:9": {"operator_user_id": 9, "operator_username": "quality_worker"}
        },
        "covered_order_ids": {"all": {101}},
        "covered_process_keys": {"all": {"GX-01"}},
        "covered_operator_keys": {"all": {"id:9"}},
    }


class QualityServiceStatsUnitTest(unittest.TestCase):
    def test_overview_uses_related_quality_scope_without_first_article(self) -> None:
        with (
            patch("app.services.quality_service._load_first_article_rows", return_value=[]),
            patch(
                "app.services.quality_service._aggregate_quality_related_totals",
                return_value=_build_related_totals(),
            ),
        ):
            result = get_quality_overview(
                None,
                start_date=None,
                end_date=None,
            )

        self.assertEqual(result["first_article_total"], 0)
        self.assertEqual(result["defect_total"], 2)
        self.assertEqual(result["scrap_total"], 2)
        self.assertEqual(result["repair_total"], 1)
        self.assertEqual(result["covered_order_count"], 1)
        self.assertEqual(result["covered_process_count"], 1)
        self.assertEqual(result["covered_operator_count"], 1)

    def test_process_stats_keep_related_only_process_rows(self) -> None:
        with (
            patch("app.services.quality_service._load_first_article_rows", return_value=[]),
            patch(
                "app.services.quality_service._aggregate_quality_related_totals",
                return_value=_build_related_totals(),
            ),
        ):
            items = get_quality_process_stats(
                None,
                start_date=None,
                end_date=None,
            )

        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["process_code"], "GX-01")
        self.assertEqual(items[0]["process_name"], "检验")
        self.assertEqual(items[0]["first_article_total"], 0)
        self.assertEqual(items[0]["defect_total"], 2)
        self.assertEqual(items[0]["scrap_total"], 2)
        self.assertEqual(items[0]["repair_total"], 1)

    def test_operator_stats_merge_first_article_and_related_operator_meta(self) -> None:
        rows = [
            SimpleNamespace(
                operator_user_id=9,
                operator=SimpleNamespace(username="quality_worker"),
                result="passed",
                created_at=datetime(2026, 3, 2, 8, 0, 0),
            )
        ]
        with (
            patch("app.services.quality_service._load_first_article_rows", return_value=rows),
            patch(
                "app.services.quality_service._aggregate_quality_related_totals",
                return_value=_build_related_totals(),
            ),
        ):
            items = get_quality_operator_stats(
                None,
                start_date=None,
                end_date=None,
            )

        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["operator_user_id"], 9)
        self.assertEqual(items[0]["operator_username"], "quality_worker")
        self.assertEqual(items[0]["first_article_total"], 1)
        self.assertEqual(items[0]["passed_total"], 1)
        self.assertEqual(items[0]["defect_total"], 2)
        self.assertEqual(items[0]["scrap_total"], 2)
        self.assertEqual(items[0]["repair_total"], 1)

    def test_quality_stats_export_matches_page_quality_columns(self) -> None:
        with (
            patch(
                "app.services.quality_service.get_quality_overview",
                return_value={
                    "first_article_total": 4,
                    "passed_total": 3,
                    "failed_total": 1,
                    "pass_rate_percent": 75.0,
                    "defect_total": 5,
                    "scrap_total": 2,
                    "repair_total": 1,
                    "covered_order_count": 2,
                    "covered_process_count": 2,
                    "covered_operator_count": 1,
                    "latest_first_article_at": datetime(2026, 3, 2, 8, 0, 0),
                },
            ),
            patch(
                "app.services.quality_service.get_quality_process_stats",
                return_value=[
                    {
                        "process_code": "GX-01",
                        "process_name": "检验",
                        "first_article_total": 4,
                        "passed_total": 3,
                        "failed_total": 1,
                        "pass_rate_percent": 75.0,
                        "defect_total": 5,
                        "scrap_total": 2,
                        "repair_total": 1,
                        "latest_first_article_at": datetime(2026, 3, 2, 8, 0, 0),
                    }
                ],
            ),
            patch(
                "app.services.quality_service.get_quality_operator_stats",
                return_value=[
                    {
                        "operator_username": "quality_worker",
                        "first_article_total": 4,
                        "passed_total": 3,
                        "failed_total": 1,
                        "pass_rate_percent": 75.0,
                        "defect_total": 5,
                        "scrap_total": 2,
                        "repair_total": 1,
                        "latest_first_article_at": datetime(2026, 3, 2, 8, 0, 0),
                    }
                ],
            ),
            patch(
                "app.services.quality_service.get_quality_product_stats",
                return_value=[
                    {
                        "product_name": "产品A",
                        "first_article_total": 4,
                        "passed_total": 3,
                        "failed_total": 1,
                        "pass_rate_percent": 75.0,
                        "defect_total": 5,
                        "scrap_total": 2,
                        "repair_total": 1,
                    }
                ],
            ),
            patch(
                "app.services.quality_service.get_quality_trend",
                return_value=[
                    {
                        "stat_date": "2026-03-02",
                        "first_article_total": 4,
                        "passed_total": 3,
                        "failed_total": 1,
                        "pass_rate_percent": 75.0,
                        "defect_total": 5,
                        "scrap_total": 2,
                        "repair_total": 1,
                    }
                ],
            ),
        ):
            payload = export_quality_stats_csv(
                None,
                start_date=None,
                end_date=None,
            )

        csv_text = __import__("base64").b64decode(payload["content_base64"]).decode(
            "utf-8-sig"
        )
        self.assertIn("不良总数", csv_text)
        self.assertIn("不良数,报废数,维修数", csv_text)
        self.assertIn("产品名称,首件总数,通过数,不通过数,通过率,不良数,报废数,维修数", csv_text)


if __name__ == "__main__":
    unittest.main()
