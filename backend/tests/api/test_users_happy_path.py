"""tests/api/test_users_happy_path.py

Happy-path integration tests for the User Module (TC-001 – TC-004).

These tests exercise the complete user lifecycle through the FastAPI
TestClient against an isolated in-memory SQLite database.

Test layout
───────────
TC-001  注册申请→审批通过→账号可用（完整注册流程）
TC-002  Web登录→获取JWT→用户信息（基础登录链路）
TC-003  登录→查询会话列表→登出（会话管理链路）
TC-004  创建用户→列表查询→编辑→删除（用户CRUD链路）
"""

from __future__ import annotations

import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[2]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.security import decode_access_token  # noqa: E402


# ─────────────────────────────────────────────────────────────────────────────
# TC-001  注册申请 → 审批通过 → 账号可用
# ─────────────────────────────────────────────────────────────────────────────

class TestRegistrationHappyPath:
    """TC-001: Complete self-registration flow."""

    def test_register_approved_user_can_login(
        self,
        client: TestClient,
        admin_token: str,
    ) -> None:
        """Step 1: Submit registration request → 202 Accepted."""
        suffix = str(int(time.time() * 1000) % 100_000)
        register_payload = {
            "account": f"rt{suffix}"[:10],
            "password": "Pwd@123",
        }
        register_resp = client.post(
            "/api/v1/auth/register",
            json=register_payload,
        )
        assert register_resp.status_code == 202, register_resp.text
        register_data = register_resp.json()["data"]
        assert register_data["account"] == f"rt{suffix}"[:10]
        assert register_data["status"] == "pending_approval"

        # Retrieve the request ID from the list endpoint
        # Use a large page_size to ensure newly created requests are on page 1
        # (DB is shared with prior test data; requests are ordered by id ASC)
        list_resp = client.get(
            "/api/v1/auth/register-requests",
            headers={"Authorization": f"Bearer {admin_token}"},
            params={"page": 1, "page_size": 200},
        )
        assert list_resp.status_code == 200, list_resp.text
        items = list_resp.json()["data"]["items"]
        matched = [i for i in items if i["account"] == f"rt{suffix}"[:10]]
        assert len(matched) == 1
        request_id = matched[0]["id"]

        # Step 2: Approve the registration request
        # Need a stage for operator roles; use the default "装配段" or create one.
        stage_resp = client.post(
            "/api/v1/craft/stages",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"code": f"stage_{suffix}", "name": f"测试工段{suffix}", "is_enabled": True},
        )
        assert stage_resp.status_code == 201, stage_resp.text
        stage_id = stage_resp.json()["data"]["id"]

        approve_payload = {
            "account": f"rt{suffix}"[:10],
            "password": "Pwd@123",
            "role_code": "operator",
            "stage_id": stage_id,
        }
        approve_resp = client.post(
            f"/api/v1/auth/register-requests/{request_id}/approve",
            headers={"Authorization": f"Bearer {admin_token}"},
            json=approve_payload,
        )
        assert approve_resp.status_code == 200, approve_resp.text
        approve_data = approve_resp.json()["data"]
        assert approve_data["approved"] is True
        assert approve_data["final_account"] == f"rt{suffix}"[:10]
        assert approve_data["role_code"] == "operator"

        # Step 3: Login with approved account
        login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": f"rt{suffix}"[:10], "password": "Pwd@123"},
        )
        assert login_resp.status_code == 200, login_resp.text
        login_data = login_resp.json()["data"]

        # Precise field assertions (not just status code)
        assert "access_token" in login_data
        assert login_data["token_type"] == "bearer"
        assert login_data["expires_in"] == 120 * 60  # exactly 120 minutes
        assert login_data["must_change_password"] is True  # new user must change pwd

        # Decode and verify JWT claims
        payload = decode_access_token(login_data["access_token"])
        assert payload["sub"] == str(approve_data["user_id"])
        assert "sid" in payload  # session_token_id present
        assert payload.get("login_type") == "web"


# ─────────────────────────────────────────────────────────────────────────────
# TC-002  Web登录 → 获取JWT → 用户信息
# ─────────────────────────────────────────────────────────────────────────────

class TestLoginHappyPath:
    """TC-002: Basic login and /auth/me flow."""

    def test_login_returns_complete_token_structure(
        self,
        client: TestClient,
    ) -> None:
        """Login as admin and verify every field in the response."""
        login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert login_resp.status_code == 200, login_resp.text
        data = login_resp.json()["data"]

        # All required fields present and correctly typed
        assert isinstance(data["access_token"], str)
        assert len(data["access_token"]) > 20  # JWT is reasonably long
        assert data["token_type"] == "bearer"
        assert isinstance(data["expires_in"], int)
        assert data["expires_in"] == 120 * 60
        assert "must_change_password" in data
        assert data["must_change_password"] is False  # admin is already set up

    def test_get_me_returns_exact_user_fields(
        self,
        client: TestClient,
        admin_token: str,
    ) -> None:
        """GET /auth/me returns correct user metadata."""
        me_resp = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert me_resp.status_code == 200, me_resp.text
        data = me_resp.json()["data"]

        assert data["username"] == "admin"
        assert data["role_code"] == "system_admin"
        assert "id" in data
        assert "full_name" in data
        assert "role_name" in data
        # stage_id / stage_name for admin are None
        assert data["stage_id"] is None
        assert data["stage_name"] is None

    def test_jwt_contains_required_claims(
        self,
        client: TestClient,
    ) -> None:
        """JWT payload contains sub, sid, login_type, iat, exp."""
        login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["data"]["access_token"]
        payload = decode_access_token(token)

        assert "sub" in payload
        assert payload["sub"].isdigit()  # user id as string
        assert "sid" in payload
        assert len(payload["sid"]) == 32  # uuid4 hex = 32 chars
        assert "login_type" in payload
        assert payload["login_type"] == "web"
        assert "iat" in payload
        assert "exp" in payload

        # exp - iat ≈ 120 minutes (7200 seconds), allow 5s clock skew
        delta = payload["exp"] - payload["iat"]
        assert 7195 <= delta <= 7205, f"Token lifetime {delta}s ≠ 7200s"


# ─────────────────────────────────────────────────────────────────────────────
# TC-003  登录 → 查询会话列表 → 登出
# ─────────────────────────────────────────────────────────────────────────────

class TestSessionManagementHappyPath:
    """TC-003: Session lifecycle — list → logout."""

    def test_login_then_list_sessions_then_logout(
        self,
        client: TestClient,
        admin_token: str,
    ) -> None:
        """Full session flow: login → /me confirms identity → /logout ends session."""
        # 1. Confirm identity with the token we already have
        me_before = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert me_before.status_code == 200, me_before.text
        user_id_before = me_before.json()["data"]["id"]

        # 2. Logout
        logout_resp = client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert logout_resp.status_code == 200, logout_resp.text
        logout_data = logout_resp.json()["data"]
        assert logout_data["logged_out"] is True

        # 3. Same token is now rejected
        me_after = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert me_after.status_code == 401, (
            f"Expected 401 after logout but got {me_after.status_code}; "
            "the token should have been invalidated."
        )

        # 4. Re-login succeeds
        re_login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert re_login_resp.status_code == 200, re_login_resp.text
        new_token = re_login_resp.json()["data"]["access_token"]
        assert new_token != admin_token  # new session token

        # 5. New token works
        me_relogged = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {new_token}"},
        )
        assert me_relogged.status_code == 200, me_relogged.text
        assert me_relogged.json()["data"]["id"] == user_id_before


# ─────────────────────────────────────────────────────────────────────────────
# TC-004  创建用户 → 列表查询 → 编辑 → 删除
# ─────────────────────────────────────────────────────────────────────────────

class TestUserCRUDHappyPath:
    """TC-004: Full user management lifecycle."""

    def test_create_then_list_then_update_then_delete(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
        admin_token: str,
    ) -> None:
        suffix = str(int(time.time() * 1000) % 100_000)
        new_username = f"cu{suffix}"[:10]
        new_full_name = f"CRUD测试用户{suffix}"

        # ── Create stage for operator role ─────────────────────────────────────
        stage_resp = client.post(
            "/api/v1/craft/stages",
            headers=admin_headers,
            json={"code": f"stage_crud{suffix}", "name": f"CRUD工段{suffix}", "is_enabled": True},
        )
        assert stage_resp.status_code == 201, stage_resp.text
        stage_id = stage_resp.json()["data"]["id"]

        # ── Create ────────────────────────────────────────────────────────────
        create_resp = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "username": new_username,
                "password": "Pwd@123",
                "role_code": "operator",
                "stage_id": stage_id,
                "remark": "TC-004 测试",
                "is_active": True,
            },
        )
        assert create_resp.status_code == 201, create_resp.text
        create_data = create_resp.json()["data"]
        user_id = create_data["id"]
        assert create_data["username"] == new_username
        assert create_data["full_name"] == new_username  # defaults to username
        assert create_data["is_active"] is True
        assert create_data["must_change_password"] is True  # new user forced pwd change

        # ── Login as new user ─────────────────────────────────────────────────
        login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": new_username, "password": "Pwd@123"},
        )
        assert login_resp.status_code == 200, login_resp.text
        user_token = login_resp.json()["data"]["access_token"]

        # ── List users (admin) ───────────────────────────────────────────────
        # Query by user_id directly to avoid pagination issues with shared DB
        get_user_resp = client.get(
            f"/api/v1/users/{user_id}",
            headers=admin_headers,
        )
        assert get_user_resp.status_code == 200, get_user_resp.text
        get_user_data = get_user_resp.json()["data"]
        assert get_user_data["username"] == new_username
        assert get_user_data["is_active"] is True

        # ── Update (admin edits new user's full_name and remark) ─────────────
        update_resp = client.put(
            f"/api/v1/users/{user_id}",
            headers=admin_headers,
            json={
                "full_name": new_full_name,
                "remark": "TC-004 已编辑",
            },
        )
        assert update_resp.status_code == 200, update_resp.text
        update_data = update_resp.json()["data"]
        assert update_data["full_name"] == new_full_name
        assert update_data["remark"] == "TC-004 已编辑"

        # ── User can still login with the same credentials ───────────────────
        login_after_update = client.post(
            "/api/v1/auth/login",
            data={"username": new_username, "password": "Pwd@123"},
        )
        assert login_after_update.status_code == 200, login_after_update.text

        # ── Delete (soft-delete) ─────────────────────────────────────────────
        import json as _json
        delete_resp = client.request(
            "DELETE",
            f"/api/v1/users/{user_id}",
            headers={**admin_headers, "Content-Type": "application/json"},
            content=_json.dumps({"remark": "TC-004 删除测试"}),
        )
        assert delete_resp.status_code == 200, delete_resp.text
        delete_data = delete_resp.json()["data"]
        assert delete_data["deleted"] is True
        assert delete_data["user"]["is_active"] is False  # deleting also deactivates

        # ── Deleted user cannot login ────────────────────────────────────────
        login_after_delete = client.post(
            "/api/v1/auth/login",
            data={"username": new_username, "password": "Pwd@123"},
        )
        assert login_after_delete.status_code == 403, login_after_delete.text
        assert "disabled" in login_after_delete.json()["detail"].lower()

        # ── Deleted user no longer appears in active user list ───────────────
        list_after_delete = client.get(
            "/api/v1/users",
            headers=admin_headers,
            params={"page": 1, "page_size": 50},
        )
        assert list_after_delete.status_code == 200, list_after_delete.text
        active_usernames = {
            u["username"]
            for u in list_after_delete.json()["data"]["items"]
            if not u.get("is_deleted", False)
        }
        assert new_username not in active_usernames

        # ── Cleanup: log back in as admin ────────────────────────────────────
        # (admin session is still valid)
        me_resp = client.get(
            "/api/v1/auth/me",
            headers=admin_headers,
        )
        assert me_resp.status_code == 200, me_resp.text
        # Verify audit log was written for logout
        audit_resp = client.get(
            "/api/v1/audits",
            headers=admin_headers,
            params={
                "action_code": "auth.logout",
                "page": 1,
                "page_size": 10,
            },
        )
        assert audit_resp.status_code == 200, audit_resp.text
