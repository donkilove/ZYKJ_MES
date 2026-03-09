from __future__ import annotations

from app.api.v1.endpoints import authz
from app.core.authz_catalog import (
    MODULE_PERMISSION_BY_MODULE_CODE,
    PERM_PROD_ORDERS_CREATE,
    PERM_PROD_ORDERS_LIST,
    PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW,
    PERM_PAGE_PRODUCTION_VIEW,
)
from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.schemas.authz import (
    RolePermissionMatrixRoleUpdateItem,
    RolePermissionMatrixUpdateRequest,
    RolePermissionUpdateRequest,
)


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


def test_authz_role_permissions_matrix_get_and_dry_run(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_matrix_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_matrix_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    matrix_resp = authz.get_role_permissions_matrix_api(
        module="production",
        db=db,
        _=sys_admin,
    )
    assert matrix_resp.data.module_code == "production"
    assert "production" in matrix_resp.data.module_codes
    assert "system" in matrix_resp.data.module_codes
    sys_admin_item = next(item for item in matrix_resp.data.role_items if item.role_code == ROLE_SYSTEM_ADMIN)
    assert sys_admin_item.readonly is True
    assert PERM_PROD_ORDERS_LIST in sys_admin_item.granted_permission_codes

    dry_run_resp = authz.put_role_permissions_matrix_api(
        RolePermissionMatrixUpdateRequest(
            module_code="production",
            dry_run=True,
            role_items=[
                RolePermissionMatrixRoleUpdateItem(
                    role_code=ROLE_PRODUCTION_ADMIN,
                    granted_permission_codes=[PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW],
                )
            ],
            remark="dry run",
        ),
        db=db,
        current_user=sys_admin,
    )
    role_result = dry_run_resp.data.role_results[0]
    assert role_result.role_code == ROLE_PRODUCTION_ADMIN
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW in role_result.after_permission_codes
    assert PERM_PAGE_PRODUCTION_VIEW in role_result.after_permission_codes
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] in role_result.after_permission_codes
    assert PERM_PAGE_PRODUCTION_VIEW in role_result.auto_granted_permission_codes

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW not in me_prod.data.permission_codes
    assert PERM_PAGE_PRODUCTION_VIEW not in me_prod.data.permission_codes


def test_authz_role_permissions_matrix_update_applies_and_ignores_system_admin_input(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_matrix_apply_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_matrix_apply_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    operator = factory.user(username="authz_matrix_apply_operator", role_codes=[ROLE_OPERATOR])
    db.commit()

    update_resp = authz.put_role_permissions_matrix_api(
        RolePermissionMatrixUpdateRequest(
            module_code="production",
            dry_run=False,
            role_items=[
                RolePermissionMatrixRoleUpdateItem(
                    role_code=ROLE_PRODUCTION_ADMIN,
                    granted_permission_codes=[PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW],
                ),
                RolePermissionMatrixRoleUpdateItem(
                    role_code=ROLE_SYSTEM_ADMIN,
                    granted_permission_codes=[],
                ),
            ],
            remark="apply",
        ),
        db=db,
        current_user=sys_admin,
    )
    prod_result = next(
        item for item in update_resp.data.role_results if item.role_code == ROLE_PRODUCTION_ADMIN
    )
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW in prod_result.after_permission_codes
    assert PERM_PAGE_PRODUCTION_VIEW in prod_result.after_permission_codes
    assert prod_result.updated_count >= 1

    sys_result = next(item for item in update_resp.data.role_results if item.role_code == ROLE_SYSTEM_ADMIN)
    assert sys_result.readonly is True
    assert sys_result.ignored_input is True
    assert PERM_PROD_ORDERS_LIST in sys_result.after_permission_codes

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW in me_prod.data.permission_codes
    assert PERM_PAGE_PRODUCTION_VIEW in me_prod.data.permission_codes
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] in me_prod.data.permission_codes

    me_operator = authz.get_my_permissions_api(module="production", db=db, current_user=operator)
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW not in me_operator.data.permission_codes


def test_authz_hierarchy_endpoints(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_hierarchy_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_hierarchy_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    catalog_resp = authz.get_permission_hierarchy_catalog_api(
        module="production",
        db=db,
        _=sys_admin,
    )
    assert catalog_resp.data.module_code == "production"
    assert catalog_resp.data.module_permission_code == MODULE_PERMISSION_BY_MODULE_CODE["production"]
    assert any(item.page_code == "production_order_query" for item in catalog_resp.data.pages)
    assert any(item.permission_code.startswith("feature.production.") for item in catalog_resp.data.features)

    role_config_resp = authz.get_permission_hierarchy_role_config_api(
        role_code=ROLE_PRODUCTION_ADMIN,
        module="production",
        db=db,
        _=sys_admin,
    )
    assert role_config_resp.data.role_code == ROLE_PRODUCTION_ADMIN
    assert role_config_resp.data.module_enabled is False

    preview_resp = authz.preview_permission_hierarchy_api(
        authz.PermissionHierarchyPreviewRequest(
            module_code="production",
            role_items=[
                {
                    "role_code": ROLE_PRODUCTION_ADMIN,
                    "module_enabled": True,
                    "page_permission_codes": [PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW],
                    "feature_permission_codes": ["feature.production.order_query.execute"],
                }
            ],
        ),
        db=db,
        _=sys_admin,
    )
    assert preview_resp.data.module_code == "production"
    assert preview_resp.data.role_results[0].role_code == ROLE_PRODUCTION_ADMIN
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] in preview_resp.data.role_results[0].after_permission_codes

    update_resp = authz.put_permission_hierarchy_role_config_api(
        role_code=ROLE_PRODUCTION_ADMIN,
        payload=authz.PermissionHierarchyRoleConfigUpdateRequest(
            module_code="production",
            module_enabled=True,
            page_permission_codes=[PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW],
            feature_permission_codes=["feature.production.order_query.execute"],
        ),
        db=db,
        _=sys_admin,
    )
    assert update_resp.data.role_code == ROLE_PRODUCTION_ADMIN
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] in update_resp.data.after_permission_codes

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] in me_prod.data.permission_codes
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW in me_prod.data.permission_codes
