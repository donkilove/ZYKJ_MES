from datetime import datetime
import csv
import io

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.core.security import verify_password
from app.db.session import get_db
from app.models.product import Product
from app.models.product_parameter_history import ProductParameterHistory
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.services.audit_service import write_audit_log
from app.schemas.product import (
    ProductImpactAnalysisQuery,
    ProductImpactAnalysisResult,
    ProductImpactOrderItem,
    ProductCreate,
    ProductDeleteRequest,
    ProductLifecycleUpdateRequest,
    ProductItem,
    ProductListResult,
    ProductParameterHistoryItem,
    ProductParameterHistoryListResult,
    ProductParameterItem,
    ProductParameterListResult,
    ProductParameterUpdateRequest,
    ProductParameterUpdateResult,
    ProductRollbackRequest,
    ProductRollbackResult,
    ProductUpdate,
    ProductVersionActivateRequest,
    ProductVersionCompareResult,
    ProductVersionCopyRequest,
    ProductVersionDiffItem,
    ProductVersionDisableRequest,
    ProductVersionItem,
    ProductVersionListResult,
    ProductVersionNoteUpdateRequest,
)
from app.services.product_service import (
    activate_product_version,
    analyze_product_impact,
    change_product_lifecycle,
    compare_product_versions,
    copy_product_version,
    create_product,
    create_product_version,
    delete_product,
    delete_product_version,
    disable_product_version,
    ensure_product_parameter_template_initialized,
    get_latest_history_map_by_product_ids,
    get_product_by_id,
    get_product_by_name,
    get_product_version,
    list_parameter_history,
    list_product_parameters,
    list_product_versions,
    list_products,
    rollback_product_to_version,
    summarize_changed_keys,
    update_product_parameters,
    update_product_version_note,
)


router = APIRouter()


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
        category=product.category or "",
        remark=product.remark or "",
        lifecycle_status=product.lifecycle_status,
        current_version=product.current_version,
        effective_version=product.effective_version,
        effective_at=product.effective_at,
        inactive_reason=product.inactive_reason,
        last_parameter_summary=last_parameter_summary,
        created_at=product.created_at,
        updated_at=product.updated_at,
    )


@router.get("", response_model=ApiResponse[ProductListResult])
def get_products(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    has_effective_version: bool | None = Query(default=None),
    updated_after: datetime | None = Query(default=None),
    updated_before: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.products.list")),
) -> ApiResponse[ProductListResult]:
    total, products, latest_map = list_products(
        db, page, page_size, keyword, category, lifecycle_status,
        has_effective_version=has_effective_version,
        updated_after=updated_after,
        updated_before=updated_before,
    )
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
    current_user: User = Depends(require_permission("product.products.create")),
) -> ApiResponse[ProductItem]:
    normalized_name = payload.name.strip()
    existing = get_product_by_name(db, normalized_name)
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product name already exists")

    try:
        product = create_product(
            db,
            normalized_name,
            category=payload.category,
            remark=payload.remark,
            operator=current_user,
        )
    except (ValueError, ValidationError) as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    write_audit_log(
        db,
        action_code="product.create",
        action_name="新建产品",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"name": product.name, "category": product.category, "remark": product.remark},
    )
    db.commit()
    return success_response(to_product_item(product, None), message="created")


@router.get("/{product_id}", response_model=ApiResponse[ProductItem])
def get_product_detail_api(
    product_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.products.list")),
) -> ApiResponse[ProductItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    latest_history = get_latest_history_map_by_product_ids(db, [product.id]).get(product.id)
    return success_response(to_product_item(product, latest_history))


@router.put("/{product_id}", response_model=ApiResponse[ProductItem])
def update_product_api(
    product_id: int,
    payload: ProductUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.products.create")),
) -> ApiResponse[ProductItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    normalized_name = payload.name.strip()
    if not normalized_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product name is required")

    if normalized_name != product.name:
        existing = get_product_by_name(db, normalized_name)
        if existing and existing.id != product.id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product name already exists")

    product.name = normalized_name
    product.category = payload.category
    product.remark = (payload.remark or "").strip()
    db.commit()
    db.refresh(product)

    write_audit_log(
        db,
        action_code="product.update",
        action_name="编辑产品",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"name": product.name, "category": product.category, "remark": product.remark},
    )
    db.commit()
    latest_history = get_latest_history_map_by_product_ids(db, [product.id]).get(product.id)
    return success_response(to_product_item(product, latest_history), message="updated")


@router.post("/{product_id}/delete", response_model=ApiResponse[dict[str, bool]])
def delete_product_api(
    product_id: int,
    payload: ProductDeleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.products.delete")),
) -> ApiResponse[dict[str, bool]]:
    if not verify_password(payload.password, current_user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Password is incorrect")

    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    try:
        delete_product(db, product)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="product.delete",
        action_name="删除产品",
        target_type="product",
        target_id=str(product_id),
        target_name=product.name,
        operator=current_user,
    )
    db.commit()
    return success_response({"deleted": True}, message="deleted")


@router.get("/{product_id}/parameters", response_model=ApiResponse[ProductParameterListResult])
def get_product_parameters(
    product_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.parameters.view")),
) -> ApiResponse[ProductParameterListResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    ensure_product_parameter_template_initialized(db, product)
    parameters = list_product_parameters(db, product.id)
    items = [
        ProductParameterItem(
            name=parameter.param_key,
            category=parameter.param_category,
            type=parameter.param_type,
            value=parameter.param_value,
            description=parameter.param_description,
            sort_order=parameter.sort_order,
            is_preset=parameter.is_preset,
        )
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
    current_user: User = Depends(require_permission("product.parameters.update")),
) -> ApiResponse[ProductParameterUpdateResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    ensure_product_parameter_template_initialized(db, product)
    try:
        changed_keys = update_product_parameters(
            db,
            product=product,
            items=[(item.name, item.category, item.type, item.value, item.description) for item in payload.items],
            remark=payload.remark,
            operator=current_user,
            confirmed=payload.confirmed,
        )
    except (ValueError, ValidationError) as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    write_audit_log(
        db,
        action_code="product.parameters.update",
        action_name="更新产品参数",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"remark": payload.remark, "changed_keys": changed_keys},
    )
    db.commit()
    return success_response(
        ProductParameterUpdateResult(
            updated_count=len(changed_keys),
            changed_keys=changed_keys,
        ),
        message="updated",
    )


@router.get("/{product_id}/impact-analysis", response_model=ApiResponse[ProductImpactAnalysisResult])
def get_product_impact_analysis(
    product_id: int,
    operation: str = Query(default="lifecycle"),
    target_status: str | None = Query(default=None),
    target_version: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.impact.analysis")),
) -> ApiResponse[ProductImpactAnalysisResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    try:
        query = ProductImpactAnalysisQuery(
            operation=operation,
            target_status=target_status,
            target_version=target_version,
        )
        result = analyze_product_impact(
            db,
            product=product,
            operation=query.operation,
            target_status=query.target_status,
            target_version=query.target_version,
        )
    except (ValueError, ValidationError) as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        ProductImpactAnalysisResult(
            operation=result.operation,
            target_status=result.target_status,
            target_version=result.target_version,
            total_orders=result.total_orders,
            pending_orders=result.pending_orders,
            in_progress_orders=result.in_progress_orders,
            requires_confirmation=result.requires_confirmation,
            items=[
                ProductImpactOrderItem(
                    order_id=item.order_id,
                    order_code=item.order_code,
                    order_status=item.order_status,
                    reason=item.reason,
                )
                for item in result.items
            ],
        )
    )


@router.post("/{product_id}/lifecycle", response_model=ApiResponse[ProductItem])
def update_product_lifecycle(
    product_id: int,
    payload: ProductLifecycleUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.lifecycle.update")),
) -> ApiResponse[ProductItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    try:
        updated = change_product_lifecycle(
            db,
            product=product,
            target_status=payload.target_status,
            confirmed=payload.confirmed,
            note=payload.note,
            inactive_reason=payload.inactive_reason,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="product.lifecycle",
        action_name="变更产品状态",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"lifecycle_status": payload.target_status},
    )
    db.commit()
    return success_response(to_product_item(updated, None), message="updated")


def _to_version_item(row: "ProductRevision") -> ProductVersionItem:
    return ProductVersionItem(
        version=row.version,
        version_label=row.version_label,
        lifecycle_status=row.lifecycle_status,
        action=row.action,
        note=row.note,
        source_version=row.source_revision.version if row.source_revision else None,
        source_version_label=row.source_revision.version_label if row.source_revision else None,
        created_by_user_id=row.created_by_user_id,
        created_by_username=row.created_by.username if row.created_by else None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.get("/{product_id}/versions", response_model=ApiResponse[ProductVersionListResult])
def get_product_versions(
    product_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.versions.list")),
) -> ApiResponse[ProductVersionListResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    rows = list_product_versions(db, product_id=product.id)
    return success_response(
        ProductVersionListResult(
            total=len(rows),
            items=[_to_version_item(row) for row in rows],
        )
    )


@router.post("/{product_id}/versions", response_model=ApiResponse[ProductVersionItem], status_code=status.HTTP_201_CREATED)
def create_product_version_api(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    try:
        revision = create_product_version(db, product=product, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="product.version.create",
        action_name="新建产品版本",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"version": revision.version, "version_label": revision.version_label},
    )
    db.commit()
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision as _PR
    revision = db.execute(
        select(_PR).where(_PR.id == revision.id)
        .options(selectinload(_PR.created_by), selectinload(_PR.source_revision))
    ).scalars().first() or revision
    return success_response(_to_version_item(revision), message="created")


@router.post("/{product_id}/versions/{version}/copy", response_model=ApiResponse[ProductVersionItem], status_code=status.HTTP_201_CREATED)
def copy_product_version_api(
    product_id: int,
    version: int,
    payload: ProductVersionCopyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    if payload.source_version != version:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Path version and source_version must match",
        )
    try:
        revision = copy_product_version(
            db, product=product, source_version=version, operator=current_user
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="product.version.copy",
        action_name="复制产品版本",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"version": revision.version, "version_label": revision.version_label, "source_version": version},
    )
    db.commit()
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision as _PR
    revision = db.execute(
        select(_PR).where(_PR.id == revision.id)
        .options(selectinload(_PR.created_by), selectinload(_PR.source_revision))
    ).scalars().first() or revision
    return success_response(_to_version_item(revision), message="created")


@router.post("/{product_id}/versions/{version}/activate", response_model=ApiResponse[ProductVersionItem])
def activate_product_version_api(
    product_id: int,
    version: int,
    payload: ProductVersionActivateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    try:
        revision = activate_product_version(
            db, product=product, version=version, confirmed=payload.confirmed, operator=current_user
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="product.version.activate",
        action_name="生效产品版本",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"version": version},
    )
    db.commit()
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision as _PR
    revision = db.execute(
        select(_PR).where(_PR.id == revision.id)
        .options(selectinload(_PR.created_by), selectinload(_PR.source_revision))
    ).scalars().first() or revision
    return success_response(_to_version_item(revision), message="activated")


@router.post("/{product_id}/versions/{version}/disable", response_model=ApiResponse[ProductVersionItem])
def disable_product_version_api(
    product_id: int,
    version: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    try:
        revision = disable_product_version(
            db, product=product, version=version, operator=current_user
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="product.version.disable",
        action_name="停用产品版本",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"version": version},
    )
    db.commit()
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision as _PR
    revision = db.execute(
        select(_PR).where(_PR.id == revision.id)
        .options(selectinload(_PR.created_by), selectinload(_PR.source_revision))
    ).scalars().first() or revision
    return success_response(_to_version_item(revision), message="disabled")


@router.delete("/{product_id}/versions/{version}", response_model=ApiResponse[dict[str, bool]])
def delete_product_version_api(
    product_id: int,
    version: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[dict[str, bool]]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    try:
        delete_product_version(db, product=product, version=version, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="product.version.delete",
        action_name="删除产品版本",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"version": version},
    )
    db.commit()
    return success_response({"deleted": True}, message="deleted")


@router.patch("/{product_id}/versions/{version}/note", response_model=ApiResponse[ProductVersionItem])
def update_product_version_note_api(
    product_id: int,
    version: int,
    body: ProductVersionNoteUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    try:
        revision = update_product_version_note(
            db, product_id=product_id, version=version, note=body.note
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_version_item(revision))


@router.get("/{product_id}/versions/compare", response_model=ApiResponse[ProductVersionCompareResult])
def compare_product_version_api(
    product_id: int,
    from_version: int = Query(ge=1),
    to_version: int = Query(ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.versions.compare")),
) -> ApiResponse[ProductVersionCompareResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    try:
        result = compare_product_versions(
            db,
            product=product,
            from_version=from_version,
            to_version=to_version,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(
        ProductVersionCompareResult(
            from_version=result.from_version,
            to_version=result.to_version,
            added_items=result.added_items,
            removed_items=result.removed_items,
            changed_items=result.changed_items,
            items=[
                ProductVersionDiffItem(
                    key=item.key,
                    diff_type=item.diff_type,
                    from_value=item.from_value,
                    to_value=item.to_value,
                )
                for item in result.items
            ],
        )
    )


@router.post("/{product_id}/rollback", response_model=ApiResponse[ProductRollbackResult])
def rollback_product_api(
    product_id: int,
    payload: ProductRollbackRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.rollback")),
) -> ApiResponse[ProductRollbackResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    if not get_product_version(db, product_id=product.id, version=payload.target_version):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target version not found")

    try:
        changed_keys = rollback_product_to_version(
            db,
            product=product,
            target_version=payload.target_version,
            confirmed=payload.confirmed,
            note=payload.note,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    write_audit_log(
        db,
        action_code="product.rollback",
        action_name="回滚产品版本",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={"target_version": payload.target_version, "changed_keys": changed_keys},
    )
    db.commit()
    refreshed = get_product_by_id(db, product.id) or product
    return success_response(
        ProductRollbackResult(
            product=to_product_item(refreshed, None),
            changed_keys=changed_keys,
        ),
        message="rolled_back",
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
    _: User = Depends(require_permission("product.parameter_history.list")),
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
            change_type=row.change_type or "edit",
            changed_keys=[str(value) for value in (row.changed_keys or [])],
            operator_username=row.operator_username,
            before_snapshot=row.before_snapshot or "{}",
            after_snapshot=row.after_snapshot or "{}",
            created_at=row.created_at,
        )
        for row in rows
    ]
    return success_response(ProductParameterHistoryListResult(total=total, items=items))


def _make_csv_response(rows: list[list[str]], filename: str) -> StreamingResponse:
    buf = io.StringIO()
    buf.write("\ufeff")  # UTF-8 BOM for Excel compatibility
    writer = csv.writer(buf)
    for row in rows:
        writer.writerow(row)
    buf.seek(0)
    headers = {
        "Content-Disposition": f'attachment; filename="{filename}"',
        "Content-Type": "text/csv; charset=utf-8-sig",
    }
    return StreamingResponse(iter([buf.getvalue()]), media_type="text/csv", headers=headers)


@router.get("/export", response_class=StreamingResponse)
def export_products(
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    has_effective_version: bool | None = Query(default=None),
    updated_after: datetime | None = Query(default=None),
    updated_before: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.products.list")),
) -> StreamingResponse:
    _, products, latest_map = list_products(
        db, 1, 10000, keyword, category, lifecycle_status,
        has_effective_version=has_effective_version,
        updated_after=updated_after,
        updated_before=updated_before,
    )
    header = ["产品名称", "分类", "状态", "当前版本", "生效版本", "备注", "创建时间", "更新时间"]
    rows: list[list[str]] = [header]
    for p in products:
        rows.append([
            p.name,
            p.category or "",
            p.lifecycle_status,
            f"V1.{p.current_version}" if p.current_version else "",
            f"V1.{p.effective_version}" if p.effective_version else "无",
            p.remark or "",
            p.created_at.strftime("%Y-%m-%d %H:%M:%S") if p.created_at else "",
            p.updated_at.strftime("%Y-%m-%d %H:%M:%S") if p.updated_at else "",
        ])
    return _make_csv_response(rows, "products.csv")


@router.get("/{product_id}/versions/{version}/export", response_class=StreamingResponse)
def export_product_version_parameters(
    product_id: int,
    version: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.parameters.view")),
) -> StreamingResponse:
    import json as _json
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    revision = get_product_version(db, product_id=product.id, version=version)
    if not revision:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Version not found")
    try:
        snapshot = _json.loads(revision.snapshot_json or "{}")
        parameters = snapshot.get("parameters", [])
    except (TypeError, ValueError):
        parameters = []
    header = ["参数名称", "参数分组", "类型", "参数值", "排序"]
    rows: list[list[str]] = [header]
    for param in parameters:
        rows.append([
            str(param.get("name", "")),
            str(param.get("category", "")),
            str(param.get("type", "")),
            str(param.get("value", "")),
            str(param.get("sort_order", "")),
        ])
    filename = f"product_{product.name}_v1.{version}_params.csv"
    return _make_csv_response(rows, filename)


@router.get("/parameters/export", response_class=StreamingResponse)
def export_product_parameters(
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.parameters.view")),
) -> StreamingResponse:
    _, products, _ = list_products(db, 1, 10000, keyword, category, None)
    header = ["产品名称", "参数名称", "参数分组", "类型", "参数值", "参数说明"]
    rows: list[list[str]] = [header]
    for product in products:
        params = list_product_parameters(db, product.id)
        for param in params:
            rows.append([
                product.name,
                param.param_key,
                param.param_category or "",
                param.param_type,
                param.param_value,
                param.param_description or "",
            ])
    return _make_csv_response(rows, "product_parameters.csv")
