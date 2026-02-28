from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_role_codes
from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.core.security import verify_password
from app.db.session import get_db
from app.models.product import Product
from app.models.product_parameter_history import ProductParameterHistory
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.product import (
    ProductCreate,
    ProductDeleteRequest,
    ProductItem,
    ProductListResult,
    ProductParameterHistoryItem,
    ProductParameterHistoryListResult,
    ProductParameterItem,
    ProductParameterListResult,
    ProductParameterUpdateRequest,
    ProductParameterUpdateResult,
)
from app.services.product_service import (
    create_product,
    delete_product,
    get_product_by_id,
    get_product_by_name,
    list_parameter_history,
    list_product_parameters,
    list_products,
    summarize_changed_keys,
    update_product_parameters,
)


router = APIRouter()

PRODUCT_READ_WRITE_ROLE_CODES = [ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN]


def to_product_item(
    product: Product,
    latest_history: ProductParameterHistory | None,
) -> ProductItem:
    last_parameter_summary = None
    if latest_history:
        history_keys = latest_history.changed_keys or []
        if isinstance(history_keys, list):
            normalized_keys = [str(value) for value in history_keys]
            last_parameter_summary = summarize_changed_keys(normalized_keys)

    return ProductItem(
        id=product.id,
        name=product.name,
        last_parameter_summary=last_parameter_summary,
        created_at=product.created_at,
        updated_at=product.updated_at,
    )


@router.get("", response_model=ApiResponse[ProductListResult])
def get_products(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(PRODUCT_READ_WRITE_ROLE_CODES)),
) -> ApiResponse[ProductListResult]:
    total, products, latest_map = list_products(db, page, page_size, keyword)
    return success_response(
        ProductListResult(
            total=total,
            items=[to_product_item(product, latest_map.get(product.id)) for product in products],
        )
    )


@router.post("", response_model=ApiResponse[ProductItem], status_code=status.HTTP_201_CREATED)
def create_product_api(
    payload: ProductCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(PRODUCT_READ_WRITE_ROLE_CODES)),
) -> ApiResponse[ProductItem]:
    normalized_name = payload.name.strip()
    existing = get_product_by_name(db, normalized_name)
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product name already exists")

    try:
        product = create_product(db, normalized_name)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(to_product_item(product, None), message="created")


@router.post("/{product_id}/delete", response_model=ApiResponse[dict[str, bool]])
def delete_product_api(
    product_id: int,
    payload: ProductDeleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN])),
) -> ApiResponse[dict[str, bool]]:
    if not verify_password(payload.password, current_user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Password is incorrect")

    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    delete_product(db, product)
    return success_response({"deleted": True}, message="deleted")


@router.get("/{product_id}/parameters", response_model=ApiResponse[ProductParameterListResult])
def get_product_parameters(
    product_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(PRODUCT_READ_WRITE_ROLE_CODES)),
) -> ApiResponse[ProductParameterListResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    parameters = list_product_parameters(db, product.id)
    items = [
        ProductParameterItem(key=parameter.param_key, value=parameter.param_value)
        for parameter in parameters
    ]
    return success_response(
        ProductParameterListResult(
            product_id=product.id,
            product_name=product.name,
            total=len(items),
            items=items,
        )
    )


@router.put("/{product_id}/parameters", response_model=ApiResponse[ProductParameterUpdateResult])
def update_parameters(
    product_id: int,
    payload: ProductParameterUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes(PRODUCT_READ_WRITE_ROLE_CODES)),
) -> ApiResponse[ProductParameterUpdateResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    try:
        changed_keys = update_product_parameters(
            db,
            product=product,
            items=[(item.key, item.value) for item in payload.items],
            remark=payload.remark,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        ProductParameterUpdateResult(
            updated_count=len(changed_keys),
            changed_keys=changed_keys,
        ),
        message="updated",
    )


@router.get(
    "/{product_id}/parameter-history",
    response_model=ApiResponse[ProductParameterHistoryListResult],
)
def get_parameter_history(
    product_id: int,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(PRODUCT_READ_WRITE_ROLE_CODES)),
) -> ApiResponse[ProductParameterHistoryListResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    total, rows = list_parameter_history(
        db,
        product_id=product.id,
        page=page,
        page_size=page_size,
    )
    items = [
        ProductParameterHistoryItem(
            id=row.id,
            remark=row.remark,
            changed_keys=[str(value) for value in (row.changed_keys or [])],
            operator_username=row.operator_username,
            created_at=row.created_at,
        )
        for row in rows
    ]
    return success_response(ProductParameterHistoryListResult(total=total, items=items))
