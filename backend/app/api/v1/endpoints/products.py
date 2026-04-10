from collections.abc import Sequence
from datetime import datetime
import csv
import io
import json
import logging
import time
import urllib.parse
from threading import RLock

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response, StreamingResponse
from pydantic import ValidationError
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.deps import require_permission, require_permission_fast
from app.core.security import verify_password
from app.db.session import get_db
from app.models.product import Product
from app.models.product_process_template import ProductProcessTemplate
from app.models.product_parameter_history import ProductParameterHistory
from app.models.product_revision import ProductRevision
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.services.audit_service import write_audit_log
from app.services.message_service import create_message_for_users
from app.schemas.product import (
    ProductDetailResult,
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
    ProductRelatedInfoItem,
    ProductRelatedInfoSection,
    ProductParameterVersionListItem,
    ProductParameterVersionListResult,
    ProductParameterUpdateRequest,
    ProductParameterUpdateResult,
    ProductRollbackRequest,
    ProductRollbackResult,
    ProductUpdate,
    ProductVersionActivateRequest,
    ProductVersionCompareResult,
    ProductVersionCopyRequest,
    ProductVersionDiffItem,
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
    get_current_revision,
    get_effective_product_parameters,
    get_effective_revision,
    get_latest_history_map_by_product_ids,
    get_product_by_id,
    get_product_by_name,
    get_product_version_parameters,
    get_product_version,
    list_parameter_history,
    list_product_parameter_versions,
    list_product_versions,
    list_products,
    append_product_history_event,
    rollback_product_to_version,
    sync_product_master_data_to_parameters,
    summarize_changed_keys,
    update_product_parameters,
    update_product_version_parameters,
    update_product_version_note,
)


router = APIRouter()
logger = logging.getLogger(__name__)
_PRODUCT_READ_RESPONSE_CACHE: dict[str, tuple[float, bytes]] = {}
_PRODUCT_READ_RESPONSE_CACHE_LOCK = RLock()
_PRODUCT_READ_RESPONSE_CACHE_TTL_SECONDS = 10
_PRODUCT_DETAIL_RESPONSE_CACHE_TTL_SECONDS = 15
_PRODUCT_PARAMETER_RESPONSE_CACHE_TTL_SECONDS = 15
_PRODUCT_IMPACT_RESPONSE_CACHE_TTL_SECONDS = 10
_PRODUCT_HISTORY_RESPONSE_CACHE_TTL_SECONDS = 10


def _product_read_cache_key(
    product_id: int,
    cache_type: str,
    payload: dict[str, object] | None = None,
) -> str:
    encoded_payload = json.dumps(
        payload or {},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return f"product_read:{product_id}:{cache_type}:{encoded_payload}"


def _get_product_read_cached_response_bytes(cache_key: str) -> bytes | None:
    with _PRODUCT_READ_RESPONSE_CACHE_LOCK:
        cached = _PRODUCT_READ_RESPONSE_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, payload_bytes = cached
        if expire_at <= time.monotonic():
            _PRODUCT_READ_RESPONSE_CACHE.pop(cache_key, None)
            return None
        return payload_bytes


def _set_product_read_cached_response_bytes(
    cache_key: str,
    payload: dict[str, object],
    *,
    ttl_seconds: int = _PRODUCT_READ_RESPONSE_CACHE_TTL_SECONDS,
) -> bytes:
    payload_bytes = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    resolved_ttl_seconds = max(1, int(ttl_seconds))
    with _PRODUCT_READ_RESPONSE_CACHE_LOCK:
        _PRODUCT_READ_RESPONSE_CACHE[cache_key] = (
            time.monotonic() + resolved_ttl_seconds,
            payload_bytes,
        )
    return payload_bytes


def _invalidate_product_read_cache(product_id: int) -> None:
    key_prefix = f"product_read:{product_id}:"
    with _PRODUCT_READ_RESPONSE_CACHE_LOCK:
        expired_keys = [
            key for key in _PRODUCT_READ_RESPONSE_CACHE if key.startswith(key_prefix)
        ]
        for key in expired_keys:
            _PRODUCT_READ_RESPONSE_CACHE.pop(key, None)


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
        current_version_label=(
            f"V1.{product.current_version - 1}" if product.current_version > 0 else "-"
        ),
        effective_version=product.effective_version,
        effective_version_label=(
            f"V1.{product.effective_version - 1}"
            if product.effective_version > 0
            else None
        ),
        effective_at=product.effective_at,
        inactive_reason=product.inactive_reason,
        last_parameter_summary=last_parameter_summary,
        created_at=product.created_at,
        updated_at=product.updated_at,
    )


def _load_snapshot_payload(snapshot: str | None) -> dict[str, object]:
    if not snapshot:
        return {}
    try:
        payload = json.loads(snapshot)
    except (TypeError, ValueError):
        return {}
    return payload if isinstance(payload, dict) else {}


def _format_parameter_snapshot_item(item: dict[str, object]) -> str:
    return (
        f"分类={str(item.get('category') or '-')}; "
        f"类型={str(item.get('type') or '-')}; "
        f"值={str(item.get('value') or '-')}; "
        f"说明={str(item.get('description') or '-')}"
    )


def _build_parameter_snapshot_map(snapshot: str | None) -> dict[str, str]:
    payload = _load_snapshot_payload(snapshot)
    parameters = payload.get("parameters")
    if not isinstance(parameters, list):
        return {}
    result: dict[str, str] = {}
    for raw_item in parameters:
        if not isinstance(raw_item, dict):
            continue
        name = str(raw_item.get("name") or "").strip()
        if not name:
            continue
        result[name] = _format_parameter_snapshot_item(raw_item)
    return result


def _build_history_display_fields(
    row: ProductParameterHistory,
) -> tuple[str | None, str | None, str | None]:
    changed_keys = [
        str(value) for value in (row.changed_keys or []) if str(value).strip()
    ]
    before_map = _build_parameter_snapshot_map(row.before_snapshot)
    after_map = _build_parameter_snapshot_map(row.after_snapshot)
    display_keys = (
        changed_keys or list(dict.fromkeys([*before_map.keys(), *after_map.keys()]))[:3]
    )
    if not display_keys:
        return None, None, None

    before_parts = [f"{key}: {before_map.get(key, '无')}" for key in display_keys]
    after_parts = [f"{key}: {after_map.get(key, '无')}" for key in display_keys]
    parameter_name = "、".join(display_keys)
    return parameter_name, "；".join(before_parts), "；".join(after_parts)


def _to_history_item(
    *,
    product: Product,
    row: ProductParameterHistory,
) -> ProductParameterHistoryItem:
    parameter_name, before_summary, after_summary = _build_history_display_fields(row)
    return ProductParameterHistoryItem(
        id=row.id,
        product_name=product.name,
        product_category=product.category or "",
        version=row.version,
        version_label=row.revision.version_label
        if row.revision is not None
        else (f"V1.{row.version - 1}" if row.version is not None else None),
        remark=row.remark,
        change_reason=row.remark,
        change_type=row.change_type or "edit",
        parameter_name=parameter_name,
        changed_keys=[str(value) for value in (row.changed_keys or [])],
        operator_username=row.operator_username,
        before_summary=before_summary,
        after_summary=after_summary,
        before_snapshot=row.before_snapshot or "{}",
        after_snapshot=row.after_snapshot or "{}",
        created_at=row.created_at,
    )


def _to_parameter_list_result(
    *,
    product: Product,
    parameter_scope: str,
    version: int,
    version_label: str,
    lifecycle_status: str,
    parameters: Sequence[object],
) -> ProductParameterListResult:
    items = [
        ProductParameterItem(
            name=str(getattr(parameter, "param_key")),
            category=str(getattr(parameter, "param_category")),
            type=str(getattr(parameter, "param_type")),  # type: ignore[reportArgumentType]
            value=str(getattr(parameter, "param_value")),
            description=str(getattr(parameter, "param_description") or ""),
            sort_order=int(getattr(parameter, "sort_order")),
            is_preset=bool(getattr(parameter, "is_preset")),
        )
        for parameter in parameters
    ]
    return ProductParameterListResult(
        product_id=product.id,
        product_name=product.name,
        parameter_scope=parameter_scope,  # type: ignore[reportArgumentType]
        version=version,
        version_label=version_label,
        lifecycle_status=lifecycle_status,
        total=len(items),
        items=items,
    )


def _build_product_detail_result(
    *, db: Session, product: Product
) -> ProductDetailResult:
    from sqlalchemy import select

    latest_history = get_latest_history_map_by_product_ids(db, [product.id]).get(
        product.id
    )
    versions = list_product_versions(db, product_id=product.id)
    template_rows = (
        db.execute(
            select(ProductProcessTemplate)
            .where(ProductProcessTemplate.product_id == product.id)
            .order_by(
                ProductProcessTemplate.is_default.desc(),
                ProductProcessTemplate.updated_at.desc(),
                ProductProcessTemplate.id.desc(),
            )
        )
        .scalars()
        .all()
    )

    latest_version_changed_at: datetime | None = None
    for row in versions:
        candidate = row.updated_at or getattr(row, "effective_at", None) or row.created_at
        if latest_version_changed_at is None or candidate > latest_version_changed_at:
            latest_version_changed_at = candidate

    detail_parameter_message: str | None = None
    detail_parameters: ProductParameterListResult
    effective_revision = get_effective_revision(db, product=product)
    if effective_revision is not None:
        revision, parameters = get_effective_product_parameters(db, product=product)
        detail_parameters = _to_parameter_list_result(
            product=product,
            parameter_scope="effective",
            version=revision.version,
            version_label=revision.version_label,
            lifecycle_status=revision.lifecycle_status,
            parameters=parameters,
        )
    else:
        current_revision = get_current_revision(db, product=product)
        if current_revision is None:
            detail_parameters = ProductParameterListResult(
                product_id=product.id,
                product_name=product.name,
                parameter_scope="version",
                version=0,
                version_label="-",
                lifecycle_status=product.lifecycle_status,
                total=0,
                items=[],
            )
            detail_parameter_message = "当前产品暂无可展示的版本参数。"
        else:
            revision, parameters = get_product_version_parameters(
                db,
                product=product,
                version=current_revision.version,
            )
            detail_parameters = _to_parameter_list_result(
                product=product,
                parameter_scope="version",
                version=revision.version,
                version_label=revision.version_label,
                lifecycle_status=revision.lifecycle_status,
                parameters=parameters,
            )
            detail_parameter_message = (
                "当前无生效版本，详情已回退展示当前版本参数快照。"
            )

    history_total, history_rows = list_parameter_history(
        db,
        product_id=product.id,
        version=None,
        page=1,
        page_size=1000,
    )

    related_info_sections = [
        ProductRelatedInfoSection(
            code="process_templates",
            title="关联工艺路线",
            total=len(template_rows),
            items=[
                ProductRelatedInfoItem(
                    label=row.template_name,
                    value=f"版本 {row.version} | {'默认' if row.is_default else '非默认'} | {row.lifecycle_status}",
                )
                for row in template_rows
            ],
            empty_message=(
                "当前产品暂未绑定工艺路线，可后续在工艺路线模块补充。"
                if not template_rows
                else None
            ),
        ),
        ProductRelatedInfoSection(
            code="applicable_lines",
            title="适用产线",
            total=0,
            items=[],
            empty_message="当前仓库尚未沉淀产品-产线关联数据。",
        ),
        ProductRelatedInfoSection(
            code="equipment",
            title="关联设备",
            total=0,
            items=[],
            empty_message="当前仓库尚未沉淀产品-设备关联数据。",
        ),
        ProductRelatedInfoSection(
            code="quality_standards",
            title="质检标准",
            total=0,
            items=[],
            empty_message="当前仓库尚未沉淀产品-质检标准关联数据。",
        ),
        ProductRelatedInfoSection(
            code="packaging_rules",
            title="包装规则",
            total=0,
            items=[],
            empty_message="当前仓库尚未沉淀产品-包装规则关联数据。",
        ),
    ]

    return ProductDetailResult(
        product=to_product_item(product, latest_history),
        detail_parameters=detail_parameters,
        detail_parameter_message=detail_parameter_message,
        latest_version_changed_at=latest_version_changed_at,
        version_total=len(versions),
        versions=[_to_version_item(row) for row in versions],
        history_total=history_total,
        history_items=[
            _to_history_item(product=product, row=row) for row in history_rows
        ],
        related_info_sections=related_info_sections,
    )


def _notify_product_version_activated(
    *,
    db: Session,
    product: Product,
    revision: ProductVersionItem,
    operator: User,
) -> None:
    payload = {
        "action": "view_version",
        "product_id": product.id,
        "product_name": product.name,
        "target_version": revision.version,
        "target_version_label": revision.version_label,
        "target_tab_code": "product_version_management",
    }
    create_message_for_users(
        db,
        message_type="notice",
        priority="important",
        title=f"产品版本已发布：{product.name} {revision.version_label}",
        summary=f"{operator.username} 已发布产品 {product.name} 的 {revision.version_label}",
        content=(
            f"产品 {product.name} 已生效到 {revision.version_label}，"
            "可从消息直接跳转到版本管理查看目标版本。"
        ),
        source_module="product",
        source_type="product_version",
        source_id=str(product.id),
        source_code=f"{product.name}/{revision.version_label}",
        target_page_code="product",
        target_tab_code="product_version_management",
        target_route_payload_json=json.dumps(payload),
        recipient_user_ids=[operator.id],
        dedupe_key=f"product_version_activated_{product.id}_{revision.version}",
        created_by_user_id=operator.id,
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
    current_version_keyword: str | None = Query(default=None),
    current_param_name_keyword: str | None = Query(default=None),
    current_param_category_keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.products.list")),
) -> ApiResponse[ProductListResult]:
    total, products, latest_map = list_products(
        db,
        page,
        page_size,
        keyword,
        category,
        lifecycle_status,
        has_effective_version=has_effective_version,
        updated_after=updated_after,
        updated_before=updated_before,
        current_version_keyword=current_version_keyword,
        current_param_name_keyword=current_param_name_keyword,
        current_param_category_keyword=current_param_category_keyword,
    )
    return success_response(
        ProductListResult(
            total=total,
            items=[
                to_product_item(product, latest_map.get(product.id))
                for product in products
            ],
        )
    )


@router.get("/parameter-query", response_model=ApiResponse[ProductListResult])
def get_product_parameter_query_products(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    has_effective_version: bool | None = Query(default=None),
    effective_version_keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.parameters.view")),
) -> ApiResponse[ProductListResult]:
    total, products, latest_map = list_products(
        db,
        page,
        page_size,
        keyword,
        category,
        lifecycle_status,
        has_effective_version=has_effective_version,
        effective_version_keyword=effective_version_keyword,
    )
    return success_response(
        ProductListResult(
            total=total,
            items=[
                to_product_item(product, latest_map.get(product.id))
                for product in products
            ],
        )
    )


@router.get(
    "/parameter-versions",
    response_model=ApiResponse[ProductParameterVersionListResult],
)
def get_product_parameter_versions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    version_keyword: str | None = Query(default=None),
    param_name_keyword: str | None = Query(default=None),
    param_category_keyword: str | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    updated_after: datetime | None = Query(default=None),
    updated_before: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.parameters.view")),
) -> ApiResponse[ProductParameterVersionListResult]:
    total, rows = list_product_parameter_versions(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        category=category,
        version_keyword=version_keyword,
        param_name_keyword=param_name_keyword,
        param_category_keyword=param_category_keyword,
        lifecycle_status=lifecycle_status,
        updated_after=updated_after,
        updated_before=updated_before,
    )
    return success_response(
        ProductParameterVersionListResult(
            total=total,
            items=[
                ProductParameterVersionListItem(
                    product_id=row.product.id,
                    product_name=row.product.name,
                    product_category=row.product.category or "",
                    version=row.revision.version,
                    version_label=row.revision.version_label,
                    lifecycle_status=row.revision.lifecycle_status,
                    is_current_version=row.product.current_version
                    == row.revision.version,
                    is_effective_version=row.product.effective_version
                    == row.revision.version,
                    created_at=row.revision.created_at,
                    parameter_summary=row.parameter_summary,
                    parameter_count=row.parameter_count,
                    matched_parameter_name=row.matched_parameter_name,
                    matched_parameter_category=row.matched_parameter_category,
                    last_modified_parameter=row.last_modified_parameter,
                    last_modified_parameter_category=row.last_modified_parameter_category,
                    updated_at=row.revision.updated_at,
                )
                for row in rows
            ],
        )
    )


@router.post(
    "", response_model=ApiResponse[ProductItem], status_code=status.HTTP_201_CREATED
)
def create_product_api(
    payload: ProductCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.products.create")),
) -> ApiResponse[ProductItem]:
    normalized_name = payload.name.strip()
    existing = get_product_by_name(db, normalized_name)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Product name already exists",
        )

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
        after_data={
            "name": product.name,
            "category": product.category,
            "remark": product.remark,
        },
    )
    db.commit()
    return success_response(to_product_item(product, None), message="created")


@router.get("/{product_id}", response_model=ApiResponse[ProductItem])
def get_product_detail_api(
    product_id: int,
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("product.products.list")),
) -> ApiResponse[ProductItem] | Response:
    cache_key = _product_read_cache_key(product_id, "detail_item")
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    latest_history = get_latest_history_map_by_product_ids(db, [product.id]).get(
        product.id
    )
    response_payload = success_response(
        to_product_item(product, latest_history)
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_DETAIL_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get("/{product_id}/detail", response_model=ApiResponse[ProductDetailResult])
def get_product_detail_bundle_api(
    product_id: int,
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("product.products.list")),
) -> ApiResponse[ProductDetailResult] | Response:
    cache_key = _product_read_cache_key(product_id, "detail_bundle")
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    response_payload = success_response(
        _build_product_detail_result(db=db, product=product)
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_DETAIL_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.put("/{product_id}", response_model=ApiResponse[ProductItem])
def update_product_api(
    product_id: int,
    payload: ProductUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.products.create")),
) -> ApiResponse[ProductItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    normalized_name = payload.name.strip()
    if not normalized_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Product name is required"
        )

    if normalized_name != product.name:
        existing = get_product_by_name(db, normalized_name)
        if existing and existing.id != product.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Product name already exists",
            )

    before_snapshot = json.dumps(
        {
            "name": product.name,
            "category": product.category,
            "remark": product.remark,
            "lifecycle_status": product.lifecycle_status,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )

    product.name = normalized_name
    product.category = payload.category
    product.remark = (payload.remark or "").strip()
    sync_product_master_data_to_parameters(db, product=product)
    after_snapshot = json.dumps(
        {
            "name": product.name,
            "category": product.category,
            "remark": product.remark,
            "lifecycle_status": product.lifecycle_status,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
    append_product_history_event(
        db,
        product=product,
        operator=current_user,
        change_type="update_product",
        remark="编辑产品基础信息",
        changed_keys=["name", "category", "remark"],
        before_snapshot=before_snapshot,
        after_snapshot=after_snapshot,
    )
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
        after_data={
            "name": product.name,
            "category": product.category,
            "remark": product.remark,
        },
    )
    db.commit()
    _invalidate_product_read_cache(product.id)
    latest_history = get_latest_history_map_by_product_ids(db, [product.id]).get(
        product.id
    )
    return success_response(to_product_item(product, latest_history), message="updated")


@router.post("/{product_id}/delete", response_model=ApiResponse[dict[str, bool]])
def delete_product_api(
    product_id: int,
    payload: ProductDeleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.products.delete")),
) -> ApiResponse[dict[str, bool]]:
    if not verify_password(payload.password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Password is incorrect"
        )

    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

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
    _invalidate_product_read_cache(product_id)
    return success_response({"deleted": True}, message="deleted")


@router.get(
    "/{product_id}/parameters", response_model=ApiResponse[ProductParameterListResult]
)
def get_product_parameters(
    product_id: int,
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("product.parameters.view")),
) -> ApiResponse[ProductParameterListResult] | Response:
    cache_key = _product_read_cache_key(product_id, "parameters_current")
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    revision = get_current_revision(db, product=product)
    if revision is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Current version not found"
        )
    revision, parameters = get_product_version_parameters(
        db,
        product=product,
        version=revision.version,
    )
    response_payload = success_response(
        _to_parameter_list_result(
            product=product,
            parameter_scope="version",
            version=revision.version,
            version_label=revision.version_label,
            lifecycle_status=revision.lifecycle_status,
            parameters=parameters,
        )
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_PARAMETER_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get(
    "/{product_id}/versions/{version}/parameters",
    response_model=ApiResponse[ProductParameterListResult],
)
def get_product_version_parameters_api(
    product_id: int,
    version: int,
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("product.parameters.view")),
) -> ApiResponse[ProductParameterListResult] | Response:
    cache_key = _product_read_cache_key(
        product_id,
        "parameters_version",
        {"version": version},
    )
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    try:
        revision, parameters = get_product_version_parameters(
            db,
            product=product,
            version=version,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error))
    response_payload = success_response(
        _to_parameter_list_result(
            product=product,
            parameter_scope="version",
            version=revision.version,
            version_label=revision.version_label,
            lifecycle_status=revision.lifecycle_status,
            parameters=parameters,
        )
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_PARAMETER_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get(
    "/{product_id}/effective-parameters",
    response_model=ApiResponse[ProductParameterListResult],
)
def get_effective_product_parameters_api(
    product_id: int,
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("product.parameters.view")),
) -> ApiResponse[ProductParameterListResult] | Response:
    cache_key = _product_read_cache_key(product_id, "parameters_effective")
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    try:
        revision, parameters = get_effective_product_parameters(
            db,
            product=product,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    response_payload = success_response(
        _to_parameter_list_result(
            product=product,
            parameter_scope="effective",
            version=revision.version,
            version_label=revision.version_label,
            lifecycle_status=revision.lifecycle_status,
            parameters=parameters,
        )
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_PARAMETER_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.put(
    "/{product_id}/parameters", response_model=ApiResponse[ProductParameterUpdateResult]
)
def update_parameters(
    product_id: int,
    payload: ProductParameterUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.parameters.update")),
) -> ApiResponse[ProductParameterUpdateResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    try:
        changed_keys = update_product_parameters(
            db,
            product=product,
            items=[
                (item.name, item.category, item.type, item.value, item.description)
                for item in payload.items
            ],
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
        after_data={
            "version": product.current_version,
            "remark": payload.remark,
            "changed_keys": changed_keys,
        },
    )
    db.commit()
    _invalidate_product_read_cache(product.id)
    return success_response(
        ProductParameterUpdateResult(
            parameter_scope="version",
            version=product.current_version,
            updated_count=len(changed_keys),
            changed_keys=changed_keys,
        ),
        message="updated",
    )


@router.put(
    "/{product_id}/versions/{version}/parameters",
    response_model=ApiResponse[ProductParameterUpdateResult],
)
def update_product_version_parameters_api(
    product_id: int,
    version: int,
    payload: ProductParameterUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.parameters.update")),
) -> ApiResponse[ProductParameterUpdateResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    try:
        changed_keys = update_product_version_parameters(
            db,
            product=product,
            version=version,
            items=[
                (item.name, item.category, item.type, item.value, item.description)
                for item in payload.items
            ],
            remark=payload.remark,
            operator=current_user,
            confirmed=payload.confirmed,
        )
    except (ValueError, ValidationError) as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    write_audit_log(
        db,
        action_code="product.parameters.update",
        action_name="更新版本参数",
        target_type="product",
        target_id=str(product.id),
        target_name=product.name,
        operator=current_user,
        after_data={
            "version": version,
            "remark": payload.remark,
            "changed_keys": changed_keys,
        },
    )
    db.commit()
    _invalidate_product_read_cache(product.id)
    return success_response(
        ProductParameterUpdateResult(
            parameter_scope="version",
            version=version,
            updated_count=len(changed_keys),
            changed_keys=changed_keys,
        ),
        message="updated",
    )


@router.get(
    "/{product_id}/impact-analysis",
    response_model=ApiResponse[ProductImpactAnalysisResult],
)
def get_product_impact_analysis(
    product_id: int,
    operation: str = Query(default="lifecycle"),
    target_status: str | None = Query(default=None),
    target_version: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("product.impact.analysis")),
) -> ApiResponse[ProductImpactAnalysisResult] | Response:
    cache_key = _product_read_cache_key(
        product_id,
        "impact_analysis",
        {
            "operation": operation,
            "target_status": target_status,
            "target_version": target_version,
        },
    )
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    try:
        query = ProductImpactAnalysisQuery(
            operation=operation,  # type: ignore[reportArgumentType]
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

    response_payload = success_response(
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
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_IMPACT_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.post("/{product_id}/lifecycle", response_model=ApiResponse[ProductItem])
def update_product_lifecycle(
    product_id: int,
    payload: ProductLifecycleUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.lifecycle.update")),
) -> ApiResponse[ProductItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    try:
        before_snapshot = json.dumps(
            {
                "lifecycle_status": product.lifecycle_status,
                "inactive_reason": product.inactive_reason,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
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
    after_snapshot = json.dumps(
        {
            "lifecycle_status": updated.lifecycle_status,
            "inactive_reason": updated.inactive_reason,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
    append_product_history_event(
        db,
        product=updated,
        operator=current_user,
        change_type="lifecycle",
        remark=f"变更产品状态为 {payload.target_status}",
        changed_keys=["lifecycle_status", "inactive_reason"],
        before_snapshot=before_snapshot,
        after_snapshot=after_snapshot,
    )
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
    _invalidate_product_read_cache(product.id)
    return success_response(to_product_item(updated, None), message="updated")


def _to_version_item(
    row: ProductRevision,
    *,
    effective_at: datetime | None = None,
) -> ProductVersionItem:
    return ProductVersionItem(
        version=row.version,
        version_label=row.version_label,
        lifecycle_status=row.lifecycle_status,
        action=row.action,
        note=row.note,
        effective_at=effective_at,
        source_version=row.source_revision.version if row.source_revision else None,
        source_version_label=row.source_revision.version_label
        if row.source_revision
        else None,
        created_by_user_id=row.created_by_user_id,
        created_by_username=row.created_by.username if row.created_by else None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.get(
    "/{product_id}/versions", response_model=ApiResponse[ProductVersionListResult]
)
def get_product_versions(
    product_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.versions.list")),
) -> ApiResponse[ProductVersionListResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    rows = list_product_versions(db, product_id=product.id)
    return success_response(
        ProductVersionListResult(
            total=len(rows),
            items=[
                _to_version_item(
                    row,
                    effective_at=product.effective_at
                    if product.effective_version == row.version
                    and row.lifecycle_status == "effective"
                    else None,
                )
                for row in rows
            ],
        )
    )


@router.post(
    "/{product_id}/versions",
    response_model=ApiResponse[ProductVersionItem],
    status_code=status.HTTP_201_CREATED,
)
def create_product_version_api(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
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
        after_data={
            "version": revision.version,
            "version_label": revision.version_label,
        },
    )
    db.commit()
    _invalidate_product_read_cache(product.id)
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision

    revision = (
        db.execute(
            select(ProductRevision)
            .where(ProductRevision.id == revision.id)
            .options(
                selectinload(ProductRevision.created_by),
                selectinload(ProductRevision.source_revision),
            )
        )
        .scalars()
        .first()
        or revision
    )
    return success_response(_to_version_item(revision), message="created")


@router.post(
    "/{product_id}/versions/{version}/copy",
    response_model=ApiResponse[ProductVersionItem],
    status_code=status.HTTP_201_CREATED,
)
def copy_product_version_api(
    product_id: int,
    version: int,
    payload: ProductVersionCopyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
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
        after_data={
            "version": revision.version,
            "version_label": revision.version_label,
            "source_version": version,
        },
    )
    db.commit()
    _invalidate_product_read_cache(product.id)
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision

    revision = (
        db.execute(
            select(ProductRevision)
            .where(ProductRevision.id == revision.id)
            .options(
                selectinload(ProductRevision.created_by),
                selectinload(ProductRevision.source_revision),
            )
        )
        .scalars()
        .first()
        or revision
    )
    return success_response(_to_version_item(revision), message="created")


@router.post(
    "/{product_id}/versions/{version}/activate",
    response_model=ApiResponse[ProductVersionItem],
)
def activate_product_version_api(
    product_id: int,
    version: int,
    payload: ProductVersionActivateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.activate")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    try:
        revision = activate_product_version(
            db,
            product=product,
            version=version,
            confirmed=payload.confirmed,
            expected_effective_version=payload.expected_effective_version,
            operator=current_user,
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
    _invalidate_product_read_cache(product.id)
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision

    revision = (
        db.execute(
            select(ProductRevision)
            .where(ProductRevision.id == revision.id)
            .options(
                selectinload(ProductRevision.created_by),
                selectinload(ProductRevision.source_revision),
            )
        )
        .scalars()
        .first()
        or revision
    )
    safe_product_id = product.id
    safe_version = version
    try:
        _notify_product_version_activated(
            db=db,
            product=product,
            revision=_to_version_item(revision),
            operator=current_user,
        )
    except (ValueError, SQLAlchemyError):
        db.rollback()
        logger.exception(
            "[MSG] 产品版本发布消息创建失败: product_id=%s version=%s",
            safe_product_id,
            safe_version,
        )
    return success_response(_to_version_item(revision), message="activated")


@router.post(
    "/{product_id}/versions/{version}/disable",
    response_model=ApiResponse[ProductVersionItem],
)
def disable_product_version_api(
    product_id: int,
    version: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
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
    _invalidate_product_read_cache(product.id)
    from sqlalchemy.orm import selectinload
    from sqlalchemy import select
    from app.models.product_revision import ProductRevision

    revision = (
        db.execute(
            select(ProductRevision)
            .where(ProductRevision.id == revision.id)
            .options(
                selectinload(ProductRevision.created_by),
                selectinload(ProductRevision.source_revision),
            )
        )
        .scalars()
        .first()
        or revision
    )
    return success_response(_to_version_item(revision), message="disabled")


@router.delete(
    "/{product_id}/versions/{version}", response_model=ApiResponse[dict[str, bool]]
)
def delete_product_version_api(
    product_id: int,
    version: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[dict[str, bool]]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    try:
        delete_product_version(
            db, product=product, version=version, operator=current_user
        )
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
    _invalidate_product_read_cache(product.id)
    return success_response({"deleted": True}, message="deleted")


@router.patch(
    "/{product_id}/versions/{version}/note",
    response_model=ApiResponse[ProductVersionItem],
)
def update_product_version_note_api(
    product_id: int,
    version: int,
    body: ProductVersionNoteUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.versions.manage")),
) -> ApiResponse[ProductVersionItem]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    try:
        revision = update_product_version_note(
            db,
            product_id=product_id,
            version=version,
            note=body.note,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    _invalidate_product_read_cache(product.id)
    return success_response(_to_version_item(revision))


@router.get(
    "/{product_id}/versions/compare",
    response_model=ApiResponse[ProductVersionCompareResult],
)
def compare_product_version_api(
    product_id: int,
    from_version: int = Query(ge=1),
    to_version: int = Query(ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.versions.compare")),
) -> ApiResponse[ProductVersionCompareResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
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


@router.post(
    "/{product_id}/rollback", response_model=ApiResponse[ProductRollbackResult]
)
def rollback_product_api(
    product_id: int,
    payload: ProductRollbackRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("product.rollback")),
) -> ApiResponse[ProductRollbackResult]:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    if not get_product_version(
        db, product_id=product.id, version=payload.target_version
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Target version not found"
        )

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
        after_data={
            "target_version": payload.target_version,
            "changed_keys": changed_keys,
        },
    )
    db.commit()
    _invalidate_product_read_cache(product.id)
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
    _: None = Depends(require_permission_fast("product.parameter_history.list")),
) -> ApiResponse[ProductParameterHistoryListResult] | Response:
    cache_key = _product_read_cache_key(
        product_id,
        "parameter_history",
        {"page": page, "page_size": page_size},
    )
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )

    total, rows = list_parameter_history(
        db,
        product_id=product.id,
        page=page,
        page_size=page_size,
    )
    items = [_to_history_item(product=product, row=row) for row in rows]
    response_payload = success_response(
        ProductParameterHistoryListResult(total=total, items=items)
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_HISTORY_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get(
    "/{product_id}/versions/{version}/parameter-history",
    response_model=ApiResponse[ProductParameterHistoryListResult],
)
def get_version_parameter_history(
    product_id: int,
    version: int,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("product.parameter_history.list")),
) -> ApiResponse[ProductParameterHistoryListResult] | Response:
    cache_key = _product_read_cache_key(
        product_id,
        "parameter_history_version",
        {"version": version, "page": page, "page_size": page_size},
    )
    cached_payload = _get_product_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    revision = get_product_version(db, product_id=product.id, version=version)
    if revision is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Version not found"
        )

    total, rows = list_parameter_history(
        db,
        product_id=product.id,
        revision_id=revision.id,
        page=page,
        page_size=page_size,
    )
    items = [_to_history_item(product=product, row=row) for row in rows]
    response_payload = success_response(
        ProductParameterHistoryListResult(
            version=revision.version,
            version_label=revision.version_label,
            lifecycle_status=revision.lifecycle_status,
            total=total,
            items=items,
        )
    ).model_dump(mode="json")
    payload_bytes = _set_product_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_PRODUCT_HISTORY_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


def _make_csv_response(rows: list[list[str]], filename: str) -> StreamingResponse:
    buf = io.StringIO()
    buf.write("\ufeff")  # UTF-8 BOM for Excel compatibility
    writer = csv.writer(buf)
    for row in rows:
        writer.writerow(row)
    buf.seek(0)
    quoted_filename = urllib.parse.quote(filename)
    ascii_filename = filename.encode("ascii", "ignore").decode().strip() or "export.csv"
    headers = {
        "Content-Disposition": (
            f'attachment; filename="{ascii_filename}"; '
            f"filename*=UTF-8''{quoted_filename}"
        ),
        "Content-Type": "text/csv; charset=utf-8-sig",
    }
    return StreamingResponse(
        iter([buf.getvalue()]), media_type="text/csv", headers=headers
    )


@router.get("/export/list", response_class=StreamingResponse)
def export_products(
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    has_effective_version: bool | None = Query(default=None),
    updated_after: datetime | None = Query(default=None),
    updated_before: datetime | None = Query(default=None),
    current_version_keyword: str | None = Query(default=None),
    current_param_name_keyword: str | None = Query(default=None),
    current_param_category_keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.products.export")),
) -> StreamingResponse:
    _total, products, latest_map = list_products(
        db,
        1,
        10000,
        keyword,
        category,
        lifecycle_status,
        has_effective_version=has_effective_version,
        updated_after=updated_after,
        updated_before=updated_before,
        current_version_keyword=current_version_keyword,
        current_param_name_keyword=current_param_name_keyword,
        current_param_category_keyword=current_param_category_keyword,
    )
    header = [
        "产品名称",
        "分类",
        "状态",
        "当前版本",
        "生效版本",
        "备注",
        "创建时间",
        "更新时间",
    ]
    rows: list[list[str]] = [header]
    for p in products:
        rows.append(
            [
                p.name,
                p.category or "",
                p.lifecycle_status,
                f"V1.{p.current_version - 1}" if p.current_version > 0 else "",
                f"V1.{p.effective_version - 1}" if p.effective_version > 0 else "无",
                p.remark or "",
                p.created_at.strftime("%Y-%m-%d %H:%M:%S") if p.created_at else "",
                p.updated_at.strftime("%Y-%m-%d %H:%M:%S") if p.updated_at else "",
            ]
        )
    return _make_csv_response(rows, "products.csv")


@router.get("/{product_id}/versions/{version}/export", response_class=StreamingResponse)
def export_product_version_parameters(
    product_id: int,
    version: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.parameters.export")),
) -> StreamingResponse:
    product = get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    try:
        revision, parameters = get_product_version_parameters(
            db,
            product=product,
            version=version,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error))
    header = ["版本号", "参数名称", "参数分组", "类型", "参数值", "参数说明", "排序"]
    rows: list[list[str]] = [header]
    for param in parameters:
        rows.append(
            [
                revision.version_label,
                param.param_key,
                param.param_category or "",
                param.param_type,
                param.param_value,
                param.param_description or "",
                str(param.sort_order),
            ]
        )
    filename = f"product_{product.name}_v1.{version}_params.csv"
    return _make_csv_response(rows, filename)


@router.get("/parameters/export", response_class=StreamingResponse)
def export_product_parameters(
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    version_keyword: str | None = Query(default=None),
    param_keyword: str | None = Query(default=None),
    param_category_keyword: str | None = Query(default=None),
    updated_after: datetime | None = Query(default=None),
    updated_before: datetime | None = Query(default=None),
    effective_only: bool = Query(default=False),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("product.parameters.export")),
) -> StreamingResponse:
    _total, products, latest_history_map = list_products(
        db,
        1,
        10000,
        keyword,
        category,
        lifecycle_status,
        updated_after=updated_after,
        updated_before=updated_before,
    )
    normalized_version_keyword = (version_keyword or "").strip().lower()
    normalized_param_keyword = (param_keyword or "").strip().lower()
    normalized_param_category_keyword = (param_category_keyword or "").strip().lower()
    if (
        normalized_version_keyword
        or normalized_param_keyword
        or normalized_param_category_keyword
    ):
        filtered_products: list[Product] = []
        for product in products:
            version_source = (
                product.effective_version if effective_only else product.current_version
            )
            version_label = f"v1.{version_source - 1}" if version_source > 0 else ""
            latest_summary = latest_history_map.get(product.id)
            summary_text = (
                (
                    summarize_changed_keys(latest_summary.changed_keys or []) or ""
                ).lower()
                if latest_summary is not None
                else ""
            )
            if (
                normalized_version_keyword
                and normalized_version_keyword not in version_label
            ):
                continue
            if (
                normalized_param_keyword
                and normalized_param_keyword not in summary_text
            ):
                continue
            filtered_products.append(product)
        products = filtered_products
    header = [
        "产品名称",
        "生效版本",
        "参数名称",
        "参数分组",
        "类型",
        "参数值",
        "参数说明",
    ]
    rows: list[list[str]] = [header]
    for product in products:
        target_revision = (
            get_effective_revision(db, product=product)
            if effective_only
            else get_current_revision(db, product=product)
        )
        if target_revision is None:
            rows.append(
                [
                    product.name,
                    "-",
                    "当前无生效版本",
                    "",
                    "",
                    "",
                    "当前筛选结果下暂无可导出参数",
                ]
            )
            continue
        params = get_product_version_parameters(
            db,
            product=product,
            version=target_revision.version,
        )[1]
        if normalized_param_keyword:
            params = [
                param
                for param in params
                if normalized_param_keyword in param.param_key.lower()
            ]
        if normalized_param_category_keyword:
            params = [
                param
                for param in params
                if normalized_param_category_keyword
                in (param.param_category or "").lower()
            ]
        if not params:
            continue
        for param in params:
            rows.append(
                [
                    product.name,
                    target_revision.version_label,
                    param.param_key,
                    param.param_category or "",
                    param.param_type,
                    param.param_value,
                    param.param_description or "",
                ]
            )
    return _make_csv_response(rows, "product_parameters.csv")
