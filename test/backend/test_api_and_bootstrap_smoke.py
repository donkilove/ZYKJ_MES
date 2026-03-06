from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.api import deps
from app.api.v1.api import api_router
from app.bootstrap import startup_bootstrap
from app.core.rbac import ROLE_OPERATOR, ROLE_SYSTEM_ADMIN
from app.core.security import create_access_token
from app.main import health
from app.models.user import User
from app.services import bootstrap_seed_service


def test_health_endpoint_function() -> None:
    assert health() == {"status": "ok"}


def test_api_router_registers_expected_prefixes() -> None:
    paths = {route.path for route in api_router.routes}
    assert "/auth/login" in paths
    assert "/users" in paths
    assert "/production/orders" in paths


def test_require_role_codes_dependency() -> None:
    dep = deps.require_role_codes([ROLE_SYSTEM_ADMIN])

    allowed_user = SimpleNamespace(roles=[SimpleNamespace(code=ROLE_SYSTEM_ADMIN)])
    assert dep(allowed_user) is allowed_user

    denied_user = SimpleNamespace(roles=[SimpleNamespace(code=ROLE_OPERATOR)])
    with pytest.raises(Exception) as exc:
        dep(denied_user)
    assert "Access denied" in str(exc.value)


def test_get_current_user_with_token(db, factory, monkeypatch) -> None:
    user = factory.user(username="token_user", role_codes=[ROLE_SYSTEM_ADMIN])
    db.commit()
    token = create_access_token(str(user.id))

    found = deps.get_current_user(token=token, db=db)
    assert isinstance(found, User)
    assert found.id == user.id

    with pytest.raises(Exception):
        deps.get_current_user(token="bad-token", db=db)

    monkeypatch.setattr(deps, "decode_access_token", lambda _: {"sub": "NaN"})
    with pytest.raises(Exception):
        deps.get_current_user(token="whatever", db=db)


def test_seed_initial_data_creates_roles_and_admin(db) -> None:
    result = bootstrap_seed_service.seed_initial_data(
        db,
        admin_username="admin",
        admin_password="Admin@123",
    )
    assert result.admin_username == "admin"
    assert result.admin_created is True

    result2 = bootstrap_seed_service.seed_initial_data(
        db,
        admin_username="admin",
        admin_password="Admin@123",
    )
    assert result2.admin_created is False


def test_startup_bootstrap_disabled_short_circuit(monkeypatch) -> None:
    monkeypatch.setattr(startup_bootstrap.settings, "bootstrap_on_startup", False)
    startup_bootstrap.run_startup_bootstrap()


def test_backend_root_points_to_backend_dir() -> None:
    backend_root = startup_bootstrap._backend_root()
    assert backend_root.name == "backend"
