from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, get_db, require_permission
from app.core.authz_catalog import (
    PERM_AUTHZ_PERMISSION_CATALOG_VIEW,
    PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE,
    PERM_AUTHZ_ROLE_PERMISSIONS_VIEW,
)
from app.models.user import User
from app.schemas.authz import (
    MyPermissionsResult,
    PermissionCatalogItem,
    PermissionCatalogResult,
    RolePermissionItem,
    RolePermissionResult,
    RolePermissionUpdateRequest,
    RolePermissionUpdateResult,
)
from app.schemas.common import ApiResponse, success_response
from app.services.authz_service import (
    get_role_permission_items,
    get_user_permission_codes,
    list_permission_catalog_rows,
    replace_role_permissions_for_module,
)


router = APIRouter()


@router.get(
    "/permissions/catalog",
    response_model=ApiResponse[PermissionCatalogResult],
)
def get_permission_catalog_api(
    module: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_PERMISSION_CATALOG_VIEW)),
) -> ApiResponse[PermissionCatalogResult]:
    rows = list_permission_catalog_rows(db, module_code=module)
    return success_response(
        PermissionCatalogResult(
            items=[
                PermissionCatalogItem(
                    permission_code=row.permission_code,
                    permission_name=row.permission_name,
                    module_code=row.module_code,
                    resource_type=row.resource_type,
                    parent_permission_code=row.parent_permission_code,
                    is_enabled=row.is_enabled,
                )
                for row in rows
            ]
        )
    )


@router.get(
    "/permissions/me",
    response_model=ApiResponse[MyPermissionsResult],
)
def get_my_permissions_api(
    module: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[MyPermissionsResult]:
    permission_codes = sorted(get_user_permission_codes(db, user=current_user, module_code=module))
    return success_response(MyPermissionsResult(permission_codes=permission_codes))


@router.get(
    "/role-permissions",
    response_model=ApiResponse[RolePermissionResult],
)
def get_role_permissions_api(
    role_code: str = Query(min_length=2, max_length=64),
    module: str = Query(min_length=2, max_length=64),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_VIEW)),
) -> ApiResponse[RolePermissionResult]:
    role_name, items = get_role_permission_items(
        db,
        role_code=role_code,
        module_code=module,
    )
    return success_response(
        RolePermissionResult(
            role_code=role_code,
            role_name=role_name,
            module_code=module,
            items=[RolePermissionItem(**item) for item in items],
        )
    )


@router.put(
    "/role-permissions/{role_code}",
    response_model=ApiResponse[RolePermissionUpdateResult],
)
def put_role_permissions_api(
    role_code: str,
    payload: RolePermissionUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)),
) -> ApiResponse[RolePermissionUpdateResult]:
    updated_count, before_codes, after_codes = replace_role_permissions_for_module(
        db,
        role_code=role_code,
        module_code=payload.module_code,
        granted_permission_codes=payload.granted_permission_codes,
        operator=current_user,
        remark=payload.remark,
    )
    return success_response(
        RolePermissionUpdateResult(
            role_code=role_code,
            module_code=payload.module_code,
            updated_count=updated_count,
            before_permission_codes=before_codes,
            after_permission_codes=after_codes,
        ),
        message="updated",
    )
