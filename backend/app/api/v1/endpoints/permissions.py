from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.permission import Permission
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.permission import PermissionItem, PermissionListResult
from app.services.permission_service import list_permissions


router = APIRouter()


def to_permission_item(permission: Permission) -> PermissionItem:
    return PermissionItem(
        id=permission.id,
        code=permission.code,
        name=permission.name,
        created_at=permission.created_at,
        updated_at=permission.updated_at,
    )


@router.get("", response_model=ApiResponse[PermissionListResult])
def get_permissions(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("role:read")),
) -> ApiResponse[PermissionListResult]:
    permissions = list_permissions(db)
    result = PermissionListResult(
        total=len(permissions),
        items=[to_permission_item(permission) for permission in permissions],
    )
    return success_response(result)

