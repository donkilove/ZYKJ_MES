import sys
import time
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from typing import cast
from unittest.mock import MagicMock, patch

from sqlalchemy import select

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.message import Message  # noqa: E402
from app.models.message_recipient import MessageRecipient  # noqa: E402
from app.models.registration_request import RegistrationRequest  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.user import User  # noqa: E402
from app.core.security import get_password_hash  # noqa: E402
from app.services.assist_authorization_service import (  # noqa: E402
    review_assist_authorization,
)
from app.services.message_service import create_message_for_users  # noqa: E402


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
        self.assertEqual(payload["total_count"], baseline_payload["total_count"] + 2)
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

    def test_assist_review_message_targets_assist_approval_detail(self) -> None:
        row = SimpleNamespace(
            id=321,
            status="pending",
            requester_user_id=88,
            order_id=12,
            order_code="PO-ASSIST-321",
            process_name="切割",
            review_remark=None,
            reviewer_user_id=None,
            reviewed_at=None,
            helper=SimpleNamespace(username="helper-a"),
            requester=SimpleNamespace(username="requester-a"),
        )
        db = MagicMock()
        db.execute.return_value.scalars.return_value.first.return_value = row
        reviewer = SimpleNamespace(id=7, username="reviewer-a")

        with (
            patch(
                "app.services.assist_authorization_service.add_order_event_log",
            ),
            patch(
                "app.services.assist_authorization_service.create_message_for_users",
            ) as create_message_mock,
        ):
            result = review_assist_authorization(
                db,
                authorization_id=row.id,
                approve=False,
                reviewer=cast(User, reviewer),
                review_remark="排班冲突",
            )

        self.assertIs(result, row)
        self.assertEqual(row.status, "rejected")
        self.assertEqual(row.review_remark, "排班冲突")
        create_message_mock.assert_called_once_with(
            db,
            message_type="notice",
            priority="normal",
            title="代班申请已拒绝：PO-ASSIST-321 / 切割",
            summary="reviewer-a 拒绝代班申请，原因：排班冲突",
            source_module="production",
            source_type="assist_authorization",
            source_id="321",
            source_code="PO-ASSIST-321",
            target_page_code="production",
            target_tab_code="production_assist_approval",
            target_route_payload_json='{"action":"detail","authorization_id":321}',
            recipient_user_ids=[88],
            dedupe_key="assist_auth_review_321",
            created_by_user_id=7,
        )

    def test_registration_approval_message_targets_change_password_section(
        self,
    ) -> None:
        account = f"u{time.time_ns()}"[:10]
        password = f"Pwd!{time.time_ns()}"

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
            message.target_route_payload_json,
            '{"action": "change_password"}',
        )


if __name__ == "__main__":
    unittest.main()
