import hashlib
import json
from threading import RLock
import time

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_user,
    get_db,
    require_permission,
    require_permission_fast,
)
from app.core.authz_catalog import (
    PERM_AUTHZ_PERMISSION_CATALOG_VIEW,
    PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE,
    PERM_AUTHZ_ROLE_PERMISSIONS_VIEW,
)
from app.models.user import User
from app.schemas.authz import (
    AuthzSnapshotResult,
    CapabilityPackCatalogResult,
    CapabilityPackBatchApplyRequest,
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
from app.services.audit_service import write_audit_log
from app.services.authz_service import (
    AuthzRevisionConflictError,
    apply_capability_pack_role_configs,
    get_capability_pack_catalog,
    get_capability_pack_effective_explain,
    get_capability_pack_role_config,
    get_authz_module_revision_map,
    get_permission_hierarchy_catalog,
    get_permission_hierarchy_role_config,
    get_role_permission_items,
    get_role_permission_matrix,
    get_user_permission_codes,
    list_permission_catalog_rows,
    preview_permission_hierarchy,
    update_capability_pack_role_config,
    update_permission_hierarchy_role_config,
    update_role_permission_matrix,
)
from app.services.authz_snapshot_service import get_authz_snapshot


router = APIRouter()

LEGACY_AUTHZ_WRITE_GONE_DETAIL = "旧权限写入入口已下线，请改用能力包配置"
_AUTHZ_ENDPOINT_RESPONSE_CACHE: dict[str, tuple[float, bytes]] = {}
_AUTHZ_ENDPOINT_RESPONSE_CACHE_LOCK = RLock()
_AUTHZ_ENDPOINT_RESPONSE_CACHE_TTL_SECONDS = 20


def _authz_endpoint_cache_key(*, cache_type: str, values: list[str]) -> str:
    joined = "|".join(values)
    digest = hashlib.sha1(f"{cache_type}|{joined}".encode("utf-8")).hexdigest()
    return f"authz_endpoint:{cache_type}:{digest}"


def _get_authz_endpoint_response_bytes(cache_key: str) -> bytes | None:
    with _AUTHZ_ENDPOINT_RESPONSE_CACHE_LOCK:
        cached = _AUTHZ_ENDPOINT_RESPONSE_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, payload_bytes = cached
        if expire_at <= time.monotonic():
            _AUTHZ_ENDPOINT_RESPONSE_CACHE.pop(cache_key, None)
            return None
        return payload_bytes


def _set_authz_endpoint_response_bytes(
    cache_key: str, payload: dict[str, object]
) -> bytes:
    payload_bytes = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    with _AUTHZ_ENDPOINT_RESPONSE_CACHE_LOCK:
        _AUTHZ_ENDPOINT_RESPONSE_CACHE[cache_key] = (
            time.monotonic() + _AUTHZ_ENDPOINT_RESPONSE_CACHE_TTL_SECONDS,
            payload_bytes,
        )
    return payload_bytes


def _authz_revision_token(
    db: Session,
    *,
    module_code: str | None,
) -> str:
    revision_by_module = get_authz_module_revision_map(db)
    if module_code is None:
        return json.dumps(
            sorted(
                (str(code), int(revision))
                for code, revision in revision_by_module.items()
            ),
            ensure_ascii=True,
            separators=(",", ":"),
        )
    return str(int(revision_by_module.get(module_code, 0)))


@router.get(
    "/permissions/catalog",
    response_model=ApiResponse[PermissionCatalogResult],
)
def get_permission_catalog_api(
    module: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast(PERM_AUTHZ_PERMISSION_CATALOG_VIEW)),
) -> ApiResponse[PermissionCatalogResult] | Response:
    normalized_module = module.strip() if module and module.strip() else None
    revision_token = _authz_revision_token(db, module_code=normalized_module)
    cache_key = _authz_endpoint_cache_key(
        cache_type="permissions_catalog_response",
        values=[normalized_module or "__all__", revision_token],
    )
    cached_bytes = _get_authz_endpoint_response_bytes(cache_key)
    if cached_bytes is not None:
        return Response(content=cached_bytes, media_type="application/json")

    rows = list_permission_catalog_rows(db, module_code=module)
    response_payload = success_response(
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
    ).model_dump(mode="json")
    payload_bytes = _set_authz_endpoint_response_bytes(cache_key, response_payload)
    return Response(content=payload_bytes, media_type="application/json")


@router.get(
    "/permissions/me",
    response_model=ApiResponse[MyPermissionsResult],
)
def get_my_permissions_api(
    module: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[MyPermissionsResult]:
    permission_codes = sorted(
        get_user_permission_codes(db, user=current_user, module_code=module)
    )
    return success_response(MyPermissionsResult(permission_codes=permission_codes))


@router.get(
    "/snapshot",
    response_model=ApiResponse[AuthzSnapshotResult],
)
def get_authz_snapshot_api(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[AuthzSnapshotResult]:
    return success_response(
        AuthzSnapshotResult(**get_authz_snapshot(db, user=current_user))  # type: ignore[reportArgumentType]
    )


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
            items=[RolePermissionItem(**item) for item in items],  # type: ignore[reportArgumentType]
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error

    return success_response(
        RolePermissionMatrixResult(
            module_code=str(payload.get("module_code", "")),
            module_codes=[str(code) for code in payload.get("module_codes", [])],  # type: ignore[reportGeneralTypeIssues]
            permissions=[
                PermissionCatalogItem(**item)  # type: ignore[reportArgumentType]
                for item in (payload.get("permissions") or [])  # type: ignore[reportGeneralTypeIssues]
                if isinstance(item, dict)
            ],
            role_items=[
                RolePermissionMatrixItem(**item)  # type: ignore[reportArgumentType]
                for item in (payload.get("role_items") or [])  # type: ignore[reportGeneralTypeIssues]
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
    current_user: User = Depends(
        require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)
    ),
) -> ApiResponse[RolePermissionMatrixUpdateResult]:
    if not payload.dry_run:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail=LEGACY_AUTHZ_WRITE_GONE_DETAIL,
        )
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error

    return success_response(
        RolePermissionMatrixUpdateResult(
            module_code=str(result.get("module_code", "")),
            dry_run=bool(result.get("dry_run", False)),
            role_results=[
                RolePermissionMatrixRoleResult(**item)  # type: ignore[reportArgumentType]
                for item in (result.get("role_results") or [])  # type: ignore[reportGeneralTypeIssues]
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
) -> ApiResponse[PermissionHierarchyCatalogResult] | Response:
    normalized_module = module.strip()
    revision_token = _authz_revision_token(db, module_code=normalized_module)
    cache_key = _authz_endpoint_cache_key(
        cache_type="hierarchy_catalog_response",
        values=[normalized_module, revision_token],
    )
    cached_bytes = _get_authz_endpoint_response_bytes(cache_key)
    if cached_bytes is not None:
        return Response(content=cached_bytes, media_type="application/json")

    try:
        payload = get_permission_hierarchy_catalog(db, module_code=module)
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    response_payload = success_response(
        PermissionHierarchyCatalogResult(**payload)  # type: ignore[reportArgumentType]
    ).model_dump(mode="json")
    payload_bytes = _set_authz_endpoint_response_bytes(cache_key, response_payload)
    return Response(content=payload_bytes, media_type="application/json")


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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    return success_response(PermissionHierarchyRoleConfigResult(**payload))  # type: ignore[reportArgumentType]


@router.put(
    "/hierarchy/role-config/{role_code}",
    response_model=ApiResponse[PermissionHierarchyRoleConfigUpdateResult],
)
def put_permission_hierarchy_role_config_api(
    role_code: str,
    payload: PermissionHierarchyRoleConfigUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)
    ),
) -> ApiResponse[PermissionHierarchyRoleConfigUpdateResult]:
    if not payload.dry_run:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail=LEGACY_AUTHZ_WRITE_GONE_DETAIL,
        )
    try:
        result = update_permission_hierarchy_role_config(
            db,
            role_code=role_code,
            module_code=payload.module_code,
            module_enabled=payload.module_enabled,
            page_permission_codes=payload.page_permission_codes,
            feature_permission_codes=payload.feature_permission_codes,
            dry_run=payload.dry_run,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    result_any: Any = result
    return success_response(
        PermissionHierarchyRoleConfigUpdateResult(  # type: ignore[reportArgumentType]
            **result_any,
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error

    return success_response(
        PermissionHierarchyPreviewResult(**result), message="previewed"  # type: ignore[reportArgumentType]
    )


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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    return success_response(CapabilityPackCatalogResult(**payload))  # type: ignore[reportArgumentType]


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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    return success_response(CapabilityPackRoleConfigResult(**payload))  # type: ignore[reportArgumentType]


@router.put(
    "/capability-packs/role-config/{role_code}",
    response_model=ApiResponse[CapabilityPackRoleConfigUpdateResult],
)
def put_capability_pack_role_config_api(
    role_code: str,
    payload: CapabilityPackRoleConfigUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)
    ),
) -> ApiResponse[CapabilityPackRoleConfigUpdateResult]:
    try:
        result = update_capability_pack_role_config(
            db,
            role_code=role_code,
            module_code=payload.module_code,
            module_enabled=payload.module_enabled,
            capability_codes=payload.capability_codes,
            dry_run=payload.dry_run,
            operator=current_user,
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    result_any: Any = result
    return success_response(
        CapabilityPackRoleConfigUpdateResult(  # type: ignore[reportArgumentType]
            **result_any,
            dry_run=payload.dry_run,
        ),
        message="updated" if not payload.dry_run else "previewed",
    )


@router.put(
    "/capability-packs/batch-apply",
    response_model=ApiResponse[CapabilityPackPreviewResult],
)
def apply_capability_packs_batch_api(
    payload: CapabilityPackBatchApplyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)
    ),
) -> ApiResponse[CapabilityPackPreviewResult]:
    try:
        result = apply_capability_pack_role_configs(
            db,
            module_code=payload.module_code,
            role_items=[item.model_dump() for item in payload.role_items],
            expected_revision=payload.expected_revision,
            operator=current_user,
            remark=payload.remark,
        )
    except AuthzRevisionConflictError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=str(error)
        ) from error
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    write_audit_log(
        db,
        action_code="authz.capability_pack.batch_apply",
        action_name="保存功能权限配置",
        target_type="authz_module",
        target_id=payload.module_code,
        operator=current_user,
        after_data={
            "module_code": payload.module_code,
            "role_count": len(payload.role_items),
        },
    )
    db.commit()
    return success_response(CapabilityPackPreviewResult(**result), message="updated")  # type: ignore[reportArgumentType]


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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error
    return success_response(PermissionExplainResult(**payload))  # type: ignore[reportArgumentType]


@router.put(
    "/role-permissions/{role_code}",
    response_model=ApiResponse[RolePermissionUpdateResult],
)
def put_role_permissions_api(
    role_code: str,
    payload: RolePermissionUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission(PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE)
    ),
) -> ApiResponse[RolePermissionUpdateResult]:
    _ = role_code
    _ = payload
    _ = db
    _ = current_user
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail=LEGACY_AUTHZ_WRITE_GONE_DETAIL,
    )
