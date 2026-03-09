from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, get_db, require_permission
from app.core.authz_catalog import (
    PERM_AUTHZ_PERMISSION_CATALOG_VIEW,
    PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE,
    PERM_AUTHZ_ROLE_PERMISSIONS_VIEW,
)
from app.models.user import User
from app.schemas.authz import (
    CapabilityPackCatalogResult,
    CapabilityPackPreviewRequest,
    CapabilityPackPreviewResult,
    CapabilityPackRoleConfigResult,
    CapabilityPackRoleConfigUpdateRequest,
    CapabilityPackRoleConfigUpdateResult,
    MyPermissionsResult,
    PermissionExplainResult,
    PermissionHierarchyCatalogResult,
    PermissionHierarchyPreviewRequest,
    PermissionHierarchyPreviewResult,
    PermissionHierarchyRoleConfigResult,
    PermissionHierarchyRoleConfigUpdateRequest,
    PermissionHierarchyRoleConfigUpdateResult,
    PermissionCatalogItem,
    PermissionCatalogResult,
    RolePermissionMatrixItem,
    RolePermissionMatrixResult,
    RolePermissionMatrixRoleResult,
    RolePermissionMatrixUpdateRequest,
    RolePermissionMatrixUpdateResult,
    RolePermissionItem,
    RolePermissionResult,
    RolePermissionUpdateRequest,
    RolePermissionUpdateResult,
)
from app.schemas.common import ApiResponse, success_response
from app.services.authz_service import (
    get_capability_pack_catalog,
    get_capability_pack_effective_explain,
    get_capability_pack_role_config,
    get_permission_hierarchy_catalog,
    get_permission_hierarchy_role_config,
    get_role_permission_items,
    get_role_permission_matrix,
    get_user_permission_codes,
    list_permission_catalog_rows,
    preview_permission_hierarchy,
    replace_role_permissions_for_module,
    update_capability_pack_role_config,
    update_permission_hierarchy_role_config,
    update_role_permission_matrix,
    preview_capability_packs,
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


@router.get(
    "/role-permissions/matrix",
    response_model=ApiResponse[RolePermissionMatrixResult],
)
def get_role_permissions_matrix_api(
    module: str = Query(min_length=2, max_length=64),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_VIEW)),
) -> ApiResponse[RolePermissionMatrixResult]:
    try:
        payload = get_role_permission_matrix(
            db,
            module_code=module,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error

    return success_response(
        RolePermissionMatrixResult(
            module_code=str(payload.get("module_code", "")),
            module_codes=[str(code) for code in payload.get("module_codes", [])],
            permissions=[
                PermissionCatalogItem(**item)
                for item in payload.get("permissions", [])
                if isinstance(item, dict)
            ],
            role_items=[
                RolePermissionMatrixItem(**item)
                for item in payload.get("role_items", [])
                if isinstance(item, dict)
            ],
        )
    )


@router.put(
    "/role-permissions/matrix",
    response_model=ApiResponse[RolePermissionMatrixUpdateResult],
)
def put_role_permissions_matrix_api(
    payload: RolePermissionMatrixUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)),
) -> ApiResponse[RolePermissionMatrixUpdateResult]:
    try:
        result = update_role_permission_matrix(
            db,
            module_code=payload.module_code,
            role_items=[item.model_dump() for item in payload.role_items],
            dry_run=payload.dry_run,
            operator=current_user,
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error

    return success_response(
        RolePermissionMatrixUpdateResult(
            module_code=str(result.get("module_code", "")),
            dry_run=bool(result.get("dry_run", False)),
            role_results=[
                RolePermissionMatrixRoleResult(**item)
                for item in result.get("role_results", [])
                if isinstance(item, dict)
            ],
        ),
        message="updated",
    )


@router.get(
    "/hierarchy/catalog",
    response_model=ApiResponse[PermissionHierarchyCatalogResult],
)
def get_permission_hierarchy_catalog_api(
    module: str = Query(min_length=2, max_length=64),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_VIEW)),
) -> ApiResponse[PermissionHierarchyCatalogResult]:
    try:
        payload = get_permission_hierarchy_catalog(db, module_code=module)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(PermissionHierarchyCatalogResult(**payload))


@router.get(
    "/hierarchy/role-config",
    response_model=ApiResponse[PermissionHierarchyRoleConfigResult],
)
def get_permission_hierarchy_role_config_api(
    role_code: str = Query(min_length=2, max_length=64),
    module: str = Query(min_length=2, max_length=64),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_VIEW)),
) -> ApiResponse[PermissionHierarchyRoleConfigResult]:
    try:
        payload = get_permission_hierarchy_role_config(
            db,
            role_code=role_code,
            module_code=module,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(PermissionHierarchyRoleConfigResult(**payload))


@router.put(
    "/hierarchy/role-config/{role_code}",
    response_model=ApiResponse[PermissionHierarchyRoleConfigUpdateResult],
)
def put_permission_hierarchy_role_config_api(
    role_code: str,
    payload: PermissionHierarchyRoleConfigUpdateRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)),
) -> ApiResponse[PermissionHierarchyRoleConfigUpdateResult]:
    try:
        result = update_permission_hierarchy_role_config(
            db,
            role_code=role_code,
            module_code=payload.module_code,
            module_enabled=payload.module_enabled,
            page_permission_codes=payload.page_permission_codes,
            feature_permission_codes=payload.feature_permission_codes,
            dry_run=payload.dry_run,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(
        PermissionHierarchyRoleConfigUpdateResult(
            **result,
            dry_run=payload.dry_run,
        ),
        message="updated" if not payload.dry_run else "previewed",
    )


@router.post(
    "/hierarchy/preview",
    response_model=ApiResponse[PermissionHierarchyPreviewResult],
)
def preview_permission_hierarchy_api(
    payload: PermissionHierarchyPreviewRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)),
) -> ApiResponse[PermissionHierarchyPreviewResult]:
    try:
        result = preview_permission_hierarchy(
            db,
            module_code=payload.module_code,
            role_items=[item.model_dump() for item in payload.role_items],
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error

    return success_response(PermissionHierarchyPreviewResult(**result), message="previewed")


@router.get(
    "/capability-packs/catalog",
    response_model=ApiResponse[CapabilityPackCatalogResult],
)
def get_capability_pack_catalog_api(
    module: str = Query(min_length=2, max_length=64),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_VIEW)),
) -> ApiResponse[CapabilityPackCatalogResult]:
    try:
        payload = get_capability_pack_catalog(db, module_code=module)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(CapabilityPackCatalogResult(**payload))


@router.get(
    "/capability-packs/role-config",
    response_model=ApiResponse[CapabilityPackRoleConfigResult],
)
def get_capability_pack_role_config_api(
    role_code: str = Query(min_length=2, max_length=64),
    module: str = Query(min_length=2, max_length=64),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_VIEW)),
) -> ApiResponse[CapabilityPackRoleConfigResult]:
    try:
        payload = get_capability_pack_role_config(
            db,
            role_code=role_code,
            module_code=module,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(CapabilityPackRoleConfigResult(**payload))


@router.put(
    "/capability-packs/role-config/{role_code}",
    response_model=ApiResponse[CapabilityPackRoleConfigUpdateResult],
)
def put_capability_pack_role_config_api(
    role_code: str,
    payload: CapabilityPackRoleConfigUpdateRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)),
) -> ApiResponse[CapabilityPackRoleConfigUpdateResult]:
    try:
        result = update_capability_pack_role_config(
            db,
            role_code=role_code,
            module_code=payload.module_code,
            module_enabled=payload.module_enabled,
            capability_codes=payload.capability_codes,
            dry_run=payload.dry_run,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(
        CapabilityPackRoleConfigUpdateResult(
            **result,
            dry_run=payload.dry_run,
        ),
        message="updated" if not payload.dry_run else "previewed",
    )


@router.post(
    "/capability-packs/preview",
    response_model=ApiResponse[CapabilityPackPreviewResult],
)
def preview_capability_packs_api(
    payload: CapabilityPackPreviewRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)),
) -> ApiResponse[CapabilityPackPreviewResult]:
    try:
        result = preview_capability_packs(
            db,
            module_code=payload.module_code,
            role_items=[item.model_dump() for item in payload.role_items],
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(CapabilityPackPreviewResult(**result), message="previewed")


@router.get(
    "/capability-packs/effective",
    response_model=ApiResponse[PermissionExplainResult],
)
def get_capability_pack_effective_api(
    role_code: str = Query(min_length=2, max_length=64),
    module: str = Query(min_length=2, max_length=64),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_VIEW)),
) -> ApiResponse[PermissionExplainResult]:
    try:
        payload = get_capability_pack_effective_explain(
            db,
            role_code=role_code,
            module_code=module,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    return success_response(PermissionExplainResult(**payload))


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
    try:
        updated_count, before_codes, after_codes = replace_role_permissions_for_module(
            db,
            role_code=role_code,
            module_code=payload.module_code,
            granted_permission_codes=payload.granted_permission_codes,
            operator=current_user,
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
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
