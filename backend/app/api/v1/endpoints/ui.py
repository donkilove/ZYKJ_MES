from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.home_dashboard import HomeDashboardResult
from app.schemas.page_catalog import PageCatalogItem, PageCatalogResult
from app.services.home_dashboard_service import build_home_dashboard
from app.services.page_catalog_service import list_page_catalog_items


router = APIRouter()


@router.get("/page-catalog", response_model=ApiResponse[PageCatalogResult])
def get_page_catalog(
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[PageCatalogResult]:
    _ = current_user
    items = [PageCatalogItem(**item) for item in list_page_catalog_items()]
    return success_response(PageCatalogResult(items=items))


@router.get("/home-dashboard", response_model=ApiResponse[HomeDashboardResult])
def get_home_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[HomeDashboardResult]:
    payload = build_home_dashboard(db, current_user=current_user)
    return success_response(payload)
