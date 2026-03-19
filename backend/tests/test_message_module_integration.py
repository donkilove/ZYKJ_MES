import sys
import time
import unittest
from pathlib import Path

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.message import Message  # noqa: E402
from app.models.message_recipient import MessageRecipient  # noqa: E402
from app.services.message_service import create_message_for_users  # noqa: E402


class MessageModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.token = self._login()
        self.message_ids: list[int] = []

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
            for message_id in reversed(self.message_ids):
                db.query(MessageRecipient).filter(MessageRecipient.message_id == message_id).delete()
                db.query(Message).filter(Message.id == message_id).delete()
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

    def _create_message(self, *, message_type: str, priority: str, title: str, status: str = "active") -> int:
        db = SessionLocal()
        try:
            msg = create_message_for_users(
                db,
                message_type=message_type,
                priority=priority,
                title=title,
                summary=f"摘要-{title}",
                source_module="production",
                source_type="repair_order",
                source_id=str(int(time.time() * 1000)),
                source_code=f"SRC-{title}",
                target_page_code="production",
                target_tab_code="production_repair_orders",
                recipient_user_ids=[1],
                dedupe_key=f"msg-test-{title}-{time.time_ns()}",
                created_by_user_id=1,
            )
            if status != "active":
                msg.status = status
                db.commit()
                db.refresh(msg)
            self.message_ids.append(msg.id)
            return msg.id
        finally:
            db.close()

    def test_summary_list_and_batch_read(self) -> None:
        todo_id = self._create_message(message_type="todo", priority="urgent", title="待办消息")
        notice_id = self._create_message(message_type="notice", priority="normal", title="普通消息")
        self._create_message(message_type="announcement", priority="important", title="失效消息", status="archived")

        summary = self.client.get("/api/v1/messages/summary", headers=self._headers())
        self.assertEqual(summary.status_code, 200, summary.text)
        payload = summary.json()["data"]
        self.assertEqual(payload["total_count"], 2)
        self.assertEqual(payload["unread_count"], 2)
        self.assertEqual(payload["todo_unread_count"], 1)
        self.assertEqual(payload["urgent_unread_count"], 1)

        list_resp = self.client.get("/api/v1/messages", headers=self._headers())
        self.assertEqual(list_resp.status_code, 200, list_resp.text)
        items = list_resp.json()["data"]["items"]
        self.assertEqual(len(items), 2)
        self.assertTrue(all(item["status"] == "active" for item in items))
        self.assertEqual(items[0]["target_page_code"], "production")
        self.assertEqual(items[0]["target_tab_code"], "production_repair_orders")

        todo_only = self.client.get(
            "/api/v1/messages?todo_only=true",
            headers=self._headers(),
        )
        self.assertEqual(todo_only.status_code, 200, todo_only.text)
        self.assertEqual(todo_only.json()["data"]["total"], 1)

        batch = self.client.post(
            "/api/v1/messages/read-batch",
            headers=self._headers(),
            json={"message_ids": [todo_id, notice_id]},
        )
        self.assertEqual(batch.status_code, 200, batch.text)
        self.assertEqual(batch.json()["data"]["updated"], 2)

        summary_after = self.client.get("/api/v1/messages/summary", headers=self._headers())
        self.assertEqual(summary_after.status_code, 200, summary_after.text)
        self.assertEqual(summary_after.json()["data"]["unread_count"], 0)


if __name__ == "__main__":
    unittest.main()
