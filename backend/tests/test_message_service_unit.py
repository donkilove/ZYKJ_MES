import asyncio
import sys
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from sqlalchemy.exc import IntegrityError

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.schemas.message import MessageCreateRequest
from app.services import message_service


class _FakeScalarResult:
    def __init__(self, *, one=None, all_rows=None):
        self._one = one
        self._all_rows = all_rows or []

    def one(self):
        return self._one

    def scalar_one(self):
        return self._one

    def scalar_one_or_none(self):
        return self._one

    def scalars(self):
        return self

    def all(self):
        return self._all_rows


class _FakeSessionContext:
    def __init__(self, db):
        self._db = db

    def __enter__(self):
        return self._db

    def __exit__(self, exc_type, exc, tb):
        return False


class MessageServiceUnitTest(unittest.TestCase):
    def test_create_message_returns_existing_when_unique_constraint_conflicts(self):
        existing = SimpleNamespace(id=99, dedupe_key="same-key")
        db = MagicMock()
        db.execute.side_effect = [
            _FakeScalarResult(one=None),
            _FakeScalarResult(one=existing),
        ]
        db.flush.side_effect = IntegrityError("insert", {}, Exception("duplicate"))

        req = MessageCreateRequest(
            message_type="notice",
            title="重复事件",
            dedupe_key="same-key",
            recipient_user_ids=[1],
        )

        result = message_service.create_message(db, req=req)

        self.assertIs(result, existing)
        db.rollback.assert_called_once()

    def test_mark_recipient_delivery_result_updates_retry_fields_and_audit(self):
        recipient = SimpleNamespace(
            id=7,
            message_id=12,
            recipient_user_id=3,
            delivery_status="pending",
            delivery_attempt_count=0,
            last_failure_reason=None,
            next_retry_at=None,
            last_push_at=None,
            delivered_at=None,
        )
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(one=recipient)
        pushed_at = datetime.now(UTC)

        with (
            patch.object(
                message_service, "SessionLocal", return_value=_FakeSessionContext(db)
            ),
            patch.object(message_service, "write_audit_log") as write_audit_log,
        ):
            message_service._mark_recipient_delivery_result(
                message_id=12,
                user_id=3,
                delivered=False,
                failure_reason="no_active_connection",
                pushed_at=pushed_at,
            )

        self.assertEqual(recipient.delivery_status, "failed")
        self.assertEqual(recipient.delivery_attempt_count, 1)
        self.assertEqual(recipient.last_failure_reason, "no_active_connection")
        self.assertIsNotNone(recipient.next_retry_at)
        self.assertEqual(recipient.last_push_at, pushed_at)
        self.assertIsNone(recipient.delivered_at)
        write_audit_log.assert_called_once()
        db.commit.assert_called_once()

    def test_run_message_maintenance_marks_missing_source_and_archives_old_rows(self):
        now = datetime.now(UTC)
        stale_message = SimpleNamespace(
            id=1,
            title="旧消息",
            status="source_unavailable",
            source_module="message",
            source_type="announcement",
            source_id="1",
            expires_at=None,
            updated_at=now - timedelta(days=40),
            created_at=now - timedelta(days=40),
        )
        missing_source_message = SimpleNamespace(
            id=2,
            title="失效来源消息",
            status="active",
            source_module="user",
            source_type="registration_request",
            source_id="123",
            expires_at=None,
            updated_at=now,
            created_at=now,
        )
        db = MagicMock()
        db.execute.side_effect = [
            _FakeScalarResult(all_rows=[stale_message, missing_source_message]),
            _FakeScalarResult(one=None),
        ]

        with (
            patch.object(message_service, "write_audit_log") as write_audit_log,
            patch.object(
                message_service, "_sync_pending_registration_request_messages"
            ),
            patch.object(message_service, "_sync_failed_first_article_messages"),
            patch.object(message_service, "_sync_overdue_production_order_messages"),
        ):
            stats = message_service.run_message_maintenance(db, now=now)

        self.assertEqual(stale_message.status, "archived")
        self.assertEqual(missing_source_message.status, "src_unavailable")
        self.assertEqual(stats["archived_messages"], 1)
        self.assertEqual(stats["source_unavailable_updated"], 1)
        db.flush.assert_called_once()
        self.assertEqual(write_audit_log.call_count, 2)

    def test_get_message_jump_target_returns_missing_target_for_blank_page(self):
        msg = SimpleNamespace(
            id=17,
            status="active",
            expires_at=None,
            target_page_code=" ",
            target_tab_code=None,
            target_route_payload_json=None,
        )
        recipient = SimpleNamespace()
        db = MagicMock()
        db.execute.return_value.one_or_none.return_value = (msg, recipient)

        with patch.object(message_service, "run_message_maintenance") as maintenance:
            result = message_service.get_message_jump_target(
                db,
                user_id=1,
                message_id=17,
            )

        self.assertIsNotNone(result)
        self.assertFalse(result.can_jump)
        self.assertEqual(result.disabled_reason, "missing_target")
        maintenance.assert_not_called()

    def test_resolve_message_status_supports_legacy_source_unavailable_value(self):
        msg = SimpleNamespace(
            status="src_unavailable",
            expires_at=None,
            target_page_code="production",
        )

        status_value, inactive_reason = message_service._resolve_message_status(
            msg,
            now=datetime.now(UTC),
            user_permission_codes={"page.production.view"},
        )

        self.assertEqual(status_value, "source_unavailable")
        self.assertEqual(inactive_reason, "source_unavailable")

    def test_retry_failed_message_deliveries_replays_due_records(self):
        recipient = SimpleNamespace(id=5, message_id=21, recipient_user_id=9)
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(all_rows=[recipient])
        retry_db = MagicMock()

        with (
            patch.object(
                message_service,
                "SessionLocal",
                return_value=_FakeSessionContext(retry_db),
            ),
            patch.object(message_service, "get_unread_count", return_value=4),
            patch.object(
                message_service, "_mark_recipient_delivery_result"
            ) as mark_result,
            patch(
                "app.services.message_push_service.push_message_created",
                new=AsyncMock(return_value=(True, None, datetime.now(UTC))),
            ),
        ):
            retried_ids = asyncio.run(
                message_service.retry_failed_message_deliveries(
                    db,
                    now=datetime.now(UTC),
                )
            )

        self.assertEqual(retried_ids, [5])
        mark_result.assert_called_once()

    def test_compensate_pending_message_deliveries_replays_stale_pending_records(self):
        recipient = SimpleNamespace(id=8, message_id=31, recipient_user_id=12)
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(all_rows=[recipient])

        with patch.object(
            message_service,
            "_push_message_created_for_recipient",
            new=AsyncMock(),
        ) as push_once:
            compensated_ids = asyncio.run(
                message_service.compensate_pending_message_deliveries(
                    db,
                    now=datetime.now(UTC),
                )
            )

        self.assertEqual(compensated_ids, [8])
        push_once.assert_awaited_once_with(31, 12)

    def test_push_message_created_async_skips_sync_compensation_without_event_loop(self):
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(all_rows=[3, 7])
        msg = SimpleNamespace(id=15)

        with (
            patch.object(
                message_service.asyncio,
                "get_running_loop",
                side_effect=RuntimeError,
            ),
            patch.object(
                message_service,
                "_push_message_created_for_recipients",
                new=AsyncMock(),
            ) as push_batch,
        ):
            message_service._push_message_created_async(db, msg)

        push_batch.assert_not_awaited()

    def test_get_message_detail_returns_failure_hint(self):
        now = datetime.now(UTC)
        msg = SimpleNamespace(
            id=15,
            message_type="todo",
            priority="important",
            title="详情消息",
            summary="摘要",
            content="正文",
            source_module="production",
            source_type="production_order",
            source_id="12",
            source_code="PO-12",
            target_page_code="production",
            target_tab_code="production_order_management",
            target_route_payload_json='{"action":"detail"}',
            status="active",
            published_at=now,
            expires_at=None,
        )
        recipient = SimpleNamespace(
            id=3,
            message_id=15,
            recipient_user_id=1,
            is_read=False,
            read_at=None,
            delivered_at=None,
            delivery_status="failed",
            delivery_attempt_count=2,
            last_push_at=now,
            next_retry_at=now + timedelta(minutes=1),
            last_failure_reason="no_active_connection",
        )
        db = MagicMock()
        db.execute.return_value.one_or_none.return_value = (msg, recipient)

        with patch.object(message_service, "run_message_maintenance") as maintenance:
            detail = message_service.get_message_detail(
                db,
                user_id=1,
                message_id=15,
            )

        self.assertIsNotNone(detail)
        self.assertEqual(detail.delivery_status, "failed")
        self.assertIn("重试", detail.failure_reason_hint)
        maintenance.assert_not_called()

    def test_get_message_jump_target_returns_disabled_reason_for_inactive_message(self):
        now = datetime.now(UTC)
        msg = SimpleNamespace(
            id=16,
            status="archived",
            expires_at=None,
            target_page_code="production",
            target_tab_code="production_order_management",
            target_route_payload_json='{"action":"detail"}',
        )
        recipient = SimpleNamespace()
        db = MagicMock()
        db.execute.return_value.one_or_none.return_value = (msg, recipient)

        with patch.object(message_service, "run_message_maintenance") as maintenance:
            result = message_service.get_message_jump_target(
                db,
                user_id=1,
                message_id=16,
            )

        self.assertIsNotNone(result)
        self.assertFalse(result.can_jump)
        self.assertEqual(result.disabled_reason, "archived")
        maintenance.assert_not_called()

    def test_get_message_summary_counts_active_todo_and_high_priority(self):
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(one=(5, 2, 2, 2))

        with patch.object(message_service, "run_message_maintenance") as maintenance:
            summary = message_service.get_message_summary(db, user_id=1)

        self.assertEqual(summary["total_count"], 5)
        self.assertEqual(summary["unread_count"], 2)
        self.assertEqual(summary["todo_unread_count"], 2)
        self.assertEqual(summary["urgent_unread_count"], 2)
        maintenance.assert_not_called()
        self.assertEqual(db.execute.call_count, 1)

    def test_list_public_announcements_returns_public_items(self):
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.side_effect = [
            _FakeScalarResult(one=1),
            _FakeScalarResult(
                all_rows=[
                    SimpleNamespace(
                        id=51,
                        message_type="announcement",
                        priority="important",
                        title="登录页全员公告",
                        summary="摘要",
                        content="正文",
                        source_module="message",
                        source_type="announcement",
                        source_code="all",
                        target_page_code=None,
                        target_tab_code=None,
                        target_route_payload_json=None,
                        status="active",
                        published_at=now,
                        expires_at=now + timedelta(days=1),
                    )
                ]
            ),
        ]

        items, total = message_service.list_public_announcements(
            db,
            page=1,
            page_size=10,
        )

        self.assertEqual(total, 1)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].title, "登录页全员公告")
        self.assertEqual(items[0].source_code, "all")
        self.assertEqual(items[0].delivery_status, "pending")
        self.assertFalse(items[0].is_read)
        self.assertEqual(items[0].expires_at, now + timedelta(days=1))

    def test_get_unread_count_does_not_run_maintenance_by_default(self):
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(one=3)

        with patch.object(message_service, "run_message_maintenance") as maintenance:
            unread = message_service.get_unread_count(db, user_id=1)

        self.assertEqual(unread, 3)
        maintenance.assert_not_called()

    def test_get_unread_count_can_run_maintenance_when_requested(self):
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(one=4)

        with patch.object(message_service, "run_message_maintenance") as maintenance:
            unread = message_service.get_unread_count(
                db,
                user_id=1,
                run_maintenance=True,
            )

        self.assertEqual(unread, 4)
        maintenance.assert_called_once()

    def test_source_record_exists_supports_non_numeric_registered_source(self):
        msg = SimpleNamespace(
            source_module="user",
            source_type="force_offline",
            source_id="sid-1001",
        )
        db = MagicMock()
        db.execute.return_value = _FakeScalarResult(
            one=SimpleNamespace(is_deleted=False)
        )

        result = message_service._source_record_exists(db, msg)

        self.assertTrue(result)


if __name__ == "__main__":
    unittest.main()
