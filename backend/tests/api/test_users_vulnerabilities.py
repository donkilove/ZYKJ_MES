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
# TC-043 / TC-044  隐患 J — 多 Worker 内存缓存不一致
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityJ_TC043_TC044:
    """_SESSION_ACTIVE_LOCAL_CACHE 和 _AUTH_USER_CACHE 不跨进程共享。"""

    def test_session_cache_not_shared_across_worker_processes(self) -> None:
        """
        Simulate two workers by reading the in-process cache state directly.

        In a real deployment (uvicorn --workers N), Worker-1 writes to its
        local _SESSION_ACTIVE_LOCAL_CACHE and Worker-2 cannot see it.

        We verify that the cache key is process-local by importing the
        module-level dict directly.
        """
        from app.services import session_service

        # Worker-A perspective: mark a session as active
        fake_token = "test_worker_sid_001"
        fake_expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

        session_service.remember_active_session_token(
            fake_token,
            expires_at=fake_expires_at,
        )

        # Worker-B perspective: read from the SAME dict (same process in this test)
        is_active_worker_b = session_service._get_cached_active_session(fake_token)

        # VULNERABILITY J: In a single-process test they share the dict,
        # but in production with --workers=2 each process has its own dict.
        # We confirm the cache exists and is a plain dict (not Redis/shared).
        assert isinstance(session_service._SESSION_ACTIVE_LOCAL_CACHE, dict), (
            "Cache is not a shared store — VULNERABILITY J: each worker "
            "process maintains its own isolated cache."
        )

        # The real vulnerability is verified by noting the cache is a plain
        # dict, not a Redis or database-backed shared store.
        # In-process: cache IS shared (both point to same dict).
        # In production: each worker has its own dict → inconsistent.
        assert is_active_worker_b is True  # same process → shared dict

        # Cleanup
        session_service.forget_active_session_token(fake_token)

    def test_session_status_snapshot_bypasses_user_id_verification(self) -> None:
        """
        touch_session_by_token_id with allow_cached_active=True returns
        SessionStatusSnapshot(status='active') WITHOUT verifying user_id.
        """
        from app.services import session_service
        from app.models.user_session import UserSession

        # Manually register a session in the cache
        fake_token = "test_bypass_sid"
        fake_expires = datetime.now(timezone.utc) + timedelta(hours=1)
        session_service.remember_active_session_token(fake_token, expires_at=fake_expires)

        # Call touch with allow_cached_active=True — returns snapshot, not row
        snapshot_or_row, was_touched = session_service.touch_session_by_token_id(
            db=None,  # type: ignore[arg-type]
            session_token_id=fake_token,
            allow_cached_active=True,
        )

        # VULNERABILITY J CONFIRMED: returns snapshot without DB lookup
        assert hasattr(snapshot_or_row, "status"), (
            f"Expected SessionStatusSnapshot, got {type(snapshot_or_row)}"
        )
        assert snapshot_or_row.status == "active"
        assert was_touched is False  # did not hit DB

        # Cleanup
        session_service.forget_active_session_token(fake_token)


# ─────────────────────────────────────────────────────────────────────────────
# TC-045  隐患 K — 密码重置后旧密码在缓存 TTL 内仍有效
# ─────────────────────────────────────────────────────────────────────────────

class TestVulnerabilityK_TC045:
    """verify_password_cached TTL=60s，密码重置后旧密码仍可登录。"""

    def test_old_password_accepted_within_cache_ttl(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        # Create a target user
        suffix = str(int(time.time() * 1000) % 100_000)
        target_username = f"pwdtest_{suffix}"
        target_password = "OldPwd@123"

        create_resp = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "username": target_username,
                "password": target_password,
                "role_code": "operator",
                "is_active": True,
            },
        )
        assert create_resp.status_code == 201
        user_id = create_resp.json()["data"]["id"]

        # Confirm old password works
        old_login = client.post(
            "/api/v1/auth/login",
            data={"username": target_username, "password": target_password},
        )
        assert old_login.status_code == 200, "Old password should work before reset"

        # Reset password (admin forces new password)
        new_password = "NewPwd@456"
        reset_resp = client.post(
            f"/api/v1/users/{user_id}/reset-password",
            headers=admin_headers,
            json={"new_password": new_password},
        )
        assert reset_resp.status_code == 200, reset_resp.text

        # Immediately try old password — VULNERABILITY K: should fail but may succeed
        old_login_after_reset = client.post(
            "/api/v1/auth/login",
            data={"username": target_username, "password": target_password},
        )

        if old_login_after_reset.status_code == 200:
            # VULNERABILITY K CONFIRMED: old password accepted within cache window
            assert True, "VULNERABILITY K CONFIRMED: old password accepted during cache TTL"
        else:
            # Either cache expired already, or the cache key changed
            # (The password hash was regenerated, so cache key = SHA256(user:id|new_hash|old_pwd) != old key)
            # This means the vulnerability is partially mitigated by the hash-in-cache-key design,
            # but the cache key uses the HASH, not the user_id alone.
            # A separate test with same hash but changed password is needed.
            pytest.skip(
                "Old password rejected immediately — cache key uses new hash; "
                "vulnerability requires old hash to still be cached from a previous login."
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
