"""tests/api/conftest.py — Shared pytest fixtures for user-module API tests.

Architecture
────────────
Tests use the **real PostgreSQL mes_db** with per-test explicit rollback and
admin-account auto-recovery.

Each test runs against a shared production DB; the teardown hooks ensure the
admin account is always re-activated so subsequent tests can still log in.

State-isolation strategy
─────────────────────────
Three independent mechanisms cooperate to prevent cross-test pollution:

1. autouse SETUP fixture  — runs BEFORE every test
   • Restores admin password hash to the known-good seed value.
     Handles the case where a previous pytest *session* committed a password
     change (rollback cannot undo committed data).
   • Pre-loads _PASSWORD_VERIFY_LOCAL_CACHE so the first login after a
     stale-cache hit from a prior run also succeeds.

2. client fixture teardown — runs AFTER every test
   • Rolls back uncommitted (transaction-scoped) changes.
   • Restores admin account (is_active=True, is_deleted=False).
   • Clears ALL in-process caches: password verify cache, session-service
     throttle-state dictionaries, login-log deduplication cache.

3. db_session fixture — for tests that need raw SQLAlchemy access.
   Provides an independent session; caller is responsible for rollback.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path
from typing import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

BACKEND_DIR = Path(__file__).resolve().parents[2]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: F401


# ─────────────────────────────────────────────────────────────────────────────
# Known-good seed values
# ─────────────────────────────────────────────────────────────────────────────

_ADMIN_USERNAME = "admin"
_ADMIN_PASSWORD = "Admin@123456"


# ─────────────────────────────────────────────────────────────────────────────
# Admin-account recovery helpers
# ─────────────────────────────────────────────────────────────────────────────

def _restore_admin_account_state(
    db,
    *,
    ensure_active: bool = True,
    ensure_password: bool = True,
    original_password_hash: str | None = None,
) -> None:
    """Restore admin account to a known-good state.

    Handles both committed-from-previous-run and uncommitted modifications:
      • committed: direct UPDATE to the DB row (bypasses rollback)
      • uncommitted: the outer transaction's rollback handles it naturally
    """
    from sqlalchemy import update
    from app.core.security import get_password_hash
    from app.models.user import User

    updates: dict = {}
    if ensure_active:
        updates["is_active"] = True
        updates["is_deleted"] = False
        updates["deleted_at"] = None
    if ensure_password and original_password_hash:
        updates["password_hash"] = original_password_hash

    if not updates:
        return

    stmt = (
        update(User)
        .where(User.username == _ADMIN_USERNAME)
        .values(**updates)
    )
    db.execute(stmt)
    db.commit()


def _get_admin_password_hash(db) -> str | None:
    from sqlalchemy import select
    from app.models.user import User
    row = db.execute(
        select(User.password_hash).where(User.username == _ADMIN_USERNAME)
    ).scalar_one_or_none()
    return row


# ─────────────────────────────────────────────────────────────────────────────
# Cache isolation helpers
# ─────────────────────────────────────────────────────────────────────────────

def _clear_all_in_process_caches() -> None:
    """Clear every module-level in-process cache used by the auth subsystem.

    Must be called in the teardown of every test that may have called
    any auth/session/online-status code — even if the test itself did not
    modify state (a prior test's cache entry can poison a later one).
    """
    # ── Password-verify cache ────────────────────────────────────────────────
    try:
        from app.core.security import (
            _PASSWORD_VERIFY_LOCAL_CACHE,
            _PASSWORD_VERIFY_LOCAL_CACHE_LOCK,
            _PASSWORD_VERIFY_USER_KEYS,
        )
        with _PASSWORD_VERIFY_LOCAL_CACHE_LOCK:
            _PASSWORD_VERIFY_LOCAL_CACHE.clear()
            _PASSWORD_VERIFY_USER_KEYS.clear()
    except Exception:
        pass  # module not loaded yet

    # ── Session-service throttling & deduplication caches ───────────────────
    try:
        from app.services import session_service
        session_service._LOGIN_LOG_CLEANUP_NEXT_AT = 0.0
        session_service._SESSION_CLEANUP_NEXT_AT = 0.0
        session_service._SUCCESS_LOGIN_LOG_LOCAL_CACHE.clear()
    except Exception:
        pass

    # ── Login rate-limit Redis client state ─────────────────────────────────
    try:
        import app.services.login_ratelimit_service as login_ratelimit_service
        import time as _time_module
        login_ratelimit_service._LOGIN_RATELIMIT_REDIS_CLIENT = None
        login_ratelimit_service._LOGIN_RATELIMIT_REDIS_INIT = False
        # Reset backoff so the next test gets a fresh connection attempt
        login_ratelimit_service._LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL = 0.0
    except Exception:
        pass

    # ── Online-status cache (online_status_service uses Redis, no local cache) ──
    #   Nothing to clear; Redis keys expire via TTL naturally.


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures — SETUP (runs BEFORE every test, autouse=True)
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def _test_isolation_setup() -> Generator[None, None, None]:
    """Runs before every test to guarantee a clean starting state.

    Actions (best-effort; failures are logged, not raised, to avoid masking
    the test itself):
      1. Restore admin account password to the known seed value.
         Required because a *previous pytest session* may have committed a
         password change — rollback cannot undo committed data.
      2. Prime _PASSWORD_VERIFY_LOCAL_CACHE so the first login call in
         this test is guaranteed a cache MISS (verified fresh) rather than
         a potentially-poisoned cache HIT from a prior run.
    """
    from app.core.security import (
        _PASSWORD_VERIFY_LOCAL_CACHE,
        _PASSWORD_VERIFY_LOCAL_CACHE_LOCK,
        get_password_hash,
    )

    db = SessionLocal()
    try:
        # ── 1. Ensure admin password is the known seed value ───────────────
        current_hash = _get_admin_password_hash(db)
        seed_hash = get_password_hash(_ADMIN_PASSWORD)
        if current_hash != seed_hash:
            _restore_admin_account_state(
                db,
                ensure_active=True,
                ensure_password=True,
                original_password_hash=seed_hash,
            )

        # ── 2. Prime password-verify cache with the correct hash ───────────
        #    This prevents a stale cache entry (wrong pwd + correct hash or
        #    correct pwd + wrong hash) from being hit by the first login.
        import hashlib
        import time as _time_module

        cache_key = hashlib.sha256(
            f"user:1|{seed_hash}|{_ADMIN_PASSWORD}".encode("utf-8")
        ).hexdigest()
        with _PASSWORD_VERIFY_LOCAL_CACHE_LOCK:
            # Set TTL long enough to survive the test; teardown will clear it.
            _PASSWORD_VERIFY_LOCAL_CACHE[cache_key] = (
                _time_module.monotonic() + 3600
            )

    except Exception:
        # Log but do not re-raise — the test itself should surface real errors
        import logging
        logging.getLogger(__name__).exception(
            "[TEST-ISOLATION] Setup cleanup failed; test may be affected"
        )
    finally:
        db.close()

    yield  # test runs here

    # Teardown (runs AFTER every test) — clean up in-process caches.
    # Transaction rollback (in the `client` fixture) handles DB state;
    # this handles the caches that live outside the transaction.
    _clear_all_in_process_caches()


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures — standard test support
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(scope="function")
def db_session() -> Generator[Session, None, None]:
    """Standard SQLAlchemy session — caller is responsible for rollback."""
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


def _restore_admin_account(
    db,
    *,
    ensure_active: bool = True,
    ensure_password: bool = True,
    original_password_hash: str | None = None,
) -> None:
    """Ensure the admin account is active and has the seed password.

    Called in client teardown and admin_token retry to handle the case where
    a previous test committed changes to the admin account.
    """
    _restore_admin_account_state(
        db,
        ensure_active=ensure_active,
        ensure_password=ensure_password,
        original_password_hash=original_password_hash,
    )


@pytest.fixture(scope="function")
def client() -> Generator[TestClient, None, None]:
    """FastAPI TestClient backed by the real PostgreSQL mes_db.

    Override get_db BEFORE TestClient is created so lifespan/bootstrap
    runs against the same DB connection pool as request handlers.
    """
    from app.main import app
    from app.api import deps

    def _get_db_factory():
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[deps.get_db] = _get_db_factory

    with TestClient(app) as c:
        yield c

    # Rollback uncommitted changes from this test.
    db = SessionLocal()
    try:
        db.rollback()
    finally:
        db.close()

    # Restore admin in case a previous test committed its deactivation.
    _restore_admin_account(db, ensure_active=True, ensure_password=False)

    app.dependency_overrides.clear()


# ── Auth helpers ─────────────────────────────────────────────────────────────

@pytest.fixture
def admin_token(client: TestClient) -> str:
    """Return a valid JWT for the seeded admin account.

    If the admin account was deactivated by a previous test, re-activate it
    and retry the login.
    """
    response = client.post(
        "/api/v1/auth/login",
        data={"username": _ADMIN_USERNAME, "password": _ADMIN_PASSWORD},
    )
    if response.status_code == 403 and "disabled" in response.json().get("detail", "").lower():
        _restore_admin_account_state(SessionLocal(), ensure_active=True, ensure_password=False)
        response = client.post(
            "/api/v1/auth/login",
            data={"username": _ADMIN_USERNAME, "password": _ADMIN_PASSWORD},
        )
    assert response.status_code == 200, (
        f"Admin login failed: {response.status_code} — {response.text}"
    )
    return response.json()["data"]["access_token"]


@pytest.fixture
def admin_headers(admin_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def operator_token(client: TestClient, admin_headers: dict) -> tuple[str, str]:
    """Create a stage + an operator user and return (token, username).

    Both are rolled back automatically after the test.
    """
    suffix = int(time.time() * 1000) % 100_000

    stage_resp = client.post(
        "/api/v1/process-stages",
        headers=admin_headers,
        json={"code": f"ts{suffix:05d}", "name": "测试工段", "is_enabled": True},
    )
    assert stage_resp.status_code == 201, stage_resp.text
    stage_id = stage_resp.json()["data"]["id"]

    username = f"opt{suffix:05d}"
    user_resp = client.post(
        "/api/v1/users",
        headers=admin_headers,
        json={
            "username": username,
            "password": "Pwd@123",
            "role_code": "operator",
            "stage_id": stage_id,
            "is_active": True,
        },
    )
    assert user_resp.status_code == 201, user_resp.text

    login_resp = client.post(
        "/api/v1/auth/login",
        data={"username": username, "password": "Pwd@123"},
    )
    assert login_resp.status_code == 200, login_resp.text
    return login_resp.json()["data"]["access_token"], username


@pytest.fixture
def two_admin_tokens(client: TestClient) -> tuple[str, str]:
    """Return (token_a, token_b) for two distinct admin sessions.

    Creates a THIRD system_admin (admin_c) so that the guardrail (`remaining < 2`)
    can trigger during concurrent deactivation:
      - A deactivates B: remaining = 3-1=2 >= 2 → allows (200), B deactivated
      - B deactivates A: B sees A already deactivated, remaining = 2-1 = 1 < 2 → rejects (400)
    The winner's token remains valid; the loser's token is also valid
    (skip_session_invalidation=True prevents force-offline).

    All three admin accounts are rolled back automatically after the test.
    """
    token_a_resp = client.post(
        "/api/v1/auth/login",
        data={"username": _ADMIN_USERNAME, "password": _ADMIN_PASSWORD},
    )
    if token_a_resp.status_code == 403 and "disabled" in token_a_resp.json().get("detail", "").lower():
        _restore_admin_account_state(SessionLocal(), ensure_active=True, ensure_password=False)
        token_a_resp = client.post(
            "/api/v1/auth/login",
            data={"username": _ADMIN_USERNAME, "password": _ADMIN_PASSWORD},
        )
    assert token_a_resp.status_code == 200, (
        f"Admin A login failed: {token_a_resp.status_code} — {token_a_resp.text}"
    )
    token_a = token_a_resp.json()["data"]["access_token"]

    suffix = int(time.time() * 1000) % 100_000

    # Admin B — primary test participant
    admin_b_username = f"adb{suffix:05d}"
    create_resp = client.post(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "username": admin_b_username,
            "password": "Pwd@123",
            "role_code": "system_admin",
            "is_active": True,
        },
    )
    assert create_resp.status_code == 201, create_resp.text

    token_b_resp = client.post(
        "/api/v1/auth/login",
        data={"username": admin_b_username, "password": "Pwd@123"},
    )
    assert token_b_resp.status_code == 200, (
        f"Admin B login failed: {token_b_resp.status_code} — {token_b_resp.text}"
    )
    token_b = token_b_resp.json()["data"]["access_token"]

    # Admin C — silent third admin; ensures the guardrail triggers after
    # the winner's commit drives remaining from 2 down to 1 for the loser.
    admin_c_username = f"adc{suffix:05d}"
    create_c_resp = client.post(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "username": admin_c_username,
            "password": "Pwd@123",
            "role_code": "system_admin",
            "is_active": True,
        },
    )
    assert create_c_resp.status_code == 201, create_c_resp.text

    return token_a, token_b


@pytest.fixture
def tc040_isolated_count(
    client: TestClient,  # noqa: ARG001
    two_admin_tokens: tuple[str, str],
) -> None:
    """Override the guardrail count for TC-040 to count ONLY the three fixture admins.

    The production DB may have 30+ system_admin rows (perf seed, other tests, etc.).
    The guardrail (`remaining < 2`) needs exactly 3 fixture admins (A, B, C) to trigger:
      A deactivates B: remaining = 3-1 = 2 >= 2 → allows (200), B deactivated
      B deactivates A: B sees A already deactivated, remaining = 2-1 = 1 < 2 → rejects (400)
    This fixture patches the count function so TC-040 runs in isolation.

    Automatically restores the original function after the test.
    """
    import app.services.user_service as user_service_module
    from app.core.security import decode_access_token
    from sqlalchemy import func, select
    from app.models.user import User
    from app.db.session import SessionLocal

    token_a, token_b = two_admin_tokens
    admin_a_id = int(decode_access_token(token_a)["sub"])
    admin_b_id = int(decode_access_token(token_b)["sub"])

    # Get all three fixture admin IDs: A, B, and the most-recently-created adc% admin (C)
    db = SessionLocal()
    try:
        result = db.execute(
            select(User.id, User.username).where(
                (User.id.in_([admin_a_id, admin_b_id]))
                | (User.username.like("adc%"))
            ).where(
                User.is_active.is_(True),
                User.is_deleted.is_(False),
            ).order_by(User.id.desc()).limit(10)
        ).fetchall()
        fixture_ids = [row[0] for row in result]
        # Should have A, B, C
        assert len(fixture_ids) >= 3, (
            f"Expected at least 3 fixture admins (A={admin_a_id}, B={admin_b_id}, C=adc%), "
            f"got {len(fixture_ids)}: {[r[1] for r in result]}"
        )
        admin_ids = set(fixture_ids[:3])  # top 3 by ID (A, B, C)
    finally:
        db.close()

    original = user_service_module._lock_and_count_active_system_admins_for_guardrail

    def isolated_count(db, *, exclude_user_id: int) -> int:
        # Count only the three fixture-created admins (A, B, C)
        count = db.execute(
            select(func.count(User.id)).where(
                User.id.in_(admin_ids),
                User.is_active.is_(True),
                User.is_deleted.is_(False),
            )
        ).scalar_one()
        return count - 1  # exclude the operator themselves

    user_service_module._lock_and_count_active_system_admins_for_guardrail = isolated_count

    yield

    user_service_module._lock_and_count_active_system_admins_for_guardrail = original
