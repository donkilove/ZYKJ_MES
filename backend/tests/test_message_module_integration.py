import sys
import time
import unittest
import asyncio
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.audit_log import AuditLog  # noqa: E402
from app.models.first_article_record import FirstArticleRecord  # noqa: E402
from app.models.maintenance_work_order import MaintenanceWorkOrder  # noqa: E402
from app.models.message import Message  # noqa: E402
from app.models.message_recipient import MessageRecipient  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.registration_request import RegistrationRequest  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.user import User  # noqa: E402
from app.core.security import get_password_hash  # noqa: E402
from app.api.v1.endpoints import messages as message_endpoint  # noqa: E402
from app.api.v1.endpoints.craft import (  # noqa: E402
    _notify_craft_template_published,
)
from app.api.v1.endpoints.products import (  # noqa: E402
    _notify_product_version_activated,
)
from app.core.authz_catalog import (  # noqa: E402
    ACTION_PERMISSION_CATALOG,
    PAGE_PERMISSION_CATALOG,
)
from app.core.authz_hierarchy_catalog import FEATURE_DEFINITIONS  # noqa: E402
from app.core.page_catalog import PAGE_CATALOG  # noqa: E402
from app.schemas.message import (  # noqa: E402
    AnnouncementManagementItem,
    AnnouncementOfflineResult,
)
from app.services.message_service import (  # noqa: E402
    _push_message_created_for_recipient,
    create_message_for_users,
    retry_failed_message_deliveries,
    run_message_maintenance,
)
from app.services import authz_service  # noqa: E402


class MessageModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.token = self._login()
        self.message_ids: list[int] = []
        self.registration_request_ids: list[int] = []
        self.created_user_ids: list[int] = []
        self.created_role_ids: list[int] = []
        self.product_ids: list[int] = []
        self.process_ids: list[int] = []
        self.production_order_ids: list[int] = []
        self.production_order_process_ids: list[int] = []
        self.first_article_record_ids: list[int] = []
        self.maintenance_work_order_ids: list[int] = []
        self.case_token = f"msg-case-{time.time_ns()}"

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
            for message_id in reversed(self.message_ids):
                db.query(MessageRecipient).filter(
                    MessageRecipient.message_id == message_id
                ).delete()
                db.query(Message).filter(Message.id == message_id).delete()
            for request_id in reversed(self.registration_request_ids):
                db.query(RegistrationRequest).filter(
                    RegistrationRequest.id == request_id
                ).delete()
            for user_id in reversed(self.created_user_ids):
                db.query(User).filter(User.id == user_id).delete()
            for role_id in reversed(self.created_role_ids):
                db.query(Role).filter(Role.id == role_id).delete()
            for record_id in reversed(self.first_article_record_ids):
                db.query(FirstArticleRecord).filter(
                    FirstArticleRecord.id == record_id
                ).delete()
            for order_process_id in reversed(self.production_order_process_ids):
                db.query(ProductionOrderProcess).filter(
                    ProductionOrderProcess.id == order_process_id
                ).delete()
            for work_order_id in reversed(self.maintenance_work_order_ids):
                db.query(MaintenanceWorkOrder).filter(
                    MaintenanceWorkOrder.id == work_order_id
                ).delete()
            for order_id in reversed(self.production_order_ids):
                db.query(ProductionOrder).filter(
                    ProductionOrder.id == order_id
                ).delete()
            for process_id in reversed(self.process_ids):
                db.query(Process).filter(Process.id == process_id).delete()
            for product_id in reversed(self.product_ids):
                db.query(Product).filter(Product.id == product_id).delete()
            db.commit()
        finally:
            db.close()

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def _login(self) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _create_message(
        self,
        *,
        message_type: str,
        priority: str,
        title: str,
        status: str = "active",
        expires_at: datetime | None = None,
        target_page_code: str = "production",
        target_route_payload_json: str | None = None,
    ) -> int:
        db = SessionLocal()
        try:
            msg = create_message_for_users(
                db,
                message_type=message_type,
                priority=priority,
                title=f"{self.case_token}-{title}",
                summary=f"{self.case_token}-摘要-{title}",
                source_module="production",
                source_type="repair_order",
                source_id=str(int(time.time() * 1000)),
                source_code=f"{self.case_token}-SRC-{title}",
                target_page_code=target_page_code,
                target_tab_code="production_repair_orders",
                target_route_payload_json=target_route_payload_json,
                recipient_user_ids=[1],
                dedupe_key=f"{self.case_token}-msg-test-{title}-{time.time_ns()}",
                created_by_user_id=1,
                expires_at=expires_at,
            )
            if status != "active":
                msg.status = status
                db.commit()
                db.refresh(msg)
            self.message_ids.append(msg.id)
            return msg.id
        finally:
            db.close()

    def _create_role(self, code: str, name: str) -> Role:
        db = SessionLocal()
        try:
            role = Role(code=code, name=name, role_type="custom", is_enabled=True)
            db.add(role)
            db.commit()
            db.refresh(role)
            self.created_role_ids.append(role.id)
            return role
        finally:
            db.close()

    def _create_user(self, *, username: str, role: Role) -> User:
        db = SessionLocal()
        try:
            user = User(
                username=username,
                full_name=username,
                password_hash=get_password_hash("Admin@123456"),
                is_active=True,
                is_deleted=False,
            )
            user.roles.append(db.merge(role))
            db.add(user)
            db.commit()
            db.refresh(user)
            self.created_user_ids.append(user.id)
            return user
        finally:
            db.close()

    def test_summary_list_and_batch_read(self) -> None:
        baseline_summary = self.client.get(
            "/api/v1/messages/summary",
            headers=self._headers(),
        )
        self.assertEqual(baseline_summary.status_code, 200, baseline_summary.text)
        baseline_payload = baseline_summary.json()["data"]

        todo_id = self._create_message(
            message_type="todo",
            priority="urgent",
            title="待办消息",
            target_route_payload_json='{"action":"detail","repair_order_id":101}',
        )
        notice_id = self._create_message(
            message_type="notice", priority="normal", title="普通消息"
        )
        self._create_message(
            message_type="announcement",
            priority="important",
            title="失效消息",
            status="archived",
        )
        expired_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="过期消息",
            expires_at=datetime.now(UTC) - timedelta(minutes=5),
        )

        summary = self.client.get("/api/v1/messages/summary", headers=self._headers())
        self.assertEqual(summary.status_code, 200, summary.text)
        payload = summary.json()["data"]
        self.assertEqual(payload["total_count"], baseline_payload["total_count"] + 4)
        self.assertEqual(
            payload["unread_count"],
            baseline_payload["unread_count"] + 2,
        )
        self.assertEqual(
            payload["todo_unread_count"],
            baseline_payload["todo_unread_count"] + 1,
        )
        self.assertEqual(
            payload["urgent_unread_count"],
            baseline_payload["urgent_unread_count"] + 1,
        )

        list_resp = self.client.get(
            f"/api/v1/messages?keyword={self.case_token}",
            headers=self._headers(),
        )
        self.assertEqual(list_resp.status_code, 200, list_resp.text)
        items = list_resp.json()["data"]["items"]
        self.assertEqual(len(items), 2)
        self.assertTrue(all(item["status"] == "active" for item in items))
        self.assertNotIn(expired_id, [item["id"] for item in items])
        self.assertEqual(items[0]["target_page_code"], "production")
        self.assertEqual(items[0]["target_tab_code"], "production_repair_orders")
        self.assertIn(items[0]["delivery_status"], {"pending", "delivered", "failed"})
        self.assertIn("delivery_attempt_count", items[0])
        self.assertEqual(
            items[0]["target_route_payload_json"],
            '{"action":"detail","repair_order_id":101}',
        )

        todo_only = self.client.get(
            f"/api/v1/messages?todo_only=true&keyword={self.case_token}",
            headers=self._headers(),
        )
        self.assertEqual(todo_only.status_code, 200, todo_only.text)
        self.assertEqual(todo_only.json()["data"]["total"], 1)

        inactive_resp = self.client.get(
            f"/api/v1/messages?active_only=false&keyword={self.case_token}",
            headers=self._headers(),
        )
        self.assertEqual(inactive_resp.status_code, 200, inactive_resp.text)
        inactive_items = {
            item["id"]: item for item in inactive_resp.json()["data"]["items"]
        }
        self.assertEqual(inactive_items[expired_id]["status"], "expired")
        self.assertEqual(inactive_items[expired_id]["inactive_reason"], "expired")

        batch = self.client.post(
            "/api/v1/messages/read-batch",
            headers=self._headers(),
            json={"message_ids": [todo_id, notice_id]},
        )
        self.assertEqual(batch.status_code, 200, batch.text)
        self.assertEqual(batch.json()["data"]["updated"], 2)

        summary_after = self.client.get(
            "/api/v1/messages/summary", headers=self._headers()
        )
        self.assertEqual(summary_after.status_code, 200, summary_after.text)
        self.assertEqual(
            summary_after.json()["data"]["unread_count"],
            baseline_payload["unread_count"],
        )
        self.assertEqual(
            summary_after.json()["data"]["todo_unread_count"],
            baseline_payload["todo_unread_count"] + 1,
        )
        self.assertEqual(
            summary_after.json()["data"]["urgent_unread_count"],
            baseline_payload["urgent_unread_count"] + 1,
        )

    def test_unread_count_mark_read_and_mark_all_read_endpoints(self) -> None:
        baseline_response = self.client.get(
            "/api/v1/messages/unread-count",
            headers=self._headers(),
        )
        self.assertEqual(baseline_response.status_code, 200, baseline_response.text)
        self.assertEqual(baseline_response.json()["code"], 0)
        self.assertEqual(set(baseline_response.json()["data"].keys()), {"unread_count"})
        baseline_unread = baseline_response.json()["data"]["unread_count"]

        first_message_id = self._create_message(
            message_type="todo",
            priority="important",
            title="接口已读-1",
        )
        second_message_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="接口已读-2",
        )

        unread_response = self.client.get(
            "/api/v1/messages/unread-count",
            headers=self._headers(),
        )
        self.assertEqual(unread_response.status_code, 200, unread_response.text)
        self.assertEqual(
            unread_response.json()["data"]["unread_count"],
            baseline_unread + 2,
        )

        mark_read_response = self.client.post(
            f"/api/v1/messages/{first_message_id}/read",
            headers=self._headers(),
        )
        self.assertEqual(mark_read_response.status_code, 200, mark_read_response.text)
        self.assertEqual(mark_read_response.json()["data"], {})

        after_mark_one = self.client.get(
            "/api/v1/messages/unread-count",
            headers=self._headers(),
        )
        self.assertEqual(after_mark_one.status_code, 200, after_mark_one.text)
        self.assertEqual(
            after_mark_one.json()["data"]["unread_count"],
            baseline_unread + 1,
        )
        unread_before_all = after_mark_one.json()["data"]["unread_count"]

        not_found_response = self.client.post(
            "/api/v1/messages/999999999/read",
            headers=self._headers(),
        )
        self.assertEqual(not_found_response.status_code, 404, not_found_response.text)

        mark_all_response = self.client.post(
            "/api/v1/messages/read-all",
            headers=self._headers(),
        )
        self.assertEqual(mark_all_response.status_code, 200, mark_all_response.text)
        self.assertEqual(mark_all_response.json()["code"], 0)
        self.assertGreaterEqual(
            mark_all_response.json()["data"]["updated"],
            unread_before_all,
        )

        unread_after_all = self.client.get(
            "/api/v1/messages/unread-count",
            headers=self._headers(),
        )
        self.assertEqual(unread_after_all.status_code, 200, unread_after_all.text)
        self.assertEqual(unread_after_all.json()["data"]["unread_count"], 0)

        db = SessionLocal()
        try:
            recipients = (
                db.execute(
                    select(MessageRecipient).where(
                        MessageRecipient.message_id.in_(
                            [first_message_id, second_message_id]
                        ),
                        MessageRecipient.recipient_user_id == 1,
                    )
                )
                .scalars()
                .all()
            )
        finally:
            db.close()

        self.assertEqual(len(recipients), 2)
        self.assertTrue(all(recipient.is_read for recipient in recipients))
        self.assertTrue(all(recipient.read_at is not None for recipient in recipients))

    def test_register_request_creates_pending_approval_message(self) -> None:
        account = f"p{time.time_ns() % 1000000000:09d}"
        password = f"Pwd!{account}!Z9"

        register_response = self.client.post(
            "/api/v1/auth/register",
            json={"account": account, "password": password},
        )
        self.assertEqual(register_response.status_code, 202, register_response.text)

        db = SessionLocal()
        try:
            request_row = (
                db.execute(
                    select(RegistrationRequest).where(
                        RegistrationRequest.account == account
                    )
                )
                .scalars()
                .first()
            )
            self.assertIsNotNone(request_row)
            self.registration_request_ids.append(request_row.id)
            message = (
                db.execute(
                    select(Message).where(
                        Message.source_type == "registration_request",
                        Message.source_id == str(request_row.id),
                        Message.dedupe_key
                        == f"registration_request_pending_{request_row.id}",
                    )
                )
                .scalars()
                .first()
            )
            self.assertIsNotNone(message)
            self.message_ids.append(message.id)
        finally:
            db.close()

        self.assertEqual(message.message_type, "todo")
        self.assertEqual(message.target_page_code, "user")
        self.assertEqual(message.target_tab_code, "registration_approval")
        self.assertEqual(
            message.target_route_payload_json,
            '{"action":"detail","request_id":%s}' % request_row.id,
        )

    def test_message_detail_and_jump_target_endpoint_return_delivery_context(
        self,
    ) -> None:
        db = SessionLocal()
        try:
            message = create_message_for_users(
                db,
                message_type="todo",
                priority="important",
                title=f"{self.case_token}-详情消息",
                summary="需要查看详情",
                content="完整消息正文",
                source_module=None,
                source_type=None,
                source_id=None,
                source_code="MSG-DETAIL-1",
                target_page_code="production",
                target_tab_code="production_order_management",
                target_route_payload_json='{"action":"detail","order_id":22}',
                recipient_user_ids=[1],
                dedupe_key=f"{self.case_token}-detail-endpoint",
                created_by_user_id=1,
            )
            self.message_ids.append(message.id)
            recipient = (
                db.execute(
                    select(MessageRecipient).where(
                        MessageRecipient.message_id == message.id
                    )
                )
                .scalars()
                .first()
            )
            recipient.delivery_status = "failed"
            recipient.delivery_attempt_count = 2
            recipient.last_failure_reason = "no_active_connection"
            db.commit()
        finally:
            db.close()

        detail_response = self.client.get(
            f"/api/v1/messages/{message.id}",
            headers=self._headers(),
        )
        self.assertEqual(detail_response.status_code, 200, detail_response.text)
        detail_payload = detail_response.json()["data"]
        self.assertEqual(detail_payload["id"], message.id)
        self.assertEqual(detail_payload["delivery_status"], "failed")
        self.assertEqual(detail_payload["delivery_attempt_count"], 2)
        self.assertIn("重试", detail_payload["failure_reason_hint"])

        jump_response = self.client.get(
            f"/api/v1/messages/{message.id}/jump-target",
            headers=self._headers(),
        )
        self.assertEqual(jump_response.status_code, 200, jump_response.text)
        jump_payload = jump_response.json()["data"]
        self.assertTrue(jump_payload["can_jump"])
        self.assertEqual(jump_payload["target_page_code"], "production")
        self.assertEqual(jump_payload["target_tab_code"], "production_order_management")

    def test_jump_target_endpoint_returns_precise_disabled_reason_matrix(self) -> None:
        archived_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="跳转禁用-归档",
            status="archived",
        )
        expired_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="跳转禁用-过期",
            expires_at=datetime.now(UTC) - timedelta(minutes=1),
        )
        no_permission_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="跳转禁用-无权限",
            target_page_code="production",
        )
        source_unavailable_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="跳转禁用-来源失效",
            status="src_unavailable",
        )
        missing_target_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="跳转禁用-目标缺失",
            target_page_code="",
        )

        with patch(
            "app.services.message_service.get_user_permission_codes",
            return_value={"page.message_center.view"},
        ):
            archived_response = self.client.get(
                f"/api/v1/messages/{archived_id}/jump-target",
                headers=self._headers(),
            )
            expired_response = self.client.get(
                f"/api/v1/messages/{expired_id}/jump-target",
                headers=self._headers(),
            )
            no_permission_response = self.client.get(
                f"/api/v1/messages/{no_permission_id}/jump-target",
                headers=self._headers(),
            )
            source_unavailable_response = self.client.get(
                f"/api/v1/messages/{source_unavailable_id}/jump-target",
                headers=self._headers(),
            )
            missing_target_response = self.client.get(
                f"/api/v1/messages/{missing_target_id}/jump-target",
                headers=self._headers(),
            )

        self.assertEqual(archived_response.status_code, 200, archived_response.text)
        self.assertEqual(
            archived_response.json()["data"]["disabled_reason"],
            "archived",
        )
        self.assertEqual(expired_response.status_code, 200, expired_response.text)
        self.assertEqual(
            expired_response.json()["data"]["disabled_reason"],
            "expired",
        )
        self.assertEqual(
            no_permission_response.json()["data"]["disabled_reason"],
            "no_permission",
        )
        self.assertEqual(
            source_unavailable_response.json()["data"]["disabled_reason"],
            "source_unavailable",
        )
        self.assertEqual(
            missing_target_response.json()["data"]["disabled_reason"],
            "missing_target",
        )

    def test_list_messages_returns_precise_inactive_reason(self) -> None:
        archived_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="归档消息",
            status="archived",
        )
        no_permission_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="无权限消息",
            target_page_code="production",
        )
        source_unavailable_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="来源失效消息",
            status="disabled",
            target_page_code="unknown_page",
        )

        with patch(
            "app.services.message_service.get_user_permission_codes",
            return_value={"page.message_center.view"},
        ):
            response = self.client.get(
                f"/api/v1/messages?active_only=false&keyword={self.case_token}",
                headers=self._headers(),
            )

        self.assertEqual(response.status_code, 200, response.text)
        items = {item["id"]: item for item in response.json()["data"]["items"]}
        self.assertEqual(items[archived_id]["status"], "archived")
        self.assertEqual(items[archived_id]["inactive_reason"], "archived")
        self.assertEqual(items[no_permission_id]["status"], "no_permission")
        self.assertEqual(items[no_permission_id]["inactive_reason"], "no_permission")
        self.assertEqual(items[source_unavailable_id]["status"], "source_unavailable")
        self.assertEqual(
            items[source_unavailable_id]["inactive_reason"],
            "source_unavailable",
        )

    def test_publish_announcement_generates_recipient_records_by_range(self) -> None:
        suffix = time.time_ns()
        role = self._create_role(f"announcement_role_{suffix}", "公告角色")
        role_user = self._create_user(
            username=f"announcement_role_user_{suffix}", role=role
        )
        direct_role = self._create_role(f"direct_role_{suffix}", "直发角色")
        direct_user = self._create_user(
            username=f"announcement_direct_user_{suffix}",
            role=direct_role,
        )

        all_response = self.client.post(
            "/api/v1/messages/announcements",
            headers=self._headers(),
            json={
                "title": "全员公告",
                "content": f"{self.case_token} 发送给全部启用用户",
                "priority": "important",
                "range_type": "all",
                "role_codes": [],
                "user_ids": [],
                "expires_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
            },
        )
        self.assertEqual(all_response.status_code, 200, all_response.text)
        all_payload = all_response.json()["data"]
        self.message_ids.append(all_payload["message_id"])
        self.assertGreaterEqual(all_payload["recipient_count"], 3)

        roles_response = self.client.post(
            "/api/v1/messages/announcements",
            headers=self._headers(),
            json={
                "title": "角色公告",
                "content": f"{self.case_token} 发送给指定角色",
                "priority": "urgent",
                "range_type": "roles",
                "role_codes": [role.code],
                "user_ids": [],
                "expires_at": None,
            },
        )
        self.assertEqual(roles_response.status_code, 200, roles_response.text)
        roles_payload = roles_response.json()["data"]
        self.message_ids.append(roles_payload["message_id"])
        self.assertEqual(roles_payload["recipient_count"], 1)

        users_response = self.client.post(
            "/api/v1/messages/announcements",
            headers=self._headers(),
            json={
                "title": "定向公告",
                "content": f"{self.case_token} 发送给指定用户",
                "priority": "normal",
                "range_type": "users",
                "role_codes": [],
                "user_ids": [direct_user.id],
                "expires_at": None,
            },
        )
        self.assertEqual(users_response.status_code, 200, users_response.text)
        users_payload = users_response.json()["data"]
        self.message_ids.append(users_payload["message_id"])
        self.assertEqual(users_payload["recipient_count"], 1)

        db = SessionLocal()
        try:
            role_recipient_ids = set(
                db.execute(
                    select(MessageRecipient.recipient_user_id).where(
                        MessageRecipient.message_id == roles_payload["message_id"]
                    )
                )
                .scalars()
                .all()
            )
            user_recipient_ids = set(
                db.execute(
                    select(MessageRecipient.recipient_user_id).where(
                        MessageRecipient.message_id == users_payload["message_id"]
                    )
                )
                .scalars()
                .all()
            )
            all_recipient_ids = set(
                db.execute(
                    select(MessageRecipient.recipient_user_id).where(
                        MessageRecipient.message_id == all_payload["message_id"]
                    )
                )
                .scalars()
                .all()
            )
        finally:
            db.close()

        self.assertEqual(role_recipient_ids, {role_user.id})
        self.assertEqual(user_recipient_ids, {direct_user.id})
        self.assertIn(1, all_recipient_ids)
        self.assertIn(role_user.id, all_recipient_ids)
        self.assertIn(direct_user.id, all_recipient_ids)

        list_resp = self.client.get(
            f"/api/v1/messages?message_type=announcement&keyword={self.case_token}",
            headers=self._headers(),
        )
        self.assertEqual(list_resp.status_code, 200, list_resp.text)
        titles = [item["title"] for item in list_resp.json()["data"]["items"]]
        self.assertIn("全员公告", titles)

    def test_public_announcements_endpoint_only_returns_active_all_announcements(self) -> None:
        suffix = time.time_ns()
        role = self._create_role(f"public_announcement_role_{suffix}", "公开公告角色")
        role_user = self._create_user(
            username=f"public_announcement_role_user_{suffix}",
            role=role,
        )
        direct_user = self._create_user(
            username=f"public_announcement_direct_user_{suffix}",
            role=role,
        )

        all_response = self.client.post(
            "/api/v1/messages/announcements",
            headers=self._headers(),
            json={
                "title": "登录页全员公告",
                "content": f"{self.case_token} 登录前可见",
                "priority": "important",
                "range_type": "all",
                "role_codes": [],
                "user_ids": [],
                "expires_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
            },
        )
        self.assertEqual(all_response.status_code, 200, all_response.text)
        all_payload = all_response.json()["data"]
        self.message_ids.append(all_payload["message_id"])

        roles_response = self.client.post(
            "/api/v1/messages/announcements",
            headers=self._headers(),
            json={
                "title": "角色公告不应公开",
                "content": f"{self.case_token} 仅角色可见",
                "priority": "normal",
                "range_type": "roles",
                "role_codes": [role.code],
                "user_ids": [],
                "expires_at": None,
            },
        )
        self.assertEqual(roles_response.status_code, 200, roles_response.text)
        self.message_ids.append(roles_response.json()["data"]["message_id"])

        users_response = self.client.post(
            "/api/v1/messages/announcements",
            headers=self._headers(),
            json={
                "title": "定向公告不应公开",
                "content": f"{self.case_token} 仅用户可见",
                "priority": "urgent",
                "range_type": "users",
                "role_codes": [],
                "user_ids": [direct_user.id, role_user.id],
                "expires_at": None,
            },
        )
        self.assertEqual(users_response.status_code, 200, users_response.text)
        self.message_ids.append(users_response.json()["data"]["message_id"])

        public_response = self.client.get("/api/v1/messages/public-announcements")
        self.assertEqual(public_response.status_code, 200, public_response.text)
        payload = public_response.json()["data"]
        titles = [item["title"] for item in payload["items"]]

        self.assertIn("登录页全员公告", titles)
        self.assertNotIn("角色公告不应公开", titles)
        self.assertNotIn("定向公告不应公开", titles)

    def test_active_announcements_endpoint_and_offline_endpoint(self) -> None:
        active_response = self.client.post(
            "/api/v1/messages/announcements",
            headers=self._headers(),
            json={
                "title": "生效公告",
                "content": f"{self.case_token} 需要出现在生效列表",
                "priority": "urgent",
                "range_type": "all",
                "role_codes": [],
                "user_ids": [],
                "expires_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
            },
        )
        self.assertEqual(active_response.status_code, 200, active_response.text)
        active_message_id = active_response.json()["data"]["message_id"]
        self.message_ids.append(active_message_id)

        archived_message_id = self._create_message(
            message_type="announcement",
            priority="urgent",
            title="已归档公告",
            status="archived",
        )
        expired_message_id = self._create_message(
            message_type="announcement",
            priority="urgent",
            title="已过期公告",
            expires_at=datetime.now(UTC) - timedelta(minutes=5),
        )

        list_response = self.client.get(
            "/api/v1/messages/announcements/active?page=1&page_size=100",
            headers=self._headers(),
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        payload = list_response.json()["data"]
        item_by_id = {item["id"]: item for item in payload["items"]}
        self.assertIn(active_message_id, item_by_id)
        self.assertEqual(item_by_id[active_message_id]["status"], "active")
        self.assertEqual(item_by_id[active_message_id]["title"], "生效公告")
        self.assertNotIn(archived_message_id, item_by_id)
        self.assertNotIn(expired_message_id, item_by_id)

        offline_response = self.client.post(
            f"/api/v1/messages/announcements/{active_message_id}/offline",
            headers=self._headers(),
        )
        self.assertEqual(offline_response.status_code, 200, offline_response.text)
        self.assertEqual(
            offline_response.json()["data"],
            {"message_id": active_message_id, "status": "offline"},
        )

        list_after_offline = self.client.get(
            "/api/v1/messages/announcements/active?page=1&page_size=100",
            headers=self._headers(),
        )
        self.assertEqual(
            list_after_offline.status_code, 200, list_after_offline.text
        )
        after_item_by_id = {
            item["id"]: item for item in list_after_offline.json()["data"]["items"]
        }
        self.assertNotIn(active_message_id, after_item_by_id)

    def test_message_module_exposes_announcement_management_catalog_and_capability(
        self,
    ) -> None:
        page_by_code = {item["code"]: item for item in PAGE_CATALOG}
        self.assertIn("announcement_management", page_by_code)
        self.assertEqual(
            page_by_code["announcement_management"]["parent_code"],
            "message",
        )

        page_permission_by_code = {
            item.permission_code: item for item in PAGE_PERMISSION_CATALOG
        }
        self.assertIn("page.announcement_management.view", page_permission_by_code)

        action_permission_by_code = {
            item.permission_code: item for item in ACTION_PERMISSION_CATALOG
        }
        self.assertIn("message.announcements.view", action_permission_by_code)
        self.assertIn("message.announcements.offline", action_permission_by_code)
        self.assertEqual(
            action_permission_by_code[
                "message.announcements.view"
            ].parent_permission_code,
            "page.announcement_management.view",
        )
        self.assertEqual(
            action_permission_by_code[
                "message.announcements.offline"
            ].parent_permission_code,
            "page.announcement_management.view",
        )

        feature_by_code = {
            item.permission_code: item for item in FEATURE_DEFINITIONS
        }
        self.assertIn("feature.message.announcement.view", feature_by_code)
        self.assertIn("feature.message.announcement.offline", feature_by_code)
        self.assertEqual(
            feature_by_code["feature.message.announcement.view"].page_code,
            "announcement_management",
        )
        self.assertEqual(
            set(
                feature_by_code[
                    "feature.message.announcement.view"
                ].action_permission_codes
            ),
            {"message.announcements.view"},
        )
        self.assertEqual(
            set(
                feature_by_code[
                    "feature.message.announcement.offline"
                ].action_permission_codes
            ),
            {"message.announcements.offline"},
        )
        self.assertEqual(
            feature_by_code[
                "feature.message.announcement.offline"
            ].dependency_permission_codes,
            ("feature.message.announcement.view",),
        )

        db = SessionLocal()
        try:
            with patch.object(authz_service, "_ensure_authz_defaults_once"):
                catalog = authz_service.get_capability_pack_catalog(
                    db,
                    module_code="message",
                )
        finally:
            db.close()

        capability_by_code = {
            item["capability_code"]: item for item in catalog["capability_packs"]
        }
        self.assertIn("feature.message.announcement.view", capability_by_code)
        self.assertIn("feature.message.announcement.offline", capability_by_code)
        self.assertEqual(
            capability_by_code["feature.message.announcement.view"]["page_code"],
            "announcement_management",
        )
        self.assertEqual(
            capability_by_code["feature.message.announcement.view"]["page_name"],
            "公告管理",
        )
        self.assertEqual(
            capability_by_code["feature.message.announcement.offline"]["group_name"],
            "公告管理",
        )

    def test_registration_approval_message_targets_change_password_section(
        self,
    ) -> None:
        account = f"u{time.time_ns()}"[:10]
        password = f"Pwd!{'!'.join(account)}!Z9"

        register_response = self.client.post(
            "/api/v1/auth/register",
            json={"account": account, "password": password},
        )
        self.assertEqual(register_response.status_code, 202, register_response.text)

        db = SessionLocal()
        try:
            request_row = (
                db.execute(
                    select(RegistrationRequest).where(
                        RegistrationRequest.account == account
                    )
                )
                .scalars()
                .first()
            )
            self.assertIsNotNone(request_row)
            self.registration_request_ids.append(request_row.id)
        finally:
            db.close()

        approve_response = self.client.post(
            f"/api/v1/auth/register-requests/{request_row.id}/approve",
            headers=self._headers(),
            json={
                "account": account,
                "password": password,
                "role_code": "quality_admin",
                "stage_id": None,
            },
        )
        self.assertEqual(approve_response.status_code, 200, approve_response.text)

        db = SessionLocal()
        try:
            message = (
                db.execute(
                    select(Message).where(
                        Message.source_type == "registration_request",
                        Message.source_id == str(request_row.id),
                        Message.dedupe_key == f"reg_approved_{request_row.id}",
                    )
                )
                .scalars()
                .first()
            )
            self.assertIsNotNone(message)
            self.message_ids.append(message.id)
            created_user = (
                db.execute(select(User).where(User.username == account))
                .scalars()
                .first()
            )
            self.assertIsNotNone(created_user)
            self.created_user_ids.append(created_user.id)
        finally:
            db.close()

        self.assertEqual(message.target_page_code, "user")
        self.assertEqual(message.target_tab_code, "account_settings")
        self.assertEqual(
            message.summary,
            f"账号 {account} 已创建，请使用初始密码登录；首次登录后系统将要求修改密码。",
        )
        self.assertEqual(
            message.target_route_payload_json,
            '{"action": "change_password"}',
        )

    def test_product_and_craft_source_messages_include_jump_targets(self) -> None:
        product_id = int(time.time_ns() % 1_000_000_000)
        template_id = product_id + 1
        db = SessionLocal()
        try:
            _notify_product_version_activated(
                db=db,
                product=SimpleNamespace(id=product_id, name=f"{self.case_token}-产品A"),
                revision=SimpleNamespace(version=3, version_label="V1.2"),
                operator=SimpleNamespace(id=1, username="admin"),
            )
            _notify_craft_template_published(
                db=db,
                template=SimpleNamespace(
                    id=template_id,
                    version=5,
                    template_name=f"{self.case_token}-模板A",
                    product=SimpleNamespace(name=f"{self.case_token}-产品A"),
                ),
                operator=SimpleNamespace(id=1, username="admin"),
            )
            rows = (
                db.execute(
                    select(Message).where(
                        Message.dedupe_key.in_(
                            [
                                f"product_version_activated_{product_id}_3",
                                f"craft_template_published_{template_id}_5",
                            ]
                        )
                    )
                )
                .scalars()
                .all()
            )
            self.message_ids.extend(row.id for row in rows)
        finally:
            db.close()

        messages = {row.source_module: row for row in rows}
        self.assertEqual(messages["product"].target_page_code, "product")
        self.assertEqual(
            messages["product"].target_tab_code,
            "product_version_management",
        )
        self.assertIn(
            f'"product_id": {product_id}',
            messages["product"].target_route_payload_json,
        )
        self.assertEqual(messages["craft"].target_page_code, "craft")
        self.assertEqual(
            messages["craft"].target_tab_code,
            "production_process_config",
        )
        self.assertIn(
            f'"template_id": {template_id}',
            messages["craft"].target_route_payload_json,
        )
        self.assertIn('"version": 5', messages["craft"].target_route_payload_json)

    def test_quality_and_production_source_messages_include_jump_targets(self) -> None:
        db = SessionLocal()
        try:
            product = Product(name=f"{self.case_token}-质量生产产品")
            process = Process(
                code=f"{self.case_token}-PROC",
                name=f"{self.case_token}-工序",
            )
            db.add_all([product, process])
            db.flush()
            self.product_ids.append(product.id)
            self.process_ids.append(process.id)

            order = ProductionOrder(
                order_code=f"{self.case_token}-ORDER",
                product_id=product.id,
                quantity=20,
                status="in_progress",
                current_process_code=process.code,
                due_date=date.today() - timedelta(days=1),
                created_by_user_id=1,
            )
            db.add(order)
            db.flush()
            self.production_order_ids.append(order.id)

            order_process = ProductionOrderProcess(
                order_id=order.id,
                process_id=process.id,
                process_code=process.code,
                process_name=process.name,
                process_order=1,
                status="in_progress",
            )
            db.add(order_process)
            db.flush()
            self.production_order_process_ids.append(order_process.id)

            record = FirstArticleRecord(
                order_id=order.id,
                order_process_id=order_process.id,
                operator_user_id=1,
                verification_date=date.today(),
                verification_code=f"FA-{time.time_ns()}",
                result="failed",
            )
            db.add(record)
            db.flush()
            self.first_article_record_ids.append(record.id)

            stats = run_message_maintenance(db, now=datetime.now(UTC))
            db.commit()

            rows = (
                db.execute(
                    select(Message).where(
                        Message.dedupe_key.in_(
                            [
                                f"first_article_failed_{record.id}",
                                f"production_order_overdue_{order.id}_{order.due_date}",
                            ]
                        )
                    )
                )
                .scalars()
                .all()
            )
            self.message_ids.extend(row.id for row in rows)
        finally:
            db.close()

        self.assertGreaterEqual(stats["source_unavailable_updated"], 0)
        self.assertEqual(len(rows), 2)
        messages = {row.source_type: row for row in rows}
        self.assertEqual(messages["first_article_record"].target_page_code, "quality")
        self.assertEqual(
            messages["first_article_record"].target_tab_code,
            "first_article_management",
        )
        self.assertIn(
            f'"record_id":{record.id}',
            messages["first_article_record"].target_route_payload_json,
        )
        self.assertEqual(messages["production_order"].target_page_code, "production")
        self.assertEqual(
            messages["production_order"].target_tab_code,
            "production_order_management",
        )
        self.assertIn(
            f'"order_id":{order.id}',
            messages["production_order"].target_route_payload_json,
        )

    def test_message_websocket_endpoint_connects_and_rejects_invalid_token(
        self,
    ) -> None:
        with self.client.websocket_connect(
            "/api/v1/messages/ws"
        ) as websocket:
            websocket.send_json({"type": "auth", "token": self.token})
            payload = websocket.receive_json()
            self.assertEqual(payload["event"], "connected")
            self.assertEqual(payload["user_id"], 1)
            self.assertIn("unread_count", payload)

            websocket.send_text("ping")
            self.assertEqual(websocket.receive_text(), "pong")

        with self.assertRaises(WebSocketDisconnect) as ctx:
            with self.client.websocket_connect(
                "/api/v1/messages/ws"
            ) as websocket:
                websocket.send_json({"type": "auth", "token": "invalid-token"})
                websocket.receive_text()

        self.assertEqual(ctx.exception.code, 4001)

    def test_push_failure_marks_recipient_failed_with_timestamp(self) -> None:
        message_id = self._create_message(
            message_type="notice",
            priority="normal",
            title="推送失败留痕",
        )
        failed_at = datetime.now(UTC)

        async def _run_push_failure() -> None:
            with patch(
                "app.services.message_push_service.push_message_created",
                new=AsyncMock(return_value=(False, "no_active_connection", failed_at)),
            ):
                await _push_message_created_for_recipient(message_id, 1)

        db = SessionLocal()
        try:
            recipient = (
                db.execute(
                    select(MessageRecipient).where(
                        MessageRecipient.message_id == message_id,
                        MessageRecipient.recipient_user_id == 1,
                    )
                )
                .scalars()
                .one()
            )
            recipient.delivery_status = "pending"
            recipient.delivery_attempt_count = 0
            recipient.last_push_at = None
            recipient.last_failure_reason = None
            recipient.next_retry_at = None
            recipient.delivered_at = None
            db.commit()
        finally:
            db.close()

        asyncio.run(_run_push_failure())

        db = SessionLocal()
        try:
            recipient = (
                db.execute(
                    select(MessageRecipient).where(
                        MessageRecipient.message_id == message_id,
                        MessageRecipient.recipient_user_id == 1,
                    )
                )
                .scalars()
                .one()
            )
        finally:
            db.close()

        self.assertEqual(recipient.delivery_status, "failed")
        self.assertIsNone(recipient.delivered_at)
        self.assertIsNotNone(recipient.last_push_at)
        self.assertEqual(recipient.last_failure_reason, "no_active_connection")
        self.assertEqual(recipient.delivery_attempt_count, 1)
        self.assertIsNotNone(recipient.next_retry_at)

        db = SessionLocal()
        try:
            logs = (
                db.execute(
                    select(AuditLog).where(
                        AuditLog.action_code == "message.delivery_state_changed",
                        AuditLog.target_name == f"message:{message_id}/user:1",
                    )
                )
                .scalars()
                .all()
            )
        finally:
            db.close()

        self.assertGreaterEqual(len(logs), 1)

    def test_sync_create_message_path_delivers_without_running_loop(self) -> None:
        with patch(
            "app.services.message_push_service.message_connection_manager.push_to_user",
            new=AsyncMock(return_value=(True, None)),
        ):
            message_id = self._create_message(
                message_type="notice",
                priority="important",
                title="同步入口首次投递",
            )

        db = SessionLocal()
        try:
            recipient = (
                db.execute(
                    select(MessageRecipient).where(
                        MessageRecipient.message_id == message_id,
                        MessageRecipient.recipient_user_id == 1,
                    )
                )
                .scalars()
                .one()
            )
        finally:
            db.close()

        self.assertEqual(recipient.delivery_status, "delivered")
        self.assertEqual(recipient.delivery_attempt_count, 1)
        self.assertIsNotNone(recipient.delivered_at)

    def test_message_maintenance_endpoint_runs_delivery_closure(self) -> None:
        with patch(
            "app.api.v1.endpoints.messages.run_message_delivery_maintenance_once",
            new=AsyncMock(
                return_value={
                    "pending_compensated": 2,
                    "failed_retried": 1,
                    "source_unavailable_updated": 3,
                    "archived_messages": 4,
                }
            ),
        ) as mocked_run:
            response = self.client.post(
                "/api/v1/messages/maintenance/run",
                headers=self._headers(),
            )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(
            response.json()["data"],
            {
                "pending_compensated": 2,
                "failed_retried": 1,
                "source_unavailable_updated": 3,
                "archived_messages": 4,
            },
        )
        mocked_run.assert_awaited_once()

    def test_message_dedupe_key_has_database_unique_constraint(self) -> None:
        dedupe_key = f"{self.case_token}-dedupe-constraint"
        db = SessionLocal()
        try:
            first = Message(
                message_type="notice",
                priority="normal",
                title="唯一约束测试-1",
                dedupe_key=dedupe_key,
                status="active",
                published_at=datetime.now(UTC),
            )
            second = Message(
                message_type="notice",
                priority="normal",
                title="唯一约束测试-2",
                dedupe_key=dedupe_key,
                status="active",
                published_at=datetime.now(UTC),
            )
            db.add(first)
            db.commit()
            self.message_ids.append(first.id)

            db.add(second)
            with self.assertRaises(IntegrityError):
                db.commit()
            db.rollback()
        finally:
            db.close()

    def test_message_maintenance_marks_missing_source_unavailable(self) -> None:
        db = SessionLocal()
        try:
            message = create_message_for_users(
                db,
                message_type="notice",
                priority="normal",
                title=f"{self.case_token}-来源失效同步",
                summary="来源记录已不存在",
                source_module="user",
                source_type="registration_request",
                source_id="999999999",
                source_code="REG-MISSING",
                recipient_user_ids=[1],
                dedupe_key=f"{self.case_token}-missing-source",
                created_by_user_id=1,
            )
            self.message_ids.append(message.id)

            stats = run_message_maintenance(db, now=datetime.now(UTC))
            db.commit()
            db.refresh(message)
            updated_status = message.status
        finally:
            db.close()

        self.assertEqual(updated_status, "src_unavailable")
        self.assertGreaterEqual(stats["source_unavailable_updated"], 1)


class MessageAnnouncementContractTest(unittest.TestCase):
    def test_active_announcement_endpoint_calls_service_and_wraps_response(self) -> None:
        expected_item = AnnouncementManagementItem(
            id=101,
            message_type="announcement",
            priority="important",
            title="公告 A",
            summary="摘要",
            content="正文",
            source_module="message",
            source_type="announcement",
            source_code="all",
            target_page_code=None,
            target_tab_code=None,
            target_route_payload_json=None,
            status="active",
            inactive_reason=None,
            published_at=datetime.now(UTC),
            expires_at=None,
        )

        with patch.object(
            message_endpoint,
            "list_active_announcements",
            return_value=([expected_item], 1),
            create=True,
        ) as mocked_list:
            response = message_endpoint.api_list_active_announcements(
                page=2,
                page_size=5,
                priority="important",
                db=MagicMock(),
                current_user=SimpleNamespace(id=1),
            )

        mocked_list.assert_called_once()
        self.assertEqual(response.code, 0)
        self.assertEqual(response.data.total, 1)
        self.assertEqual(response.data.page, 2)
        self.assertEqual(response.data.page_size, 5)
        self.assertEqual(response.data.items[0].id, 101)
        self.assertEqual(response.data.items[0].title, "公告 A")

    def test_offline_announcement_endpoint_calls_service_and_wraps_response(self) -> None:
        expected_result = AnnouncementOfflineResult(message_id=101, status="offline")
        db = MagicMock()

        with (
            patch.object(
                message_endpoint,
                "offline_announcement",
                return_value=expected_result,
                create=True,
            ) as mocked_offline,
        ):
            response = message_endpoint.api_offline_announcement(
                message_id=101,
                db=db,
                current_user=SimpleNamespace(id=1, username="admin"),
            )

        mocked_offline.assert_called_once()
        db.commit.assert_called_once()
        self.assertEqual(response.code, 0)
        self.assertEqual(response.data.message_id, 101)
        self.assertEqual(response.data.status, "offline")

    def test_message_module_exposes_announcement_management_catalog_contract(
        self,
    ) -> None:
        page_by_code = {item["code"]: item for item in PAGE_CATALOG}
        self.assertIn("announcement_management", page_by_code)
        self.assertEqual(
            page_by_code["announcement_management"]["parent_code"],
            "message",
        )

        page_permission_by_code = {
            item.permission_code: item for item in PAGE_PERMISSION_CATALOG
        }
        self.assertIn("page.announcement_management.view", page_permission_by_code)

        action_permission_by_code = {
            item.permission_code: item for item in ACTION_PERMISSION_CATALOG
        }
        self.assertIn("message.announcements.view", action_permission_by_code)
        self.assertIn("message.announcements.offline", action_permission_by_code)
        self.assertEqual(
            action_permission_by_code[
                "message.announcements.view"
            ].parent_permission_code,
            "page.announcement_management.view",
        )
        self.assertEqual(
            action_permission_by_code[
                "message.announcements.offline"
            ].parent_permission_code,
            "page.announcement_management.view",
        )

        feature_by_code = {
            item.permission_code: item for item in FEATURE_DEFINITIONS
        }
        self.assertIn("feature.message.announcement.view", feature_by_code)
        self.assertIn("feature.message.announcement.offline", feature_by_code)
        self.assertEqual(
            feature_by_code["feature.message.announcement.view"].page_code,
            "announcement_management",
        )
        self.assertEqual(
            set(
                feature_by_code[
                    "feature.message.announcement.view"
                ].action_permission_codes
            ),
            {"message.announcements.view"},
        )
        self.assertEqual(
            set(
                feature_by_code[
                    "feature.message.announcement.offline"
                ].action_permission_codes
            ),
            {"message.announcements.offline"},
        )
        self.assertEqual(
            feature_by_code[
                "feature.message.announcement.offline"
            ].dependency_permission_codes,
            ("feature.message.announcement.view",),
        )

        with (
            patch.object(authz_service, "_ensure_authz_defaults_once"),
            patch.object(
                authz_service,
                "_authz_read_revision_state",
                return_value=({"message": 1}, "rev-message"),
            ),
            patch.object(
                authz_service,
                "_normalize_capability_pack_module_code",
                return_value=("message", ["message"]),
            ),
        ):
            catalog = authz_service.get_capability_pack_catalog(
                MagicMock(),
                module_code="message",
            )

        capability_by_code = {
            item["capability_code"]: item for item in catalog["capability_packs"]
        }
        self.assertIn("feature.message.announcement.view", capability_by_code)
        self.assertIn("feature.message.announcement.offline", capability_by_code)
        self.assertEqual(
            capability_by_code["feature.message.announcement.view"]["page_code"],
            "announcement_management",
        )
        self.assertEqual(
            capability_by_code["feature.message.announcement.view"]["page_name"],
            "公告管理",
        )
        self.assertEqual(
            capability_by_code["feature.message.announcement.offline"]["group_name"],
            "公告管理",
        )


if __name__ == "__main__":
    unittest.main()
