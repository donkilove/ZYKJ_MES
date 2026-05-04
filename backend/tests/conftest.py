"""backend/tests/conftest.py — Global pytest configuration for all backend tests.

Architecture
────────────
All tests run against the real PostgreSQL mes_db with **nested-transaction
isolation** (PostgreSQL SAVEPOINTs).  Each test lives inside a sub-transaction
that is always rolled back, so:

  • No test can commit to the real DB (session-level autocommit stays off).
  • No test's data leaks to the next test.
  • Admin password state from previous pytest sessions is repaired once at
    session-start (outside the test transaction, so the fix is durable).

Isolation layers
────────────────
1. Function-scoped autouse fixture (_db_isolation_autouse)
      Creates _IsolatedSessionTransaction per test.
      Patches app.db.session.SessionLocal so direct SessionLocal() calls
      (including those in setUp / setUpClass) return isolated sessions.
      After test: rollback outer tx → DB fully restored.

2. unittest.TestCase bridge (_UnittestTransactionBridge)
      test_user_module_integration.py manages its own bridge in setUpClass.
      Detected by _db_isolation_autouse and skipped (no double-isolation).

3. tests/api/conftest.py — client fixture
      db_session fixture calls begin_nested() explicitly.
      client fixture overrides get_db to use the isolated session.
      Skips _db_isolation_autouse via pytest marker.

4. _DictRedisMock — in-memory Redis mock (function-scoped, autouse).
"""

from __future__ import annotations

import pytest
from sqlalchemy import event, text
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import NullPool


# ─────────────────────────────────────────────────────────────────────────────
# DB — nested-transaction isolation via SQLAlchemy SAVEPOINT
# ─────────────────────────────────────────────────────────────────────────────

from app.db.session import engine  # noqa: E402


class _IsolatedSessionTransaction:
    """Manages one isolated DB connection (outer tx) + SQLAlchemy SAVEPOINT (per test).

    Architecture:
      connection.begin()          ← outer transaction (never committed by tests)
          sessionmaker(bind=connection)
              session.begin_nested() ← SAVEPOINT (the "test sandbox")

    The after_transaction_end listener re-creates the SAVEPOINT every time
    the app code or a previous test action commits/rolls back the inner
    transaction — so the session always stays usable.

    Teardown: session.close() → outer_transaction.rollback() → connection.close()
    """

    _savepoint_counter = 0

    def __init__(self) -> None:
        self._connection = engine.connect().__enter__()
        self._outer_transaction = self._connection.begin()

        self._session_maker = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=self._connection,
            expire_on_commit=False,
        )
        self._session: Session = self._session_maker()

        _IsolatedSessionTransaction._savepoint_counter += 1
        self._sp_name = f"_test_sp_{_IsolatedSessionTransaction._savepoint_counter}"
        self._session.execute(text(f"SAVEPOINT {self._sp_name}"))

        # Track nested-transaction state to avoid re-creating SAVEPOINT on
        # begin_nested() entry (SQLAlchemy fires after_transaction_end during
        # begin_nested() itself before the nested tx is fully established).
        self._nested_transaction: object | None = None
        self._in_nested: bool = False

        @event.listens_for(self._session, "after_transaction_end")
        def _reopen_savepoint(
            session: Session,  # noqa: ARG001
            transaction_or_nested: object,
        ) -> None:
            if transaction_or_nested is self._outer_transaction:
                return
            # Only create a new SAVEPOINT when we are EXITING a nested tx
            # (is_active=False), not when ENTERING (is_active=True).
            is_active = getattr(transaction_or_nested, "is_active", True)
            if self._in_nested and not is_active:
                # Exiting nested → recreate once.
                session.execute(text(f"SAVEPOINT {self._sp_name}"))
                self._nested_transaction = None
                self._in_nested = False
            elif not self._in_nested and is_active:
                # Entering nested (begin_nested() just finished).
                self._nested_transaction = transaction_or_nested
                self._in_nested = True

    def session(self) -> Session:
        return self._session

    def rollback_to_savepoint(self) -> None:
        self._session.rollback()
        self._session.expire_all()

    def close(self) -> None:
        try:
            self._outer_transaction.rollback()
        except Exception:
            pass
        try:
            self._session.close()
        except Exception:
            pass
        try:
            self._connection.close()
        except Exception:
            pass


# ─────────────────────────────────────────────────────────────────────────────
# unittest.TestCase bridge
# ─────────────────────────────────────────────────────────────────────────────


class _UnittestTransactionBridge:
    """Per-class transaction used by unittest.TestCase subclasses.

    Provides classmethods that test_user_module_integration.py calls from
    its own setUpClass / tearDownClass.
    """

    _class_tx: "_IsolatedTransaction | None" = None

    @classmethod
    def begin(cls) -> None:
        if cls._class_tx is not None:
            raise RuntimeError("begin() called twice without end()")
        cls._class_tx = _IsolatedTransaction()

    @classmethod
    def rollback_test_method(cls) -> None:
        if cls._class_tx is None:
            raise RuntimeError("begin() was not called")
        cls._class_tx.rollback_to_savepoint()

    @classmethod
    def end(cls) -> None:
        if cls._class_tx is not None:
            cls._class_tx.close()
            cls._class_tx = None

    @classmethod
    def session(cls) -> Session:
        if cls._class_tx is None:
            raise RuntimeError("begin() was not called")
        return cls._class_tx.session()


pytest_unittest_transaction_bridge = _UnittestTransactionBridge


# ─────────────────────────────────────────────────────────────────────────────
# Setup — runs once per session: fix admin password committed by previous runs
# ─────────────────────────────────────────────────────────────────────────────


def _repair_admin_from_prior_session() -> None:
    from sqlalchemy import update
    from app.core.security import get_password_hash
    from app.models.user import User

    _ADMIN_USERNAME = "admin"
    _ADMIN_PASSWORD = "Admin@123456"

    repair_engine = engine.execution_options(poolclass=NullPool)
    RepairSession = sessionmaker(bind=repair_engine)
    repair_session = RepairSession()
    try:
        seed_hash = get_password_hash(_ADMIN_PASSWORD)
        repair_session.execute(
            update(User)
            .where(User.username == _ADMIN_USERNAME)
            .values(
                is_active=True,
                is_deleted=False,
                deleted_at=None,
                password_hash=seed_hash,
            )
        )
        repair_session.commit()
    except Exception:
        repair_session.rollback()
        raise
    finally:
        repair_session.close()
        repair_engine.dispose()


@pytest.fixture(scope="session", autouse=True)
def _session_setup() -> None:
    _repair_admin_from_prior_session()
    yield


# ─────────────────────────────────────────────────────────────────────────────
# Autouse isolation: function-scoped (per test, patches SessionLocal for setUp)
#
# Skipped for:
#   • tests using _UnittestTransactionBridge (test_user_module_integration.py)
#   • tests using the db_session fixture (tests/api/conftest.py) — those have
#     their own isolated transaction managed by _SessionFactoryResult
# ─────────────────────────────────────────────────────────────────────────────

from app.db import session as _session_module


def _skip_autouse_isolation(request: pytest.FixtureRequest) -> bool:
    """Return True if the current test should skip autouse DB isolation.

    Reasons to skip:
      1. unittest bridge is active (test_user_module_integration.py)
      2. test uses the db_session fixture (tests/api/conftest.py) — those
         tests manage their own isolated transaction via _SessionFactoryResult.
    """
    if _UnittestTransactionBridge._class_tx is not None:
        return True

    # Check if the test uses the db_session fixture (api conftest).
    # Those tests get their own isolated transaction from _SessionFactoryResult.
    if "db_session" in request.fixturenames:
        return True

    return False


@pytest.fixture(autouse=True, scope="function")
def _db_isolation_autouse(request: pytest.FixtureRequest) -> None:
    """Per-function DB isolation with SAVEPOINT.

    Creates an isolated transaction before the test, patches SessionLocal so
    setUpClass / setUp calls get isolated sessions, and rolls back after test.
    """
    if _skip_autouse_isolation(request):
        yield
        return

    isolated_tx = _IsolatedSessionTransaction()

    _session_maker = sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=isolated_tx._connection,
        expire_on_commit=False,
    )

    _original = _session_module.SessionLocal

    def _isolated_session_factory() -> Session:
        s = _session_maker()
        s.begin_nested()
        return s

    _session_module.SessionLocal = _isolated_session_factory  # type: ignore[method-assign]

    try:
        yield
    finally:
        _session_module.SessionLocal = _original  # type: ignore[method-assign]
        isolated_tx.close()


# ─────────────────────────────────────────────────────────────────────────────
# Redis mock  (pure in-memory, function-scoped, no DB involvement)
# ─────────────────────────────────────────────────────────────────────────────


class _DictRedisMock:
    def __init__(self) -> None:
        self._data: dict[str, str] = {}

    def setex(self, key: str, ttl: int, value: str) -> None:
        self._data[key] = value

    def set(self, key: str, value: str, ex: int | None = None) -> None:
        self._data[key] = value

    def get(self, key: str) -> str | None:
        return self._data.get(key)

    def delete(self, key: str) -> int:
        if key in self._data:
            del self._data[key]
            return 1
        return 0

    def exists(self, key: str) -> int:
        return 1 if key in self._data else 0

    def scan(
        self, cursor: int = 0, match: str | None = None, count: int = 100
    ) -> tuple[int, list[str]]:
        import fnmatch

        all_keys = list(self._data.keys())
        matched = [k for k in all_keys if fnmatch.fnmatch(k, match)] if match else all_keys
        start, end = cursor, cursor + count
        page = matched[start:end]
        return (0, page) if end >= len(matched) else (end, page)

    def keys(self, pattern: str = "*") -> list[str]:
        import fnmatch

        return [k for k in self._data.keys() if fnmatch.fnmatch(k, pattern)]

    def pipeline(self) -> "_DictPipelineMock":
        return _DictPipelineMock(self)


class _DictPipelineMock:
    def __init__(self, client: _DictRedisMock) -> None:
        self._client = client
        self._commands: list[tuple[str, tuple, dict]] = []

    def setex(self, key: str, ttl: int, value: str) -> "_DictPipelineMock":
        self._commands.append(("setex", (key, ttl, value), {}))
        return self

    def exists(self, key: str) -> "_DictPipelineMock":
        self._commands.append(("exists", (key,), {}))
        return self

    def get(self, key: str) -> "_DictPipelineMock":
        self._commands.append(("get", (key,), {}))
        return self

    def execute(self) -> list:
        results: list = []
        for cmd, args, _kwargs in self._commands:
            if cmd == "setex":
                self._client.setex(*args)
                results.append(True)
            elif cmd == "exists":
                results.append(self._client.exists(*args))
            elif cmd == "get":
                results.append(self._client.get(*args))
            else:
                results.append(None)
        self._commands.clear()
        return results


_redis_store: _DictRedisMock | None = None


def _get_shared_redis() -> _DictRedisMock:
    global _redis_store
    if _redis_store is None:
        _redis_store = _DictRedisMock()
    return _redis_store


def _clear_shared_redis() -> None:
    global _redis_store
    if _redis_store is not None:
        _redis_store._data.clear()


@pytest.fixture(autouse=True, scope="function")
def _redis_mock() -> None:
    _clear_shared_redis()

    import app.services.session_service as _ss

    _ss._SESSION_REDIS_CLIENT = _get_shared_redis()
    _ss._SESSION_REDIS_INIT = True
    _ss._SESSION_REDIS_DISABLED_UNTIL = 0.0

    import app.services.online_status_service as _oss

    _oss._ONLINE_REDIS_CLIENT = _get_shared_redis()
    _oss._ONLINE_REDIS_INIT = True
    _oss._ONLINE_REDIS_DISABLED_UNTIL = 0.0

    import app.services.login_ratelimit_service as _lrs

    _lrs._LOGIN_RATELIMIT_REDIS_CLIENT = _get_shared_redis()
    _lrs._LOGIN_RATELIMIT_REDIS_INIT = True
    _lrs._LOGIN_RATELIMIT_REDIS_DISABLED_UNTIL = 0.0

    yield

    _clear_shared_redis()


# ─────────────────────────────────────────────────────────────────────────────
# Internal alias used by tests/api/conftest.py
# ─────────────────────────────────────────────────────────────────────────────

_IsolatedTransaction = _IsolatedSessionTransaction
