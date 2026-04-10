from fastapi import APIRouter, Depends

from app.api.deps import get_current_active_user
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.page_catalog import PageCatalogItem, PageCatalogResult
from app.services.page_catalog_service import list_page_catalog_items


router = APIRouter()


@router.get("/page-catalog", response_model=ApiResponse[PageCatalogResult])
def get_page_catalog(
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[PageCatalogResult]:
    _ = current_user
    items = [PageCatalogItem(**item) for item in list_page_catalog_items()]  # type: ignore[reportArgumentType]
    return success_response(PageCatalogResult(items=items))
