import sys
import time
import unittest
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import delete


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.security import decode_access_token  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.audit_log import AuditLog  # noqa: E402
from app.models.authz_change_log import AuthzChangeLogItem  # noqa: E402
from app.models.login_log import LoginLog  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.role_permission_grant import RolePermissionGrant  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.user_session import UserSession  # noqa: E402


class UserModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.admin_token = self._login("admin", "Admin@123456")
        self.role_id: int | None = None
        self.role_code: str | None = None
        self.username: str | None = None
        self.user_id: int | None = None
        self.user_token: str | None = None
        self.user_session_id: str | None = None

    def tearDown(self) -> None:
        db = SessionLocal()
        try:
            if self.user_session_id:
                db.execute(
                    delete(UserSession).where(
                        UserSession.session_token_id == self.user_session_id
                    )
                )
                db.execute(
                    delete(LoginLog).where(
                        LoginLog.session_token_id == self.user_session_id
                    )
                )
            if self.username:
                db.execute(
                    delete(AuditLog).where(AuditLog.target_name == self.username)
                )
                db.execute(delete(LoginLog).where(LoginLog.username == self.username))
                user = (
                    db.query(User).filter(User.username == self.username).one_or_none()
                )
                if user is not None:
                    user.roles.clear()
                    db.flush()
                    db.delete(user)
            if self.role_code:
                db.execute(
                    delete(AuthzChangeLogItem).where(
                        AuthzChangeLogItem.role_code == self.role_code
                    )
                )
                db.execute(
                    delete(RolePermissionGrant).where(
                        RolePermissionGrant.role_code == self.role_code
                    )
                )
                db.execute(
                    delete(AuditLog).where(AuditLog.target_name == self.role_code)
                )
                role = db.query(Role).filter(Role.code == self.role_code).one_or_none()
                if role is not None:
                    db.delete(role)
            db.commit()
        finally:
            db.close()

    def _headers(self, token: str | None = None) -> dict[str, str]:
        return {"Authorization": f"Bearer {token or self.admin_token}"}

    def _login(self, username: str, password: str) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": username, "password": password},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _create_role_and_user(self) -> None:
        suffix = str(int(time.time() * 1000) % 100000)
        self.role_code = f"utask_{suffix}"
        self.username = f"u{suffix}"

        role_response = self.client.post(
            "/api/v1/roles",
            headers=self._headers(),
            json={
                "code": self.role_code,
                "name": f"用户回归{suffix}",
                "description": "用户模块回归测试角色",
                "role_type": "custom",
                "is_enabled": True,
            },
        )
        self.assertEqual(role_response.status_code, 201, role_response.text)
        self.role_id = int(role_response.json()["data"]["id"])

        user_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": self.username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "remark": "用户模块回归测试账号",
                "is_active": True,
            },
        )
        self.assertEqual(user_response.status_code, 201, user_response.text)
        self.user_id = int(user_response.json()["data"]["id"])

        self.user_token = self._login(self.username, "Pwd@123")
        token_payload = decode_access_token(self.user_token)
        self.user_session_id = str(token_payload.get("sid") or "") or None

    def test_account_settings_stays_accessible_for_logged_in_user(self) -> None:
        self._create_role_and_user()
        assert self.role_code is not None
        assert self.user_token is not None

        update_response = self.client.put(
            f"/api/v1/authz/capability-packs/role-config/{self.role_code}",
            headers=self._headers(),
            json={
                "module_code": "user",
                "module_enabled": False,
                "capability_codes": [],
                "dry_run": False,
                "remark": "验证个人中心硬保底",
            },
        )
        self.assertEqual(update_response.status_code, 200, update_response.text)
        update_data = update_response.json()["data"]
        self.assertIn(
            "feature.user.account_settings.profile_view",
            update_data["effective_capability_codes"],
        )
        self.assertIn(
            "feature.user.account_settings.password_update",
            update_data["effective_capability_codes"],
        )
        self.assertIn(
            "feature.user.account_settings.session_view",
            update_data["effective_capability_codes"],
        )
        self.assertIn(
            "page.account_settings.view",
            update_data["effective_page_permission_codes"],
        )

        snapshot_response = self.client.get(
            "/api/v1/authz/snapshot",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(snapshot_response.status_code, 200, snapshot_response.text)
        snapshot_data = snapshot_response.json()["data"]
        self.assertIn("user", snapshot_data["visible_sidebar_codes"])
        self.assertIn("account_settings", snapshot_data["tab_codes_by_parent"]["user"])

        permissions_response = self.client.get(
            "/api/v1/authz/permissions/me?module=user",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(
            permissions_response.status_code, 200, permissions_response.text
        )
        permission_codes = permissions_response.json()["data"]["permission_codes"]
        self.assertIn("page.account_settings.view", permission_codes)

        profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(profile_response.status_code, 200, profile_response.text)
        self.assertEqual(profile_response.json()["data"]["username"], self.username)

        session_response = self.client.get(
            "/api/v1/me/session",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(session_response.status_code, 200, session_response.text)
        self.assertEqual(
            session_response.json()["data"]["session_token_id"], self.user_session_id
        )

    def test_user_module_admin_endpoints_cover_core_chains(self) -> None:
        self._create_role_and_user()
        assert self.role_id is not None
        assert self.role_code is not None
        assert self.user_id is not None
        assert self.user_token is not None
        assert self.user_session_id is not None

        role_list_response = self.client.get(
            f"/api/v1/roles?keyword={self.role_code}",
            headers=self._headers(),
        )
        self.assertEqual(role_list_response.status_code, 200, role_list_response.text)
        self.assertTrue(role_list_response.json()["data"]["items"])

        role_detail_response = self.client.get(
            f"/api/v1/roles/{self.role_id}",
            headers=self._headers(),
        )
        self.assertEqual(
            role_detail_response.status_code, 200, role_detail_response.text
        )
        self.assertEqual(role_detail_response.json()["data"]["code"], self.role_code)

        user_list_response = self.client.get(
            f"/api/v1/users?keyword={self.username}",
            headers=self._headers(),
        )
        self.assertEqual(user_list_response.status_code, 200, user_list_response.text)
        self.assertTrue(user_list_response.json()["data"]["items"])

        user_detail_response = self.client.get(
            f"/api/v1/users/{self.user_id}",
            headers=self._headers(),
        )
        self.assertEqual(
            user_detail_response.status_code, 200, user_detail_response.text
        )
        self.assertEqual(user_detail_response.json()["data"]["username"], self.username)

        catalog_response = self.client.get(
            "/api/v1/authz/capability-packs/catalog?module=user",
            headers=self._headers(),
        )
        self.assertEqual(catalog_response.status_code, 200, catalog_response.text)
        self.assertEqual(catalog_response.json()["data"]["module_code"], "user")

        role_config_response = self.client.get(
            f"/api/v1/authz/capability-packs/role-config?role_code={self.role_code}&module=user",
            headers=self._headers(),
        )
        self.assertEqual(
            role_config_response.status_code, 200, role_config_response.text
        )
        self.assertEqual(
            role_config_response.json()["data"]["role_code"], self.role_code
        )

        login_log_response = self.client.get(
            f"/api/v1/sessions/login-logs?username={self.username}",
            headers=self._headers(),
        )
        self.assertEqual(login_log_response.status_code, 200, login_log_response.text)
        login_log_items = login_log_response.json()["data"]["items"]
        self.assertTrue(
            any(
                item["session_token_id"] == self.user_session_id
                for item in login_log_items
            )
        )

        online_response = self.client.get(
            f"/api/v1/sessions/online?keyword={self.username}",
            headers=self._headers(),
        )
        self.assertEqual(online_response.status_code, 200, online_response.text)
        online_items = online_response.json()["data"]["items"]
        self.assertTrue(
            any(
                item["session_token_id"] == self.user_session_id
                for item in online_items
            )
        )

        force_offline_response = self.client.post(
            "/api/v1/sessions/force-offline",
            headers=self._headers(),
            json={"session_token_id": self.user_session_id},
        )
        self.assertEqual(
            force_offline_response.status_code, 200, force_offline_response.text
        )
        self.assertEqual(force_offline_response.json()["data"]["affected"], 1)

        audit_response = self.client.get(
            "/api/v1/audits?action_code=session.force_offline&target_type=session",
            headers=self._headers(),
        )
        self.assertEqual(audit_response.status_code, 200, audit_response.text)
        audit_items = audit_response.json()["data"]["items"]
        self.assertTrue(
            any(item["target_id"] == self.user_session_id for item in audit_items)
        )


if __name__ == "__main__":
    unittest.main()
