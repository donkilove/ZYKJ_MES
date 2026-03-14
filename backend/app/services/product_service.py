from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import UTC, datetime
import json
import logging

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session, selectinload

from app.core.product_lifecycle import (
    PRODUCT_LIFECYCLE_ACTIVE,
    PRODUCT_LIFECYCLE_DISABLED,
    PRODUCT_LIFECYCLE_DRAFT,
    PRODUCT_LIFECYCLE_EFFECTIVE,
    PRODUCT_LIFECYCLE_INACTIVE,
    PRODUCT_LIFECYCLE_OBSOLETE,
    PRODUCT_LIFECYCLE_OPTIONS,
    PRODUCT_REVISION_LIFECYCLE_OPTIONS,
    PRODUCT_LIFECYCLE_TRANSITIONS,
)
from app.core.product_parameter_template import (
    ALLOWED_PARAMETER_TYPES,
    PARAMETER_TYPE_TEXT,
    PRODUCT_NAME_PARAMETER_CATEGORY,
    PRODUCT_NAME_PARAMETER_KEY,
    PRODUCT_NAME_PARAMETER_TYPE,
    PRODUCT_PARAMETER_TEMPLATE,
    PRODUCT_PARAMETER_TEMPLATE_NAME_SET,
)
from app.core.production_constants import ORDER_STATUS_IN_PROGRESS, ORDER_STATUS_PENDING
from app.models.product import Product
from app.models.product_parameter import ProductParameter
from app.models.product_parameter_history import ProductParameterHistory
from app.models.product_process_template import ProductProcessTemplate
from app.models.product_process_template_step import ProductProcessTemplateStep
from app.models.product_revision import ProductRevision
from app.models.production_order import ProductionOrder
from app.models.user import User
from app.services.craft_service import resolve_system_master_template


logger = logging.getLogger(__name__)


@dataclass(slots=True)
class ProductImpactOrder:
    order_id: int
    order_code: str
    order_status: str
    reason: str | None = None


@dataclass(slots=True)
class ProductImpactResult:
    operation: str
    target_status: str | None
    target_version: int | None
    total_orders: int
    pending_orders: int
    in_progress_orders: int
    requires_confirmation: bool
    items: list[ProductImpactOrder]


@dataclass(slots=True)
class ProductVersionCompareRow:
    key: str
    diff_type: str
    from_value: str | None = None
    to_value: str | None = None


@dataclass(slots=True)
class ProductVersionCompareResult:
    from_version: int
    to_version: int
    added_items: int
    removed_items: int
    changed_items: int
    items: list[ProductVersionCompareRow]


def _normalize_product_name(name: str) -> str:
    normalized = name.strip()
    if not normalized:
        raise ValueError("Product name is required")
    return normalized


def _normalize_product_lifecycle_status(value: str | None) -> str:
    normalized = (value or PRODUCT_LIFECYCLE_ACTIVE).strip().lower()
    if normalized not in PRODUCT_LIFECYCLE_OPTIONS:
        raise ValueError("Invalid lifecycle status")
    return normalized


def _normalize_revision_lifecycle_status(value: str | None) -> str:
    normalized = (value or PRODUCT_LIFECYCLE_DRAFT).strip().lower()
    if normalized not in PRODUCT_REVISION_LIFECYCLE_OPTIONS:
        raise ValueError("Invalid revision lifecycle status")
    return normalized


_LINK_VALUE_PATTERN = re.compile(
    r"^(https?://|\\\\|[A-Za-z]:[/\\])",
    re.IGNORECASE,
)


def _validate_link_value(value: str) -> None:
    if value and not _LINK_VALUE_PATTERN.match(value):
        raise ValueError(
            f"Link 参数值格式无效，必须以 http://、https://、\\\\（UNC）或盘符路径（如 C:\\）开头：{value!r}"
        )


def _normalize_parameter_items(items: list[tuple[str, str, str, str]]) -> list[dict[str, object]]:
    normalized_items: list[dict[str, object]] = []
    key_set: set[str] = set()
    for index, (name, category, parameter_type, value) in enumerate(items, start=1):
        normalized_name = name.strip()
        normalized_category = category.strip()
        normalized_type = parameter_type.strip()
        normalized_value = value.strip()

        if not normalized_name:
            raise ValueError("Parameter name is required")
        if not normalized_category:
            raise ValueError("Parameter category is required")
        if normalized_type not in ALLOWED_PARAMETER_TYPES:
            raise ValueError(f"Invalid parameter type: {normalized_type}")
        if normalized_name in key_set:
            raise ValueError(f"Duplicate parameter name: {normalized_name}")
        if normalized_type == "Link":
            _validate_link_value(normalized_value)

        key_set.add(normalized_name)
        normalized_items.append(
            {
                "name": normalized_name,
                "category": normalized_category,
                "type": normalized_type,
                "value": normalized_value,
                "sort_order": index,
                "is_preset": normalized_name in PRODUCT_PARAMETER_TEMPLATE_NAME_SET,
            }
        )
    return normalized_items


def _parameter_compare_value(item: dict[str, object]) -> str:
    return (
        f"分类={item['category']};"
        f"类型={item['type']};"
        f"值={item['value']};"
        f"排序={item['sort_order']};"
        f"预置={'是' if bool(item['is_preset']) else '否'}"
    )


def _snapshot_signature(payload: dict[str, object]) -> str:
    return json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _build_snapshot_payload(
    *,
    product_name: str,
    parameters: list[ProductParameter],
) -> dict[str, object]:
    return {
        "name": product_name,
        "parameters": [
            {
                "name": row.param_key,
                "category": row.param_category,
                "type": row.param_type,
                "value": row.param_value,
                "sort_order": row.sort_order,
                "is_preset": row.is_preset,
            }
            for row in parameters
        ],
    }


def _normalize_snapshot_payload(payload: dict[str, object]) -> dict[str, object]:
    product_name = _normalize_product_name(str(payload.get("name") or ""))
    raw_parameters = payload.get("parameters")
    if not isinstance(raw_parameters, list):
        raise ValueError("Invalid revision snapshot")

    tuples: list[tuple[str, str, str, str]] = []
    for raw_item in raw_parameters:
        if not isinstance(raw_item, dict):
            raise ValueError("Invalid revision snapshot")
        tuples.append(
            (
                str(raw_item.get("name") or ""),
                str(raw_item.get("category") or ""),
                str(raw_item.get("type") or ""),
                str(raw_item.get("value") or ""),
            )
        )

    normalized_parameters = _normalize_parameter_items(tuples)
    by_name = {str(item["name"]): item for item in normalized_parameters}
    name_parameter = by_name.get(PRODUCT_NAME_PARAMETER_KEY)
    if name_parameter is None:
        raise ValueError("Invalid revision snapshot: product name parameter missing")
    name_parameter["category"] = PRODUCT_NAME_PARAMETER_CATEGORY
    name_parameter["type"] = PRODUCT_NAME_PARAMETER_TYPE
    name_parameter["value"] = product_name

    return {
        "name": product_name,
        "parameters": normalized_parameters,
    }


def _parse_revision_snapshot(row: ProductRevision) -> dict[str, object]:
    try:
        raw_payload = json.loads(row.snapshot_json)
    except (TypeError, ValueError) as error:
        raise ValueError("Invalid revision snapshot") from error
    if not isinstance(raw_payload, dict):
        raise ValueError("Invalid revision snapshot")
    return _normalize_snapshot_payload(raw_payload)


def _calculate_changed_keys(
    *,
    current_parameters: list[ProductParameter],
    next_items: list[dict[str, object]],
) -> list[str]:
    current_by_name = {item.param_key: item for item in current_parameters}
    current_order = [item.param_key for item in current_parameters]
    next_order = [str(item["name"]) for item in next_items]
    next_by_name = {str(item["name"]): item for item in next_items}

    current_name_set = set(current_by_name.keys())
    next_name_set = set(next_by_name.keys())
    changed_name_set: set[str] = set()

    changed_name_set.update(current_name_set - next_name_set)
    changed_name_set.update(next_name_set - current_name_set)

    for name in current_name_set & next_name_set:
        existing = current_by_name[name]
        next_item = next_by_name[name]
        if (
            existing.param_category != next_item["category"]
            or existing.param_type != next_item["type"]
            or existing.param_value != next_item["value"]
            or existing.sort_order != next_item["sort_order"]
            or existing.is_preset != next_item["is_preset"]
        ):
            changed_name_set.add(name)

    max_count = max(len(current_order), len(next_order))
    for index in range(max_count):
        current_name = current_order[index] if index < len(current_order) else None
        next_name = next_order[index] if index < len(next_order) else None
        if current_name == next_name:
            continue
        if current_name is not None:
            changed_name_set.add(current_name)
        if next_name is not None:
            changed_name_set.add(next_name)

    return sorted(changed_name_set)


def summarize_changed_keys(changed_keys: list[str], *, max_count: int = 3) -> str | None:
    if not changed_keys:
        return None
    preview = changed_keys[:max_count]
    if len(changed_keys) <= max_count:
        return ", ".join(preview)
    return f"{', '.join(preview)} (+{len(changed_keys) - max_count})"


def get_product_by_id(db: Session, product_id: int) -> Product | None:
    stmt = select(Product).where(Product.id == product_id, Product.is_deleted.is_(False))
    return db.execute(stmt).scalars().first()


def get_product_by_name(db: Session, name: str) -> Product | None:
    stmt = select(Product).where(Product.name == name, Product.is_deleted.is_(False))
    return db.execute(stmt).scalars().first()


def list_products(
    db: Session,
    page: int,
    page_size: int,
    keyword: str | None,
    category: str | None,
    lifecycle_status: str | None = None,
    has_effective_version: bool | None = None,
    updated_after: datetime | None = None,
    updated_before: datetime | None = None,
) -> tuple[int, list[Product], dict[int, ProductParameterHistory]]:
    stmt = select(Product).where(Product.is_deleted.is_(False)).order_by(Product.updated_at.desc())
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(Product.name.ilike(like_pattern))
    if category is not None and category != "":
        stmt = stmt.where(Product.category == category)
    if lifecycle_status is not None and lifecycle_status != "":
        stmt = stmt.where(Product.lifecycle_status == lifecycle_status)
    if has_effective_version is True:
        stmt = stmt.where(Product.effective_version > 0)
    elif has_effective_version is False:
        stmt = stmt.where(Product.effective_version == 0)
    if updated_after is not None:
        stmt = stmt.where(Product.updated_at >= updated_after)
    if updated_before is not None:
        stmt = stmt.where(Product.updated_at <= updated_before)

    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    paged_stmt = stmt.offset(offset).limit(page_size)
    products = db.execute(paged_stmt).scalars().all()

    history_map = get_latest_history_map_by_product_ids(db, [product.id for product in products])
    return total, products, history_map


def _clone_default_craft_template_for_new_product(
    db: Session,
    *,
    product: Product,
    operator: User,
) -> None:
    existing_enabled_template_id = (
        db.execute(
            select(ProductProcessTemplate.id).where(
                ProductProcessTemplate.product_id == product.id,
                ProductProcessTemplate.is_enabled.is_(True),
                ProductProcessTemplate.lifecycle_status == "published",
            )
        )
        .scalars()
        .first()
    )
    if existing_enabled_template_id is not None:
        logger.warning(
            "Skip auto bind default process template: product_id=%s already has enabled template_id=%s",
            product.id,
            existing_enabled_template_id,
        )
        return

    source_result = resolve_system_master_template(db)
    if source_result.template is None:
        if source_result.skip_reason:
            logger.info(
                "Skip auto bind default process template: product_id=%s reason=%s",
                product.id,
                source_result.skip_reason,
            )
        return

    source_template = source_result.template
    source_steps = sorted(source_template.steps, key=lambda item: (item.step_order, item.id))
    if not source_steps:
        logger.warning(
            "Skip auto bind default process template: product_id=%s system_master_template_id=%s has no steps",
            product.id,
            source_template.id,
        )
        return

    row = ProductProcessTemplate(
        product_id=product.id,
        template_name="默认模板",
        version=1,
        lifecycle_status="published",
        published_version=1,
        is_default=True,
        is_enabled=True,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
    )
    db.add(row)
    db.flush()
    for step in source_steps:
        row.steps.append(
            ProductProcessTemplateStep(
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
            )
        )
    db.flush()

    enabled_rows = db.execute(
        select(ProductProcessTemplate).where(
            ProductProcessTemplate.product_id == product.id,
            ProductProcessTemplate.is_enabled.is_(True),
            ProductProcessTemplate.lifecycle_status == "published",
        )
    ).scalars().all()
    for item in enabled_rows:
        item.is_default = item.id == row.id

    logger.info(
        "Auto bound default process template for product_id=%s from system_master_template_id=%s to template_id=%s",
        product.id,
        source_template.id,
        row.id,
    )


def _create_product_revision_snapshot(
    db: Session,
    *,
    product: Product,
    lifecycle_status: str,
    action: str,
    note: str | None,
    operator: User,
    source_revision_id: int | None = None,
    version_label: str | None = None,
) -> ProductRevision:
    parameters = list_product_parameters(db, product.id)
    payload = _build_snapshot_payload(product_name=product.name, parameters=parameters)
    row = ProductRevision(
        product_id=product.id,
        version=product.current_version,
        version_label=version_label or f"V1.{product.current_version - 1}",
        lifecycle_status=_normalize_revision_lifecycle_status(lifecycle_status),
        action=action,
        note=(note or "").strip() or None,
        source_revision_id=source_revision_id,
        snapshot_json=_snapshot_signature(payload),
        created_by_user_id=operator.id,
    )
    db.add(row)
    db.flush()
    return row


def _replace_effective_revision(
    db: Session,
    *,
    product: Product,
    effective_version: int,
) -> None:
    for row in db.execute(
        select(ProductRevision).where(ProductRevision.product_id == product.id)
    ).scalars():
        if row.version == effective_version:
            row.lifecycle_status = PRODUCT_LIFECYCLE_EFFECTIVE
        elif row.lifecycle_status in {
            PRODUCT_LIFECYCLE_EFFECTIVE,
            PRODUCT_LIFECYCLE_INACTIVE,
        }:
            row.lifecycle_status = PRODUCT_LIFECYCLE_OBSOLETE


def _mark_revision_inactive(
    db: Session,
    *,
    product: Product,
    revision_version: int,
) -> None:
    row = get_product_version(db, product_id=product.id, version=revision_version)
    if row is not None:
        row.lifecycle_status = PRODUCT_LIFECYCLE_INACTIVE


def create_product(
    db: Session,
    name: str,
    *,
    category: str = "",
    remark: str = "",
    operator: User,
) -> Product:
    normalized_name = _normalize_product_name(name)
    product = Product(
        name=normalized_name,
        category=category,
        remark=(remark or "").strip(),
        parameter_template_initialized=True,
        lifecycle_status=PRODUCT_LIFECYCLE_ACTIVE,
        current_version=1,
        effective_version=0,
        effective_at=None,
        inactive_reason=None,
    )
    db.add(product)
    db.flush()

    for template in PRODUCT_PARAMETER_TEMPLATE:
        db.add(
            ProductParameter(
                product_id=product.id,
                param_key=template.name,
                param_category=template.category,
                param_type=template.parameter_type,
                param_value=(
                    normalized_name
                    if template.name == PRODUCT_NAME_PARAMETER_KEY
                    else ""
                ),
                sort_order=template.sort_order,
                is_preset=True,
            )
        )
    db.flush()

    _create_product_revision_snapshot(
        db,
        product=product,
        lifecycle_status=PRODUCT_LIFECYCLE_DRAFT,
        action="create",
        note="Initial draft V1.0",
        operator=operator,
        version_label="V1.0",
    )

    _clone_default_craft_template_for_new_product(
        db,
        product=product,
        operator=operator,
    )

    db.commit()
    db.refresh(product)
    return product


def delete_product(db: Session, product: Product) -> None:
    product.is_deleted = True
    db.commit()


def ensure_product_parameter_template_initialized(db: Session, product: Product) -> bool:
    # Always keep the key product-name parameter aligned, even when template is initialized.
    if product.parameter_template_initialized:
        parameters = list_product_parameters(db, product.id)
        product_name_parameter = next(
            (
                item
                for item in parameters
                if item.param_key == PRODUCT_NAME_PARAMETER_KEY
            ),
            None,
        )
        changed = False
        if product_name_parameter is None:
            db.add(
                ProductParameter(
                    product_id=product.id,
                    param_key=PRODUCT_NAME_PARAMETER_KEY,
                    param_category=PRODUCT_NAME_PARAMETER_CATEGORY,
                    param_type=PRODUCT_NAME_PARAMETER_TYPE,
                    param_value=product.name,
                    sort_order=1,
                    is_preset=True,
                )
            )
            changed = True
        else:
            if (
                product_name_parameter.param_category
                != PRODUCT_NAME_PARAMETER_CATEGORY
            ):
                product_name_parameter.param_category = (
                    PRODUCT_NAME_PARAMETER_CATEGORY
                )
                changed = True
            if product_name_parameter.param_type != PRODUCT_NAME_PARAMETER_TYPE:
                product_name_parameter.param_type = PRODUCT_NAME_PARAMETER_TYPE
                changed = True
            if product_name_parameter.param_value != product.name:
                product_name_parameter.param_value = product.name
                changed = True
            if not product_name_parameter.is_preset:
                product_name_parameter.is_preset = True
                changed = True

        if changed:
            db.commit()
            db.refresh(product)
        return changed

    parameters = list_product_parameters(db, product.id)
    current_by_key = {item.param_key: item for item in parameters}

    for template in PRODUCT_PARAMETER_TEMPLATE:
        existing = current_by_key.get(template.name)
        if existing is None:
            db.add(
                ProductParameter(
                    product_id=product.id,
                    param_key=template.name,
                    param_category=template.category,
                    param_type=template.parameter_type,
                    param_value=(
                        product.name
                        if template.name == PRODUCT_NAME_PARAMETER_KEY
                        else ""
                    ),
                    sort_order=template.sort_order,
                    is_preset=True,
                )
            )
            continue

        existing.param_category = template.category
        existing.param_type = template.parameter_type
        existing.sort_order = template.sort_order
        existing.is_preset = True
        if template.name == PRODUCT_NAME_PARAMETER_KEY:
            existing.param_value = product.name

    next_sort_order = len(PRODUCT_PARAMETER_TEMPLATE) + 1
    for parameter in parameters:
        if parameter.param_key in PRODUCT_PARAMETER_TEMPLATE_NAME_SET:
            continue
        parameter.sort_order = next_sort_order
        parameter.is_preset = False
        if not parameter.param_category.strip():
            parameter.param_category = "自定义参数"
        if parameter.param_type not in ALLOWED_PARAMETER_TYPES:
            parameter.param_type = PARAMETER_TYPE_TEXT
        next_sort_order += 1

    product.parameter_template_initialized = True
    db.commit()
    db.refresh(product)
    return True


def list_product_parameters(db: Session, product_id: int) -> list[ProductParameter]:
    stmt = (
        select(ProductParameter)
        .where(ProductParameter.product_id == product_id)
        .order_by(ProductParameter.sort_order.asc(), ProductParameter.id.asc())
    )
    return db.execute(stmt).scalars().all()


def _list_open_orders_for_product(db: Session, *, product_id: int) -> list[ProductionOrder]:
    return (
        db.execute(
            select(ProductionOrder)
            .where(
                ProductionOrder.product_id == product_id,
                ProductionOrder.status.in_([ORDER_STATUS_PENDING, ORDER_STATUS_IN_PROGRESS]),
            )
            .order_by(ProductionOrder.id.asc())
        )
        .scalars()
        .all()
    )


def analyze_product_impact(
    db: Session,
    *,
    product: Product,
    operation: str,
    target_status: str | None = None,
    target_version: int | None = None,
) -> ProductImpactResult:
    normalized_operation = (operation or "").strip().lower()
    if normalized_operation not in {"update_parameters", "lifecycle", "rollback"}:
        raise ValueError("Invalid operation")

    normalized_target_status = None
    if target_status is not None:
        normalized_target_status = _normalize_product_lifecycle_status(target_status)

    open_orders = _list_open_orders_for_product(db, product_id=product.id)
    pending_orders = sum(1 for row in open_orders if row.status == ORDER_STATUS_PENDING)
    in_progress_orders = sum(1 for row in open_orders if row.status == ORDER_STATUS_IN_PROGRESS)

    requires_confirmation = False
    reason_text: str | None = None
    if normalized_operation == "update_parameters":
        requires_confirmation = (
            product.lifecycle_status == PRODUCT_LIFECYCLE_ACTIVE and len(open_orders) > 0
        )
        if requires_confirmation:
            reason_text = "Active product has unfinished orders"
    elif normalized_operation == "lifecycle":
        if normalized_target_status is None:
            raise ValueError("target_status is required for lifecycle impact analysis")
        requires_confirmation = (
            normalized_target_status == PRODUCT_LIFECYCLE_INACTIVE and len(open_orders) > 0
        )
        if requires_confirmation:
            reason_text = "Inactive transition affects unfinished orders"
    elif normalized_operation == "rollback":
        requires_confirmation = len(open_orders) > 0
        if requires_confirmation:
            reason_text = "Rollback affects unfinished orders"

    items = [
        ProductImpactOrder(
            order_id=row.id,
            order_code=row.order_code,
            order_status=row.status,
            reason=reason_text,
        )
        for row in open_orders
    ]
    return ProductImpactResult(
        operation=normalized_operation,
        target_status=normalized_target_status,
        target_version=target_version,
        total_orders=len(open_orders),
        pending_orders=pending_orders,
        in_progress_orders=in_progress_orders,
        requires_confirmation=requires_confirmation,
        items=items,
    )


def update_product_parameters(
    db: Session,
    *,
    product: Product,
    items: list[tuple[str, str, str, str, str]],
    remark: str,
    operator: User,
    confirmed: bool = False,
) -> list[str]:
    normalized_remark = remark.strip()
    if not normalized_remark:
        raise ValueError("Remark is required")

    impact = analyze_product_impact(
        db,
        product=product,
        operation="update_parameters",
    )
    if impact.requires_confirmation and not confirmed:
        raise ValueError("Impact confirmation required before updating active product")

    normalized_items = _normalize_parameter_items([(name, cat, ptype, val) for name, cat, ptype, val, _desc in items])
    description_map = {name.strip(): desc.strip() for name, _cat, _ptype, _val, desc in items}
    normalized_by_name = {
        str(item["name"]): item
        for item in normalized_items
    }
    product_name_item = normalized_by_name.get(PRODUCT_NAME_PARAMETER_KEY)
    if product_name_item is None:
        raise ValueError("Product name parameter cannot be deleted")
    product_name_item["category"] = PRODUCT_NAME_PARAMETER_CATEGORY
    product_name_item["type"] = PRODUCT_NAME_PARAMETER_TYPE
    candidate_product_name = _normalize_product_name(str(product_name_item["value"]))
    product_name_item["value"] = candidate_product_name

    existing_product = get_product_by_name(db, candidate_product_name)
    if existing_product and existing_product.id != product.id:
        raise ValueError("Product name already exists")

    current_parameters = list_product_parameters(db, product.id)
    changed_keys = _calculate_changed_keys(
        current_parameters=current_parameters,
        next_items=normalized_items,
    )
    if not changed_keys:
        raise ValueError("No parameter changes detected")

    before_snapshot = _snapshot_signature(
        _build_snapshot_payload(product_name=product.name, parameters=current_parameters)
    )

    db.execute(delete(ProductParameter).where(ProductParameter.product_id == product.id))

    for item in normalized_items:
        item_name = str(item["name"])
        db.add(
            ProductParameter(
                product_id=product.id,
                param_key=item_name,
                param_category=str(item["category"]),
                param_type=str(item["type"]),
                param_value=str(item["value"]),
                param_description=description_map.get(item_name, ""),
                sort_order=int(item["sort_order"]),
                is_preset=bool(item["is_preset"]),
            )
        )

    after_snapshot = _snapshot_signature(
        {"name": candidate_product_name, "parameters": normalized_items}
    )
    db.add(
        ProductParameterHistory(
            product_id=product.id,
            operator_user_id=operator.id,
            operator_username=operator.username,
            remark=normalized_remark,
            change_type="edit",
            changed_keys=changed_keys,
            before_snapshot=before_snapshot,
            after_snapshot=after_snapshot,
        )
    )
    product.name = candidate_product_name
    product.updated_at = datetime.now(UTC)
    product.current_version = max(product.current_version, 0) + 1
    revision_status = PRODUCT_LIFECYCLE_DRAFT
    if product.lifecycle_status == PRODUCT_LIFECYCLE_ACTIVE:
        product.effective_version = product.current_version
        product.effective_at = datetime.now(UTC)
        revision_status = PRODUCT_LIFECYCLE_EFFECTIVE
    db.flush()
    revision = _create_product_revision_snapshot(
        db,
        product=product,
        lifecycle_status=revision_status,
        action="update_parameters",
        note=normalized_remark,
        operator=operator,
    )
    if revision.lifecycle_status == PRODUCT_LIFECYCLE_EFFECTIVE:
        _replace_effective_revision(
            db,
            product=product,
            effective_version=revision.version,
        )

    db.commit()
    return changed_keys


def change_product_lifecycle(
    db: Session,
    *,
    product: Product,
    target_status: str,
    confirmed: bool,
    note: str | None,
    inactive_reason: str | None,
    operator: User,
) -> Product:
    del note  # reserved for future audit expansion.
    del operator  # lifecycle transition currently does not create a separate revision row.

    normalized_target_status = _normalize_product_lifecycle_status(target_status)
    current_status = _normalize_product_lifecycle_status(product.lifecycle_status)

    if normalized_target_status == current_status:
        raise ValueError("Product is already in target status")

    allowed_targets = PRODUCT_LIFECYCLE_TRANSITIONS.get(current_status, set())
    if normalized_target_status not in allowed_targets:
        raise ValueError(
            f"Lifecycle transition not allowed: {current_status} -> {normalized_target_status}"
        )

    impact = analyze_product_impact(
        db,
        product=product,
        operation="lifecycle",
        target_status=normalized_target_status,
    )
    if impact.requires_confirmation and not confirmed:
        raise ValueError("Impact confirmation required before changing lifecycle")

    normalized_reason = (inactive_reason or "").strip() or None
    if normalized_target_status == PRODUCT_LIFECYCLE_INACTIVE and not normalized_reason:
        raise ValueError("inactive_reason is required when target_status is inactive")

    product.lifecycle_status = normalized_target_status
    if normalized_target_status == PRODUCT_LIFECYCLE_ACTIVE:
        product.effective_version = max(product.current_version, 1)
        product.effective_at = datetime.now(UTC)
        product.inactive_reason = None
        _replace_effective_revision(
            db,
            product=product,
            effective_version=product.effective_version,
        )
    else:
        product.inactive_reason = normalized_reason
        _mark_revision_inactive(
            db,
            product=product,
            revision_version=max(product.effective_version, 1),
        )

    product.updated_at = datetime.now(UTC)
    db.commit()
    db.refresh(product)
    return product


def list_product_versions(db: Session, *, product_id: int) -> list[ProductRevision]:
    return (
        db.execute(
            select(ProductRevision)
            .where(ProductRevision.product_id == product_id)
            .options(
                selectinload(ProductRevision.created_by),
                selectinload(ProductRevision.source_revision),
            )
            .order_by(ProductRevision.version.desc(), ProductRevision.id.desc())
        )
        .scalars()
        .all()
    )


def get_product_version(db: Session, *, product_id: int, version: int) -> ProductRevision | None:
    return (
        db.execute(
            select(ProductRevision)
            .where(
                ProductRevision.product_id == product_id,
                ProductRevision.version == version,
            )
            .options(
                selectinload(ProductRevision.created_by),
                selectinload(ProductRevision.source_revision),
            )
        )
        .scalars()
        .first()
    )


def get_draft_revision(db: Session, *, product_id: int) -> ProductRevision | None:
    return (
        db.execute(
            select(ProductRevision)
            .where(
                ProductRevision.product_id == product_id,
                ProductRevision.lifecycle_status == PRODUCT_LIFECYCLE_DRAFT,
            )
        )
        .scalars()
        .first()
    )


def _next_version_label(db: Session, product_id: int) -> str:
    labels = db.execute(
        select(ProductRevision.version_label).where(ProductRevision.product_id == product_id)
    ).scalars().all()
    max_minor = -1
    for label in labels:
        if label and label.startswith("V1."):
            try:
                minor = int(label[3:])
                max_minor = max(max_minor, minor)
            except ValueError:
                pass
    return f"V1.{max_minor + 1}"


def create_product_version(
    db: Session,
    *,
    product: Product,
    operator: User,
) -> ProductRevision:
    existing_draft = get_draft_revision(db, product_id=product.id)
    if existing_draft is not None:
        raise ValueError(
            f"已存在草稿版本 {existing_draft.version_label}，请先完成或删除当前草稿后再新建版本"
        )

    version_label = _next_version_label(db, product.id)
    next_version = max(product.current_version, 0) + 1
    product.current_version = next_version
    db.flush()

    revision = _create_product_revision_snapshot(
        db,
        product=product,
        lifecycle_status=PRODUCT_LIFECYCLE_DRAFT,
        action="create",
        note=None,
        operator=operator,
        version_label=version_label,
    )
    db.commit()
    db.refresh(revision)
    return revision


def copy_product_version(
    db: Session,
    *,
    product: Product,
    source_version: int,
    operator: User,
) -> ProductRevision:
    existing_draft = get_draft_revision(db, product_id=product.id)
    if existing_draft is not None:
        raise ValueError(
            f"已存在草稿版本 {existing_draft.version_label}，请先完成或删除当前草稿后再复制版本"
        )

    source = get_product_version(db, product_id=product.id, version=source_version)
    if source is None:
        raise ValueError("来源版本不存在")

    version_label = _next_version_label(db, product.id)
    next_version = max(product.current_version, 0) + 1
    product.current_version = next_version

    # Restore source snapshot to current parameters
    source_snapshot = _parse_revision_snapshot(source)
    db.execute(delete(ProductParameter).where(ProductParameter.product_id == product.id))
    for item in source_snapshot["parameters"]:
        item_dict = dict(item)
        db.add(
            ProductParameter(
                product_id=product.id,
                param_key=str(item_dict["name"]),
                param_category=str(item_dict["category"]),
                param_type=str(item_dict["type"]),
                param_value=str(item_dict["value"]),
                sort_order=int(item_dict["sort_order"]),
                is_preset=bool(item_dict["is_preset"]),
            )
        )
    db.flush()

    revision = _create_product_revision_snapshot(
        db,
        product=product,
        lifecycle_status=PRODUCT_LIFECYCLE_DRAFT,
        action="copy",
        note=f"Copied from {source.version_label}",
        operator=operator,
        source_revision_id=source.id,
        version_label=version_label,
    )
    db.commit()
    db.refresh(revision)
    return revision


def activate_product_version(
    db: Session,
    *,
    product: Product,
    version: int,
    confirmed: bool,
    operator: User,
) -> ProductRevision:
    revision = get_product_version(db, product_id=product.id, version=version)
    if revision is None:
        raise ValueError("版本不存在")
    if revision.lifecycle_status != PRODUCT_LIFECYCLE_DRAFT:
        raise ValueError("只有草稿版本可以生效")
    if product.lifecycle_status != PRODUCT_LIFECYCLE_ACTIVE:
        raise ValueError("产品必须处于启用状态才能生效版本")

    # Check version has parameters
    try:
        snapshot = _parse_revision_snapshot(revision)
    except ValueError as error:
        raise ValueError(f"版本参数快照无效: {error}") from error
    if not snapshot.get("parameters"):
        raise ValueError("版本下至少需要一条参数记录才能生效")

    impact = analyze_product_impact(
        db,
        product=product,
        operation="lifecycle",
        target_status=PRODUCT_LIFECYCLE_ACTIVE,
    )
    if impact.requires_confirmation and not confirmed:
        raise ValueError("存在未完成工单，请确认后再生效")

    # Mark previous effective as obsolete
    for row in db.execute(
        select(ProductRevision).where(ProductRevision.product_id == product.id)
    ).scalars():
        if row.id != revision.id and row.lifecycle_status == PRODUCT_LIFECYCLE_EFFECTIVE:
            row.lifecycle_status = PRODUCT_LIFECYCLE_OBSOLETE

    revision.lifecycle_status = PRODUCT_LIFECYCLE_EFFECTIVE
    product.effective_version = version
    product.effective_at = datetime.now(UTC)
    product.updated_at = datetime.now(UTC)

    db.commit()
    db.refresh(revision)
    return revision


def disable_product_version(
    db: Session,
    *,
    product: Product,
    version: int,
    operator: User,
) -> ProductRevision:
    revision = get_product_version(db, product_id=product.id, version=version)
    if revision is None:
        raise ValueError("版本不存在")
    if revision.lifecycle_status not in {PRODUCT_LIFECYCLE_EFFECTIVE, PRODUCT_LIFECYCLE_OBSOLETE}:
        raise ValueError("只有已生效或已失效的版本可以停用")

    revision.lifecycle_status = PRODUCT_LIFECYCLE_DISABLED
    if product.effective_version == version:
        product.effective_version = 0
        product.effective_at = None
    product.updated_at = datetime.now(UTC)

    db.commit()
    db.refresh(revision)
    return revision


def update_product_version_note(
    db: Session,
    *,
    product_id: int,
    version: int,
    note: str,
) -> ProductRevision:
    revision = get_product_version(db, product_id=product_id, version=version)
    if revision is None:
        raise ValueError("版本不存在")
    revision.note = note.strip() or None
    db.commit()
    db.refresh(revision)
    return revision


def delete_product_version(
    db: Session,
    *,
    product: Product,
    version: int,
    operator: User,
) -> None:
    revision = get_product_version(db, product_id=product.id, version=version)
    if revision is None:
        raise ValueError("版本不存在")
    if revision.lifecycle_status != PRODUCT_LIFECYCLE_DRAFT:
        raise ValueError("只有草稿版本可以删除")

    # Ensure at least one non-draft revision remains
    other_revisions = db.execute(
        select(ProductRevision).where(
            ProductRevision.product_id == product.id,
            ProductRevision.id != revision.id,
        )
    ).scalars().all()
    if not other_revisions:
        raise ValueError("产品至少需要保留一个版本记录，无法删除唯一版本")

    db.delete(revision)
    db.commit()


def compare_product_versions(
    db: Session,
    *,
    product: Product,
    from_version: int,
    to_version: int,
) -> ProductVersionCompareResult:
    from_row = get_product_version(db, product_id=product.id, version=from_version)
    to_row = get_product_version(db, product_id=product.id, version=to_version)
    if from_row is None or to_row is None:
        raise ValueError("Product version not found")

    from_snapshot = _parse_revision_snapshot(from_row)
    to_snapshot = _parse_revision_snapshot(to_row)

    from_map: dict[str, str] = {
        "产品名称": str(from_snapshot["name"]),
    }
    to_map: dict[str, str] = {
        "产品名称": str(to_snapshot["name"]),
    }

    for item in from_snapshot["parameters"]:
        item_dict = dict(item)
        from_map[f"参数:{item_dict['name']}"] = _parameter_compare_value(item_dict)
    for item in to_snapshot["parameters"]:
        item_dict = dict(item)
        to_map[f"参数:{item_dict['name']}"] = _parameter_compare_value(item_dict)

    all_keys = sorted(set(from_map.keys()) | set(to_map.keys()))
    rows: list[ProductVersionCompareRow] = []
    added = 0
    removed = 0
    changed = 0

    for key in all_keys:
        from_value = from_map.get(key)
        to_value = to_map.get(key)
        if from_value is None:
            added += 1
            rows.append(
                ProductVersionCompareRow(
                    key=key,
                    diff_type="added",
                    from_value=None,
                    to_value=to_value,
                )
            )
            continue
        if to_value is None:
            removed += 1
            rows.append(
                ProductVersionCompareRow(
                    key=key,
                    diff_type="removed",
                    from_value=from_value,
                    to_value=None,
                )
            )
            continue
        if from_value != to_value:
            changed += 1
            rows.append(
                ProductVersionCompareRow(
                    key=key,
                    diff_type="changed",
                    from_value=from_value,
                    to_value=to_value,
                )
            )

    return ProductVersionCompareResult(
        from_version=from_version,
        to_version=to_version,
        added_items=added,
        removed_items=removed,
        changed_items=changed,
        items=rows,
    )


def rollback_product_to_version(
    db: Session,
    *,
    product: Product,
    target_version: int,
    confirmed: bool,
    note: str | None,
    operator: User,
) -> list[str]:
    target_revision = get_product_version(db, product_id=product.id, version=target_version)
    if target_revision is None:
        raise ValueError("Target version not found")

    impact = analyze_product_impact(
        db,
        product=product,
        operation="rollback",
        target_version=target_version,
    )
    if impact.requires_confirmation and not confirmed:
        raise ValueError("Impact confirmation required before rollback")

    target_snapshot = _parse_revision_snapshot(target_revision)
    current_parameters = list_product_parameters(db, product.id)
    current_snapshot = _build_snapshot_payload(
        product_name=product.name,
        parameters=current_parameters,
    )
    if _snapshot_signature(current_snapshot) == _snapshot_signature(target_snapshot):
        raise ValueError("Selected version is identical to current state")

    candidate_name = _normalize_product_name(str(target_snapshot["name"]))
    existing_product = get_product_by_name(db, candidate_name)
    if existing_product and existing_product.id != product.id:
        raise ValueError("Product name already exists")

    next_items = [dict(item) for item in target_snapshot["parameters"]]
    changed_keys = _calculate_changed_keys(
        current_parameters=current_parameters,
        next_items=next_items,
    )

    before_snapshot = _snapshot_signature(current_snapshot)

    db.execute(delete(ProductParameter).where(ProductParameter.product_id == product.id))
    for item in next_items:
        db.add(
            ProductParameter(
                product_id=product.id,
                param_key=str(item["name"]),
                param_category=str(item["category"]),
                param_type=str(item["type"]),
                param_value=str(item["value"]),
                sort_order=int(item["sort_order"]),
                is_preset=bool(item["is_preset"]),
            )
        )

    after_snapshot = _snapshot_signature(target_snapshot)
    product.name = candidate_name
    product.updated_at = datetime.now(UTC)
    product.current_version = max(product.current_version, 0) + 1
    revision_status = PRODUCT_LIFECYCLE_DRAFT
    if product.lifecycle_status == PRODUCT_LIFECYCLE_ACTIVE:
        product.effective_version = product.current_version
        product.effective_at = datetime.now(UTC)
        revision_status = PRODUCT_LIFECYCLE_EFFECTIVE

    rollback_note = (note or "").strip() or f"Rollback to v{target_version}"
    db.add(
        ProductParameterHistory(
            product_id=product.id,
            operator_user_id=operator.id,
            operator_username=operator.username,
            remark=rollback_note,
            change_type="rollback",
            changed_keys=changed_keys,
            before_snapshot=before_snapshot,
            after_snapshot=after_snapshot,
        )
    )
    db.flush()
    revision = _create_product_revision_snapshot(
        db,
        product=product,
        lifecycle_status=revision_status,
        action="rollback",
        note=rollback_note,
        operator=operator,
        source_revision_id=target_revision.id,
    )
    if revision.lifecycle_status == PRODUCT_LIFECYCLE_EFFECTIVE:
        _replace_effective_revision(
            db,
            product=product,
            effective_version=revision.version,
        )

    db.commit()
    return changed_keys


def list_parameter_history(
    db: Session,
    *,
    product_id: int,
    page: int,
    page_size: int,
) -> tuple[int, list[ProductParameterHistory]]:
    stmt = (
        select(ProductParameterHistory)
        .where(ProductParameterHistory.product_id == product_id)
        .order_by(
            ProductParameterHistory.created_at.desc(),
            ProductParameterHistory.id.desc(),
        )
    )
    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()
    offset = (page - 1) * page_size
    rows = db.execute(stmt.offset(offset).limit(page_size)).scalars().all()
    return total, rows


def get_latest_history_map_by_product_ids(
    db: Session,
    product_ids: list[int],
) -> dict[int, ProductParameterHistory]:
    if not product_ids:
        return {}
    stmt = (
        select(ProductParameterHistory)
        .where(ProductParameterHistory.product_id.in_(product_ids))
        .order_by(
            ProductParameterHistory.product_id.asc(),
            ProductParameterHistory.created_at.desc(),
            ProductParameterHistory.id.desc(),
        )
    )
    rows = db.execute(stmt).scalars().all()
    latest_map: dict[int, ProductParameterHistory] = {}
    for row in rows:
        if row.product_id not in latest_map:
            latest_map[row.product_id] = row
    return latest_map
