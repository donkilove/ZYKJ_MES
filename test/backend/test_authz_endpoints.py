from __future__ import annotations

from app.api.v1.endpoints import authz
from app.core.authz_catalog import (
    PERM_PROD_ORDERS_CREATE,
    PERM_PROD_ORDERS_LIST,
)
from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.schemas.authz import RolePermissionUpdateRequest


def test_authz_catalog_and_my_permissions(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_sys_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_prod_admin", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    catalog_resp = authz.get_permission_catalog_api(module="production", db=db, _=sys_admin)
    catalog_codes = {item.permission_code for item in catalog_resp.data.items}
    assert PERM_PROD_ORDERS_LIST in catalog_codes
    assert PERM_PROD_ORDERS_CREATE in catalog_codes

    me_sys = authz.get_my_permissions_api(module="production", db=db, current_user=sys_admin)
    assert PERM_PROD_ORDERS_LIST in me_sys.data.permission_codes
    assert PERM_PROD_ORDERS_CREATE in me_sys.data.permission_codes

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert PERM_PROD_ORDERS_LIST not in me_prod.data.permission_codes
    assert PERM_PROD_ORDERS_CREATE not in me_prod.data.permission_codes


def test_authz_role_permissions_update(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_update_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_update_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    update_resp = authz.put_role_permissions_api(
        ROLE_PRODUCTION_ADMIN,
        RolePermissionUpdateRequest(
            module_code="production",
            granted_permission_codes=[
                PERM_PROD_ORDERS_LIST,
                PERM_PROD_ORDERS_CREATE,
            ],
            remark="test update",
        ),
        db=db,
        current_user=sys_admin,
    )
    assert update_resp.data.role_code == ROLE_PRODUCTION_ADMIN
    assert PERM_PROD_ORDERS_LIST in update_resp.data.after_permission_codes
    assert PERM_PROD_ORDERS_CREATE in update_resp.data.after_permission_codes

    role_resp = authz.get_role_permissions_api(
        role_code=ROLE_PRODUCTION_ADMIN,
        module="production",
        db=db,
        _=sys_admin,
    )
    granted_map = {item.permission_code: item.granted for item in role_resp.data.items}
    assert granted_map.get(PERM_PROD_ORDERS_LIST) is True
    assert granted_map.get(PERM_PROD_ORDERS_CREATE) is True

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert PERM_PROD_ORDERS_LIST in me_prod.data.permission_codes
    assert PERM_PROD_ORDERS_CREATE in me_prod.data.permission_codes
