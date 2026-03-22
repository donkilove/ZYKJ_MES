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
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.registration_request import RegistrationRequest  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.role_permission_grant import RolePermissionGrant  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.user_session import UserSession  # noqa: E402
from app.services.user_service import approve_registration_request  # noqa: E402


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
        self.stage_id: int | None = None
        self.registration_request_id: int | None = None

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
            if self.registration_request_id is not None:
                db.execute(
                    delete(RegistrationRequest).where(
                        RegistrationRequest.id == self.registration_request_id
                    )
                )
            if self.stage_id is not None:
                stage = db.query(ProcessStage).filter(ProcessStage.id == self.stage_id).one_or_none()
                if stage is not None:
                    db.delete(stage)
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

    def _create_enabled_stage_without_processes(self) -> int:
        suffix = str(int(time.time() * 1000) % 100000)
        db = SessionLocal()
        try:
            stage = ProcessStage(
                code=f"USTAGE{suffix}",
                name=f"用户测试工段{suffix}",
                sort_order=1,
                is_enabled=True,
                remark="用户模块回归测试工段",
            )
            db.add(stage)
            db.commit()
            db.refresh(stage)
            self.stage_id = int(stage.id)
            return self.stage_id
        finally:
            db.close()

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

    def test_change_password_requires_immediate_relogin(self) -> None:
        self._create_role_and_user()
        assert self.username is not None
        assert self.user_token is not None
        new_password = f"Pwd@{int(time.time() * 1000) % 100000}Aa"

        response = self.client.post(
            "/api/v1/me/password",
            headers=self._headers(self.user_token),
            json={
                "old_password": "Pwd@123",
                "new_password": new_password,
                "confirm_password": new_password,
            },
        )
        self.assertEqual(response.status_code, 200, response.text)

        old_profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(
            old_profile_response.status_code, 401, old_profile_response.text
        )

        new_token = self._login(self.username, new_password)
        new_profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(new_token),
        )
        self.assertEqual(
            new_profile_response.status_code, 200, new_profile_response.text
        )

    def test_update_user_rejects_legacy_password_contract(self) -> None:
        self._create_role_and_user()
        assert self.user_id is not None

        response = self.client.put(
            f"/api/v1/users/{self.user_id}",
            headers=self._headers(),
            json={
                "remark": "仅更新备注",
                "password": "Legacy@123",
            },
        )
        self.assertEqual(response.status_code, 422, response.text)

    def test_operator_user_flows_accept_stage_without_enabled_processes(self) -> None:
        stage_id = self._create_enabled_stage_without_processes()

        suffix = str(int(time.time() * 1000) % 100000)
        self.username = f"op{suffix}"

        create_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": self.username,
                "password": "Pwd@123",
                "role_code": "operator",
                "stage_id": stage_id,
                "remark": "无工序工段建人回归",
                "is_active": True,
            },
        )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        self.user_id = int(create_response.json()["data"]["id"])
        self.assertEqual(create_response.json()["data"]["stage_id"], stage_id)

        update_response = self.client.put(
            f"/api/v1/users/{self.user_id}",
            headers=self._headers(),
            json={
                "remark": "无工序工段改人回归",
                "stage_id": stage_id,
            },
        )
        self.assertEqual(update_response.status_code, 200, update_response.text)
        self.assertEqual(update_response.json()["data"]["stage_id"], stage_id)

        account = f"rg{suffix}"
        password = f"Pwd@{suffix}Aa"

        db = SessionLocal()
        try:
            request_row = RegistrationRequest(
                account=account,
                password_hash="mocked-password-hash",
                status="pending",
            )
            db.add(request_row)
            db.commit()
            db.refresh(request_row)
            self.registration_request_id = int(request_row.id)

            approved_user, approve_error = approve_registration_request(
                db,
                request=request_row,
                account=account,
                password=password,
                role_code="operator",
                stage_id=stage_id,
                reviewer=None,
            )
            self.assertIsNone(approve_error)
            self.assertIsNotNone(approved_user)
            assert approved_user is not None
            self.assertEqual(approved_user.stage_id, stage_id)
        finally:
            db.close()

    def test_builtin_role_lifecycle_allows_manual_toggle(self) -> None:
        db = SessionLocal()
        try:
            role = (
                db.query(Role)
                .filter(
                    Role.is_deleted.is_(False),
                    Role.is_builtin.is_(True),
                    Role.code != "system_admin",
                )
                .order_by(Role.id.asc())
                .first()
            )
            self.assertIsNotNone(role)
            assert role is not None
            original_enabled = bool(role.is_enabled)
            role_id = int(role.id)
        finally:
            db.close()

        toggle_response = self.client.post(
            f"/api/v1/roles/{role_id}/{'disable' if original_enabled else 'enable'}",
            headers=self._headers(),
        )
        self.assertEqual(toggle_response.status_code, 200, toggle_response.text)

        db = SessionLocal()
        try:
            persisted = db.query(Role).filter(Role.id == role_id).one()
            self.assertEqual(bool(persisted.is_enabled), not original_enabled)
        finally:
            db.close()

        restore_response = self.client.post(
            f"/api/v1/roles/{role_id}/{'enable' if original_enabled else 'disable'}",
            headers=self._headers(),
        )
        self.assertEqual(restore_response.status_code, 200, restore_response.text)

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
        self.assertEqual(
            catalog_response.json()["data"]["module_codes"],
            [
                "user",
                "product",
                "craft",
                "production",
                "quality",
                "equipment",
                "message",
            ],
        )

        system_catalog_response = self.client.get(
            "/api/v1/authz/capability-packs/catalog?module=system",
            headers=self._headers(),
        )
        self.assertEqual(
            system_catalog_response.status_code, 400, system_catalog_response.text
        )

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

        system_role_config_response = self.client.get(
            f"/api/v1/authz/capability-packs/role-config?role_code={self.role_code}&module=system",
            headers=self._headers(),
        )
        self.assertEqual(
            system_role_config_response.status_code,
            400,
            system_role_config_response.text,
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
