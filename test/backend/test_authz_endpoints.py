from __future__ import annotations

import pytest

from fastapi import HTTPException

from app.api.v1.endpoints import authz
from app.core.authz_catalog import (
    MODULE_PERMISSION_BY_MODULE_CODE,
    PERM_PROD_ORDERS_CREATE,
    PERM_PROD_ORDERS_LIST,
    PERM_PROD_MY_ORDERS_LIST,
    PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW,
    PERM_PAGE_PRODUCTION_VIEW,
)
from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.role_permission_grant import RolePermissionGrant
from app.schemas.authz import (
    CapabilityPackBatchApplyRequest,
    RolePermissionMatrixRoleUpdateItem,
    RolePermissionMatrixUpdateRequest,
    RolePermissionUpdateRequest,
)
from app.services.authz_service import ensure_authz_defaults, has_permission


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
    factory.user(username="authz_update_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    with pytest.raises(HTTPException) as exc_info:
        authz.put_role_permissions_api(
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

    assert exc_info.value.status_code == 410
    assert "能力包配置" in str(exc_info.value.detail)


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
    factory.user(username="authz_matrix_apply_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    factory.user(username="authz_matrix_apply_operator", role_codes=[ROLE_OPERATOR])
    db.commit()

    with pytest.raises(HTTPException) as exc_info:
        authz.put_role_permissions_matrix_api(
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

    assert exc_info.value.status_code == 410
    assert "能力包配置" in str(exc_info.value.detail)


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

    with pytest.raises(HTTPException) as exc_info:
        authz.put_permission_hierarchy_role_config_api(
            role_code=ROLE_PRODUCTION_ADMIN,
            payload=authz.PermissionHierarchyRoleConfigUpdateRequest(
                module_code="production",
                module_enabled=True,
                page_permission_codes=[PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW],
                feature_permission_codes=["feature.production.order_query.execute"],
            ),
            db=db,
            current_user=sys_admin,
        )

    assert exc_info.value.status_code == 410
    assert "能力包配置" in str(exc_info.value.detail)

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] not in me_prod.data.permission_codes
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW not in me_prod.data.permission_codes


def test_authz_capability_pack_endpoints(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_capability_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_capability_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    catalog_resp = authz.get_capability_pack_catalog_api(
        module="production",
        db=db,
        _=sys_admin,
    )
    assert catalog_resp.data.module_code == "production"
    assert any(item.capability_code == "feature.production.order_query.execute" for item in catalog_resp.data.capability_packs)
    assert any(item.role_code == ROLE_PRODUCTION_ADMIN for item in catalog_resp.data.role_templates)

    role_config_resp = authz.get_capability_pack_role_config_api(
        role_code=ROLE_PRODUCTION_ADMIN,
        module="production",
        db=db,
        _=sys_admin,
    )
    assert role_config_resp.data.role_code == ROLE_PRODUCTION_ADMIN
    assert role_config_resp.data.module_enabled is False

    update_resp = authz.put_capability_pack_role_config_api(
        role_code=ROLE_PRODUCTION_ADMIN,
        payload=authz.CapabilityPackRoleConfigUpdateRequest(
            module_code="production",
            module_enabled=True,
            capability_codes=["feature.production.order_query.execute"],
            dry_run=False,
        ),
        db=db,
        current_user=sys_admin,
    )
    assert update_resp.data.role_code == ROLE_PRODUCTION_ADMIN
    assert update_resp.data.updated_count >= 1
    assert "feature.production.order_query.execute" in update_resp.data.after_capability_codes

    effective_resp = authz.get_capability_pack_effective_api(
        role_code=ROLE_PRODUCTION_ADMIN,
        module="production",
        db=db,
        _=sys_admin,
    )
    assert effective_resp.data.role_code == ROLE_PRODUCTION_ADMIN
    assert any(item.capability_code == "feature.production.order_query.execute" for item in effective_resp.data.capability_items)

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] in me_prod.data.permission_codes
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW in me_prod.data.permission_codes


def test_page_permission_no_longer_grants_action_access(db, factory) -> None:
    factory.ensure_default_roles()
    prod_admin = factory.user(username="authz_page_only_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    ensure_authz_defaults(db)
    db.commit()

    for permission_code in [
        MODULE_PERMISSION_BY_MODULE_CODE["production"],
        PERM_PAGE_PRODUCTION_VIEW,
        PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW,
    ]:
        grant = (
            db.query(RolePermissionGrant)
            .filter(
                RolePermissionGrant.role_code == ROLE_PRODUCTION_ADMIN,
                RolePermissionGrant.permission_code == permission_code,
            )
            .first()
        )
        assert grant is not None
        grant.granted = True
    db.commit()

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW in me_prod.data.permission_codes
    assert PERM_PROD_MY_ORDERS_LIST not in me_prod.data.permission_codes
    assert has_permission(db, user=prod_admin, permission_code=PERM_PROD_MY_ORDERS_LIST) is False


def test_authz_snapshot_and_batch_apply_expose_linked_actions(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_snapshot_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_snapshot_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    catalog_resp = authz.get_capability_pack_catalog_api(
        module="production",
        db=db,
        _=sys_admin,
    )
    apply_resp = authz.apply_capability_packs_batch_api(
        CapabilityPackBatchApplyRequest(
            module_code="production",
            expected_revision=catalog_resp.data.module_revision,
            role_items=[
                {
                    "role_code": ROLE_PRODUCTION_ADMIN,
                    "module_enabled": True,
                    "capability_codes": ["feature.production.order_query.execute"],
                }
            ],
            remark="batch apply",
        ),
        db=db,
        current_user=sys_admin,
    )
    assert apply_resp.data.module_revision >= catalog_resp.data.module_revision

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert PERM_PROD_MY_ORDERS_LIST in me_prod.data.permission_codes

    snapshot_resp = authz.get_authz_snapshot_api(db=db, current_user=prod_admin)
    production_module = next(
        item for item in snapshot_resp.data.module_items if item.module_code == "production"
    )
    assert "production" in snapshot_resp.data.visible_sidebar_codes
    assert PERM_PROD_MY_ORDERS_LIST in production_module.effective_action_permission_codes
    assert has_permission(db, user=prod_admin, permission_code=PERM_PROD_MY_ORDERS_LIST) is True


def test_capability_pack_auto_enables_module_when_capabilities_selected(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_auto_enable_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    prod_admin = factory.user(username="authz_auto_enable_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    update_resp = authz.put_capability_pack_role_config_api(
        role_code=ROLE_PRODUCTION_ADMIN,
        payload=authz.CapabilityPackRoleConfigUpdateRequest(
            module_code="production",
            module_enabled=False,
            capability_codes=["feature.production.order_query.execute"],
            dry_run=False,
        ),
        db=db,
        current_user=sys_admin,
    )
    assert "feature.production.order_query.execute" in update_resp.data.after_capability_codes

    me_prod = authz.get_my_permissions_api(module="production", db=db, current_user=prod_admin)
    assert MODULE_PERMISSION_BY_MODULE_CODE["production"] in me_prod.data.permission_codes
    assert PERM_PROD_MY_ORDERS_LIST in me_prod.data.permission_codes


def test_capability_pack_batch_apply_rejects_stale_revision(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(username="authz_revision_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    factory.user(username="authz_revision_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    catalog_resp = authz.get_capability_pack_catalog_api(
        module="production",
        db=db,
        _=sys_admin,
    )
    authz.apply_capability_packs_batch_api(
        CapabilityPackBatchApplyRequest(
            module_code="production",
            expected_revision=catalog_resp.data.module_revision,
            role_items=[
                {
                    "role_code": ROLE_PRODUCTION_ADMIN,
                    "module_enabled": True,
                    "capability_codes": ["feature.production.order_query.execute"],
                }
            ],
            remark="first update",
        ),
        db=db,
        current_user=sys_admin,
    )

    with pytest.raises(HTTPException) as exc_info:
        authz.apply_capability_packs_batch_api(
            CapabilityPackBatchApplyRequest(
                module_code="production",
                expected_revision=catalog_resp.data.module_revision,
                role_items=[
                    {
                        "role_code": ROLE_PRODUCTION_ADMIN,
                        "module_enabled": True,
                        "capability_codes": ["feature.production.order_query.proxy"],
                    }
                ],
                remark="stale update",
            ),
            db=db,
            current_user=sys_admin,
        )

    assert exc_info.value.status_code == 409
    assert "authz revision conflict" in str(exc_info.value.detail)


def test_capability_pack_batch_apply_rejects_system_admin(db, factory) -> None:
    factory.ensure_default_roles()
    sys_admin = factory.user(
        username="authz_batch_apply_system_admin",
        role_codes=[ROLE_SYSTEM_ADMIN],
    )
    db.commit()

    catalog_resp = authz.get_capability_pack_catalog_api(
        module="production",
        db=db,
        _=sys_admin,
    )

    with pytest.raises(HTTPException) as exc_info:
        authz.apply_capability_packs_batch_api(
            CapabilityPackBatchApplyRequest(
                module_code="production",
                expected_revision=catalog_resp.data.module_revision,
                role_items=[
                    {
                        "role_code": ROLE_SYSTEM_ADMIN,
                        "module_enabled": True,
                        "capability_codes": ["feature.production.order_query.execute"],
                    }
                ],
                remark="invalid system admin update",
            ),
            db=db,
            current_user=sys_admin,
        )

    assert exc_info.value.status_code == 400
    assert "system_admin" in str(exc_info.value.detail)
