import sys
import unittest
from datetime import UTC, datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import quality_service  # noqa: E402


class _FakeScalarResult:
    def __init__(self, *, rows=None):
        self._rows = list(rows or [])

    def scalars(self):
        return self

    def all(self):
        return list(self._rows)


class QualityFirstArticleActionsUnitTest(unittest.TestCase):
    def test_cancel_first_article_marks_record_cancelled_and_invalidates_cache(self):
        now = datetime.now(UTC)
        record = SimpleNamespace(
            id=11,
            order_id=21,
            order_process_id=31,
            result="passed",
            is_cancelled=False,
            cancelled_at=None,
            cancelled_by_user_id=None,
        )
        context = SimpleNamespace(
            record=record,
            order=SimpleNamespace(order_code="PO-21"),
            process_row=SimpleNamespace(process_name="装配"),
            sub_order=SimpleNamespace(id=41),
            first_article_production_record=None,
            review_sessions=[SimpleNamespace(id=91)],
            assist_authorization=None,
            pipeline_instances=[],
            has_following_production=False,
        )
        operator = SimpleNamespace(id=7, username="quality_admin")
        db = MagicMock()

        with (
            patch.object(
                quality_service,
                "_load_first_article_action_context",
                return_value=context,
            ),
            patch.object(
                quality_service,
                "_can_cancel_first_article_context",
                return_value=True,
            ),
            patch.object(quality_service, "_rollback_first_article_execution_state") as rollback,
            patch.object(quality_service, "_invalidate_quality_stats_cache") as invalidate_cache,
            patch.object(quality_service, "add_order_event_log") as add_event_log,
            patch("app.services.quality_service.datetime") as mocked_datetime,
        ):
            mocked_datetime.now.return_value = now
            mocked_datetime.now.__name__ = "now"

            result = quality_service.cancel_first_article(
                db,
                record_id=record.id,
                operator=operator,
            )

        rollback.assert_called_once()
        invalidate_cache.assert_called_once()
        add_event_log.assert_called_once()
        db.flush.assert_called_once()
        self.assertTrue(record.is_cancelled)
        self.assertEqual(record.cancelled_by_user_id, operator.id)
        self.assertEqual(record.cancelled_at, now)
        self.assertEqual(result["record_status"], "cancelled")
        self.assertEqual(result["cancelled_by_username"], operator.username)

    def test_cancel_first_article_rejects_when_following_production_exists(self):
        context = SimpleNamespace(
            record=SimpleNamespace(
                id=12,
                order_id=22,
                order_process_id=32,
                result="passed",
                is_cancelled=False,
            ),
            order=None,
            process_row=None,
            sub_order=None,
            first_article_production_record=None,
            review_sessions=[],
            assist_authorization=None,
            pipeline_instances=[],
            has_following_production=True,
        )
        with patch.object(
            quality_service,
            "_load_first_article_action_context",
            return_value=context,
        ):
            with self.assertRaisesRegex(ValueError, "真实报工"):
                quality_service.cancel_first_article(
                    MagicMock(),
                    record_id=12,
                    operator=SimpleNamespace(id=1, username="tester"),
                )

    def test_delete_first_article_rejects_active_passed_record_with_following_production(self):
        context = SimpleNamespace(
            record=SimpleNamespace(
                id=13,
                order_id=23,
                order_process_id=33,
                result="passed",
                is_cancelled=False,
            ),
            order=SimpleNamespace(order_code="PO-23"),
            process_row=SimpleNamespace(process_name="检验"),
            sub_order=SimpleNamespace(id=43),
            first_article_production_record=SimpleNamespace(id=53),
            review_sessions=[],
            assist_authorization=None,
            pipeline_instances=[],
            has_following_production=True,
        )
        with patch.object(
            quality_service,
            "_load_first_article_action_context",
            return_value=context,
        ):
            with self.assertRaisesRegex(ValueError, "真实报工"):
                quality_service.delete_first_article(
                    MagicMock(),
                    record_id=13,
                    operator=SimpleNamespace(id=1, username="tester"),
                )

    def test_delete_failed_first_article_deletes_all_related_rows(self):
        record = SimpleNamespace(
            id=14,
            order_id=24,
            order_process_id=34,
            result="failed",
            is_cancelled=False,
        )
        review_session = SimpleNamespace(id=61)
        history_row = SimpleNamespace(id=71)
        disposition_row = SimpleNamespace(id=81)
        participant_row = SimpleNamespace(id=91)
        context = SimpleNamespace(
            record=record,
            order=SimpleNamespace(order_code="PO-24"),
            process_row=SimpleNamespace(process_name="装配"),
            sub_order=None,
            first_article_production_record=None,
            review_sessions=[review_session],
            assist_authorization=None,
            pipeline_instances=[],
            has_following_production=False,
        )
        db = MagicMock()
        db.execute.side_effect = [
            _FakeScalarResult(rows=[history_row]),
            _FakeScalarResult(rows=[disposition_row]),
            _FakeScalarResult(rows=[participant_row]),
        ]

        with (
            patch.object(
                quality_service,
                "_load_first_article_action_context",
                return_value=context,
            ),
            patch.object(quality_service, "_invalidate_quality_stats_cache") as invalidate_cache,
            patch.object(quality_service, "add_order_event_log") as add_event_log,
        ):
            result = quality_service.delete_first_article(
                db,
                record_id=record.id,
                operator=SimpleNamespace(id=2, username="quality_admin"),
            )

        invalidate_cache.assert_called_once()
        add_event_log.assert_called_once()
        self.assertEqual(
            db.delete.call_args_list,
            [
                unittest.mock.call(review_session),
                unittest.mock.call(history_row),
                unittest.mock.call(disposition_row),
                unittest.mock.call(participant_row),
                unittest.mock.call(record),
            ],
        )
        self.assertTrue(result["deleted"])


if __name__ == "__main__":
    unittest.main()
