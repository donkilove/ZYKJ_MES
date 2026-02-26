from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, require_role_codes
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.page_visibility import (
    PageCatalogItem,
    PageCatalogResult,
    PageVisibilityConfigItem,
    PageVisibilityConfigResult,
    PageVisibilityConfigUpdateRequest,
    PageVisibilityConfigUpdateResult,
    PageVisibilityMeResult,
)
from app.services.page_visibility_service import (
    ensure_visibility_defaults,
    get_page_visibility_config,
    get_user_visible_pages,
    list_page_catalog_items,
    update_page_visibility_config,
)


router = APIRouter()


@router.get("/page-catalog", response_model=ApiResponse[PageCatalogResult])
def get_page_catalog(
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[PageCatalogResult]:
    _ = current_user
    items = [PageCatalogItem(**item) for item in list_page_catalog_items()]
    return success_response(PageCatalogResult(items=items))


@router.get("/page-visibility/me", response_model=ApiResponse[PageVisibilityMeResult])
def get_my_page_visibility(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[PageVisibilityMeResult]:
    ensure_visibility_defaults(db)
    role_codes = [role.code for role in current_user.roles]
    sidebar_codes, tab_codes_by_parent = get_user_visible_pages(db, role_codes)
    return success_response(
        PageVisibilityMeResult(
            sidebar_codes=sidebar_codes,
            tab_codes_by_parent=tab_codes_by_parent,
        )
    )


@router.get("/page-visibility/config", response_model=ApiResponse[PageVisibilityConfigResult])
def get_page_visibility_configuration(
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[PageVisibilityConfigResult]:
    ensure_visibility_defaults(db)
    items = [PageVisibilityConfigItem(**item) for item in get_page_visibility_config(db)]
    return success_response(PageVisibilityConfigResult(items=items))


@router.put("/page-visibility/config", response_model=ApiResponse[PageVisibilityConfigUpdateResult])
def update_page_visibility_configuration(
    payload: PageVisibilityConfigUpdateRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[PageVisibilityConfigUpdateResult]:
    updates = [item.model_dump() for item in payload.items]
    updated_count, invalid_items = update_page_visibility_config(db, updates)
    if invalid_items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="; ".join(invalid_items),
        )
    return success_response(
        PageVisibilityConfigUpdateResult(updated_count=updated_count),
        message="updated",
    )
