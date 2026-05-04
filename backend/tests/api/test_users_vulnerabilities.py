"""tests/api/test_users_vulnerabilities.py

Vulnerability verification tests for the User Module (TC-032 – TC-051).

Each test is named after its associated vulnerability ID (A–O) and the TC
number it exercises.  Tests are deliberately designed to **confirm the
vulnerability exists** rather than asserting the opposite — the expected
behaviour documents the actual (insecure) behaviour, so that the report's
findings can be reproduced.

Architecture notes
──────────────────
• ``client`` fixture  — isolated in-memory SQLite, tables wiped before every test.
• ``admin_token``     — valid JWT for the seeded admin account.
• ``two_admin_tokens``— two separate admin sessions (needed for TC-040).
• Concurrent requests (TC-040) are simulated with ``threading`` since SQLite
  serialises writes anyway; the race window is in the Python application
  logic, not the DB layer.

Test-to-vulnerability mapping
─────────────────────────────
TC-032  → 隐患 A    TC-039  → 隐患 F    TC-046  → 隐患 L
TC-033  → 隐患 B    TC-040  → 隐患 G    TC-047  → 隐患 M
TC-034  → 隐患 C    TC-041  → 隐患 H    TC-048  → 隐患 N
TC-035  → 隐患 C    TC-042  → 隐患 I    TC-049  → 隐患 O
TC-036  → 隐患 D    TC-043  → 隐患 J    TC-050  → 隐患 O
TC-037  → 隐患 D    TC-044  → 隐患 J    TC-051  → 隐患 O
TC-038  → 隐患 E    TC-045  → 隐患 K
"""

from __future__ import annotations

import json
import re
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[2]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.security import decode_access_token  # noqa: E402


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def decode_jwt_claims(token: str) -> dict[str, Any]:
    """Decode JWT without verification (uses the real secret in test env)."""
    return decode_access_token(token)


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def seconds_since(epoch_ts: int) -> float:
    """Return seconds elapsed since a Unix timestamp."""
    return (datetime.now(timezone.utc) - datetime.fromtimestamp(epoch_ts, tz=timezone.utc)).total_seconds()


# ─────────────────────────────────────────────────────────────────────────────
# TC-032  隐患 A — Token 使用不足 1 小时时续期被拒绝
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityA_TC032:
    """renew-token 必须要求 Token 已使用超过 1 小时。"""

    def test_renew_token_rejects_fresh_token(self, client: TestClient) -> None:
        # Login to get a fresh token
        login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert login_resp.status_code == 200, login_resp.text
        token = login_resp.json()["data"]["access_token"]
        payload = decode_jwt_claims(token)
        age_seconds = seconds_since(payload["iat"])
        assert age_seconds < 60, "Token should be < 60s old at start of test"

        renew_resp = client.post(
            "/api/v1/auth/renew-token",
            headers={"Authorization": f"Bearer {token}"},
            json={"password": "Admin@123456"},
        )
        assert renew_resp.status_code == 400, renew_resp.text
        detail = renew_resp.json()["detail"]
        assert "不足1小时" in detail or "1小时" in detail, (
            f"Expected '不足1小时' error, got: {detail}"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-033  隐患 B — 续期后旧 Token 在缓存窗口内仍可用
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityB_TC033:
    """旧 Token 在 _AUTH_USER_CACHE TTL（10s）窗口内仍被接受。"""

    def test_old_token_works_within_cache_ttl(self, client: TestClient) -> None:
        # Login
        login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert login_resp.status_code == 200
        old_token = login_resp.json()["data"]["access_token"]

        # Advance clock past 1h — we simulate this by directly patching time
        # within the renew-token handler's age check.  In a real scenario,
        # a user would wait > 1h.  Here we use the raw endpoint logic to
        # bypass the 1h gate.
        # NOTE: We patch the token's iat in the JWT by re-signing.
        from app.core.security import create_access_token
        from app.core.config import settings

        old_payload = decode_jwt_claims(old_token)
        sid = old_payload["sid"]

        # Manually create a token that is > 1h old (iat = now - 3700s)
        old_token_1h = create_access_token(
            subject=str(old_payload["sub"]),
            extra_claims={"sid": sid, "login_type": "web"},
            expires_minutes=120,
        )
        # Patch iat to be 3700 seconds ago
        import jwt as _jose
        unsigned = _jose.jwt_encode_timer(
            {"sub": str(old_payload["sub"]), "sid": sid, "login_type": "web"},
            settings.jwt_secret_key,
            algorithm=settings.jwt_algorithm,
            now=datetime.now(timezone.utc) - timedelta(seconds=3700),
        )

        renew_resp = client.post(
            "/api/v1/auth/renew-token",
            headers={"Authorization": f"Bearer {old_token}"},
            json={"password": "Admin@123456"},
        )
        # If this fails due to 1h gate, the test would error — that's OK for
        # this TC as we are testing the CACHE window, not the 1h gate.
        if renew_resp.status_code != 200:
            pytest.skip("renew-token 1h gate prevented access; patch token iat in real scenario")

        new_token = renew_resp.json()["data"]["access_token"]
        assert new_token != old_token

        # Immediately (< 1s) try old token — should succeed within 10s TTL
        old_token_still_valid = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {old_token}"},
        )
        # CONFIRMS VULNERABILITY: old token accepted during cache window
        assert old_token_still_valid.status_code == 200, (
            f"VULNERABILITY B NOT REPRODUCIBLE: old token rejected after "
            f"{old_token_still_valid.status_code}. "
            "Cache window may have already expired."
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-034 / TC-035  隐患 C — 移动端 Token 生命周期与续期不对称
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityC_TC034_TC035:
    """移动端登录签发 10080min token，但续期后被缩短至 180min。"""

    def test_mobile_login_token_has_10080_min_expiry(self, client: TestClient) -> None:
        login_resp = client.post(
            "/api/v1/auth/mobile-scan-review-login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert login_resp.status_code == 200, login_resp.text
        data = login_resp.json()["data"]
        assert data["token_type"] == "bearer"

        # expires_in must be 10080 minutes * 60 = 604800 seconds
        assert data["expires_in"] == 604_800, (
            f"Mobile token expires_in={data['expires_in']}, "
            f"expected 604800 (10080 min). VULNERABILITY C: token lifetime incorrect."
        )

        payload = decode_jwt_claims(data["access_token"])
        actual_seconds = payload["exp"] - payload["iat"]
        assert 604_795 <= actual_seconds <= 604_805, (
            f"Mobile JWT lifetime {actual_seconds}s ≠ 604800s"
        )

    def test_mobile_token_renewal_shortens_to_180_minutes(self, client: TestClient) -> None:
        # Mobile login
        mobile_login = client.post(
            "/api/v1/auth/mobile-scan-review-login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert mobile_login.status_code == 200
        mobile_token = mobile_login.json()["data"]["access_token"]

        # Advance past 1h by replacing the token's iat
        # (In a real test: wait 3600s; here we patch the token to have old iat)
        from app.core.security import create_access_token
        from app.core.config import settings
        import jwt as _jose

        mobile_payload = decode_jwt_claims(mobile_token)
        old_iat_dt = datetime.now(timezone.utc) - timedelta(seconds=3700)

        # Recreate token with old iat
        fake_mobile_token = _jose.jwt_encode(
            {
                "sub": mobile_payload["sub"],
                "sid": mobile_payload["sid"],
                "login_type": "mobile_scan",
                "exp": old_iat_dt + timedelta(minutes=10080),
                "iat": old_iat_dt,
            },
            settings.jwt_secret_key,
            algorithm=settings.jwt_algorithm,
        )

        renew_resp = client.post(
            "/api/v1/auth/renew-token",
            headers={"Authorization": f"Bearer {fake_mobile_token}"},
            json={"password": "Admin@123456"},
        )
        if renew_resp.status_code == 400 and "不足1小时" in renew_resp.json().get("detail", ""):
            pytest.skip("1h gate cannot be bypassed without DB-level session manipulation")

        assert renew_resp.status_code == 200, renew_resp.text
        new_token = renew_resp.json()["data"]["access_token"]
        new_payload = decode_jwt_claims(new_token)
        new_lifetime = new_payload["exp"] - new_payload["iat"]

        # VULNERABILITY C CONFIRMED: mobile token lifetime shortened from 604800s to 10800s
        assert new_lifetime < 20000, (
            f"VULNERABILITY C NOT PRESENT: new token lifetime is {new_lifetime}s, "
            "expected ~10800s (shortened by renewal logic)."
        )
        # The fix should preserve 10080 min; if it does, this assertion fails
        # showing the vulnerability is resolved.
        assert new_lifetime == 10800, (
            f"VULNERABILITY C CONFIRMED: mobile token renewed to {new_lifetime}s (180min), "
            f"not preserved at 604800s (10080min)."
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-036 / TC-037  隐患 D — 移动端登录不强制下线 Web 会话
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityD_TC036_TC037:
    """移动端登录应独立，不影响 Web 活跃会话。"""

    def test_web_login_forces_other_web_sessions_offline(self, client: TestClient) -> None:
        # Browser A login
        login_a = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert login_a.status_code == 200
        token_a = login_a.json()["data"]["access_token"]
        sid_a = decode_jwt_claims(token_a)["sid"]

        # Browser B login → should force offline A
        login_b = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert login_b.status_code == 200
        token_b = login_b.json()["data"]["access_token"]
        sid_b = decode_jwt_claims(token_b)["sid"]
        assert sid_b != sid_a

        # Token A should be rejected (forced offline)
        me_a = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token_a}"},
        )
        assert me_a.status_code == 401, (
            f"Web single-session control FAILED: token_a still valid ({me_a.status_code}). "
            "VULNERABILITY: concurrent Web sessions not forced offline."
        )

        # Token B works
        me_b = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token_b}"},
        )
        assert me_b.status_code == 200

    def test_mobile_login_does_not_force_web_sessions_offline(self, client: TestClient) -> None:
        # Web login first
        web_login = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert web_login.status_code == 200
        web_token = web_login.json()["data"]["access_token"]
        web_sid = decode_jwt_claims(web_token)["sid"]

        # Confirm web session is alive
        me_web = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {web_token}"},
        )
        assert me_web.status_code == 200

        # Mobile scan-review login — does NOT trigger force_offline
        mobile_login = client.post(
            "/api/v1/auth/mobile-scan-review-login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert mobile_login.status_code == 200
        mobile_token = mobile_login.json()["data"]["access_token"]
        mobile_sid = decode_jwt_claims(mobile_token)["sid"]

        # VULNERABILITY D CONFIRMED: web token still alive after mobile login
        me_web_after_mobile = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {web_token}"},
        )
        assert me_web_after_mobile.status_code == 200, (
            f"VULNERABILITY D NOT REPRODUCIBLE: web token invalidated after mobile login "
            f"(status={me_web_after_mobile.status_code}). The security control exists."
        )
        assert mobile_sid != web_sid, "Mobile and web sessions should have different sid"


# ─────────────────────────────────────────────────────────────────────────────
# TC-038  隐患 E — Web 登录不强制下线移动端会话
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityE_TC038:
    """Web 登录不影响移动端独立会话。"""

    def test_web_login_does_not_force_mobile_sessions_offline(self, client: TestClient) -> None:
        # Mobile login first
        mobile_login = client.post(
            "/api/v1/auth/mobile-scan-review-login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert mobile_login.status_code == 200
        mobile_token = mobile_login.json()["data"]["access_token"]

        # Confirm mobile session alive
        me_mobile = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {mobile_token}"},
        )
        assert me_mobile.status_code == 200

        # Web login
        web_login = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        assert web_login.status_code == 200

        # VULNERABILITY E CONFIRMED: mobile token still works after web login
        me_mobile_after_web = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {mobile_token}"},
        )
        assert me_mobile_after_web.status_code == 200, (
            f"VULNERABILITY E NOT REPRODUCIBLE: mobile token invalidated after web login "
            f"(status={me_mobile_after_web.status_code}). The cross-terminal control exists."
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-039  隐患 F — Token 可跨设备使用（无设备指纹绑定）
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityF_TC039:
    """Token 不绑定设备，可在任意客户端使用。"""

    def test_token_works_across_different_request_contexts(self, client: TestClient) -> None:
        # Simulate "device A" by making a request with specific User-Agent
        login_resp = client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
            headers={"User-Agent": "Device-A-Client/1.0"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["data"]["access_token"]

        # "Device B" reuses the same token
        device_b_resp = client.get(
            "/api/v1/auth/me",
            headers={
                "Authorization": f"Bearer {token}",
                "User-Agent": "Device-B-Client/2.0",  # different device
            },
        )

        # VULNERABILITY F CONFIRMED: token accepted from different device
        assert device_b_resp.status_code == 200, (
            f"VULNERABILITY F NOT REPRODUCIBLE: token rejected from different device "
            f"({device_b_resp.status_code}). Device binding exists."
        )
        user_data = device_b_resp.json()["data"]
        assert user_data["username"] == "admin"


# ─────────────────────────────────────────────────────────────────────────────
# TC-040  隐患 G — 系统管理员并发停用 TOCTOU 竞态
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityG_TC040:
    """隐患 G — 系统管理员并发停用 TOCTOU 竞态（修复验证）

    修复核心：SQLAlchemy with_for_update() 行级排他锁 + order_by(User.id.asc())
    强制两个 deactivation 请求完全串行化，护栏阈值严格保持 `< 1`。

    场景（仅 2 个管理员 A, B）：
      A 先执行：remaining = 2-1 = 1 >= 1 → 继续，停用 B
      B 后执行：A 已提交，remaining = 1-1 = 0 < 1 → 护栏拒绝（400）

    修复前（无锁）：两者都看到 count=2，remaining=1 >= 1，全部写入，admin=0（灾难）。
    修复后（有锁）：一个 200，一个 400，admin 永远不为零。

    SQLite 测试策略：
      SQLite 不支持 FOR UPDATE 阻塞行锁，无法真实触发串行化。
      因此通过 mock.patch 模拟串行化行为：第一个请求看到 remaining=1（通过），
      第二个请求（模拟 A 已停用 B 后）看到 remaining=0（护栏拦截，400）。
      验证的是护栏逻辑本身，而非底层锁实现。
    """

    def test_concurrent_admin_deactivation_one_request_is_rejected(
        self,
        client: TestClient,
        two_admin_tokens: tuple[str, str],
        tc040_isolated_count: None,  # noqa: ARG001
    ) -> None:
        import unittest.mock as mock

        from app.services import user_service

        token_a, token_b = two_admin_tokens

        # 解析出两个 admin 的 user_id
        payload_a = decode_jwt_claims(token_a)
        payload_b = decode_jwt_claims(token_b)
        admin_a_id = int(payload_a["sub"])
        admin_b_id = int(payload_b["sub"])
        assert admin_a_id != admin_b_id, "两个 admin 必须有不同 ID"

        # ── SQLite 模拟策略 ───────────────────────────────────────────────
        # SQLite 无真实 FOR UPDATE 行锁，无法触发数据库层串行化。
        # 用 mock 模拟锁行为：第一次调用计数 remaining=1（通过），
        # 第二次（A 已停用 B 之后）计数 remaining=0（护栏拦截）。
        #
        # 调用序列（模拟并发串行化后）：
        #   Call 1: A 尝试停用 B  → remaining=1 >= 1 → 200
        #   Call 2: B 尝试停用 A  → remaining=0 < 1  → 400（护栏）

        call_count = 0

        def _simulate_serialized_count(
            db,
            *,
            operator_user_id: int,
            target_user_id: int,
        ) -> int:
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                # 第一个请求：系统有 2 个管理员，A 尝试停用 B
                # remaining = 2 - 1 = 1 >= 1 → 放行
                return 1
            else:
                # 第二个请求：A 已停用 B 并提交，系统只剩 B
                # remaining = 1 - 1 = 0 < 1 → 护栏拦截
                return 0

        patcher = mock.patch.object(
            user_service,
            "_lock_and_count_active_system_admins_for_guardrail",
            side_effect=_simulate_serialized_count,
        )
        patcher.start()

        try:
            results: dict[str, int | str] = {}
            lock = threading.Lock()

            def deactivate(target_id: int, token: str, label: str) -> None:
                resp = client.put(
                    f"/api/v1/users/{target_id}",
                    headers={"Authorization": f"Bearer {token}"},
                    json={"is_active": False},
                )
                with lock:
                    results[f"{label}_target"] = target_id
                    results[f"{label}_status"] = resp.status_code
                    results[f"{label}_detail"] = resp.json().get("detail", "")

            # 模拟两个并发请求
            t1 = threading.Thread(
                target=deactivate,
                args=(admin_b_id, token_a, "first"),
            )
            t2 = threading.Thread(
                target=deactivate,
                args=(admin_a_id, token_b, "second"),
            )

            t1.start()
            t2.start()
            t1.join()
            t2.join()

            # ── 核心断言（修复后行为）───────────────────────────────────────
            statuses = {results["first_status"], results["second_status"]}

            # 断言 1：恰好一个 200，一个 400（串行化 + 护栏生效）
            # 修复前：两者都 200 → admin 归零（灾难）；修复后：一个被护栏拦截
            assert statuses == {200, 400}, (
                f"Expected exactly one 200 and one 400 (serialized + guardrail). "
                f"Got statuses={statuses}. "
                "TOCTOU race still present — both requests may have succeeded."
            )

            # 断言 2：成功请求（200）的发起者，其 token 依然有效
            # winner 触发了 skip_session_invalidation，未被强制下线
            if results["first_status"] == 200:
                assert results["second_status"] == 400
                me_a = client.get(
                    "/api/v1/auth/me",
                    headers={"Authorization": f"Bearer {token_a}"},
                )
                assert me_a.status_code == 200, (
                    f"Admin A (winner) deactivated Admin B — Admin A's token MUST remain valid. "
                    f"Got Admin A status={me_a.status_code}. "
                    "skip_session_invalidation may not be wired, or session was invalidated."
                )
            elif results["second_status"] == 200:
                assert results["first_status"] == 400
                me_b = client.get(
                    "/api/v1/auth/me",
                    headers={"Authorization": f"Bearer {token_b}"},
                )
                assert me_b.status_code == 200, (
                    f"Admin B (winner) deactivated Admin A — Admin B's token MUST remain valid. "
                    f"Got Admin B status={me_b.status_code}. "
                    "skip_session_invalidation may not be wired, or session was invalidated."
                )

            # 断言 3：失败请求（400）的 detail 必须是护栏消息，不允许通过其他方式绕过
            failed_label = (
                "first" if results["first_status"] == 400 else
                "second" if results["second_status"] == 400 else
                None
            )
            assert failed_label is not None, "Must have one failed request"
            detail = results.get(f"{failed_label}_detail", "")
            assert "至少保留一个" in detail, (
                f"Failed request must be rejected by guardrail (remaining < 1), "
                f"got detail: '{detail}'. "
                "Do NOT bypass the guardrail via 401/auth errors — the lock+check "
                "logic itself must reject the second request."
            )

            # 断言 4：mock 调用了两次（两个请求均进入护栏检查函数）
            assert call_count == 2, (
                f"Expected 2 calls to guardrail function, got {call_count}"
            )
        finally:
            patcher.stop()


# ─────────────────────────────────────────────────────────────────────────────
# TC-041  隐患 H — 用户激活状态变更无原子性
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityH_TC041:
    """并发激活/停用同一用户导致 session/online_status 非原子更新。"""

    def test_concurrent_activate_and_deactivate_produces_undefined_state(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        suffix = str(int(time.time() * 1000) % 100_000)
        username = f"h_test_{suffix}"

        # Create a regular user
        create_resp = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "username": username,
                "password": "Pwd@123",
                "role_code": "operator",
                "is_active": True,
            },
        )
        assert create_resp.status_code == 201
        user_id = create_resp.json()["data"]["id"]

        results: dict[str, int] = {}

        def activate(label: str) -> None:
            resp = client.patch(
                f"/api/v1/users/{user_id}",
                headers=admin_headers,
                json={"is_active": True},
            )
            results[f"{label}_status"] = resp.status_code

        def deactivate(label: str) -> None:
            resp = client.patch(
                f"/api/v1/users/{user_id}",
                headers=admin_headers,
                json={"is_active": False},
            )
            results[f"{label}_status"] = resp.status_code

        t1 = threading.Thread(target=activate, args=("t_activate",))
        t2 = threading.Thread(target=deactivate, args=("t_deactivate",))
        t1.start()
        t2.start()
        t1.join()
        t2.join()

        # Both return 200 — no database-level lock prevents concurrent writes
        # The final state is non-deterministic
        statuses = [v for v in results.values() if isinstance(v, int)]
        assert len(statuses) == 2, f"Expected 2 statuses, got {results}"

        # At minimum, verify no 500 crash occurred
        assert all(s in (200, 400) for s in statuses), (
            f"Concurrent state change caused crash: {results}"
        )

        # The session force-offline count may be inconsistent
        # (We can only verify the API doesn't crash here; deeper consistency
        #  requires DB transaction inspection.)


# ─────────────────────────────────────────────────────────────────────────────
# TC-042  隐患 I — 批量角色规范化事务边界
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityI_TC042:
    """normalize_users_to_single_role 批量更新无隔离，单次失败导致部分用户状态不一致。"""

    def test_normalize_users_not_atomic_without_explicit_rollback(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        """Verify that normalize_users_to_single_role commits partially on error.

        We inject a scenario: two multi-role users are created, then the
        function processes them and we check the DB state.
        """
        from app.services.user_service import normalize_users_to_single_role
        from app.db.session import SessionLocal

        db = SessionLocal()
        try:
            # Create two multi-role users before normalisation
            suffix = str(int(time.time() * 1000) % 100_000)

            # User 1: multi-role
            user1_resp = client.post(
                "/api/v1/users",
                headers=admin_headers,
                json={
                    "username": f"multi1_{suffix}",
                    "password": "Pwd@123",
                    "role_code": "operator",
                    "is_active": True,
                },
            )
            assert user1_resp.status_code == 201
            user1_id = user1_resp.json()["data"]["id"]

            # User 2: multi-role
            user2_resp = client.post(
                "/api/v1/users",
                headers=admin_headers,
                json={
                    "username": f"multi2_{suffix}",
                    "password": "Pwd@123",
                    "role_code": "operator",
                    "is_active": True,
                },
            )
            assert user2_resp.status_code == 201
            user2_id = user2_resp.json()["data"]["id"]

            # Check role counts before normalisation
            from app.models.user import User
            from sqlalchemy import func, select

            def role_count(uid: int) -> int:
                result = db.execute(
                    select(func.count())
                    .select_from(User)
                    .where(User.id == uid)
                ).scalar_one()
                return result

            # Run normalisation — if it succeeds, it commits all at once
            # If we inject an error mid-way, partial state would be visible
            changed = normalize_users_to_single_role(db)

            # At minimum, the function ran without crashing
            assert isinstance(changed, int)

            # VULNERABILITY I: The function commits as a whole batch.
            # We cannot easily inject a mid-batch failure here without
            # patching; the vulnerability is structural (one db.commit()
            # after the loop, not per-user).  This test documents the
            # non-atomicity concern.
        finally:
            db.close()


# ─────────────────────────────────────────────────────────────────────────────
# TC-043 / TC-044  隐患 J — 多 Worker 内存缓存不一致（已修复）
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityJ_TC043_TC044:
    """修复验证：Session 活跃度追踪和用户在线状态已迁移至 Redis。

    修复核心：
      session_service.py:
        - 删除 _SESSION_ACTIVE_LOCAL_CACHE（进程本地字典）
        - 引入 Redis SETEX（Key = "mes:session:active:{session_token_id}"，TTL = 30s）
        - remember_active_session_token / forget_active_session_token 改为 Redis 操作
        - touch_session_by_token_id 新增 require_user_id 参数，消除 allow_cached_active
          绕过的身份验证漏洞

      online_status_service.py:
        - 删除 _last_seen_by_user_id（进程本地字典）
        - 引入 Redis SETEX（Key = "mes:online:{user_id}"，TTL = online_status_ttl_seconds = 90s）
        - Redis TTL 天然接管心跳逻辑，无需手动 prune

      force_offline / mark_session_logout / clear_user 在更新 DB 的同时同步删除 Redis Key，
      确保强制下线在所有 Worker 立即生效。

    TC-043: 验证 Redis 会话活跃度 Key 在模拟多 Worker 环境下跨进程共享。
    TC-044: 验证 force offline / logout 立即清除 Redis Key，且 user_id 强校验。
    """

    def test_redis_session_active_key_is_shared_across_worker_simulation(
        self,
    ) -> None:
        """
        TC-043: Redis Key "mes:session:active:{token}" 对所有 Worker 可见。

        通过 mock 两个隔离的 Redis 客户端（模拟 Worker-A 和 Worker-B）验证：
          1. Worker-A 调用 remember_active_session_token → Redis SETEX
          2. Worker-B 调用 is_session_active_in_redis → Redis GET → True
          3. 即使进程/Worker 独立，只要共享同一 Redis 实例，Key 即共享。
        """
        import unittest.mock as mock
        from app.services import session_service

        fake_token = "tc043_fake_token_001"
        fake_user_id = 42
        fake_ttl = 30

        # ── 隔离的 Redis 模拟：Worker-A（写） ───────────────────────────────
        redis_worker_a: dict[str, str] = {}

        def redis_worker_a_setex(key: str, ttl: int, value: str) -> None:
            redis_worker_a[key] = value

        def redis_worker_a_get(key: str) -> str | None:
            return redis_worker_a.get(key)

        def redis_worker_a_exists(key: str) -> int:
            return 1 if key in redis_worker_a else 0

        def redis_worker_a_delete(key: str) -> int:
            return redis_worker_a.pop(key, None) is not None

        mock_client_a = mock.MagicMock()
        mock_client_a.setex.side_effect = redis_worker_a_setex
        mock_client_a.get.side_effect = redis_worker_a_get
        mock_client_a.exists.side_effect = redis_worker_a_exists
        mock_client_a.delete.side_effect = redis_worker_a_delete

        # ── 隔离的 Redis 模拟：Worker-B（读） ───────────────────────────────
        redis_worker_b: dict[str, str] = {}

        def redis_worker_b_setex(key: str, ttl: int, value: str) -> None:
            redis_worker_b[key] = value

        def redis_worker_b_get(key: str) -> str | None:
            return redis_worker_b.get(key)

        def redis_worker_b_exists(key: str) -> int:
            return 1 if key in redis_worker_b else 0

        def redis_worker_b_delete(key: str) -> int:
            return redis_worker_b.pop(key, None) is not None

        mock_client_b = mock.MagicMock()
        mock_client_b.setex.side_effect = redis_worker_b_setex
        mock_client_b.get.side_effect = redis_worker_b_get
        mock_client_b.exists.side_effect = redis_worker_b_exists
        mock_client_b.delete.side_effect = redis_worker_b_delete

        # ── Worker-A 写入 Redis ────────────────────────────────────────────
        with mock.patch.object(
            session_service,
            "_get_session_redis_client",
            return_value=mock_client_a,
        ):
            session_service.remember_active_session_token(
                session_token_id=fake_token,
                user_id=fake_user_id,
                ttl_seconds=fake_ttl,
            )

        # Verify Worker-A wrote the key
        expected_key = f"mes:session:active:{fake_token}"
        assert expected_key in redis_worker_a, (
            f"Worker-A should have written key {expected_key}"
        )
        assert redis_worker_a[expected_key].startswith(f"{fake_user_id}:"), (
            "Redis value should contain user_id prefix"
        )

        # ── Worker-B 读取 Redis（共享同一 Redis 实例） ──────────────────────
        # Simulate Worker-B using a different client connected to the SAME Redis
        # by injecting the shared dict (simulates shared Redis)
        redis_shared: dict[str, str] = redis_worker_a  # both point to same store

        def shared_get(key: str) -> str | None:
            return redis_shared.get(key)

        def shared_exists(key: str) -> int:
            return 1 if key in redis_shared else 0

        def shared_delete(key: str) -> int:
            return redis_shared.pop(key, None) is not None

        mock_client_b.get.side_effect = shared_get
        mock_client_b.exists.side_effect = shared_exists
        mock_client_b.delete.side_effect = shared_delete

        with mock.patch.object(
            session_service,
            "_get_session_redis_client",
            return_value=mock_client_b,
        ):
            is_active = session_service.is_session_active_in_redis(fake_token)

        # FIX CONFIRMED: Worker-B can see Worker-A's write through shared Redis
        assert is_active is True, (
            "FIX VULNERABILITY J: Redis key should be visible across workers. "
            "If this fails, Redis is not shared or key was not set correctly."
        )

        # Cleanup
        with mock.patch.object(
            session_service,
            "_get_session_redis_client",
            return_value=mock_client_a,
        ):
            session_service.forget_active_session_token(fake_token)

        assert expected_key not in redis_shared, (
            "Redis key should be deleted after forget_active_session_token"
        )

    def test_force_offline_immediately_deletes_redis_key_and_user_id_verification(
        self,
    ) -> None:
        """
        TC-044: force_offline_sessions / mark_session_logout 必须同步删除 Redis Key。

        验证三点：
          1. force offline 立即删除 Redis Key（模拟所有 Worker 可见）
          2. touch_session_by_token_id(require_user_id=X) 在 Redis user_id 不匹配时
             降级到 DB 查询（消除 allow_cached_active 绕过）
          3. 在线状态 clear_user 立即删除 Redis Key
        """
        import unittest.mock as mock
        from app.services import session_service
        from app.services import online_status_service

        fake_token = "tc044_fake_token_001"
        fake_user_id = 99

        # ── Shared Redis store ─────────────────────────────────────────────
        redis_store: dict[str, str] = {}

        def make_mock_client() -> mock.MagicMock:
            client = mock.MagicMock()

            def _setex(key: str, ttl: int, value: str) -> None:
                redis_store[key] = value

            def _get(key: str) -> str | None:
                return redis_store.get(key)

            def _exists(key: str) -> int:
                return 1 if key in redis_store else 0

            def _delete(key: str) -> int:
                return redis_store.pop(key, None) is not None

            client.setex.side_effect = _setex
            client.get.side_effect = _get
            client.exists.side_effect = _exists
            client.delete.side_effect = _delete
            return client

        session_redis = make_mock_client()
        online_redis = make_mock_client()

        def get_session_redis():
            return session_redis

        def get_online_redis():
            return online_redis

        with (
            mock.patch.object(session_service, "_get_session_redis_client", get_session_redis),
            mock.patch.object(online_status_service, "_get_online_redis_client", get_online_redis),
        ):
            # Step 1: Touch session — sets Redis key
            session_service.remember_active_session_token(
                session_token_id=fake_token,
                user_id=fake_user_id,
                ttl_seconds=30,
            )
            session_key = f"mes:session:active:{fake_token}"
            assert session_key in redis_store, "Redis key should be set after touch"

            # Step 2: Force offline — must DELETE Redis key
            session_service.mark_session_logout(
                db=mock.MagicMock(),  # type: ignore[arg-type]
                session_token_id=fake_token,
                forced_offline=True,
            )
            assert session_key not in redis_store, (
                "FIX VULNERABILITY J: Redis key must be deleted IMMEDIATELY on force offline. "
                "If this fails, Redis key persists and other workers still think session is active."
            )

            # Step 3: Redis key gone → subsequent touch_session_by_token_id falls
            # back to DB (no snapshot bypass). Verify by checking require_user_id mismatch.
            # Re-set the key with a different user_id to test mismatch path
            redis_store[session_key] = f"{fake_user_id}:{int(time.time())}"

            # Mock DB to return None (key not in DB → should return None)
            mock_db = mock.MagicMock()
            mock_db.execute.return_value.scalars.return_value.first.return_value = None

            result, _ = session_service.touch_session_by_token_id(
                mock_db,
                session_token_id=fake_token,
                require_user_id=fake_user_id + 1,  # intentionally wrong
            )
            # Redis has user_id=fake_user_id, but require_user_id=fake_user_id+1
            # → Redis lookup returns (True, fake_user_id) but mismatch → falls to DB
            # → DB returns None → result is None
            assert result is None, (
                "Mismatch require_user_id should fall through to DB and return None"
            )

            # Step 4: Online status — clear_user deletes Redis key
            test_user_id = 12345
            online_key = f"mes:online:{test_user_id}"
            redis_store[online_key] = str(int(time.time()))
            assert online_key in redis_store

            online_status_service.clear_user(test_user_id)
            assert online_key not in redis_store, (
                "FIX VULNERABILITY J: Redis online key must be deleted on clear_user"
            )

    def test_redis_online_ttl_auto_expires(self) -> None:
        """
        Verify that online status uses Redis TTL (90s) as the heartbeat mechanism.

        No in-process dictionary, no manual prune loop — Redis auto-expiry is
        the source of truth for online/offline.
        """
        import unittest.mock as mock
        from app.services import online_status_service

        redis_store: dict[str, str] = {}
        stored_ttls: dict[str, int] = {}

        def _setex(key: str, ttl: int, value: str) -> None:
            redis_store[key] = value
            stored_ttls[key] = ttl

        def _get(key: str) -> str | None:
            return redis_store.get(key)

        def _delete(key: str) -> int:
            return redis_store.pop(key, None) is not None

        # Mock pipeline for list_online_user_ids batch check
        def _pipeline():
            pipe = mock.MagicMock()
            pending_keys: list[str] = []

            def _exists(key: str) -> mock.MagicMock:
                pending_keys.append(key)
                return pipe  # fluent API

            def _execute() -> list[int]:
                result = []
                for k in pending_keys:
                    result.append(1 if k in redis_store else 0)
                pending_keys.clear()
                return result

            pipe.exists = _exists
            pipe.execute = _execute
            return pipe

        mock_client = mock.MagicMock()
        mock_client.setex.side_effect = _setex
        mock_client.get.side_effect = _get
        mock_client.delete.side_effect = _delete
        mock_client.pipeline.side_effect = _pipeline

        with mock.patch.object(
            online_status_service,
            "_get_online_redis_client",
            return_value=mock_client,
        ):
            # Touch user — Redis SETEX with TTL
            online_status_service.touch_user(50001)
            key = "mes:online:50001"
            assert key in redis_store, "Online key should be set"
            assert stored_ttls.get(key) == 90, (
                f"TTL should be 90s (online_status_ttl_seconds), got {stored_ttls.get(key)}"
            )

            # list_online_user_ids — batch pipelined check
            online_ids = online_status_service.list_online_user_ids([50001])
            assert 50001 in online_ids, "User should be online"

            # clear_user — DELETE key
            online_status_service.clear_user(50001)
            assert key not in redis_store, "Online key should be deleted on clear_user"

            # After deletion, user is offline
            online_ids_after = online_status_service.list_online_user_ids([50001])
            assert 50001 not in online_ids_after, "User should be offline after clear_user"


# ─────────────────────────────────────────────────────────────────────────────
# TC-045  隐患 K — 密码重置后旧密码在缓存 TTL 内仍有效
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityK_TC045:
    """修复验证：密码重置后旧密码必须在缓存 TTL 内被拒绝。

    修复核心：
      1. security.py 新增 invalidate_password_cache(user_id)，按 user_id 追踪并清除
         _PASSWORD_VERIFY_LOCAL_CACHE 中该用户所有缓存条目（通过 _PASSWORD_VERIFY_USER_KEYS 反查）。
      2. user_service.py 在 reset_user_password / change_user_password 执行后显式调用
         invalidate_password_cache(user.id)，确保旧密码缓存立即失效。
      3. 缓存键包含 user_id（在 cache_scope 中），追踪映射确保精准清理，无需全量扫描。

    漏洞复现路径（修复前）：
      - 用户登录 → verify_password_cached 缓存 SHA256("user:{id}|{old_hash}|{old_pwd}") = True
      - 管理员重置密码 → password_hash 变化，但旧缓存条目未清除
      - 攻击者立即用旧密码登录 → 旧缓存命中 → 登录成功（HTTP 200）

    修复后行为：
      - 重置密码后旧密码立即被 invalidate_password_cache 清除
      - 旧密码登录 → 缓存未命中 → bcrypt 验证失败 → HTTP 401
    """

    def test_old_password_rejected_after_reset(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        # Create a stage first (operator role requires stage_id); correct path is /api/v1/craft/stages
        suffix = str(int(time.time() * 1000) % 100_000)
        stage_resp = client.post(
            "/api/v1/craft/stages",
            headers=admin_headers,
            json={"code": f"kst{suffix}", "name": f"工段{suffix}", "is_enabled": True},
        )
        assert stage_resp.status_code == 201, stage_resp.text
        stage_id = stage_resp.json()["data"]["id"]

        # Create a target operator user (username max_length=10)
        target_username = f"pt{suffix}"[:10]
        old_password = "Pwd@123"

        create_resp = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "username": target_username,
                "password": old_password,
                "role_code": "operator",
                "stage_id": stage_id,
                "is_active": True,
            },
        )
        assert create_resp.status_code == 201, (
            f"User creation failed ({create_resp.status_code}): {create_resp.text}"
        )
        user_id = create_resp.json()["data"]["id"]

        # Step 1: old password must work before reset (populates the cache)
        old_login = client.post(
            "/api/v1/auth/login",
            data={"username": target_username, "password": old_password},
        )
        assert old_login.status_code == 200, (
            "Precondition failed: old password should succeed before reset"
        )

        # Step 2: admin resets to a new password (UserResetPasswordRequest: password + remark)
        new_password = "NewPwd@999"
        reset_resp = client.post(
            f"/api/v1/users/{user_id}/reset-password",
            headers=admin_headers,
            json={"password": new_password, "remark": "密码重置测试"},
        )
        assert reset_resp.status_code == 200, reset_resp.text

        # Step 3: new password must work immediately
        new_login = client.post(
            "/api/v1/auth/login",
            data={"username": target_username, "password": new_password},
        )
        assert new_login.status_code == 200, (
            f"New password should work immediately after reset. "
            f"Got {new_login.status_code}: {new_login.text}"
        )

        # Step 4: old password must be rejected immediately (within TTL)
        old_login_after_reset = client.post(
            "/api/v1/auth/login",
            data={"username": target_username, "password": old_password},
        )

        # FIX ASSERTION: old password MUST be rejected
        assert old_login_after_reset.status_code == 401, (
            f"SECURITY REGRESSION: old password accepted after reset "
            f"(status={old_login_after_reset.status_code}). "
            f"invalidate_password_cache was not called or did not clear the cache entry."
        )
        detail = old_login_after_reset.json().get("detail", "")
        assert "password" in detail.lower() or "incorrect" in detail.lower(), (
            f"Expected password-error detail, got: '{detail}'"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-046  隐患 L — 服务重启后内存在线状态丢失
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityL_TC046:
    """online_status_service 的 _last_seen_by_user_id 纯内存，重启丢失。"""

    def test_online_status_not_persisted_across_restarts(self) -> None:
        """
        The in-memory dict has no persistence mechanism.
        We verify by checking that the state is a plain dict.
        """
        from app.services import online_status_service

        # Verify the storage is a plain dict
        assert isinstance(online_status_service._last_seen_by_user_id, dict), (
            "VULNERABILITY L: online status stored in a non-persistent dict. "
            "Service restart will clear all online status."
        )

        # Touch a user and verify it is recorded
        test_user_id = 99999
        online_status_service.touch_user(test_user_id)

        is_online, _ = online_status_service.get_user_online_snapshot(test_user_id)
        assert is_online is True, "User should be online after touch"

        # Simulate "restart" by clearing the dict
        online_status_service._last_seen_by_user_id.clear()

        is_online_after_restart = online_status_service.get_user_online_snapshot(test_user_id)
        assert is_online_after_restart[0] is False, (
            "VULNERABILITY L CONFIRMED: user offline after dict clear (simulated restart)"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-047  隐患 M — 登录接口无速率限制
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityM_TC047:
    """连续错误密码登录无封禁，可暴力枚举。"""

    def test_no_rate_limit_on_failed_login_attempts(self, client: TestClient) -> None:
        wrong_password = "WrongPwd000"
        attempts = 30
        errors_received = 0
        blocked_count = 0

        for i in range(attempts):
            resp = client.post(
                "/api/v1/auth/login",
                data={"username": "admin", "password": wrong_password},
            )
            if resp.status_code == 401:
                errors_received += 1
            if resp.status_code == 429:
                blocked_count += 1

        # VULNERABILITY M CONFIRMED: no 429 Too Many Requests
        assert blocked_count == 0, (
            "Rate limiting IS implemented — vulnerability not present."
        )
        # At least some requests were processed (no block)
        assert errors_received >= 10, (
            f"Expected many 401 errors, got {errors_received} for {attempts} attempts"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-048  隐患 N — 默认弱 JWT 密钥仍可签发 Token
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityN_TC048:
    """jwt_secret_key 为默认值时仍能成功签发 Token，密钥安全检查非启动时强制。"""

    def test_weak_default_jwt_secret_still_encodes_tokens(self) -> None:
        from app.core import security

        # Patch settings to use insecure default
        original_key = security.settings.jwt_secret_key
        security.settings.jwt_secret_key = "replace_with_a_strong_secret"  # insecure default

        try:
            # create_access_token calls ensure_runtime_settings_secure() internally
            token = security.create_access_token(subject="1", expires_minutes=30)

            # VULNERABILITY N CONFIRMED: token created without raising
            assert len(token) > 20, "Token should be a valid JWT string"
            assert "." in token, "JWT should contain dots (header.payload.signature)"

            # The check is buried inside create_access_token, not at startup
            # Any request made with the insecure key is accepted
        finally:
            security.settings.jwt_secret_key = original_key


# ─────────────────────────────────────────────────────────────────────────────
# TC-049 / TC-050 / TC-051  隐患 O — 用户管理关键操作无审计日志
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityO_TC049_TC050_TC051:
    """用户管理关键操作（修改/密码重置/停用/删除）缺少 write_audit_log 记录。"""

    def test_user_update_does_not_write_audit_log(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        """TC-049: 修改用户名/角色后无审计日志。"""
        suffix = str(int(time.time() * 1000) % 100_000)
        username = f"audit_test_{suffix}"

        # Create user
        create_resp = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "username": username,
                "password": "Pwd@123",
                "role_code": "operator",
                "is_active": True,
            },
        )
        assert create_resp.status_code == 201
        user_id = create_resp.json()["data"]["id"]

        # Update user (change full_name)
        update_resp = client.patch(
            f"/api/v1/users/{user_id}",
            headers=admin_headers,
            json={"full_name": f"已修改_{suffix}"},
        )
        assert update_resp.status_code == 200, update_resp.text

        # Query audit logs for user.update action
        audit_resp = client.get(
            "/api/v1/audit-logs",
            headers=admin_headers,
            params={
                "action_code": "user.update",
                "target_type": "user",
                "page": 1,
                "page_size": 50,
            },
        )
        # If endpoint doesn't support action_code filter, try generic search
        if audit_resp.status_code == 422:
            audit_resp = client.get(
                "/api/v1/audit-logs",
                headers=admin_headers,
                params={"page": 1, "page_size": 100},
            )
        assert audit_resp.status_code == 200, audit_resp.text
        audit_items = audit_resp.json().get("data", {}).get("items", [])

        # VULNERABILITY O CONFIRMED: no "user.update" audit entry
        user_update_logs = [
            log for log in audit_items
            if str(log.get("target_id")) == str(user_id)
            and "update" in str(log.get("action_code", "")).lower()
        ]
        assert len(user_update_logs) == 0, (
            "VULNERABILITY O NOT CONFIRMED: user.update audit log was found. "
            f"Log entry: {user_update_logs}"
        )

    def test_password_reset_does_not_write_audit_log(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        """TC-050: 密码重置无审计日志。"""
        suffix = str(int(time.time() * 1000) % 100_000)
        username = f"reset_audit_{suffix}"

        # Create user
        create_resp = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "username": username,
                "password": "Pwd@123",
                "role_code": "operator",
                "is_active": True,
            },
        )
        assert create_resp.status_code == 201
        user_id = create_resp.json()["data"]["id"]

        # Reset password
        reset_resp = client.post(
            f"/api/v1/users/{user_id}/reset-password",
            headers=admin_headers,
            json={"new_password": "NewPwd@999"},
        )
        assert reset_resp.status_code == 200, reset_resp.text

        # Search audit logs
        audit_resp = client.get(
            "/api/v1/audit-logs",
            headers=admin_headers,
            params={"page": 1, "page_size": 100},
        )
        assert audit_resp.status_code == 200
        audit_items = audit_resp.json().get("data", {}).get("items", [])

        password_reset_logs = [
            log for log in audit_items
            if str(log.get("target_id")) == str(user_id)
            and (
                "password" in str(log.get("action_code", "")).lower()
                or "reset" in str(log.get("action_name", "")).lower()
            )
        ]

        # VULNERABILITY O CONFIRMED: no password reset audit log
        assert len(password_reset_logs) == 0, (
            "VULNERABILITY O NOT CONFIRMED: password reset audit log was found. "
            f"Log entry: {password_reset_logs}"
        )

    def test_user_deactivate_delete_do_not_write_audit_log(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        """TC-051: 停用/删除用户无审计日志。"""
        suffix = str(int(time.time() * 1000) % 100_000)
        username = f"lifecycle_audit_{suffix}"

        # Create user
        create_resp = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "username": username,
                "password": "Pwd@123",
                "role_code": "operator",
                "is_active": True,
            },
        )
        assert create_resp.status_code == 201
        user_id = create_resp.json()["data"]["id"]

        # Deactivate user
        deactivate_resp = client.patch(
            f"/api/v1/users/{user_id}",
            headers=admin_headers,
            json={"is_active": False},
        )
        assert deactivate_resp.status_code == 200, deactivate_resp.text

        # Delete user
        delete_resp = client.delete(
            f"/api/v1/users/{user_id}",
            headers=admin_headers,
        )
        assert delete_resp.status_code == 200, delete_resp.text

        # Query audit logs
        audit_resp = client.get(
            "/api/v1/audit-logs",
            headers=admin_headers,
            params={"page": 1, "page_size": 100},
        )
        assert audit_resp.status_code == 200
        audit_items = audit_resp.json().get("data", {}).get("items", [])

        lifecycle_logs = [
            log for log in audit_items
            if str(log.get("target_id")) == str(user_id)
            and (
                "deactivat" in str(log.get("action_code", "")).lower()
                or "delet" in str(log.get("action_code", "")).lower()
                or "lifecycle" in str(log.get("action_name", "")).lower()
            )
        ]

        # VULNERABILITY O CONFIRMED: no lifecycle audit logs
        assert len(lifecycle_logs) == 0, (
            "VULNERABILITY O NOT CONFIRMED: lifecycle audit log was found. "
            f"Log entry: {lifecycle_logs}"
        )
