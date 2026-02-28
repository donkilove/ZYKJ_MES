from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_role_codes
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.user import UserCreate, UserItem, UserListResult, UserUpdate
from app.services.online_status_service import get_user_online_snapshot
from app.services.user_service import (
    create_user,
    delete_user,
    get_user_by_id,
    get_user_by_username,
    list_users,
    update_user,
)


router = APIRouter()


def to_user_item(user: User) -> UserItem:
    is_online, last_seen_at = get_user_online_snapshot(user.id)
    return UserItem(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        is_online=is_online,
        last_seen_at=last_seen_at,
        role_codes=sorted(role.code for role in user.roles),
        role_names=sorted(role.name for role in user.roles),
        process_codes=sorted(process.code for process in user.processes),
        process_names=sorted(process.name for process in user.processes),
        created_at=user.created_at,
        updated_at=user.updated_at,
    )


@router.get("", response_model=ApiResponse[UserListResult])
def get_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[UserListResult]:
    total, users = list_users(db, page, page_size, keyword)
    result = UserListResult(total=total, items=[to_user_item(user) for user in users])
    return success_response(result)


@router.post("", response_model=ApiResponse[UserItem], status_code=status.HTTP_201_CREATED)
def create_user_api(
    payload: UserCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[UserItem]:
    existing = get_user_by_username(db, payload.username)
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already exists")

    user, error_message = create_user(db, payload)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not user:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to create user")
    return success_response(to_user_item(user), message="created")


@router.get("/{user_id}", response_model=ApiResponse[UserItem])
def get_user_detail(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[UserItem]:
    user = get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return success_response(to_user_item(user))


@router.put("/{user_id}", response_model=ApiResponse[UserItem])
def update_user_api(
    user_id: int,
    payload: UserUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[UserItem]:
    user = get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    updated, error_message = update_user(db, user, payload)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update user")
    return success_response(to_user_item(updated))


@router.delete("/{user_id}", response_model=ApiResponse[dict[str, bool]])
def delete_user_api(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[dict[str, bool]]:
    if user_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete current login user")

    user = get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    delete_user(db, user)
    return success_response({"deleted": True}, message="deleted")
