import sys
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.models.first_article_record import FirstArticleRecord  # noqa: E402
from app.models.first_article_review_session import (  # noqa: E402
    FirstArticleReviewSession,
)


class FirstArticleScanReviewModelTest(unittest.TestCase):
    def test_first_article_review_session_model_has_required_fields(self) -> None:
        expires_at = datetime.now(UTC) + timedelta(minutes=5)
        row = FirstArticleReviewSession(
            token_hash="hash-value",
            status="pending",
            expires_at=expires_at,
            order_id=1,
            order_process_id=2,
            pipeline_instance_id=None,
            operator_user_id=3,
            assist_authorization_id=None,
            template_id=None,
            check_content="外观检查",
            test_value="尺寸 10.01",
            participant_user_ids=[3, 4],
        )

        self.assertEqual(row.status, "pending")
        self.assertEqual(row.participant_user_ids, [3, 4])
        self.assertEqual(row.expires_at, expires_at)

    def test_first_article_record_has_review_fields(self) -> None:
        reviewed_at = datetime.now(UTC)
        row = FirstArticleRecord(
            order_id=1,
            order_process_id=2,
            operator_user_id=3,
            verification_date=reviewed_at.date(),
            verification_code="SCAN-APPROVED",
            result="passed",
            reviewer_user_id=5,
            reviewed_at=reviewed_at,
            review_remark="参数一致",
        )

        self.assertEqual(row.reviewer_user_id, 5)
        self.assertEqual(row.reviewed_at, reviewed_at)
        self.assertEqual(row.review_remark, "参数一致")


if __name__ == "__main__":
    unittest.main()
