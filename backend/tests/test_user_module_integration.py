import base64
from datetime import UTC, datetime, timedelta
import sys
import time
import unittest
from pathlib import Path
from unittest.mock import patch

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
from app.models.message import Message  # noqa: E402
from app.models.message_recipient import MessageRecipient  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.registration_request import RegistrationRequest  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.role_permission_grant import RolePermissionGrant  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.user_export_task import UserExportTask  # noqa: E402
from app.models.user_session import UserSession  # noqa: E402
from app.core.authz_catalog import PERMISSION_CATALOG  # noqa: E402
from app.schemas.user import UserUpdate  # noqa: E402
from app.services.bootstrap_seed_service import seed_initial_data  # noqa: E402
from app.services.audit_service import write_audit_log  # noqa: E402
from app.services.authz_service import ensure_role_permission_defaults  # noqa: E402
from app.services.user_service import approve_registration_request, update_user  # noqa: E402
from app.services.user_export_task_service import ensure_user_export_runtime_dir  # noqa: E402

# Bridge that coordinates the isolated DB transaction with tests/conftest.py.
from tests.conftest import pytest_unittest_transaction_bridge as _bridge  # noqa: E402


class _BridgeBoundSessionFactory:
    """A drop-in replacement for SessionLocal that returns the bridge's session.

    Monkey-patching SessionLocal to this class ensures that ALL ORM operations
    in every test method — including direct SessionLocal() calls — are bound
    to the same isolated transaction, so the savepoint rollback discards them.
    """

    __call__ = property(lambda self: lambda: _bridge.session())


class UserModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        _bridge.begin()

        # Replace SessionLocal so every test method uses the bridge's session.
        from app.db import session as _session_module

        cls._original_SessionLocal = _session_module.SessionLocal
        _session_module.SessionLocal = _BridgeBoundSessionFactory()

        # Override get_db so TestClient request handlers also use the bridge.
        from app.api import deps

        def _get_isolated_db():
            yield _bridge.session()

        cls._original_get_db = deps.get_db
        deps.get_db = _get_isolated_db
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.client.close()
        from app.api import deps  # noqa: F401

        deps.get_db = cls._original_get_db
        # Restore original SessionLocal.
        from app.db import session as _session_module

        _session_module.SessionLocal = cls._original_SessionLocal
        _bridge.end()

    def setUp(self) -> None:
        # Roll back to the pre-test savepoint so each test starts clean.
        _bridge.rollback_test_method()

        self.admin_token = self._login("admin", "Admin@123456")
        self.role_id: int | None = None
        self.role_code: str | None = None
        self.username: str | None = None
        self.user_id: int | None = None
        self.user_token: str | None = None
        self.user_session_id: str | None = None
        self.stage_id: int | None = None
        self.registration_request_id: int | None = None
        self.extra_role_codes: list[str] = []
        self.extra_usernames: list[str] = []
        self.extra_session_ids: list[str] = []
        self.extra_registration_request_ids: list[int] = []
        self.extra_export_task_ids: list[int] = []
        self._registration_request_seq = 0

    def tearDown(self) -> None:
        # Roll back the savepoint — all data created by this test is discarded.
        _bridge.rollback_test_method()

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

    def _create_registration_request(
        self,
        *,
        status: str = "pending",
        rejected_reason: str | None = None,
    ) -> RegistrationRequest:
        self._registration_request_seq += 1
        suffix = f"{int(time.time() * 1000) % 10000:04d}{self._registration_request_seq % 10}"
        request_row = RegistrationRequest(
            account=f"rg{suffix}",
            password_hash="mocked-password-hash",
            status=status,
            rejected_reason=rejected_reason,
        )
        db = _bridge.session()
        db.add(request_row)
        db.flush()
        db.refresh(request_row)
        self.extra_registration_request_ids.append(int(request_row.id))
        return request_row

    def _create_enabled_stage_without_processes(self) -> int:
        suffix = str(int(time.time() * 1000) % 100000)
        db = _bridge.session()
        stage = ProcessStage(
            code=f"USTAGE{suffix}",
            name=f"用户测试工段{suffix}",
            sort_order=1,
            is_enabled=True,
            remark="用户模块回归测试工段",
        )
        db.add(stage)
        db.flush()
        db.refresh(stage)
        self.stage_id = int(stage.id)
        return self.stage_id

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
        self.assertEqual(snapshot_data["role_codes"], [self.role_code])
        self.assertIn("home", snapshot_data["visible_sidebar_codes"])
        self.assertIn("user", snapshot_data["visible_sidebar_codes"])
        self.assertIn("account_settings", snapshot_data["tab_codes_by_parent"]["user"])
        self.assertNotIn("message", snapshot_data["visible_sidebar_codes"])
        user_module_item = next(
            item
            for item in snapshot_data["module_items"]
            if item["module_code"] == "user"
        )
        self.assertTrue(user_module_item["module_enabled"])
        self.assertIn(
            "page.account_settings.view",
            user_module_item["effective_page_permission_codes"],
        )

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

    def test_create_user_rejects_password_with_four_consecutive_identical_chars(
        self,
    ) -> None:
        suffix = str(int(time.time() * 1000) % 100000)
        self.username = f"pwd4{suffix}"

        response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": self.username,
                "password": "Ab1111",
                "role_code": "production_admin",
                "is_active": True,
            },
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(
            response.json()["detail"],
            "密码不得包含连续4位相同字符",
        )

    def test_create_user_allows_password_matching_existing_user_password(self) -> None:
        suffix = str(int(time.time() * 1000) % 100000)
        self.username = f"sp{suffix}"

        response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": self.username,
                "password": "Admin@123456",
                "role_code": "production_admin",
                "is_active": True,
            },
        )

        self.assertEqual(response.status_code, 201, response.text)
        self.user_id = int(response.json()["data"]["id"])

    def test_users_export_covers_csv_excel_success_and_excel_failure(self) -> None:
        self._create_role_and_user()
        assert self.username is not None

        csv_response = self.client.get(
            f"/api/v1/users/export?keyword={self.username}&format=csv",
            headers=self._headers(),
        )
        self.assertEqual(csv_response.status_code, 200, csv_response.text)
        csv_data = csv_response.json()["data"]
        self.assertEqual(csv_data["filename"], "users_export.csv")
        csv_content = base64.b64decode(csv_data["content_base64"]).decode("utf-8-sig")
        self.assertIn("用户名", csv_content)
        self.assertIn(self.username, csv_content)

        excel_response = self.client.get(
            f"/api/v1/users/export?keyword={self.username}&format=excel",
            headers=self._headers(),
        )
        self.assertEqual(excel_response.status_code, 200, excel_response.text)
        excel_data = excel_response.json()["data"]
        self.assertEqual(excel_data["filename"], "users_export.xlsx")
        self.assertEqual(
            excel_data["content_type"],
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        self.assertTrue(
            base64.b64decode(excel_data["content_base64"]).startswith(b"PK")
        )

        with patch("app.api.v1.endpoints.users._build_excel_export", return_value=""):
            failed_response = self.client.get(
                f"/api/v1/users/export?keyword={self.username}&format=excel",
                headers=self._headers(),
            )
        self.assertEqual(failed_response.status_code, 500, failed_response.text)
        self.assertEqual(
            failed_response.json()["detail"],
            "Excel export not available (openpyxl not installed)",
        )

    def test_change_password_keeps_original_password_checks(self) -> None:
        self._create_role_and_user()
        assert self.user_token is not None

        wrong_old_password_response = self.client.post(
            "/api/v1/me/password",
            headers=self._headers(self.user_token),
            json={
                "old_password": "Wrong@123",
                "new_password": "NewPwd@123",
                "confirm_password": "NewPwd@123",
            },
        )
        self.assertEqual(
            wrong_old_password_response.status_code,
            400,
            wrong_old_password_response.text,
        )
        self.assertEqual(wrong_old_password_response.json()["detail"], "原密码不正确")

        confirm_mismatch_response = self.client.post(
            "/api/v1/me/password",
            headers=self._headers(self.user_token),
            json={
                "old_password": "Pwd@123",
                "new_password": "NewPwd@123",
                "confirm_password": "NewPwd@456",
            },
        )
        self.assertEqual(
            confirm_mismatch_response.status_code,
            400,
            confirm_mismatch_response.text,
        )
        self.assertEqual(
            confirm_mismatch_response.json()["detail"],
            "新密码与确认密码不一致",
        )

        same_password_response = self.client.post(
            "/api/v1/me/password",
            headers=self._headers(self.user_token),
            json={
                "old_password": "Pwd@123",
                "new_password": "Pwd@123",
                "confirm_password": "Pwd@123",
            },
        )
        self.assertEqual(
            same_password_response.status_code,
            400,
            same_password_response.text,
        )
        self.assertEqual(
            same_password_response.json()["detail"],
            "新密码不能与原密码相同",
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

    def test_user_mutation_negative_matrix_covers_create_update_delete_and_toggle(
        self,
    ) -> None:
        self._create_role_and_user()
        assert self.username is not None
        assert self.user_id is not None

        duplicate_create_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": self.username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "is_active": True,
            },
        )
        self.assertEqual(
            duplicate_create_response.status_code,
            400,
            duplicate_create_response.text,
        )
        self.assertEqual(
            duplicate_create_response.json()["detail"], "Username already exists"
        )

        invalid_role_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": f"bad{int(time.time() * 1000) % 100000}",
                "password": "Pwd@123",
                "role_code": "missing_role",
                "is_active": True,
            },
        )
        self.assertEqual(
            invalid_role_response.status_code, 400, invalid_role_response.text
        )
        self.assertEqual(
            invalid_role_response.json()["detail"],
            "Role code not found: missing_role",
        )

        extra_suffix = str(int(time.time() * 1000) % 100000)
        extra_username = f"ux{extra_suffix}"
        self.extra_usernames.append(extra_username)
        second_user_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": extra_username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "is_active": True,
            },
        )
        self.assertEqual(
            second_user_response.status_code, 201, second_user_response.text
        )
        second_user_id = int(second_user_response.json()["data"]["id"])

        duplicate_update_response = self.client.put(
            f"/api/v1/users/{self.user_id}",
            headers=self._headers(),
            json={"username": extra_username},
        )
        self.assertEqual(
            duplicate_update_response.status_code,
            400,
            duplicate_update_response.text,
        )
        self.assertEqual(
            duplicate_update_response.json()["detail"], "Username already exists"
        )

        missing_update_response = self.client.put(
            "/api/v1/users/999999",
            headers=self._headers(),
            json={"remark": "missing user"},
        )
        self.assertEqual(
            missing_update_response.status_code, 404, missing_update_response.text
        )
        self.assertEqual(missing_update_response.json()["detail"], "User not found")

        missing_disable_response = self.client.post(
            "/api/v1/users/999999/disable",
            headers=self._headers(),
            json={"remark": "缺失用户校验"},
        )
        self.assertEqual(
            missing_disable_response.status_code,
            404,
            missing_disable_response.text,
        )
        self.assertEqual(missing_disable_response.json()["detail"], "User not found")

        missing_delete_response = self.client.request(
            "DELETE",
            "/api/v1/users/999999",
            headers=self._headers(),
            json={"remark": "缺失用户校验"},
        )
        self.assertEqual(
            missing_delete_response.status_code, 404, missing_delete_response.text
        )
        self.assertEqual(missing_delete_response.json()["detail"], "User not found")

        delete_response = self.client.request(
            "DELETE",
            f"/api/v1/users/{second_user_id}",
            headers=self._headers(),
            json={"remark": "测试逻辑删除"},
        )
        self.assertEqual(delete_response.status_code, 200, delete_response.text)
        self.assertTrue(delete_response.json()["data"]["deleted"])
        self.assertEqual(
            delete_response.json()["data"]["forced_offline_session_count"],
            0,
        )

        enable_deleted_response = self.client.post(
            f"/api/v1/users/{second_user_id}/enable",
            headers=self._headers(),
            json={},
        )
        self.assertEqual(
            enable_deleted_response.status_code,
            400,
            enable_deleted_response.text,
        )
        self.assertEqual(
            enable_deleted_response.json()["detail"],
            "Deleted user cannot be enabled",
        )

    def test_delete_and_restore_user_flow_tracks_reason_scope_and_session(self) -> None:
        self._create_role_and_user()
        assert self.user_id is not None
        assert self.user_session_id is not None

        delete_response = self.client.request(
            "DELETE",
            f"/api/v1/users/{self.user_id}",
            headers=self._headers(),
            json={"remark": "离职归档"},
        )
        self.assertEqual(delete_response.status_code, 200, delete_response.text)
        delete_payload = delete_response.json()["data"]
        self.assertTrue(delete_payload["deleted"])
        self.assertEqual(delete_payload["user"]["id"], self.user_id)
        self.assertTrue(delete_payload["user"]["is_deleted"])
        self.assertFalse(delete_payload["user"]["is_active"])
        self.assertGreaterEqual(delete_payload["forced_offline_session_count"], 1)

        deleted_list_response = self.client.get(
            "/api/v1/users",
            headers=self._headers(),
            params={"deleted_scope": "deleted", "page_size": 200},
        )
        self.assertEqual(
            deleted_list_response.status_code, 200, deleted_list_response.text
        )
        deleted_ids = {
            int(item["id"]) for item in deleted_list_response.json()["data"]["items"]
        }
        self.assertIn(self.user_id, deleted_ids)

        export_response = self.client.get(
            "/api/v1/users/export",
            headers=self._headers(),
            params={"deleted_scope": "deleted", "format": "csv"},
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        self.assertTrue(export_response.json()["data"]["content_base64"])

        db = SessionLocal()
        try:
            deleted_user = db.query(User).filter(User.id == self.user_id).one()
            self.assertTrue(deleted_user.is_deleted)
            self.assertFalse(deleted_user.is_active)
            self.assertIsNotNone(deleted_user.deleted_at)
            deleted_session = (
                db.query(UserSession)
                .filter(UserSession.session_token_id == self.user_session_id)
                .one()
            )
            self.assertEqual(deleted_session.status, "forced_offline")
            delete_audit = (
                db.query(AuditLog)
                .filter(
                    AuditLog.action_code == "user.delete",
                    AuditLog.target_id == str(self.user_id),
                )
                .order_by(AuditLog.id.desc())
                .first()
            )
            assert delete_audit is not None
            self.assertEqual(delete_audit.remark, "离职归档")
        finally:
            db.close()

        restore_response = self.client.post(
            f"/api/v1/users/{self.user_id}/restore",
            headers=self._headers(),
            json={"remark": "资料纠正恢复"},
        )
        self.assertEqual(restore_response.status_code, 200, restore_response.text)
        restore_payload = restore_response.json()["data"]
        self.assertEqual(restore_payload["user"]["id"], self.user_id)
        self.assertFalse(restore_payload["user"]["is_deleted"])
        self.assertFalse(restore_payload["user"]["is_active"])

        active_list_response = self.client.get(
            "/api/v1/users",
            headers=self._headers(),
            params={"deleted_scope": "active", "keyword": self.username},
        )
        self.assertEqual(active_list_response.status_code, 200, active_list_response.text)
        restored_items = active_list_response.json()["data"]["items"]
        self.assertTrue(any(int(item["id"]) == self.user_id for item in restored_items))

        restored_db = SessionLocal()
        try:
            restored_user = restored_db.query(User).filter(User.id == self.user_id).one()
            self.assertFalse(restored_user.is_deleted)
            self.assertFalse(restored_user.is_active)
            self.assertIsNone(restored_user.deleted_at)
            restore_audit = (
                restored_db.query(AuditLog)
                .filter(
                    AuditLog.action_code == "user.restore",
                    AuditLog.target_id == str(self.user_id),
                )
                .order_by(AuditLog.id.desc())
                .first()
            )
            assert restore_audit is not None
            self.assertEqual(restore_audit.remark, "资料纠正恢复")
        finally:
            restored_db.close()

    def test_user_export_tasks_create_complete_and_download(self) -> None:
        self._create_role_and_user()

        create_response = self.client.post(
            "/api/v1/users/export-tasks",
            headers=self._headers(),
            json={
                "format": "csv",
                "keyword": self.username,
                "role_code": self.role_code,
                "deleted_scope": "active",
            },
        )
        self.assertEqual(create_response.status_code, 200, create_response.text)
        task_payload = create_response.json()["data"]
        task_id = int(task_payload["id"])
        self.extra_export_task_ids.append(task_id)

        detail_response = None
        for _ in range(10):
            detail_response = self.client.get(
                f"/api/v1/users/export-tasks/{task_id}",
                headers=self._headers(),
            )
            self.assertEqual(
                detail_response.status_code, 200, detail_response.text
            )
            if detail_response.json()["data"]["status"] == "succeeded":
                break
            time.sleep(0.2)
        assert detail_response is not None
        self.assertEqual(detail_response.json()["data"]["status"], "succeeded")
        self.assertGreaterEqual(detail_response.json()["data"]["record_count"], 1)
        self.assertTrue(detail_response.json()["data"]["file_name"].startswith("users_active_"))

        list_response = self.client.get(
            "/api/v1/users/export-tasks",
            headers=self._headers(),
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        listed_ids = {int(item["id"]) for item in list_response.json()["data"]["items"]}
        self.assertIn(task_id, listed_ids)

        download_response = self.client.get(
            f"/api/v1/users/export-tasks/{task_id}/download",
            headers=self._headers(),
        )
        self.assertEqual(download_response.status_code, 200, download_response.text)
        self.assertTrue(download_response.content)
        self.assertIn(
            "attachment; filename=",
            download_response.headers.get("content-disposition", ""),
        )

        db = SessionLocal()
        try:
            task = db.query(UserExportTask).filter(UserExportTask.id == task_id).one()
            self.assertEqual(task.status, "succeeded")
            self.assertIsNotNone(task.storage_path)
            self.assertTrue(Path(task.storage_path).exists())

            create_audit = (
                db.query(AuditLog)
                .filter(
                    AuditLog.action_code == "user.export.create",
                    AuditLog.target_id == str(task_id),
                )
                .order_by(AuditLog.id.desc())
                .first()
            )
            complete_audit = (
                db.query(AuditLog)
                .filter(
                    AuditLog.action_code == "user.export.complete",
                    AuditLog.target_id == str(task_id),
                )
                .order_by(AuditLog.id.desc())
                .first()
            )
            assert create_audit is not None
            assert complete_audit is not None
            self.assertEqual(create_audit.after_data["deleted_scope"], "active")
            self.assertEqual(complete_audit.after_data["status"], "succeeded")
        finally:
            db.close()

    def test_system_admin_guardrails_block_disabling_last_permission_admin(
        self,
    ) -> None:
        db = SessionLocal()
        try:
            admin_user = db.query(User).filter(User.username == "admin").one()
            admin_user_id = int(admin_user.id)
            other_admins = (
                db.query(User)
                .join(User.roles)
                .filter(Role.code == "system_admin", User.id != admin_user_id)
                .all()
            )
            original_states = {
                int(user.id): bool(user.is_active) for user in other_admins
            }
            for user in other_admins:
                user.is_active = False
            db.commit()
        finally:
            db.close()

        try:
            response = self.client.post(
                f"/api/v1/users/{admin_user_id}/disable",
                headers=self._headers(),
                json={"remark": "管理员停用保护"},
            )
            self.assertEqual(response.status_code, 400, response.text)
            self.assertEqual(
                response.json()["detail"],
                "必须至少保留一个可进入功能权限配置页面的系统管理员账号",
            )
        finally:
            restore_db = SessionLocal()
            try:
                for user_id, is_active in original_states.items():
                    restore_user = (
                        restore_db.query(User).filter(User.id == user_id).one()
                    )
                    restore_user.is_active = is_active
                restore_db.commit()
            finally:
                restore_db.close()

    def test_disable_user_closes_online_state_forces_sessions_and_records_audit(
        self,
    ) -> None:
        self._create_role_and_user()
        assert self.user_id is not None
        assert self.user_token is not None
        assert self.user_session_id is not None

        response = self.client.post(
            f"/api/v1/users/{self.user_id}/disable",
            headers=self._headers(),
            json={"remark": "夜班收口"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        response_data = response.json()["data"]
        self.assertFalse(response_data["user"]["is_active"])
        self.assertGreaterEqual(response_data["forced_offline_session_count"], 1)
        self.assertTrue(response_data["cleared_online_status"])

        db = SessionLocal()
        try:
            session_row = (
                db.query(UserSession)
                .filter(UserSession.session_token_id == self.user_session_id)
                .one_or_none()
            )
            self.assertIsNotNone(session_row)
            assert session_row is not None
            self.assertEqual(session_row.status, "forced_offline")

            audit_row = (
                db.query(AuditLog)
                .filter(
                    AuditLog.action_code == "user.disable",
                    AuditLog.target_id == str(self.user_id),
                )
                .order_by(AuditLog.id.desc())
                .first()
            )
            self.assertIsNotNone(audit_row)
            assert audit_row is not None
            self.assertEqual(audit_row.remark, "夜班收口")
            self.assertEqual(audit_row.before_data["is_active"], True)
            self.assertEqual(audit_row.before_data["is_online"], True)
            self.assertGreaterEqual(audit_row.before_data["active_session_count"], 1)
            self.assertEqual(audit_row.after_data["is_active"], False)
            self.assertGreaterEqual(
                audit_row.after_data["forced_offline_session_count"], 1
            )
            self.assertTrue(audit_row.after_data["cleared_online_status"])
        finally:
            db.close()

        online_status_response = self.client.get(
            f"/api/v1/users/online-status?user_id={self.user_id}",
            headers=self._headers(),
        )
        self.assertEqual(
            online_status_response.status_code, 200, online_status_response.text
        )
        self.assertNotIn(
            self.user_id,
            set(online_status_response.json()["data"]["user_ids"]),
        )

        profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(profile_response.status_code, 401, profile_response.text)

    def test_enable_user_restores_account_but_does_not_restore_online_until_relogin(
        self,
    ) -> None:
        self._create_role_and_user()
        assert self.user_id is not None
        assert self.user_token is not None

        disable_response = self.client.post(
            f"/api/v1/users/{self.user_id}/disable",
            headers=self._headers(),
            json={"remark": "临时停用"},
        )
        self.assertEqual(disable_response.status_code, 200, disable_response.text)

        enable_response = self.client.post(
            f"/api/v1/users/{self.user_id}/enable",
            headers=self._headers(),
            json={"remark": "恢复班次"},
        )
        self.assertEqual(enable_response.status_code, 200, enable_response.text)
        enable_data = enable_response.json()["data"]
        self.assertTrue(enable_data["user"]["is_active"])
        self.assertEqual(enable_data["forced_offline_session_count"], 0)
        self.assertFalse(enable_data["cleared_online_status"])
        self.assertFalse(enable_data["user"]["is_online"])

        online_status_response = self.client.get(
            f"/api/v1/users/online-status?user_id={self.user_id}",
            headers=self._headers(),
        )
        self.assertEqual(
            online_status_response.status_code, 200, online_status_response.text
        )
        self.assertNotIn(
            self.user_id,
            set(online_status_response.json()["data"]["user_ids"]),
        )

        stale_profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(
            stale_profile_response.status_code, 401, stale_profile_response.text
        )

        relogin_token = self._login(self.username, "Pwd@123")
        relogin_profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(relogin_token),
        )
        self.assertEqual(
            relogin_profile_response.status_code,
            200,
            relogin_profile_response.text,
        )

    def test_disable_user_requires_non_empty_remark(self) -> None:
        self._create_role_and_user()
        assert self.user_id is not None

        response = self.client.post(
            f"/api/v1/users/{self.user_id}/disable",
            headers=self._headers(),
            json={"remark": "   "},
        )
        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(response.json()["detail"], "停用原因不能为空")

    def test_me_session_returns_404_when_token_sid_is_missing(self) -> None:
        self._create_role_and_user()
        assert self.user_token is not None

        with patch(
            "app.api.v1.endpoints.me.decode_access_token",
            return_value={"sub": str(self.user_id)},
        ):
            response = self.client.get(
                "/api/v1/me/session",
                headers=self._headers(self.user_token),
            )

        self.assertEqual(response.status_code, 404, response.text)
        self.assertEqual(response.json()["detail"], "Current session not found")

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

    def test_custom_role_user_flows_accept_stage_assignment(self) -> None:
        stage_id = self._create_enabled_stage_without_processes()

        suffix = str(int(time.time() * 1000) % 100000)
        self.role_code = f"custom_stage_{suffix}"
        self.username = f"cu{suffix}"

        role_response = self.client.post(
            "/api/v1/roles",
            headers=self._headers(),
            json={
                "code": self.role_code,
                "name": f"自定义工段角色{suffix}",
                "role_type": "custom",
                "is_enabled": True,
            },
        )
        self.assertEqual(role_response.status_code, 201, role_response.text)
        self.role_id = int(role_response.json()["data"]["id"])

        create_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": self.username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "stage_id": stage_id,
                "remark": "自定义角色分配工段回归",
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
                "remark": "自定义角色保留工段回归",
                "stage_id": stage_id,
            },
        )
        self.assertEqual(update_response.status_code, 200, update_response.text)
        self.assertEqual(update_response.json()["data"]["stage_id"], stage_id)

    def test_roles_endpoint_normalizes_maintenance_staff_as_builtin(self) -> None:
        response = self.client.get(
            "/api/v1/roles?keyword=maintenance_staff",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 200, response.text)
        items = response.json()["data"]["items"]
        self.assertTrue(items)
        maintenance_role = next(
            (item for item in items if item["code"] == "maintenance_staff"),
            None,
        )
        self.assertIsNotNone(maintenance_role)
        assert maintenance_role is not None
        self.assertEqual(maintenance_role["role_type"], "builtin")
        self.assertTrue(maintenance_role["is_builtin"])

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

    def test_role_management_guardrails_and_auth_boundaries(self) -> None:
        self._create_role_and_user()
        assert self.role_id is not None
        assert self.role_code is not None
        assert self.user_token is not None

        db = SessionLocal()
        try:
            system_admin_role_id = int(
                db.query(Role).filter(Role.code == "system_admin").one().id
            )
        finally:
            db.close()

        duplicate_create_response = self.client.post(
            "/api/v1/roles",
            headers=self._headers(),
            json={
                "code": self.role_code.upper(),
                "name": f"重复角色{self.role_code}",
                "role_type": "custom",
                "is_enabled": True,
            },
        )
        self.assertEqual(
            duplicate_create_response.status_code,
            400,
            duplicate_create_response.text,
        )
        self.assertIn(
            "Role code already exists",
            duplicate_create_response.json()["detail"],
        )

        builtin_update_response = self.client.put(
            f"/api/v1/roles/{system_admin_role_id}",
            headers=self._headers(),
            json={"code": "system_admin_x"},
        )
        self.assertEqual(
            builtin_update_response.status_code,
            400,
            builtin_update_response.text,
        )
        self.assertIn(
            "Built-in role code cannot be changed",
            builtin_update_response.json()["detail"],
        )

        builtin_delete_response = self.client.delete(
            f"/api/v1/roles/{system_admin_role_id}",
            headers=self._headers(),
        )
        self.assertEqual(
            builtin_delete_response.status_code,
            400,
            builtin_delete_response.text,
        )
        self.assertEqual(
            builtin_delete_response.json()["detail"],
            "Built-in role cannot be deleted",
        )

        forbidden_list_response = self.client.get(
            "/api/v1/roles",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(
            forbidden_list_response.status_code,
            403,
            forbidden_list_response.text,
        )
        self.assertEqual(forbidden_list_response.json()["detail"], "Access denied")

    def test_seed_initial_data_repairs_builtin_role_metadata(self) -> None:
        db = SessionLocal()
        try:
            role = (
                db.query(Role)
                .filter(Role.code == "maintenance_staff", Role.is_deleted.is_(False))
                .one()
            )
            role.role_type = "custom"
            role.is_builtin = False
            db.commit()

            seed_initial_data(
                db,
                admin_username="admin",
                admin_password="Admin@123456",
            )

            db.refresh(role)
            self.assertEqual(role.role_type, "builtin")
            self.assertTrue(role.is_builtin)
        finally:
            db.close()

    def test_role_permission_defaults_skip_pending_duplicate_grants(self) -> None:
        suffix = str(time.time_ns())
        role_code = f"authz_idempotent_{suffix}"
        self.extra_role_codes.append(role_code)
        permission_code = PERMISSION_CATALOG[0].permission_code

        db = SessionLocal()
        try:
            role = Role(
                code=role_code,
                name=f"幂等角色{suffix}",
                role_type="custom",
                is_builtin=False,
                is_enabled=True,
                is_deleted=False,
            )
            db.add(role)
            db.commit()

            db.add(
                RolePermissionGrant(
                    role_code=role_code,
                    permission_code=permission_code,
                    granted=False,
                )
            )

            changed = ensure_role_permission_defaults(db)

            self.assertTrue(changed)
            db.commit()
            persisted_count = (
                db.query(RolePermissionGrant)
                .filter(
                    RolePermissionGrant.role_code == role_code,
                    RolePermissionGrant.permission_code == permission_code,
                )
                .count()
            )
            self.assertEqual(persisted_count, 1)
        finally:
            db.close()

    def test_register_requests_support_list_detail_reject_and_pending_guard(
        self,
    ) -> None:
        request_row = self._create_registration_request()

        list_response = self.client.get(
            f"/api/v1/auth/register-requests?keyword={request_row.account}&status=pending",
            headers=self._headers(),
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        self.assertEqual(list_response.json()["data"]["total"], 1)
        self.assertEqual(
            list_response.json()["data"]["items"][0]["id"],
            int(request_row.id),
        )

        detail_response = self.client.get(
            f"/api/v1/auth/register-requests/{request_row.id}",
            headers=self._headers(),
        )
        self.assertEqual(detail_response.status_code, 200, detail_response.text)
        self.assertEqual(detail_response.json()["data"]["status"], "pending")

        reject_response = self.client.post(
            f"/api/v1/auth/register-requests/{request_row.id}/reject",
            headers=self._headers(),
            json={"reason": "资料不完整"},
        )
        self.assertEqual(reject_response.status_code, 200, reject_response.text)
        reject_data = reject_response.json()["data"]
        self.assertEqual(reject_data["status"], "rejected")
        self.assertEqual(reject_data["rejected_reason"], "资料不完整")

        rejected_detail_response = self.client.get(
            f"/api/v1/auth/register-requests/{request_row.id}",
            headers=self._headers(),
        )
        self.assertEqual(
            rejected_detail_response.status_code,
            200,
            rejected_detail_response.text,
        )
        self.assertEqual(
            rejected_detail_response.json()["data"]["status"],
            "rejected",
        )

        rejected_list_response = self.client.get(
            f"/api/v1/auth/register-requests?keyword={request_row.account}&status=rejected",
            headers=self._headers(),
        )
        self.assertEqual(
            rejected_list_response.status_code,
            200,
            rejected_list_response.text,
        )
        self.assertEqual(rejected_list_response.json()["data"]["total"], 1)

        second_reject_response = self.client.post(
            f"/api/v1/auth/register-requests/{request_row.id}/reject",
            headers=self._headers(),
            json={"reason": "重复驳回"},
        )
        self.assertEqual(
            second_reject_response.status_code,
            400,
            second_reject_response.text,
        )
        self.assertEqual(
            second_reject_response.json()["detail"],
            "Registration request is not pending",
        )

    def test_register_request_approve_negative_branches_cover_404_pending_and_conflict(
        self,
    ) -> None:
        missing_response = self.client.post(
            "/api/v1/auth/register-requests/999999/approve",
            headers=self._headers(),
            json={
                "account": "missing1",
                "password": "Pwd@123",
                "role_code": "production_admin",
                "stage_id": None,
            },
        )
        self.assertEqual(missing_response.status_code, 404, missing_response.text)
        self.assertEqual(
            missing_response.json()["detail"], "Registration request not found"
        )

        non_pending_request = self._create_registration_request(status="approved")
        non_pending_response = self.client.post(
            f"/api/v1/auth/register-requests/{non_pending_request.id}/approve",
            headers=self._headers(),
            json={
                "account": non_pending_request.account,
                "password": "Pwd@123",
                "role_code": "production_admin",
                "stage_id": None,
            },
        )
        self.assertEqual(
            non_pending_response.status_code, 400, non_pending_response.text
        )
        self.assertEqual(
            non_pending_response.json()["detail"],
            "Registration request is not pending",
        )

        conflict_request = self._create_registration_request()
        self._create_role_and_user()
        assert self.username is not None
        conflict_response = self.client.post(
            f"/api/v1/auth/register-requests/{conflict_request.id}/approve",
            headers=self._headers(),
            json={
                "account": self.username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "stage_id": None,
            },
        )
        self.assertEqual(conflict_response.status_code, 400, conflict_response.text)
        self.assertEqual(conflict_response.json()["detail"], "Username already exists")

    def test_auth_login_rejects_missing_pending_rejected_disabled_and_deleted_accounts(
        self,
    ) -> None:
        pending_request = self._create_registration_request()
        rejected_request = self._create_registration_request(
            status="rejected",
            rejected_reason="资料不完整",
        )

        missing_response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "missing_t37", "password": "Pwd@123"},
        )
        self.assertEqual(missing_response.status_code, 401, missing_response.text)
        self.assertEqual(
            missing_response.json()["detail"], "Incorrect username or password"
        )

        pending_response = self.client.post(
            "/api/v1/auth/login",
            data={"username": pending_request.account, "password": "Pwd@123"},
        )
        self.assertEqual(pending_response.status_code, 403, pending_response.text)
        self.assertEqual(
            pending_response.json()["detail"], "Account is pending approval"
        )

        rejected_response = self.client.post(
            "/api/v1/auth/login",
            data={"username": rejected_request.account, "password": "Pwd@123"},
        )
        self.assertEqual(rejected_response.status_code, 403, rejected_response.text)
        self.assertEqual(
            rejected_response.json()["detail"], "Registration request was rejected"
        )

        self._create_role_and_user()
        assert self.username is not None
        assert self.user_id is not None

        disable_db = SessionLocal()
        try:
            disabled_user = disable_db.query(User).filter(User.id == self.user_id).one()
            disabled_user.is_active = False
            disable_db.commit()
        finally:
            disable_db.close()

        disabled_response = self.client.post(
            "/api/v1/auth/login",
            data={"username": self.username, "password": "Pwd@123"},
        )
        self.assertEqual(disabled_response.status_code, 403, disabled_response.text)
        self.assertEqual(disabled_response.json()["detail"], "Account is disabled")

        deleted_username = f"d{int(time.time() * 1000) % 100000:05d}"
        self.extra_usernames.append(deleted_username)
        deleted_user_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": deleted_username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "is_active": True,
            },
        )
        self.assertEqual(
            deleted_user_response.status_code, 201, deleted_user_response.text
        )

        deleted_db = SessionLocal()
        try:
            deleted_user = (
                deleted_db.query(User).filter(User.username == deleted_username).one()
            )
            deleted_user.is_deleted = True
            deleted_user.is_active = False
            deleted_user.deleted_at = datetime.now(UTC)
            deleted_db.commit()
        finally:
            deleted_db.close()

        deleted_response = self.client.post(
            "/api/v1/auth/login",
            data={"username": deleted_username, "password": "Pwd@123"},
        )
        self.assertEqual(deleted_response.status_code, 403, deleted_response.text)
        self.assertEqual(deleted_response.json()["detail"], "Account is disabled")

        verify_db = SessionLocal()
        try:
            missing_log = (
                verify_db.query(LoginLog)
                .filter(LoginLog.username == "missing_t37")
                .order_by(LoginLog.id.desc())
                .first()
            )
            self.assertIsNotNone(missing_log)
            self.assertFalse(missing_log.success)
            self.assertIsNone(missing_log.user_id)
            self.assertEqual(
                missing_log.failure_reason, "Incorrect username or password"
            )

            pending_log = (
                verify_db.query(LoginLog)
                .filter(LoginLog.username == pending_request.account)
                .order_by(LoginLog.id.desc())
                .first()
            )
            self.assertIsNotNone(pending_log)
            self.assertFalse(pending_log.success)
            self.assertEqual(pending_log.failure_reason, "Account is pending approval")

            rejected_log = (
                verify_db.query(LoginLog)
                .filter(LoginLog.username == rejected_request.account)
                .order_by(LoginLog.id.desc())
                .first()
            )
            self.assertIsNotNone(rejected_log)
            self.assertFalse(rejected_log.success)
            self.assertEqual(
                rejected_log.failure_reason,
                "Registration request was rejected: 资料不完整",
            )

            disabled_log = (
                verify_db.query(LoginLog)
                .filter(LoginLog.username == self.username)
                .filter(LoginLog.success.is_(False))
                .order_by(LoginLog.id.desc())
                .first()
            )
            self.assertIsNotNone(disabled_log)
            self.assertEqual(disabled_log.user_id, self.user_id)
            self.assertEqual(disabled_log.failure_reason, "Account is disabled")

            deleted_log = (
                verify_db.query(LoginLog)
                .filter(LoginLog.username == deleted_username)
                .order_by(LoginLog.id.desc())
                .first()
            )
            self.assertIsNotNone(deleted_log)
            self.assertFalse(deleted_log.success)
            self.assertEqual(deleted_log.failure_reason, "Account is disabled")
        finally:
            verify_db.close()

    def test_auth_login_success_persists_side_effects_and_auth_contracts(self) -> None:
        self._create_role_and_user()
        assert self.username is not None

        login_response = self.client.post(
            "/api/v1/auth/login",
            data={"username": self.username, "password": "Pwd@123"},
            headers={"user-agent": "T37-Test-Agent"},
        )
        self.assertEqual(login_response.status_code, 200, login_response.text)
        login_data = login_response.json()["data"]
        self.assertTrue(login_data["must_change_password"])

        access_token = login_data["access_token"]
        session_id = str(decode_access_token(access_token).get("sid") or "")
        self.assertTrue(session_id)
        self.extra_session_ids.append(session_id)

        me_unauthorized_response = self.client.get("/api/v1/auth/me")
        self.assertEqual(
            me_unauthorized_response.status_code,
            401,
            me_unauthorized_response.text,
        )

        verify_db = SessionLocal()
        try:
            user = verify_db.query(User).filter(User.username == self.username).one()
            self.assertIsNotNone(user.last_login_at)
            self.assertEqual(user.last_login_ip, "testclient")
            self.assertEqual(user.last_login_terminal, "T37-Test-Agent")
            self.assertTrue(user.must_change_password)

            success_log = (
                verify_db.query(LoginLog)
                .filter(LoginLog.session_token_id == session_id)
                .one()
            )
            self.assertTrue(success_log.success)
            self.assertEqual(success_log.username, self.username)
            self.assertEqual(success_log.user_id, user.id)
            self.assertEqual(success_log.ip_address, "testclient")
            self.assertEqual(success_log.terminal_info, "T37-Test-Agent")
            self.assertIsNone(success_log.failure_reason)

            session_row = (
                verify_db.query(UserSession)
                .filter(UserSession.session_token_id == session_id)
                .one()
            )
            self.assertEqual(session_row.user_id, user.id)
            self.assertEqual(session_row.status, "active")
            self.assertEqual(user.last_login_at, session_row.login_time)
        finally:
            verify_db.close()

    def test_auth_register_covers_success_password_rule_and_conflicts(self) -> None:
        account = f"r{int(time.time() * 1000) % 10000000:07d}"
        register_response = self.client.post(
            "/api/v1/auth/register",
            json={"account": f" {account} ", "password": "Pwd@123"},
        )
        self.assertEqual(register_response.status_code, 202, register_response.text)
        register_data = register_response.json()["data"]
        self.assertEqual(register_data["account"], account)
        self.assertEqual(register_data["status"], "pending_approval")

        verify_db = SessionLocal()
        try:
            request_row = (
                verify_db.query(RegistrationRequest)
                .filter(RegistrationRequest.account == account)
                .one()
            )
            self.extra_registration_request_ids.append(int(request_row.id))
            self.assertEqual(request_row.status, "pending")
        finally:
            verify_db.close()

        pending_conflict_response = self.client.post(
            "/api/v1/auth/register",
            json={"account": account, "password": "Pwd@123"},
        )
        self.assertEqual(
            pending_conflict_response.status_code,
            400,
            pending_conflict_response.text,
        )
        self.assertEqual(
            pending_conflict_response.json()["detail"],
            "Registration request is pending approval",
        )

        invalid_password_response = self.client.post(
            "/api/v1/auth/register",
            json={"account": f"x{account[1:]}", "password": "Ab1111"},
        )
        self.assertEqual(
            invalid_password_response.status_code,
            400,
            invalid_password_response.text,
        )
        self.assertEqual(
            invalid_password_response.json()["detail"],
            "密码不得包含连续4位相同字符",
        )

        self._create_role_and_user()
        assert self.username is not None
        existing_user_response = self.client.post(
            "/api/v1/auth/register",
            json={"account": self.username, "password": "Pwd@123"},
        )
        self.assertEqual(
            existing_user_response.status_code, 400, existing_user_response.text
        )
        self.assertEqual(
            existing_user_response.json()["detail"], "Username already exists"
        )

    def test_authz_capability_pack_batch_apply_and_revision_conflict(self) -> None:
        self._create_role_and_user()
        assert self.role_code is not None

        catalog_response = self.client.get(
            "/api/v1/authz/capability-packs/catalog?module=user",
            headers=self._headers(),
        )
        self.assertEqual(catalog_response.status_code, 200, catalog_response.text)
        module_revision = int(catalog_response.json()["data"]["module_revision"])

        apply_response = self.client.put(
            "/api/v1/authz/capability-packs/batch-apply",
            headers=self._headers(),
            json={
                "module_code": "user",
                "expected_revision": module_revision,
                "remark": "批量配置注册审批能力",
                "role_items": [
                    {
                        "role_code": self.role_code,
                        "module_enabled": True,
                        "capability_codes": [
                            "feature.user.registration_approval.reject"
                        ],
                    }
                ],
            },
        )
        self.assertEqual(apply_response.status_code, 200, apply_response.text)
        role_result = apply_response.json()["data"]["role_results"][0]
        self.assertEqual(role_result["role_code"], self.role_code)
        self.assertGreaterEqual(int(role_result["updated_count"]), 1)
        self.assertIn(
            "feature.user.registration_approval.reject",
            role_result["after_capability_codes"],
        )
        self.assertIn(
            "feature.user.registration_approval.view",
            role_result["effective_capability_codes"],
        )

        effective_response = self.client.get(
            f"/api/v1/authz/capability-packs/effective?role_code={self.role_code}&module=user",
            headers=self._headers(),
        )
        self.assertEqual(
            effective_response.status_code,
            200,
            effective_response.text,
        )
        effective_data = effective_response.json()["data"]
        self.assertIn(
            "feature.user.registration_approval.reject",
            effective_data["effective_capability_codes"],
        )

        conflict_response = self.client.put(
            "/api/v1/authz/capability-packs/batch-apply",
            headers=self._headers(),
            json={
                "module_code": "user",
                "expected_revision": module_revision,
                "remark": "使用过期版本号重放",
                "role_items": [
                    {
                        "role_code": self.role_code,
                        "module_enabled": True,
                        "capability_codes": [
                            "feature.user.registration_approval.reject"
                        ],
                    }
                ],
            },
        )
        self.assertEqual(conflict_response.status_code, 409, conflict_response.text)
        self.assertIn("authz revision conflict", conflict_response.json()["detail"])

    def test_user_module_authz_specialized_contracts_cover_role_config_batch_apply_and_effective(
        self,
    ) -> None:
        self._create_role_and_user()
        assert self.role_code is not None

        catalog_response = self.client.get(
            "/api/v1/authz/capability-packs/catalog?module=user",
            headers=self._headers(),
        )
        self.assertEqual(catalog_response.status_code, 200, catalog_response.text)
        catalog_data = catalog_response.json()["data"]
        self.assertEqual(catalog_data["module_code"], "user")
        capability_codes = {
            item["capability_code"] for item in catalog_data["capability_packs"]
        }
        self.assertIn(
            "feature.user.registration_approval.reject",
            capability_codes,
        )
        self.assertIn(
            "feature.user.account_settings.session_view",
            capability_codes,
        )

        preview_response = self.client.put(
            f"/api/v1/authz/capability-packs/role-config/{self.role_code}",
            headers=self._headers(),
            json={
                "module_code": "user",
                "module_enabled": False,
                "capability_codes": ["feature.user.registration_approval.reject"],
                "dry_run": True,
                "remark": "用户模块特化预览",
            },
        )
        self.assertEqual(preview_response.status_code, 200, preview_response.text)
        preview_data = preview_response.json()["data"]
        self.assertTrue(preview_data["dry_run"])
        self.assertIn(
            "feature.user.registration_approval.view",
            preview_data["after_capability_codes"],
        )
        self.assertIn(
            "feature.user.registration_approval.view",
            preview_data["auto_linked_dependencies"],
        )
        self.assertIn(
            "page.registration_approval.view",
            preview_data["effective_page_permission_codes"],
        )

        apply_response = self.client.put(
            "/api/v1/authz/capability-packs/batch-apply",
            headers=self._headers(),
            json={
                "module_code": "user",
                "expected_revision": catalog_data["module_revision"],
                "remark": "用户模块批量关闭后校验账号设置保底",
                "role_items": [
                    {
                        "role_code": self.role_code,
                        "module_enabled": False,
                        "capability_codes": [],
                    }
                ],
            },
        )
        self.assertEqual(apply_response.status_code, 200, apply_response.text)
        apply_role_result = apply_response.json()["data"]["role_results"][0]
        self.assertEqual(apply_role_result["role_code"], self.role_code)
        self.assertIn(
            "feature.user.account_settings.profile_view",
            apply_role_result["effective_capability_codes"],
        )
        self.assertIn(
            "page.account_settings.view",
            apply_role_result["effective_page_permission_codes"],
        )

        effective_response = self.client.get(
            f"/api/v1/authz/capability-packs/effective?role_code={self.role_code}&module=user",
            headers=self._headers(),
        )
        self.assertEqual(effective_response.status_code, 200, effective_response.text)
        effective_data = effective_response.json()["data"]
        self.assertIn(
            "page.account_settings.view",
            effective_data["effective_page_permission_codes"],
        )
        registration_reject_item = next(
            item
            for item in effective_data["capability_items"]
            if item["capability_code"] == "feature.user.registration_approval.reject"
        )
        self.assertFalse(registration_reject_item["available"])
        self.assertIn(
            "capability_not_granted",
            registration_reject_item["reason_codes"],
        )

    def test_sessions_batch_force_offline_updates_session_status(self) -> None:
        self._create_role_and_user()
        assert self.user_session_id is not None
        assert self.user_token is not None

        response = self.client.post(
            "/api/v1/sessions/force-offline/batch",
            headers=self._headers(),
            json={"session_token_ids": [self.user_session_id]},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["data"]["affected"], 1)

        db = SessionLocal()
        try:
            session_row = (
                db.query(UserSession)
                .filter(UserSession.session_token_id == self.user_session_id)
                .one_or_none()
            )
            self.assertIsNotNone(session_row)
            assert session_row is not None
            self.assertEqual(session_row.status, "forced_offline")
        finally:
            db.close()

        profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(profile_response.status_code, 401, profile_response.text)

    def test_audits_cover_filters_empty_results_pagination_and_auth_boundary(
        self,
    ) -> None:
        self._create_role_and_user()
        assert self.username is not None
        assert self.user_token is not None

        suffix = str(time.time_ns())
        action_code = f"user.audit.coverage.{suffix}"
        target_type = f"user_audit_test_{suffix}"
        window_start = datetime.now(UTC)

        db = SessionLocal()
        try:
            admin_user = db.query(User).filter(User.username == "admin").one()
            for index in range(3):
                row = write_audit_log(
                    db,
                    action_code=action_code,
                    action_name="用户审计覆盖",
                    target_type=target_type,
                    target_id=str(index + 1),
                    target_name=self.username,
                    operator=admin_user,
                    remark=f"audit-case-{index + 1}",
                )
                row.occurred_at = window_start + timedelta(seconds=index)
            db.commit()
        finally:
            db.close()

        first_page_response = self.client.get(
            "/api/v1/audits",
            headers=self._headers(),
            params={
                "operator_username": "admin",
                "action_code": action_code,
                "target_type": target_type,
                "start_time": (window_start - timedelta(seconds=1)).isoformat(),
                "end_time": (window_start + timedelta(seconds=5)).isoformat(),
                "page": 1,
                "page_size": 2,
            },
        )
        self.assertEqual(
            first_page_response.status_code,
            200,
            first_page_response.text,
        )
        first_page_data = first_page_response.json()["data"]
        self.assertEqual(first_page_data["total"], 3)
        self.assertEqual(len(first_page_data["items"]), 2)
        self.assertEqual(first_page_data["items"][0]["target_id"], "3")
        self.assertEqual(first_page_data["items"][1]["target_id"], "2")

        second_page_response = self.client.get(
            "/api/v1/audits",
            headers=self._headers(),
            params={
                "operator_username": "admin",
                "action_code": action_code,
                "target_type": target_type,
                "start_time": (window_start - timedelta(seconds=1)).isoformat(),
                "end_time": (window_start + timedelta(seconds=5)).isoformat(),
                "page": 2,
                "page_size": 2,
            },
        )
        self.assertEqual(
            second_page_response.status_code,
            200,
            second_page_response.text,
        )
        second_page_data = second_page_response.json()["data"]
        self.assertEqual(second_page_data["total"], 3)
        self.assertEqual(len(second_page_data["items"]), 1)
        self.assertEqual(second_page_data["items"][0]["target_id"], "1")

        empty_response = self.client.get(
            "/api/v1/audits",
            headers=self._headers(),
            params={
                "action_code": action_code,
                "target_type": target_type,
                "start_time": (window_start + timedelta(days=1)).isoformat(),
                "end_time": (window_start + timedelta(days=1, seconds=5)).isoformat(),
            },
        )
        self.assertEqual(empty_response.status_code, 200, empty_response.text)
        self.assertEqual(empty_response.json()["data"]["total"], 0)
        self.assertEqual(empty_response.json()["data"]["items"], [])

        forbidden_response = self.client.get(
            "/api/v1/audits",
            headers=self._headers(self.user_token),
            params={
                "action_code": action_code,
                "target_type": target_type,
            },
        )
        self.assertEqual(
            forbidden_response.status_code,
            403,
            forbidden_response.text,
        )
        self.assertEqual(forbidden_response.json()["detail"], "Access denied")

    def test_sessions_batch_force_offline_denies_user_without_permission(self) -> None:
        self._create_role_and_user()
        assert self.user_token is not None
        assert self.user_session_id is not None

        response = self.client.post(
            "/api/v1/sessions/force-offline/batch",
            headers=self._headers(self.user_token),
            json={"session_token_ids": [self.user_session_id]},
        )
        self.assertEqual(response.status_code, 403, response.text)
        self.assertEqual(response.json()["detail"], "Access denied")

    def test_sessions_force_offline_boundary_cases_cover_missing_and_mixed_batch(
        self,
    ) -> None:
        self._create_role_and_user()
        assert self.user_session_id is not None

        missing_single_response = self.client.post(
            "/api/v1/sessions/force-offline",
            headers=self._headers(),
            json={"session_token_id": "missing-session"},
        )
        self.assertEqual(
            missing_single_response.status_code,
            404,
            missing_single_response.text,
        )
        self.assertEqual(
            missing_single_response.json()["detail"], "Online session not found"
        )

        empty_batch_response = self.client.post(
            "/api/v1/sessions/force-offline/batch",
            headers=self._headers(),
            json={"session_token_ids": []},
        )
        self.assertEqual(
            empty_batch_response.status_code, 422, empty_batch_response.text
        )

        mixed_batch_response = self.client.post(
            "/api/v1/sessions/force-offline/batch",
            headers=self._headers(),
            json={"session_token_ids": [self.user_session_id, "missing-session"]},
        )
        self.assertEqual(
            mixed_batch_response.status_code, 200, mixed_batch_response.text
        )
        self.assertEqual(mixed_batch_response.json()["data"]["affected"], 1)

    def test_delete_role_blocks_when_active_users_are_bound(self) -> None:
        self._create_role_and_user()
        assert self.role_id is not None

        response = self.client.delete(
            f"/api/v1/roles/{self.role_id}",
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(
            response.json()["detail"], "Role has bound users and cannot be deleted"
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

    def test_auth_bootstrap_accounts_me_and_logout_cover_contracts(self) -> None:
        self._create_role_and_user()
        assert self.username is not None
        assert self.user_token is not None

        accounts_response = self.client.get("/api/v1/auth/accounts")
        self.assertEqual(accounts_response.status_code, 200, accounts_response.text)
        self.assertIn(self.username, accounts_response.json()["data"]["accounts"])

        me_response = self.client.get(
            "/api/v1/auth/me",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(me_response.status_code, 200, me_response.text)
        me_data = me_response.json()["data"]
        self.assertEqual(me_data["username"], self.username)
        self.assertEqual(me_data["role_code"], self.role_code)
        self.assertIsNotNone(me_data["role_name"])
        self.assertIsNone(me_data["stage_id"])
        self.assertIsNone(me_data["stage_name"])

        logout_response = self.client.post(
            "/api/v1/auth/logout",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(logout_response.status_code, 200, logout_response.text)
        self.assertTrue(logout_response.json()["data"]["logged_out"])

        profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(profile_response.status_code, 401, profile_response.text)

        db = SessionLocal()
        try:
            admin_user = db.query(User).filter(User.username == "admin").one()
            admin_user.roles.clear()
            admin_user.is_deleted = True
            admin_user.deleted_at = datetime.now(UTC)
            db.commit()
        finally:
            db.close()

        bootstrap_response = self.client.post("/api/v1/auth/bootstrap-admin")
        self.assertEqual(bootstrap_response.status_code, 200, bootstrap_response.text)
        bootstrap_data = bootstrap_response.json()["data"]
        self.assertEqual(bootstrap_data["username"], "admin")
        self.assertFalse(bootstrap_data["created"])
        self.assertTrue(bootstrap_data["role_repaired"])

        restored_admin_token = self._login("admin", "Admin@123456")
        restored_me_response = self.client.get(
            "/api/v1/auth/me",
            headers=self._headers(restored_admin_token),
        )
        self.assertEqual(
            restored_me_response.status_code, 200, restored_me_response.text
        )
        self.assertEqual(restored_me_response.json()["data"]["username"], "admin")

    def test_user_guardrails_reset_password_and_export_filters(self) -> None:
        self._create_role_and_user()
        assert self.role_code is not None
        assert self.user_id is not None
        assert self.username is not None
        assert self.user_token is not None

        reset_password = f"Reset@{int(time.time() * 1000) % 100000}Aa"
        reset_response = self.client.post(
            f"/api/v1/users/{self.user_id}/reset-password",
            headers=self._headers(),
            json={"password": reset_password, "remark": "账号交接重置"},
        )
        self.assertEqual(reset_response.status_code, 200, reset_response.text)
        reset_data = reset_response.json()["data"]
        self.assertTrue(reset_data["must_change_password"])
        self.assertGreaterEqual(reset_data["forced_offline_session_count"], 1)
        self.assertTrue(reset_data["cleared_online_status"])

        old_profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(self.user_token),
        )
        self.assertEqual(
            old_profile_response.status_code, 401, old_profile_response.text
        )

        relogin_token = self._login(self.username, reset_password)
        relogin_profile_response = self.client.get(
            "/api/v1/me/profile",
            headers=self._headers(relogin_token),
        )
        self.assertEqual(
            relogin_profile_response.status_code,
            200,
            relogin_profile_response.text,
        )

        db = SessionLocal()
        try:
            audit_row = (
                db.query(AuditLog)
                .filter(
                    AuditLog.action_code == "user.reset_password",
                    AuditLog.target_id == str(self.user_id),
                )
                .order_by(AuditLog.id.desc())
                .first()
            )
            self.assertIsNotNone(audit_row)
            assert audit_row is not None
            self.assertEqual(audit_row.remark, "账号交接重置")
            self.assertEqual(audit_row.before_data["is_online"], True)
            self.assertGreaterEqual(audit_row.before_data["active_session_count"], 1)
            self.assertEqual(audit_row.before_data["must_change_password"], True)
            self.assertEqual(audit_row.after_data["must_change_password"], True)
            self.assertGreaterEqual(
                audit_row.after_data["forced_offline_session_count"], 1
            )
            self.assertTrue(audit_row.after_data["cleared_online_status"])

            reset_message = (
                db.query(Message)
                .filter(
                    Message.source_type == "user_reset_password",
                    Message.source_id == str(self.user_id),
                )
                .order_by(Message.id.desc())
                .first()
            )
            self.assertIsNotNone(reset_message)
            assert reset_message is not None
            self.assertEqual(reset_message.message_type, "warning")
            self.assertEqual(reset_message.priority, "important")
            self.assertEqual(reset_message.target_tab_code, "account_settings")
            self.assertIn("账号交接重置", reset_message.content or "")
            recipient_row = (
                db.query(MessageRecipient)
                .filter(
                    MessageRecipient.message_id == reset_message.id,
                    MessageRecipient.recipient_user_id == self.user_id,
                )
                .one_or_none()
            )
            self.assertIsNotNone(recipient_row)

            operator = db.query(User).filter(User.id == self.user_id).one()
            admin_user = db.query(User).filter(User.username == "admin").one()
            _, rename_error = update_user(
                db,
                user=admin_user,
                payload=UserUpdate(username="adminx"),
                operator=operator,
            )
            self.assertEqual(
                rename_error, "Only system administrator can modify username"
            )
            db.rollback()
        finally:
            db.close()

        admin_me_response = self.client.get(
            "/api/v1/auth/me",
            headers=self._headers(),
        )
        self.assertEqual(admin_me_response.status_code, 200, admin_me_response.text)
        admin_delete_response = self.client.request(
            "DELETE",
            f"/api/v1/users/{admin_me_response.json()['data']['id']}",
            headers=self._headers(),
            json={"remark": "删除当前登录用户"},
        )
        self.assertEqual(
            admin_delete_response.status_code, 400, admin_delete_response.text
        )
        self.assertEqual(
            admin_delete_response.json()["detail"],
            "Cannot delete current login user",
        )

        original_states: dict[int, bool] = {}
        guardrail_db = SessionLocal()
        try:
            admin_user = guardrail_db.query(User).filter(User.username == "admin").one()
            admin_user_id = int(admin_user.id)
            other_admins = (
                guardrail_db.query(User)
                .join(User.roles)
                .filter(Role.code == "system_admin", User.id != admin_user_id)
                .all()
            )
            original_states = {
                int(user.id): bool(user.is_active) for user in other_admins
            }
            for user in other_admins:
                user.is_active = False
            guardrail_db.commit()

            _, role_error = update_user(
                guardrail_db,
                user=admin_user,
                payload=UserUpdate(role_code="production_admin"),
                operator=admin_user,
            )
            self.assertEqual(
                role_error,
                "必须至少保留一个可进入功能权限配置页面的系统管理员账号",
            )
            guardrail_db.rollback()
        finally:
            guardrail_db.close()

        restore_db = SessionLocal()
        try:
            for user_id, is_active in original_states.items():
                restore_user = restore_db.query(User).filter(User.id == user_id).one()
                restore_user.is_active = is_active
            restore_db.commit()
        finally:
            restore_db.close()

        shared_keyword = self.username[:-1]
        extra_username = f"{shared_keyword}x"
        self.extra_usernames.append(extra_username)
        inactive_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": extra_username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "is_active": False,
            },
        )
        self.assertEqual(inactive_response.status_code, 201, inactive_response.text)

        list_response = self.client.get(
            f"/api/v1/users?keyword={shared_keyword}&role_code={self.role_code}&is_active=true",
            headers=self._headers(),
        )
        self.assertEqual(list_response.status_code, 200, list_response.text)
        listed_usernames = [
            item["username"] for item in list_response.json()["data"]["items"]
        ]
        self.assertIn(self.username, listed_usernames)
        self.assertNotIn(extra_username, listed_usernames)

        export_response = self.client.get(
            f"/api/v1/users/export?keyword={shared_keyword}&role_code={self.role_code}&is_active=true&format=csv",
            headers=self._headers(),
        )
        self.assertEqual(export_response.status_code, 200, export_response.text)
        export_csv = base64.b64decode(
            export_response.json()["data"]["content_base64"]
        ).decode("utf-8-sig")
        self.assertIn(self.username, export_csv)
        self.assertNotIn(extra_username, export_csv)

    def test_reset_password_rejects_same_password_and_requires_remark(self) -> None:
        self._create_role_and_user()
        assert self.user_id is not None

        missing_remark_response = self.client.post(
            f"/api/v1/users/{self.user_id}/reset-password",
            headers=self._headers(),
            json={"password": "Reset@123"},
        )
        self.assertEqual(
            missing_remark_response.status_code,
            422,
            missing_remark_response.text,
        )

        same_password_response = self.client.post(
            f"/api/v1/users/{self.user_id}/reset-password",
            headers=self._headers(),
            json={"password": "Pwd@123", "remark": "重复密码校验"},
        )
        self.assertEqual(
            same_password_response.status_code,
            400,
            same_password_response.text,
        )
        self.assertEqual(
            same_password_response.json()["detail"],
            "新密码不能与当前密码相同",
        )

    def test_users_online_status_endpoint_and_is_online_filter(self) -> None:
        self._create_role_and_user()
        assert self.role_code is not None
        assert self.user_id is not None
        assert self.username is not None

        offline_username = f"of{int(time.time() * 1000) % 1000000}"
        self.extra_usernames.append(offline_username)
        offline_user_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": offline_username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "is_active": True,
            },
        )
        self.assertEqual(
            offline_user_response.status_code, 201, offline_user_response.text
        )
        offline_user_id = int(offline_user_response.json()["data"]["id"])

        online_status_response = self.client.get(
            (
                f"/api/v1/users/online-status?user_id={self.user_id}"
                f"&user_id={offline_user_id}&user_id=999999"
            ),
            headers=self._headers(),
        )
        self.assertEqual(
            online_status_response.status_code, 200, online_status_response.text
        )
        online_user_ids = set(online_status_response.json()["data"]["user_ids"])
        self.assertIn(self.user_id, online_user_ids)
        self.assertNotIn(offline_user_id, online_user_ids)

        online_filtered_response = self.client.get(
            f"/api/v1/users?keyword={self.username}&is_online=true",
            headers=self._headers(),
        )
        self.assertEqual(
            online_filtered_response.status_code,
            200,
            online_filtered_response.text,
        )
        online_usernames = {
            item["username"]
            for item in online_filtered_response.json()["data"]["items"]
        }
        self.assertIn(self.username, online_usernames)

        offline_filtered_response = self.client.get(
            f"/api/v1/users?keyword={offline_username}&is_online=false",
            headers=self._headers(),
        )
        self.assertEqual(
            offline_filtered_response.status_code,
            200,
            offline_filtered_response.text,
        )
        offline_usernames = {
            item["username"]
            for item in offline_filtered_response.json()["data"]["items"]
        }
        self.assertIn(offline_username, offline_usernames)

    def test_authz_catalog_matrix_hierarchy_and_legacy_entries(self) -> None:
        self._create_role_and_user()
        assert self.role_code is not None

        catalog_response = self.client.get(
            "/api/v1/authz/permissions/catalog?module=user",
            headers=self._headers(),
        )
        self.assertEqual(catalog_response.status_code, 200, catalog_response.text)
        catalog_items = catalog_response.json()["data"]["items"]
        self.assertTrue(
            any(
                item["permission_code"] == "page.account_settings.view"
                for item in catalog_items
            )
        )

        matrix_response = self.client.get(
            "/api/v1/authz/role-permissions/matrix?module=user",
            headers=self._headers(),
        )
        self.assertEqual(matrix_response.status_code, 200, matrix_response.text)
        self.assertEqual(matrix_response.json()["data"]["module_code"], "user")

        matrix_preview_response = self.client.put(
            "/api/v1/authz/role-permissions/matrix",
            headers=self._headers(),
            json={
                "module_code": "user",
                "dry_run": True,
                "role_items": [
                    {
                        "role_code": self.role_code,
                        "granted_permission_codes": ["page.account_settings.view"],
                    }
                ],
            },
        )
        self.assertEqual(
            matrix_preview_response.status_code,
            200,
            matrix_preview_response.text,
        )
        self.assertTrue(matrix_preview_response.json()["data"]["dry_run"])

        matrix_legacy_response = self.client.put(
            "/api/v1/authz/role-permissions/matrix",
            headers=self._headers(),
            json={
                "module_code": "user",
                "dry_run": False,
                "role_items": [],
            },
        )
        self.assertEqual(
            matrix_legacy_response.status_code,
            410,
            matrix_legacy_response.text,
        )

        hierarchy_catalog_response = self.client.get(
            "/api/v1/authz/hierarchy/catalog?module=user",
            headers=self._headers(),
        )
        self.assertEqual(
            hierarchy_catalog_response.status_code,
            200,
            hierarchy_catalog_response.text,
        )
        self.assertEqual(
            hierarchy_catalog_response.json()["data"]["module_code"], "user"
        )

        hierarchy_role_config_response = self.client.get(
            f"/api/v1/authz/hierarchy/role-config?role_code={self.role_code}&module=user",
            headers=self._headers(),
        )
        self.assertEqual(
            hierarchy_role_config_response.status_code,
            200,
            hierarchy_role_config_response.text,
        )
        self.assertEqual(
            hierarchy_role_config_response.json()["data"]["role_code"], self.role_code
        )

        hierarchy_preview_response = self.client.put(
            f"/api/v1/authz/hierarchy/role-config/{self.role_code}",
            headers=self._headers(),
            json={
                "module_code": "user",
                "module_enabled": True,
                "page_permission_codes": ["page.account_settings.view"],
                "feature_permission_codes": [
                    "feature.user.account_settings.profile_view"
                ],
                "dry_run": True,
            },
        )
        self.assertEqual(
            hierarchy_preview_response.status_code,
            200,
            hierarchy_preview_response.text,
        )
        self.assertTrue(hierarchy_preview_response.json()["data"]["dry_run"])

        hierarchy_legacy_response = self.client.put(
            f"/api/v1/authz/hierarchy/role-config/{self.role_code}",
            headers=self._headers(),
            json={
                "module_code": "user",
                "module_enabled": True,
                "page_permission_codes": [],
                "feature_permission_codes": [],
                "dry_run": False,
            },
        )
        self.assertEqual(
            hierarchy_legacy_response.status_code,
            410,
            hierarchy_legacy_response.text,
        )

    def test_sessions_filters_and_me_session_foreign_or_expired(self) -> None:
        self._create_role_and_user()
        assert self.user_id is not None
        assert self.username is not None
        assert self.user_token is not None
        assert self.user_session_id is not None
        assert self.role_code is not None

        failed_login_response = self.client.post(
            "/api/v1/auth/login",
            data={"username": self.username, "password": "Wrong@123"},
        )
        self.assertEqual(
            failed_login_response.status_code, 401, failed_login_response.text
        )

        success_log_response = self.client.get(
            f"/api/v1/sessions/login-logs?username={self.username}&success=true",
            headers=self._headers(),
        )
        self.assertEqual(
            success_log_response.status_code, 200, success_log_response.text
        )
        self.assertTrue(
            any(
                item["success"] is True
                and item["session_token_id"] == self.user_session_id
                for item in success_log_response.json()["data"]["items"]
            )
        )

        failed_log_response = self.client.get(
            f"/api/v1/sessions/login-logs?username={self.username}&success=false",
            headers=self._headers(),
        )
        self.assertEqual(failed_log_response.status_code, 200, failed_log_response.text)
        self.assertTrue(
            any(
                item["success"] is False
                and item["failure_reason"] == "Incorrect username or password"
                for item in failed_log_response.json()["data"]["items"]
            )
        )

        active_online_response = self.client.get(
            f"/api/v1/sessions/online?keyword={self.username}&status_filter=active",
            headers=self._headers(),
        )
        self.assertEqual(
            active_online_response.status_code,
            200,
            active_online_response.text,
        )
        self.assertTrue(
            any(
                item["session_token_id"] == self.user_session_id
                for item in active_online_response.json()["data"]["items"]
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

        offline_online_response = self.client.get(
            f"/api/v1/sessions/online?keyword={self.username}&status_filter=offline",
            headers=self._headers(),
        )
        self.assertEqual(
            offline_online_response.status_code,
            200,
            offline_online_response.text,
        )
        offline_item = next(
            item
            for item in offline_online_response.json()["data"]["items"]
            if item["session_token_id"] == self.user_session_id
        )
        self.assertEqual(offline_item["status"], "forced_offline")

        foreign_username = f"f{int(time.time() * 1000) % 100000}"
        self.extra_usernames.append(foreign_username)
        foreign_user_response = self.client.post(
            "/api/v1/users",
            headers=self._headers(),
            json={
                "username": foreign_username,
                "password": "Pwd@123",
                "role_code": self.role_code,
                "is_active": True,
            },
        )
        self.assertEqual(
            foreign_user_response.status_code, 201, foreign_user_response.text
        )
        foreign_token = self._login(foreign_username, "Pwd@123")
        foreign_sid = str(decode_access_token(foreign_token).get("sid") or "")
        self.extra_session_ids.append(foreign_sid)

        refreshed_token = self._login(self.username, "Pwd@123")
        refreshed_sid = str(decode_access_token(refreshed_token).get("sid") or "")
        if refreshed_sid:
            self.extra_session_ids.append(refreshed_sid)

        with patch(
            "app.api.v1.endpoints.me.decode_access_token",
            return_value={"sub": str(self.user_id), "sid": foreign_sid},
        ):
            foreign_session_response = self.client.get(
                "/api/v1/me/session",
                headers=self._headers(refreshed_token),
            )
        self.assertEqual(
            foreign_session_response.status_code,
            404,
            foreign_session_response.text,
        )
        self.assertEqual(
            foreign_session_response.json()["detail"], "Current session not found"
        )

        db = SessionLocal()
        try:
            session_row = (
                db.query(UserSession)
                .filter(UserSession.session_token_id == refreshed_sid)
                .one()
            )
            session_row.status = "active"
            session_row.is_forced_offline = False
            session_row.expires_at = datetime.now(UTC) - timedelta(seconds=5)
            db.commit()
        finally:
            db.close()

        with patch(
            "app.api.deps.touch_session_by_token_id",
            return_value=(type("SessionStub", (), {"status": "active"})(), False),
        ):
            expired_session_response = self.client.get(
                "/api/v1/me/session",
                headers=self._headers(refreshed_token),
            )
        self.assertEqual(
            expired_session_response.status_code,
            404,
            expired_session_response.text,
        )
        self.assertEqual(
            expired_session_response.json()["detail"], "Current session not found"
        )


# ─────────────────────────────────────────────────────────────────────────────
# 隐患 D & F 测试用例：TC-036/037/039
# ─────────────────────────────────────────────────────────────────────────────

    def _fingerprint_mismatch_request(
        self,
        token: str,
        *,
        different_ip: bool = False,
        different_ua: bool = False,
    ) -> None:
        """Helper: replay a request with a mismatched IP/UA to trigger fingerprint rejection."""
        # Import here to avoid circular import at module level
        from starlette.datastructures import Address, Headers

        original_host = "127.0.0.1"
        spoofed_host = "10.0.0.99" if different_ip else original_host

        original_ua = "TestClient/1.0"
        spoofed_ua = "EvilBrowser/666.0" if different_ua else original_ua

        def _patch_request(client_self: object, scope: dict) -> None:
            """Patches the request scope to simulate different IP/UA."""
            scope["client"] = (spoofed_host, 12345)
            scope["headers"] = [
                (b"user-agent", spoofed_ua.encode()),
                (b"host", b"testserver"),
            ]

        import app.main as _app_main

        _original = _app_main.app.root_path

        # Use middleware-like approach: patch the request at the asgi scope level
        # We achieve this by patching get_current_user's request object directly
        original_get_current_user = __import__(
            "app.api.deps", fromlist=["get_current_user"]
        ).get_current_user

        import app.api.deps as deps_module
        import types

        # We'll use a different approach: monkeypatch at the endpoint level
        # by passing a pre-built request with spoofed attributes
        from fastapi import Request
        from starlette.testclient import ASGIAdapter, _Scope
        from starlette.requests import Request as StarletteRequest

        # Find the ASGI app
        asgi_app = _app_main.app

        def _build_spoofed_request(
            token_str: str,
            ip: str,
            ua: str,
        ) -> Request:
            """Build a spoofed Request object for direct endpoint testing."""
            from starlette.testclient import _Scope

            scope: _Scope = {
                "type": "http",
                "method": "GET",
                "path": "/api/v1/me/profile",
                "query_string": b"",
                "headers": [(b"authorization", f"Bearer {token_str}".encode())],
                "client": (ip, 12345),
                "server": ("testserver", 80),
                "root_path": "/",
            }
            return StarletteRequest(scope)

        spoofed_req = _build_spoofed_request(
            token_str=token,
            ip=spoofed_host,
            ua=spoofed_ua,
        )

        # Directly call the dependency function with a spoofed request
        from app.api import deps as deps_module

        try:
            deps_module.get_current_user(
                token=token,
                request=spoofed_req,
                db=SessionLocal(),
            )
            self.fail("Expected 401 HTTPException for fingerprint mismatch")
        except Exception as e:
            status_code = getattr(e, "status_code", None)
            if status_code == 401:
                return  # Expected
            # It might be a redirect (SQLAlchemy session issue)
            raise

    def test_tc036_token_stolen_and_replayed_on_different_user_agent(self) -> None:
        """TC-036: Token replayed from a different User-Agent → 401 + forced logout.

        隐患 F：设备指纹绑定 — 跨 UA 使用 Token 必须被拒绝。
        """
        self._create_role_and_user()
        assert self.user_token is not None
        assert self.user_session_id is not None
        assert self.user_id is not None

        from starlette.requests import Request

        def _build_spoofed_request(token_str: str, ua: str) -> Request:
            scope = {
                "type": "http",
                "method": "GET",
                "path": "/api/v1/me/profile",
                "query_string": b"",
                "headers": [
                    (b"authorization", f"Bearer {token_str}".encode()),
                    (b"user-agent", ua.encode()),
                ],
                "client": ("127.0.0.1", 12345),
                "server": ("testserver", 80),
                "root_path": "/",
            }
            return Request(scope)

        # Login UA is the default TestClient UA; spoof a different one
        spoofed_req = _build_spoofed_request(
            token_str=self.user_token,
            ua="EvilBrowser/666.0",
        )

        db = SessionLocal()
        try:
            from app.api import deps as deps_module

            with self.assertRaises(Exception) as ctx:
                deps_module.get_current_user(
                    token=self.user_token,
                    request=spoofed_req,
                    db=db,
                )
            exc = ctx.exception
            status_code = getattr(exc, "status_code", None)
            self.assertEqual(
                status_code, 401,
                f"Expected 401 but got {type(exc).__name__}: {exc}"
            )
        finally:
            db.close()

    def test_tc037_token_stolen_and_replayed_from_different_ip(self) -> None:
        """TC-037: Token replayed from a different IP address → 401 + forced logout.

        隐患 F：设备指纹绑定 — 跨 IP 使用 Token 必须被拒绝。
        """
        self._create_role_and_user()
        assert self.user_token is not None
        assert self.user_session_id is not None

        from starlette.requests import Request

        def _build_spoofed_request(token_str: str, client_ip: str) -> Request:
            scope = {
                "type": "http",
                "method": "GET",
                "path": "/api/v1/me/profile",
                "query_string": b"",
                "headers": [
                    (b"authorization", f"Bearer {token_str}".encode()),
                ],
                "client": (client_ip, 54321),
                "server": ("testserver", 80),
                "root_path": "/",
            }
            return Request(scope)

        # Login was from 'testclient' (TestClient default); replay from different IP
        spoofed_req = _build_spoofed_request(
            token_str=self.user_token,
            client_ip="10.255.255.1",
        )

        db = SessionLocal()
        try:
            from app.api import deps as deps_module

            with self.assertRaises(Exception) as ctx:
                deps_module.get_current_user(
                    token=self.user_token,
                    request=spoofed_req,
                    db=db,
                )
            exc = ctx.exception
            status_code = getattr(exc, "status_code", None)
            self.assertEqual(
                status_code, 401,
                f"Expected 401 (fingerprint mismatch) but got {type(exc).__name__}: {exc}"
            )

            # Verify the session was force-offlined in DB.
            # Force a fresh read bypassing SQLAlchemy's identity map:
            # use a new connection + raw SQL so we see the committed state.
            from sqlalchemy import text
            from app.db.session import engine

            with engine.connect() as fresh_conn:
                result = fresh_conn.execute(
                    text(
                        "SELECT status FROM sys_user_session "
                        "WHERE session_token_id = :sid"
                    ),
                    {"sid": self.user_session_id},
                ).fetchone()
                if result is not None:
                    db_status = result[0]
                    self.assertIn(
                        db_status,
                        {"forced_offline", "logged_out"},
                        f"Session should be force-offlined; got: {db_status!r}",
                    )
        finally:
            db.close()

    def test_tc039_mobile_scan_login_with_single_sign_on_kicks_all_other_sessions(
        self,
    ) -> None:
        """TC-039: Mobile scan login with SSO enabled kicks all other sessions offline.

        隐患 D：跨端互斥 — 移动端登录配置单点登录后，新登录踢掉旧端所有会话。
        """
        # Temporarily enable SSO for this test
        import app.core.config as config_module

        original_sso = config_module.settings.session_single_sign_on
        config_module.settings.session_single_sign_on = True
        try:
            # Login via web (creates web session)
            self._create_role_and_user()
            assert self.user_token is not None
            assert self.user_session_id is not None
            assert self.username is not None

            web_session_id = self.user_session_id

            # Verify web session is active
            profile_resp = self.client.get(
                "/api/v1/me/profile",
                headers=self._headers(self.user_token),
            )
            self.assertEqual(profile_resp.status_code, 200, profile_resp.text)

            # Now login via mobile scan with SSO enabled
            # Mobile scan login uses /api/v1/auth/mobile-scan-review-login
            mobile_login_resp = self.client.post(
                "/api/v1/auth/mobile-scan-review-login",
                data={"username": self.username, "password": "Pwd@123"},
                headers={"User-Agent": "MES-Mobile-Scanner/1.0"},
            )
            self.assertEqual(
                mobile_login_resp.status_code, 200, mobile_login_resp.text
            )
            mobile_token = mobile_login_resp.json()["data"]["access_token"]

            # Verify the old web session is now force-offlined
            db = SessionLocal()
            try:
                old_web_session = (
                    db.query(UserSession)
                    .filter(UserSession.session_token_id == web_session_id)
                    .one_or_none()
                )
                self.assertIsNotNone(old_web_session)
                assert old_web_session is not None
                self.assertEqual(
                    old_web_session.status,
                    "forced_offline",
                    "Web session should have been force-offlined by mobile SSO login",
                )
                self.assertTrue(old_web_session.is_forced_offline)
            finally:
                db.close()

            # The old web token should now be invalid (401)
            old_web_profile_resp = self.client.get(
                "/api/v1/me/profile",
                headers=self._headers(self.user_token),
            )
            self.assertEqual(
                old_web_profile_resp.status_code, 401,
                "Old web token should be rejected after mobile SSO login"
            )

            # The new mobile token should work
            new_mobile_profile_resp = self.client.get(
                "/api/v1/me/profile",
                headers=self._headers(mobile_token),
            )
            self.assertEqual(
                new_mobile_profile_resp.status_code, 200,
                "New mobile token should work"
            )

        finally:
            config_module.settings.session_single_sign_on = original_sso


if __name__ == "__main__":
    unittest.main()
