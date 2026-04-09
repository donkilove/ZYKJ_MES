from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.role import Role
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.role import RoleCreate, RoleItem, RoleListResult, RoleUpdate
from app.services.audit_service import write_audit_log
from app.services.role_service import (
    count_active_users_for_role_ids,
    count_active_users_for_role,
    create_role,
    delete_role,
    get_role_by_id,
    list_roles,
    update_role,
)


router = APIRouter()


def _normalize_role_output(role: Role) -> tuple[str, bool]:
    role_type = role.role_type
    is_builtin = role.is_builtin
    if role.code == "maintenance_staff":
        role_type = "builtin"
        is_builtin = True
    return role_type, is_builtin


def to_role_item(
    db: Session,
    role: Role,
    *,
    user_count: int | None = None,
) -> RoleItem:
    role_type, is_builtin = _normalize_role_output(role)
    resolved_user_count = (
        count_active_users_for_role(db, role.id)
        if user_count is None
        else user_count
    )
    return RoleItem(
        id=role.id,
        code=role.code,
        name=role.name,
        description=role.description,
        role_type=role_type,
        is_builtin=is_builtin,
        is_enabled=role.is_enabled,
        user_count=resolved_user_count,
        created_at=role.created_at,
        updated_at=role.updated_at,
    )


@router.get("", response_model=ApiResponse[RoleListResult])
def get_roles(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=500),
    keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.roles.list")),
) -> ApiResponse[RoleListResult]:
    total, roles = list_roles(db, page, page_size, keyword)
    user_count_by_role_id = count_active_users_for_role_ids(
        db,
        [role.id for role in roles],
    )
    result = RoleListResult(
        total=total,
        items=[
            to_role_item(
                db,
                role,
                user_count=user_count_by_role_id.get(role.id, 0),
            )
            for role in roles
        ],
    )
    return success_response(result)


@router.get("/{role_id}", response_model=ApiResponse[RoleItem])
def get_role_detail(
    role_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.roles.detail")),
) -> ApiResponse[RoleItem]:
    role = get_role_by_id(db, role_id)
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role not found")
    return success_response(to_role_item(db, role))


@router.post("", response_model=ApiResponse[RoleItem], status_code=status.HTTP_201_CREATED)
def create_role_api(
    payload: RoleCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.roles.create")),
) -> ApiResponse[RoleItem]:
    role, errors = create_role(db, payload)
    if errors:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="; ".join(errors))
    if not role:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to create role")
    write_audit_log(
        db,
        action_code="role.create",
        action_name="新建角色",
        target_type="role",
        target_id=str(role.id),
        target_name=role.name,
        operator=current_user,
        after_data={
            "code": role.code,
            "name": role.name,
            "role_type": role.role_type,
            "is_enabled": role.is_enabled,
        },
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    return success_response(to_role_item(db, role), message="created")


@router.put("/{role_id}", response_model=ApiResponse[RoleItem])
def update_role_api(
    role_id: int,
    payload: RoleUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.roles.update")),
) -> ApiResponse[RoleItem]:
    role = get_role_by_id(db, role_id)
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role not found")
    before_data = {
        "code": role.code,
        "name": role.name,
        "description": role.description,
        "role_type": role.role_type,
        "is_enabled": role.is_enabled,
    }
    updated, errors = update_role(db, role, payload)
    if errors:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="; ".join(errors))
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update role")
    write_audit_log(
        db,
        action_code="role.update",
        action_name="编辑角色",
        target_type="role",
        target_id=str(updated.id),
        target_name=updated.name,
        operator=current_user,
        before_data=before_data,
        after_data={
            "code": updated.code,
            "name": updated.name,
            "description": updated.description,
            "role_type": updated.role_type,
            "is_enabled": updated.is_enabled,
        },
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    return success_response(to_role_item(db, updated), message="updated")


@router.post("/{role_id}/enable", response_model=ApiResponse[RoleItem])
def enable_role_api(
    role_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.roles.enable")),
) -> ApiResponse[RoleItem]:
    role = get_role_by_id(db, role_id)
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role not found")
    updated, errors = update_role(db, role, RoleUpdate(is_enabled=True))
    if errors:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="; ".join(errors))
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to enable role")
    write_audit_log(
        db,
        action_code="role.enable",
        action_name="启用角色",
        target_type="role",
        target_id=str(updated.id),
        target_name=updated.name,
        operator=current_user,
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    return success_response(to_role_item(db, updated))


@router.post("/{role_id}/disable", response_model=ApiResponse[RoleItem])
def disable_role_api(
    role_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.roles.disable")),
) -> ApiResponse[RoleItem]:
    role = get_role_by_id(db, role_id)
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role not found")
    updated, errors = update_role(db, role, RoleUpdate(is_enabled=False))
    if errors:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="; ".join(errors))
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to disable role")
    write_audit_log(
        db,
        action_code="role.disable",
        action_name="停用角色",
        target_type="role",
        target_id=str(updated.id),
        target_name=updated.name,
        operator=current_user,
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    return success_response(to_role_item(db, updated))


@router.delete("/{role_id}", response_model=ApiResponse[dict[str, bool]])
def delete_role_api(
    role_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.roles.delete")),
) -> ApiResponse[dict[str, bool]]:
    role = get_role_by_id(db, role_id)
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role not found")
    deleted, error = delete_role(db, role)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    write_audit_log(
        db,
        action_code="role.delete",
        action_name="删除角色",
        target_type="role",
        target_id=str(role.id),
        target_name=role.name,
        operator=current_user,
        ip_address=request.client.host if request.client else None,
        terminal_info=request.headers.get("user-agent"),
    )
    db.commit()
    return success_response({"deleted": bool(deleted)}, message="deleted")
