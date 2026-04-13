import sys
import time
import unittest
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import delete

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.security import get_password_hash  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.associations import user_roles  # noqa: E402
from app.models.message import Message  # noqa: E402
from app.models.message_recipient import MessageRecipient  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.message_service import create_message_for_users  # noqa: E402


class BaseAPITestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self._case_token = f"home-dashboard-{time.time_ns()}"
        self._created_message_ids: list[int] = []
        self._created_user_ids: list[int] = []
        self._created_role_ids: list[int] = []
        self._restricted_token: str | None = None
        self._token = self._login("admin", "Admin@123456")

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
            for message_id in reversed(self._created_message_ids):
                db.query(MessageRecipient).filter(
                    MessageRecipient.message_id == message_id
                ).delete()
                db.query(Message).filter(Message.id == message_id).delete()
            for user_id in reversed(self._created_user_ids):
                db.execute(delete(user_roles).where(user_roles.c.user_id == user_id))
                db.query(User).filter(User.id == user_id).delete()
            for role_id in reversed(self._created_role_ids):
                db.execute(delete(user_roles).where(user_roles.c.role_id == role_id))
                db.query(Role).filter(Role.id == role_id).delete()
            db.commit()
        finally:
            db.close()

    def _login(self, username: str, password: str) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": username, "password": password},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self._token}"}

    def _restricted_headers(self) -> dict[str, str]:
        if self._restricted_token is None:
            suffix = str(time.time_ns())
            db = SessionLocal()
            try:
                role = Role(
                    code=f"home_dash_role_{suffix}",
                    name=f"首页裁剪角色-{suffix}",
                    role_type="custom",
                    is_enabled=True,
                )
                user = User(
                    username=f"home_dash_user_{suffix}",
                    full_name=f"首页裁剪用户-{suffix}",
                    password_hash=get_password_hash("Admin@123456"),
                    is_active=True,
                    is_deleted=False,
                )
                user.roles.append(role)
                db.add_all([role, user])
                db.commit()
                db.refresh(role)
                db.refresh(user)
                self._created_role_ids.append(role.id)
                self._created_user_ids.append(user.id)
            finally:
                db.close()
            self._restricted_token = self._login(
                username=f"home_dash_user_{suffix}",
                password="Admin@123456",
            )
        return {"Authorization": f"Bearer {self._restricted_token}"}

    def _create_todo_message(self, *, priority: str) -> int:
        db = SessionLocal()
        try:
            message = create_message_for_users(
                db,
                message_type="todo",
                priority=priority,
                title=f"{self._case_token}-{priority}",
                summary="首页工作台集成测试待办",
                source_module="production",
                source_type="repair_order",
                source_id=str(time.time_ns()),
                source_code=f"{self._case_token}-SRC",
                target_page_code="production",
                target_tab_code="production_order_query",
                target_route_payload_json='{"source":"integration_test"}',
                recipient_user_ids=[1],
                dedupe_key=f"{self._case_token}-{priority}-{time.time_ns()}",
                created_by_user_id=1,
                expires_at=None,
            )
            self._created_message_ids.append(message.id)
            return message.id
        finally:
            db.close()


class TestUiHomeDashboardIntegration(BaseAPITestCase):
    def test_home_dashboard_returns_todo_risk_and_kpi_blocks(self) -> None:
        self._create_todo_message(priority="urgent")
        response = self.client.get(
            "/api/v1/ui/home-dashboard",
            headers=self._headers(),
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        self.assertIn("generated_at", payload)
        self.assertIn("todo_summary", payload)
        self.assertIn("todo_items", payload)
        self.assertIn("risk_items", payload)
        self.assertIn("kpi_items", payload)
        self.assertIn("degraded_blocks", payload)
        self.assertLessEqual(len(payload["todo_items"]), 4)
        self.assertEqual(payload["todo_summary"]["overdue_count"], 0)

        risk_items = payload["risk_items"]
        kpi_items = payload["kpi_items"]
        risk_codes = {item["code"] for item in risk_items}
        kpi_codes = {item["code"] for item in kpi_items}
        self.assertTrue({"production_exception", "quality_warning"}.issubset(risk_codes))
        self.assertTrue(
            {
                "wip_orders",
                "today_quantity",
                "first_article_pass_rate",
                "scrap_total",
            }.issubset(kpi_codes)
        )
        risk_by_code = {item["code"]: item for item in risk_items}
        kpi_by_code = {item["code"]: item for item in kpi_items}
        self.assertEqual(risk_by_code["production_exception"]["value"], "0")
        self.assertEqual(risk_by_code["production_exception"]["target_page_code"], "production")
        self.assertEqual(risk_by_code["production_exception"]["target_tab_code"], "production_order_query")
        self.assertEqual(kpi_by_code["wip_orders"]["target_page_code"], "production")
        self.assertEqual(kpi_by_code["wip_orders"]["target_tab_code"], "production_data_query")

    def test_home_dashboard_hides_production_blocks_when_page_not_visible(self) -> None:
        response = self.client.get(
            "/api/v1/ui/home-dashboard",
            headers=self._restricted_headers(),
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        risk_codes = {item["code"] for item in payload["risk_items"]}
        kpi_codes = {item["code"] for item in payload["kpi_items"]}
        self.assertTrue(all(not code.startswith("production_") for code in risk_codes))
        self.assertTrue(all(not code.startswith("quality_") for code in risk_codes))
        self.assertTrue(all(not code.startswith("production_") for code in kpi_codes))
        self.assertTrue(all(not code.startswith("quality_") for code in kpi_codes))


if __name__ == "__main__":
    unittest.main()
