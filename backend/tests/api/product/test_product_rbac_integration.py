from __future__ import annotations

import time

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import get_password_hash
from app.models.role import Role
from app.models.user import User
from app.services.authz_service import replace_role_permissions_for_module
from tests.api.product.product_test_helpers import activate_version, create_product


def _unique_suffix(label: str) -> str:
    return f"{label}{int(time.time() * 1000)}"


def _create_role_and_user_with_permissions(
    db_session: Session,
    *,
    suffix: str,
    permission_codes: list[str],
) -> tuple[Role, User]:
    role = Role(
        code=f"product_it_{suffix}_{int(time.time() * 1000)}",
        name=f"产品权限角色-{suffix}",
        role_type="custom",
        is_enabled=True,
        is_builtin=False,
        is_deleted=False,
    )
    db_session.add(role)
    db_session.commit()
    db_session.refresh(role)

    user = User(
        username=f"product_perm_{suffix}_{int(time.time() * 1000)}",
        full_name=f"产品权限用户-{suffix}",
        password_hash=get_password_hash("Pwd@123"),
        is_active=True,
        is_superuser=False,
        remark="产品模块 RBAC 集成测试",
    )
    user.roles.append(db_session.merge(role))
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    replace_role_permissions_for_module(
        db_session,
        role_code=role.code,
        module_code="product",
        granted_permission_codes=permission_codes,
        operator=None,
        remark="产品模块 RBAC 集成测试授权",
    )
    db_session.commit()
    db_session.refresh(user)
    return role, user


def _login_as(
    client: TestClient,
    *,
    username: str,
    password: str = "Pwd@123",
) -> str:
    response = client.post(
        "/api/v1/auth/login",
        data={"username": username, "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()["data"]["access_token"]


def test_product_rbac_separates_create_update_delete_and_version_destructive_permissions(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    _, limited_user = _create_role_and_user_with_permissions(
        db_session,
        suffix=_unique_suffix("limited"),
        permission_codes=[
            "product.products.list",
            "product.products.create",
        ],
    )
    limited_headers = {
        "Authorization": f"Bearer {_login_as(client, username=limited_user.username)}"
    }

    list_response = client.get("/api/v1/products", headers=limited_headers)
    assert list_response.status_code == 200, list_response.text
    assert "total" in list_response.json()["data"]

    create_response = client.post(
        "/api/v1/products",
        headers=limited_headers,
        json={
            "name": f"RBAC-产品-{_unique_suffix('create')}",
            "category": "贴片",
            "remark": "RBAC 创建产品",
        },
    )
    assert create_response.status_code == 201, create_response.text
    created_product = create_response.json()["data"]
    product_id = int(created_product["id"])
    current_version = int(created_product["current_version"])

    update_denied = client.put(
        f"/api/v1/products/{product_id}",
        headers=limited_headers,
        json={
            "name": f"RBAC-改名-{_unique_suffix('update')}",
            "category": "DTU",
            "remark": "RBAC 越权更新应被拒绝",
        },
    )
    assert update_denied.status_code == 403, update_denied.text

    delete_denied = client.post(
        f"/api/v1/products/{product_id}/delete",
        headers=limited_headers,
        json={"password": "Pwd@123"},
    )
    assert delete_denied.status_code == 403, delete_denied.text

    activate_response = activate_version(
        client,
        admin_headers,
        product_id=product_id,
        version=current_version,
        expected_effective_version=0,
    )
    assert activate_response.status_code == 200, activate_response.text

    replace_role_permissions_for_module(
        db_session,
        role_code=limited_user.roles[0].code,
        module_code="product",
        granted_permission_codes=[
            "product.products.list",
            "product.products.create",
            "product.versions.create",
        ],
        operator=None,
        remark="补充版本新建权限",
    )
    db_session.commit()

    version_create_headers = {
        "Authorization": f"Bearer {_login_as(client, username=limited_user.username)}"
    }

    create_version_response = client.post(
        f"/api/v1/products/{product_id}/versions",
        headers=version_create_headers,
        json={},
    )
    assert create_version_response.status_code == 201, create_version_response.text
    draft_version = int(create_version_response.json()["data"]["version"])
    assert draft_version == current_version + 1
    assert create_version_response.json()["data"]["lifecycle_status"] == "draft"

    disable_denied = client.post(
        f"/api/v1/products/{product_id}/versions/{current_version}/disable",
        headers=version_create_headers,
        json={},
    )
    assert disable_denied.status_code == 403, disable_denied.text

    delete_version_denied = client.delete(
        f"/api/v1/products/{product_id}/versions/{draft_version}",
        headers=version_create_headers,
    )
    assert delete_version_denied.status_code == 403, delete_version_denied.text
