"""tests/api/conftest.py — Shared pytest fixtures for user-module API tests.

Architecture
────────────
All DB access is routed through an isolated transaction.  The `db_session` fixture
owns the transaction; the `client` fixture shares the same transaction so data
created via API calls is immediately visible to ORM queries via db_session.

Each function-scoped test gets its own dedicated DB connection with a SAVEPOINT
that is always rolled back at test exit.  No test can commit to the real DB.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path
from typing import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

BACKEND_DIR = Path(__file__).resolve().parents[2]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import deps
from app.main import app


# ─────────────────────────────────────────────────────────────────────────────
# Session-level constants
# ─────────────────────────────────────────────────────────────────────────────

_ADMIN_USERNAME = "admin"
_ADMIN_PASSWORD = "Admin@123456"


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _clear_all_in_process_caches() -> None:
    """Clear every module-level in-process cache used by the auth subsystem."""
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
        pass

    try:
        import app.services.session_service as session_service
        session_service._SUCCESS_LOGIN_LOG_LOCAL_CACHE.clear()
    except Exception:
        pass

    try:
        import app.services.login_ratelimit_service as login_ratelimit_service
        login_ratelimit_service._LOGIN_RATELIMIT_REDIS_CLIENT = None
        login_ratelimit_service._LOGIN_RATELIMIT_REDIS_INIT = False
        login_ratelimit_service._LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL = 0.0
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────────────────────
# Import the bridge class and isolated tx class from tests/conftest.py
# ─────────────────────────────────────────────────────────────────────────────

pytest_unittest_transaction_bridge = pytest.importorskip(
    "tests.conftest"
).pytest_unittest_transaction_bridge
_IsolatedTransaction = pytest.importorskip("tests.conftest")._IsolatedTransaction


# ─────────────────────────────────────────────────────────────────────────────
# db_session — yields a session factory bound to the isolated transaction
# ─────────────────────────────────────────────────────────────────────────────

class _SessionFactoryResult:
    """Holds the transaction + session factory for a test's lifetime."""

    def __init__(self) -> None:
        self.tx = _IsolatedTransaction()
        self._factory = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=self.tx._connection,
            expire_on_commit=False,
        )

    def session(self) -> Session:
        return self._factory()

    def close(self) -> None:
        try:
            self.tx.close()
        except Exception:
            pass


@pytest.fixture(scope="function")
def db_session() -> Generator[Session, None, None]:
    """SQLAlchemy session bound to the isolated transaction with SAVEPOINT active.

    Yields a session with begin_nested() called so the app's db.commit() calls
    only close/reopen the SAVEPOINT (not the outer transaction).
    The after_transaction_end listener in tests/conftest.py re-creates the
    SAVEPOINT automatically whenever it ends.

    Teardown: rollback SAVEPOINT → close session → rollback outer tx.
    """
    result = _SessionFactoryResult()
    session = result.session()
    # Activate the nested transaction (SAVEPOINT) — this is the test sandbox.
    session.begin_nested()
    try:
        yield session
    finally:
        try:
            session.close()
        except Exception:
            pass
        result.close()
        _clear_all_in_process_caches()


# ─────────────────────────────────────────────────────────────────────────────
# client — FastAPI TestClient sharing the same transaction as db_session
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(scope="function")
def client(db_session: Session) -> Generator[TestClient, None, None]:
    """FastAPI TestClient whose request handlers use the same isolated transaction as db_session.

    Uses a session factory so concurrent threads each get their own SQLAlchemy
    session bound to the same connection + transaction, avoiding "Session is already flushing".
    """
    db_bind = db_session.get_bind()

    # Get the _SessionFactoryResult that owns the transaction.
    # We reach into the db_session's bind to find the owning transaction.
    # The connection from get_bind() was obtained from _IsolatedTransaction._connection.
    # We create a new sessionmaker on the same connection.
    _session_factory = sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=db_bind,
        expire_on_commit=False,
    )

    def _get_isolated_db():
        yield _session_factory()

    app.dependency_overrides[deps.get_db] = _get_isolated_db

    try:
        with TestClient(app) as c:
            yield c
    finally:
        app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# Auth helper fixtures
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture
def admin_token(client: TestClient, db_session: Session) -> str:
    """Return a valid JWT for the seeded admin account."""
    response = client.post(
        "/api/v1/auth/login",
        data={"username": _ADMIN_USERNAME, "password": _ADMIN_PASSWORD},
    )
    if response.status_code == 403 and "disabled" in response.json().get("detail", "").lower():
        # Fix within the isolated transaction — will be rolled back at test exit.
        from sqlalchemy import update
        from app.models.user import User
        from app.core.security import get_password_hash

        db_session.execute(
            update(User)
            .where(User.username == _ADMIN_USERNAME)
            .values(is_active=True, password_hash=get_password_hash(_ADMIN_PASSWORD))
        )
        db_session.commit()

        response = client.post(
            "/api/v1/auth/login",
            data={"username": _ADMIN_USERNAME, "password": _ADMIN_PASSWORD},
        )

    assert response.status_code == 200, f"Admin login failed: {response.status_code} — {response.text}"
    return response.json()["data"]["access_token"]


@pytest.fixture
def admin_headers(admin_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def operator_token(client: TestClient, admin_headers: dict) -> tuple[str, str]:
    """Create a stage + an operator user; return (token, username)."""
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
    """Return (token_a, token_b) for two distinct admin sessions."""
    token_a_resp = client.post(
        "/api/v1/auth/login",
        data={"username": _ADMIN_USERNAME, "password": _ADMIN_PASSWORD},
    )
    assert token_a_resp.status_code == 200, (
        f"Admin A login failed: {token_a_resp.status_code} — {token_a_resp.text}"
    )
    token_a = token_a_resp.json()["data"]["access_token"]

    suffix = int(time.time() * 1000) % 100_000

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
    """Patch the guardrail counter so TC-040 runs with exactly 3 fixture admins."""
    import app.services.user_service as user_service_module
    from app.core.security import decode_access_token
    from sqlalchemy import func, select
    from app.models.user import User
    from app.db.session import SessionLocal

    token_a, token_b = two_admin_tokens
    admin_a_id = int(decode_access_token(token_a)["sub"])
    admin_b_id = int(decode_access_token(token_b)["sub"])

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
        assert len(fixture_ids) >= 3, (
            f"Expected at least 3 fixture admins, got {len(fixture_ids)}"
        )
        admin_ids = set(fixture_ids[:3])
    finally:
        db.close()

    original = user_service_module._lock_and_count_active_system_admins_for_guardrail

    def isolated_count(db_inner, *, exclude_user_id: int) -> int:
        return (
            db_inner.execute(
                select(func.count(User.id)).where(
                    User.id.in_(admin_ids),
                    User.is_active.is_(True),
                    User.is_deleted.is_(False),
                )
            ).scalar_one()
            - 1
        )

    user_service_module._lock_and_count_active_system_admins_for_guardrail = isolated_count

    yield

    user_service_module._lock_and_count_active_system_admins_for_guardrail = original
