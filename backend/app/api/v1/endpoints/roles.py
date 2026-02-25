from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.role import Role
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.role import RoleItem, RoleListResult
from app.services.role_service import get_role_by_id, list_roles


router = APIRouter()


def to_role_item(role: Role) -> RoleItem:
    return RoleItem(
        id=role.id,
        code=role.code,
        name=role.name,
        permission_codes=sorted(permission.code for permission in role.permissions),
        created_at=role.created_at,
        updated_at=role.updated_at,
    )


@router.get("", response_model=ApiResponse[RoleListResult])
def get_roles(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("role:read")),
) -> ApiResponse[RoleListResult]:
    total, roles = list_roles(db, page, page_size, keyword)
    result = RoleListResult(total=total, items=[to_role_item(role) for role in roles])
    return success_response(result)


@router.get("/{role_id}", response_model=ApiResponse[RoleItem])
def get_role_detail(
    role_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("role:read")),
) -> ApiResponse[RoleItem]:
    role = get_role_by_id(db, role_id)
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role not found")
    return success_response(to_role_item(role))

