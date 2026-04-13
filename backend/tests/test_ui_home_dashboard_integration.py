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
from app.models.role import Role  # noqa: E402
from app.models.user import User  # noqa: E402


class BaseAPITestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self._created_user_ids: list[int] = []
        self._created_role_ids: list[int] = []
        self._restricted_token: str | None = None
        self._token = self._login("admin", "Admin@123456")

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
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


class TestUiHomeDashboardIntegration(BaseAPITestCase):
    def test_home_dashboard_returns_todo_risk_and_kpi_blocks(self) -> None:
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

    def test_home_dashboard_hides_production_blocks_when_page_not_visible(self) -> None:
        response = self.client.get(
            "/api/v1/ui/home-dashboard",
            headers=self._restricted_headers(),
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        risk_codes = {item["code"] for item in payload["risk_items"]}
        self.assertNotIn("production_exception", risk_codes)


if __name__ == "__main__":
    unittest.main()
