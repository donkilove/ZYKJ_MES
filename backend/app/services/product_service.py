from __future__ import annotations

import re
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
import json
import logging

from sqlalchemy import delete, func, select, tuple_
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
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
    VALID_PRODUCT_PARAMETER_CATEGORY_SET,
)
from app.core.production_constants import ORDER_STATUS_IN_PROGRESS, ORDER_STATUS_PENDING
from app.models.product import Product
from app.models.product_parameter import ProductParameter
from app.models.product_parameter_history import ProductParameterHistory
from app.models.product_revision_parameter import ProductRevisionParameter
from app.models.product_process_template import ProductProcessTemplate
from app.models.product_process_template_step import ProductProcessTemplateStep
from app.models.product_revision import ProductRevision
from app.models.first_article_record import FirstArticleRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.repair_cause import RepairCause
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
from app.models.repair_order import RepairOrder
from app.models.user import User
from app.services.craft_service import resolve_system_master_template


logger = logging.getLogger(__name__)


NO_EFFECTIVE_VERSION_INACTIVE_REASON = (
    "当前无生效版本，请前往版本管理生效版本后恢复启用"
)


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


@dataclass(slots=True)
class ProductParameterVersionListRow:
    product: Product
    revision: ProductRevision
    parameter_summary: str | None
    parameter_count: int
    matched_parameter_name: str | None
    matched_parameter_category: str | None
    last_modified_parameter: str | None
    last_modified_parameter_category: str | None


def _format_version_label(version: int) -> str:
    return f"V1.{version - 1}" if version > 0 else "-"


def _normalize_product_name(name: str) -> str:
    normalized = name.strip()
    if not normalized:
        raise ValueError("Product name is required")
    return normalized


def _normalize_product_category(category: str) -> str:
    normalized = category.strip()
    if not normalized:
        raise ValueError("Product category is required")
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


def _normalize_parameter_items(
    items: list[tuple[str, str, str, str, str]],
) -> list[dict[str, object]]:
    normalized_items: list[dict[str, object]] = []
    key_set: set[str] = set()
    for index, (name, category, parameter_type, value, description) in enumerate(
        items, start=1
    ):
        normalized_name = name.strip()
        normalized_category = category.strip()
        normalized_type = parameter_type.strip()
        normalized_value = value.strip()
        normalized_description = description.strip()

        if not normalized_name:
            raise ValueError("Parameter name is required")
        if not normalized_category:
            raise ValueError("Parameter category is required")
        if normalized_category not in VALID_PRODUCT_PARAMETER_CATEGORY_SET:
            raise ValueError(f"Invalid parameter category: {normalized_category}")
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
                "description": normalized_description,
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
        f"说明={item['description']};"
        f"排序={item['sort_order']};"
        f"预置={'是' if bool(item['is_preset']) else '否'}"
    )


def _snapshot_signature(payload: dict[str, object]) -> str:
    return json.dumps(
        payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )


def _build_snapshot_payload(
    *,
    product_name: str,
    parameters: list[ProductParameter | ProductRevisionParameter],
) -> dict[str, object]:
    return {
        "name": product_name,
        "parameters": [
            {
                "name": row.param_key,
                "category": row.param_category,
                "type": row.param_type,
                "value": row.param_value,
                "description": row.param_description,
                "sort_order": row.sort_order,
                "is_preset": row.is_preset,
            }
            for row in parameters
        ],
    }


def _build_snapshot_payload_from_items(
    *,
    product_name: str,
    items: list[dict[str, object]],
) -> dict[str, object]:
    return {
        "name": product_name,
        "parameters": [
            {
                "name": str(item["name"]),
                "category": str(item["category"]),
                "type": str(item["type"]),
                "value": str(item["value"]),
                "description": str(item.get("description") or ""),
                "sort_order": int(str(item["sort_order"])),
                "is_preset": bool(item["is_preset"]),
            }
            for item in items
        ],
    }


def _item_signature_from_row(row: ProductParameter | ProductRevisionParameter) -> tuple:
    return (
        row.param_category,
        row.param_type,
        row.param_value,
        row.param_description,
        row.sort_order,
        row.is_preset,
    )


def _item_signature_from_item(item: dict[str, object]) -> tuple:
    return (
        str(item["category"]),
        str(item["type"]),
        str(item["value"]),
        str(item.get("description") or ""),
        int(str(item["sort_order"])),
        bool(item["is_preset"]),
    )


def _classify_parameter_change_types(
    *,
    current_parameters: Sequence[ProductRevisionParameter],
    next_items: list[dict[str, object]],
) -> dict[str, list[str]]:
    current_by_name = {row.param_key: row for row in current_parameters}
    next_by_name = {str(item["name"]): item for item in next_items}

    change_map: dict[str, list[str]] = {"add": [], "edit": [], "delete": []}

    for name in sorted(set(current_by_name) | set(next_by_name)):
        current_row = current_by_name.get(name)
        next_item = next_by_name.get(name)
        if current_row is None and next_item is not None:
            change_map["add"].append(name)
            continue
        if current_row is not None and next_item is None:
            change_map["delete"].append(name)
            continue
        if current_row is None or next_item is None:
            continue
        if _item_signature_from_row(current_row) != _item_signature_from_item(next_item):
            change_map["edit"].append(name)

    return change_map


def _normalize_snapshot_payload(payload: dict[str, object]) -> dict[str, object]:
    product_name = _normalize_product_name(str(payload.get("name") or ""))
    raw_parameters = payload.get("parameters")
    if not isinstance(raw_parameters, list):
        raise ValueError("Invalid revision snapshot")

    tuples: list[tuple[str, str, str, str, str]] = []
    for raw_item in raw_parameters:
        if not isinstance(raw_item, dict):
            raise ValueError("Invalid revision snapshot")
        tuples.append(
            (
                str(raw_item.get("name") or ""),
                str(raw_item.get("category") or ""),
                str(raw_item.get("type") or ""),
                str(raw_item.get("value") or ""),
                str(raw_item.get("description") or ""),
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
    current_parameters: Sequence[ProductParameter | ProductRevisionParameter],
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
            or existing.param_description != next_item["description"]
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


def summarize_changed_keys(
    changed_keys: list[str], *, max_count: int = 3
) -> str | None:
    if not changed_keys:
        return None
    preview = changed_keys[:max_count]
    if len(changed_keys) <= max_count:
        return ", ".join(preview)
    return f"{', '.join(preview)} (+{len(changed_keys) - max_count})"


def get_product_by_id(db: Session, product_id: int) -> Product | None:
    stmt = select(Product).where(
        Product.id == product_id, Product.is_deleted.is_(False)
    )
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
    current_version_keyword: str | None = None,
    effective_version_keyword: str | None = None,
    current_param_name_keyword: str | None = None,
    current_param_category_keyword: str | None = None,
) -> tuple[int, list[Product], dict[int, ProductParameterHistory]]:
    stmt = (
        select(Product)
        .where(Product.is_deleted.is_(False))
        .order_by(Product.updated_at.desc())
    )
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
    if current_version_keyword is not None and current_version_keyword.strip():
        normalized_version_keyword = current_version_keyword.strip().lower()
        stmt = stmt.where(
            func.lower(func.concat("v1.", Product.current_version - 1)).contains(
                normalized_version_keyword
            )
        )
    if effective_version_keyword is not None and effective_version_keyword.strip():
        normalized_effective_version_keyword = effective_version_keyword.strip().lower()
        stmt = stmt.where(
            func.lower(func.concat("v1.", Product.effective_version - 1)).contains(
                normalized_effective_version_keyword
            )
        )
    if current_param_name_keyword is not None and current_param_name_keyword.strip():
        like_pattern = f"%{current_param_name_keyword.strip()}%"
        stmt = stmt.where(
            select(ProductRevisionParameter.id)
            .where(
                ProductRevisionParameter.product_id == Product.id,
                ProductRevisionParameter.version == Product.current_version,
                ProductRevisionParameter.param_key.ilike(like_pattern),
            )
            .exists()
        )
    if (
        current_param_category_keyword is not None
        and current_param_category_keyword.strip()
    ):
        like_pattern = f"%{current_param_category_keyword.strip()}%"
        stmt = stmt.where(
            select(ProductRevisionParameter.id)
            .where(
                ProductRevisionParameter.product_id == Product.id,
                ProductRevisionParameter.version == Product.current_version,
                ProductRevisionParameter.param_category.ilike(like_pattern),
            )
            .exists()
        )

    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    paged_stmt = stmt.offset(offset).limit(page_size)
    products = db.execute(paged_stmt).scalars().all()

    history_map = get_latest_history_map_by_product_ids(
        db, [product.id for product in products]
    )
    return total, products, history_map


def list_product_parameter_versions(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    category: str | None,
    version_keyword: str | None,
    param_name_keyword: str | None,
    param_category_keyword: str | None,
    lifecycle_status: str | None,
    updated_after: datetime | None,
    updated_before: datetime | None,
) -> tuple[int, list[ProductParameterVersionListRow]]:
    stmt = (
        select(ProductRevision, Product)
        .join(Product, Product.id == ProductRevision.product_id)
        .where(Product.is_deleted.is_(False))
        .order_by(ProductRevision.updated_at.desc(), ProductRevision.id.desc())
    )
    if keyword and keyword.strip():
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(Product.name.ilike(like_pattern))
    if category is not None and category != "":
        stmt = stmt.where(Product.category == category)
    if version_keyword and version_keyword.strip():
        normalized_version_keyword = version_keyword.strip().lower()
        stmt = stmt.where(
            func.lower(ProductRevision.version_label).contains(
                normalized_version_keyword
            )
        )
    if param_name_keyword and param_name_keyword.strip():
        like_pattern = f"%{param_name_keyword.strip()}%"
        stmt = stmt.where(
            select(ProductRevisionParameter.id)
            .where(
                ProductRevisionParameter.revision_id == ProductRevision.id,
                ProductRevisionParameter.param_key.ilike(like_pattern),
            )
            .exists()
        )
    if param_category_keyword and param_category_keyword.strip():
        like_pattern = f"%{param_category_keyword.strip()}%"
        stmt = stmt.where(
            select(ProductRevisionParameter.id)
            .where(
                ProductRevisionParameter.revision_id == ProductRevision.id,
                ProductRevisionParameter.param_category.ilike(like_pattern),
            )
            .exists()
        )
    if lifecycle_status is not None and lifecycle_status != "":
        stmt = stmt.where(ProductRevision.lifecycle_status == lifecycle_status)
    if updated_after is not None:
        stmt = stmt.where(ProductRevision.updated_at >= updated_after)
    if updated_before is not None:
        stmt = stmt.where(ProductRevision.updated_at <= updated_before)

    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    raw_rows = db.execute(stmt.offset(offset).limit(page_size)).all()
    if not raw_rows:
        return total, []

    version_keys = [
        (revision.product_id, revision.version) for revision, _product in raw_rows
    ]
    history_rows = (
        db.execute(
            select(ProductParameterHistory)
            .where(
                tuple_(
                    ProductParameterHistory.product_id,
                    ProductParameterHistory.version,
                ).in_(version_keys)
            )
            .order_by(
                ProductParameterHistory.product_id.asc(),
                ProductParameterHistory.version.asc(),
                ProductParameterHistory.created_at.desc(),
                ProductParameterHistory.id.desc(),
            )
        )
        .scalars()
        .all()
    )
    history_map: dict[tuple[int, int], ProductParameterHistory] = {}
    for history in history_rows:
        if history.version is None:
            continue
        key = (history.product_id, history.version)
        if key not in history_map:
            history_map[key] = history

    revision_id_set = {revision.id for revision, _product in raw_rows}
    parameter_rows = (
        db.execute(
            select(ProductRevisionParameter)
            .where(ProductRevisionParameter.revision_id.in_(revision_id_set))
            .order_by(
                ProductRevisionParameter.revision_id.asc(),
                ProductRevisionParameter.sort_order.asc(),
                ProductRevisionParameter.id.asc(),
            )
        )
        .scalars()
        .all()
    )
    revision_parameter_map: dict[int, list[ProductRevisionParameter]] = {}
    for row in parameter_rows:
        revision_parameter_map.setdefault(row.revision_id, []).append(row)

    normalized_param_name_keyword = (param_name_keyword or "").strip().lower()
    normalized_param_category_keyword = (param_category_keyword or "").strip().lower()

    items: list[ProductParameterVersionListRow] = []
    for revision, product in raw_rows:
        latest_history = history_map.get((product.id, revision.version))
        revision_parameters = revision_parameter_map.get(revision.id, [])
        summary = None
        if latest_history is not None:
            summary = summarize_changed_keys(
                [str(value) for value in (latest_history.changed_keys or [])]
            )
        if not summary:
            summary = (revision.note or "").strip() or None
        matched_row = next(
            (
                row
                for row in revision_parameters
                if (
                    not normalized_param_name_keyword
                    or normalized_param_name_keyword in row.param_key.lower()
                )
                and (
                    not normalized_param_category_keyword
                    or normalized_param_category_keyword
                    in (row.param_category or "").lower()
                )
            ),
            revision_parameters[0] if revision_parameters else None,
        )
        last_modified_parameter_category = None
        if latest_history is not None and latest_history.changed_keys:
            latest_key = str(latest_history.changed_keys[0])
            last_modified_parameter_category = next(
                (
                    row.param_category
                    for row in revision_parameters
                    if row.param_key == latest_key
                ),
                None,
            )
        items.append(
            ProductParameterVersionListRow(
                product=product,
                revision=revision,
                parameter_summary=summary,
                parameter_count=len(revision_parameters),
                matched_parameter_name=matched_row.param_key if matched_row else None,
                matched_parameter_category=(
                    matched_row.param_category if matched_row else None
                ),
                last_modified_parameter=(
                    str(latest_history.changed_keys[0])
                    if latest_history is not None and latest_history.changed_keys
                    else None
                ),
                last_modified_parameter_category=last_modified_parameter_category,
            )
        )
    return total, items


def _clone_default_craft_template_for_new_product(
    db: Session,
    *,
    product: Product,
    operator: User,
) -> None:
    if not settings.craft_auto_bind_default_template_enabled:
        logger.info(
            "Skip auto bind default process template: product_id=%s config=craft_auto_bind_default_template_enabled disabled",
            product.id,
        )
        return

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
    source_steps = sorted(
        source_template.steps, key=lambda item: (item.step_order, item.id)
    )
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
        source_type="system_master",
        source_template_name="系统母版",
        source_system_master_version=source_template.version,
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

    enabled_rows = (
        db.execute(
            select(ProductProcessTemplate).where(
                ProductProcessTemplate.product_id == product.id,
                ProductProcessTemplate.is_enabled.is_(True),
                ProductProcessTemplate.lifecycle_status == "published",
            )
        )
        .scalars()
        .all()
    )
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
    version: int,
    lifecycle_status: str,
    action: str,
    note: str | None,
    operator: User,
    source_revision_id: int | None = None,
    version_label: str | None = None,
    parameter_items: list[dict[str, object]] | None = None,
) -> ProductRevision:
    if parameter_items is None:
        parameters = list_product_parameters(db, product.id)
        payload = _build_snapshot_payload(
            product_name=product.name, parameters=parameters
        )
        normalized_parameters = payload["parameters"]
        if not isinstance(normalized_parameters, list):
            raise ValueError("Invalid revision snapshot payload")
        items_to_write = [
            dict(item) for item in normalized_parameters if isinstance(item, dict)
        ]
    else:
        payload = _build_snapshot_payload_from_items(
            product_name=product.name, items=parameter_items
        )
        items_to_write = [dict(item) for item in parameter_items]
    row = ProductRevision(
        product_id=product.id,
        version=version,
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
    _replace_revision_parameters(
        db,
        product=product,
        revision=row,
        items=items_to_write,
    )
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


def _has_any_effective_revision(
    db: Session,
    *,
    product_id: int,
    exclude_version: int | None = None,
) -> bool:
    conditions = [
        ProductRevision.product_id == product_id,
        ProductRevision.lifecycle_status == PRODUCT_LIFECYCLE_EFFECTIVE,
    ]
    if exclude_version is not None:
        conditions.append(ProductRevision.version != exclude_version)
    return (
        db.execute(select(ProductRevision.id).where(*conditions)).scalars().first()
        is not None
    )


def create_product(
    db: Session,
    name: str,
    *,
    category: str = "",
    remark: str = "",
    operator: User,
) -> Product:
    normalized_name = _normalize_product_name(name)
    normalized_category = _normalize_product_category(category)
    product = Product(
        name=normalized_name,
        category=normalized_category,
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

    initial_items = [
        {
            "name": template.name,
            "category": template.category,
            "type": template.parameter_type,
            "value": normalized_name
            if template.name == PRODUCT_NAME_PARAMETER_KEY
            else "",
            "description": "",
            "sort_order": template.sort_order,
            "is_preset": True,
        }
        for template in PRODUCT_PARAMETER_TEMPLATE
    ]

    initial_revision = _create_product_revision_snapshot(
        db,
        product=product,
        version=1,
        lifecycle_status=PRODUCT_LIFECYCLE_DRAFT,
        action="create",
        note="Initial draft V1.0",
        operator=operator,
        version_label="V1.0",
        parameter_items=initial_items,
    )
    _sync_current_parameter_rows(db, product=product, items=initial_items)
    _append_revision_history(
        db,
        product=product,
        revision=initial_revision,
        operator=operator,
        change_type="create",
        remark="创建初始草稿版本 V1.0",
    )

    _clone_default_craft_template_for_new_product(
        db,
        product=product,
        operator=operator,
    )

    db.refresh(product)
    return product


def sync_product_master_data_to_parameters(
    db: Session,
    *,
    product: Product,
) -> None:
    revisions = (
        db.execute(
            select(ProductRevision)
            .where(ProductRevision.product_id == product.id)
            .order_by(ProductRevision.version.asc(), ProductRevision.id.asc())
        )
        .scalars()
        .all()
    )
    for revision in revisions:
        revision_parameters = _ensure_revision_parameters_materialized(
            db,
            product=product,
            revision=revision,
        )
        for row in revision_parameters:
            if row.param_key == PRODUCT_NAME_PARAMETER_KEY:
                row.param_value = product.name
        revision.snapshot_json = _snapshot_signature(
            _build_snapshot_payload(
                product_name=product.name,
                parameters=revision_parameters,
            )
        )

    current_revision = get_current_revision(db, product=product)
    if current_revision is not None:
        _sync_current_parameters_from_revision(
            db,
            product=product,
            revision=current_revision,
        )


def delete_product(db: Session, product: Product) -> None:
    open_orders = _list_open_orders_for_product(db, product_id=product.id)
    if open_orders:
        raise ValueError("该产品存在未完成的工单，不允许删除，仅允许停用")
    blockers = _list_product_reference_blockers(db, product_id=product.id)
    if blockers:
        raise ValueError("该产品已被业务记录引用，不允许删除：" + "；".join(blockers))
    product.is_deleted = True
    db.commit()


def ensure_product_parameter_template_initialized(
    db: Session, product: Product
) -> bool:
    current_revision = get_current_revision(db, product=product)
    if current_revision is None:
        return False
    rows = _sync_current_parameters_from_revision(
        db,
        product=product,
        revision=current_revision,
    )
    product.parameter_template_initialized = True
    db.commit()
    db.refresh(product)
    return bool(rows)


def list_product_parameters(db: Session, product_id: int) -> list[ProductParameter]:
    stmt = (
        select(ProductParameter)
        .where(ProductParameter.product_id == product_id)
        .order_by(ProductParameter.sort_order.asc(), ProductParameter.id.asc())
    )
    return db.execute(stmt).scalars().all()


def list_revision_parameters(
    db: Session, revision_id: int
) -> list[ProductRevisionParameter]:
    stmt = (
        select(ProductRevisionParameter)
        .where(ProductRevisionParameter.revision_id == revision_id)
        .order_by(
            ProductRevisionParameter.sort_order.asc(), ProductRevisionParameter.id.asc()
        )
    )
    return db.execute(stmt).scalars().all()


def _replace_revision_parameters(
    db: Session,
    *,
    product: Product,
    revision: ProductRevision,
    items: list[dict[str, object]],
) -> None:
    db.execute(
        delete(ProductRevisionParameter).where(
            ProductRevisionParameter.revision_id == revision.id
        )
    )
    for item in items:
        db.add(
            ProductRevisionParameter(
                product_id=product.id,
                revision_id=revision.id,
                version=revision.version,
                param_key=str(item["name"]),
                param_category=str(item["category"]),
                param_type=str(item["type"]),
                param_value=str(item["value"]),
                param_description=str(item.get("description") or ""),
                sort_order=int(item["sort_order"]),
                is_preset=bool(item["is_preset"]),
            )
        )


def _sync_current_parameter_rows(
    db: Session,
    *,
    product: Product,
    items: list[dict[str, object]],
) -> None:
    db.execute(
        delete(ProductParameter).where(ProductParameter.product_id == product.id)
    )
    for item in items:
        db.add(
            ProductParameter(
                product_id=product.id,
                param_key=str(item["name"]),
                param_category=str(item["category"]),
                param_type=str(item["type"]),
                param_value=str(item["value"]),
                param_description=str(item.get("description") or ""),
                sort_order=int(item["sort_order"]),
                is_preset=bool(item["is_preset"]),
            )
        )


def _ensure_revision_parameters_materialized(
    db: Session,
    *,
    product: Product,
    revision: ProductRevision,
) -> list[ProductRevisionParameter]:
    rows = list_revision_parameters(db, revision.id)
    if rows:
        return rows

    payload = _parse_revision_snapshot(revision)
    parameter_items = payload.get("parameters")
    if not isinstance(parameter_items, list):
        return []

    normalized_items = [
        dict(item) for item in parameter_items if isinstance(item, dict)
    ]
    _replace_revision_parameters(
        db,
        product=product,
        revision=revision,
        items=normalized_items,
    )
    db.flush()
    return list_revision_parameters(db, revision.id)


def get_current_revision(db: Session, *, product: Product) -> ProductRevision | None:
    if product.current_version <= 0:
        return None
    return get_product_version(
        db, product_id=product.id, version=product.current_version
    )


def get_effective_revision(db: Session, *, product: Product) -> ProductRevision | None:
    if product.effective_version <= 0:
        return None
    return get_product_version(
        db, product_id=product.id, version=product.effective_version
    )


def _sync_current_parameters_from_revision(
    db: Session,
    *,
    product: Product,
    revision: ProductRevision,
) -> list[ProductRevisionParameter]:
    revision_parameters = _ensure_revision_parameters_materialized(
        db,
        product=product,
        revision=revision,
    )
    normalized_items = [
        {
            "name": row.param_key,
            "category": row.param_category,
            "type": row.param_type,
            "value": row.param_value,
            "description": row.param_description,
            "sort_order": row.sort_order,
            "is_preset": row.is_preset,
        }
        for row in revision_parameters
    ]
    _sync_current_parameter_rows(
        db,
        product=product,
        items=normalized_items,
    )
    return revision_parameters


def _append_revision_history(
    db: Session,
    *,
    product: Product,
    revision: ProductRevision,
    operator: User,
    change_type: str,
    remark: str,
    before_snapshot: str = "{}",
    after_snapshot: str | None = None,
    changed_keys: list[str] | None = None,
) -> None:
    db.add(
        ProductParameterHistory(
            product_id=product.id,
            revision_id=revision.id,
            version=revision.version,
            operator_user_id=operator.id,
            operator_username=operator.username,
            remark=remark,
            change_type=change_type,
            changed_keys=changed_keys or [],
            before_snapshot=before_snapshot,
            after_snapshot=after_snapshot
            if after_snapshot is not None
            else revision.snapshot_json,
        )
    )


def append_product_history_event(
    db: Session,
    *,
    product: Product,
    operator: User,
    change_type: str,
    remark: str,
    changed_keys: list[str],
    before_snapshot: str,
    after_snapshot: str,
) -> None:
    revision = get_current_revision(db, product=product) or get_effective_revision(
        db, product=product
    )
    db.add(
        ProductParameterHistory(
            product_id=product.id,
            revision_id=revision.id if revision else None,
            version=revision.version if revision else None,
            operator_user_id=operator.id,
            operator_username=operator.username,
            remark=remark,
            change_type=change_type,
            changed_keys=changed_keys,
            before_snapshot=before_snapshot,
            after_snapshot=after_snapshot,
        )
    )


def _build_revision_items_from_rows(
    rows: Sequence[ProductRevisionParameter],
) -> list[dict[str, object]]:
    return [
        {
            "name": row.param_key,
            "category": row.param_category,
            "type": row.param_type,
            "value": row.param_value,
            "description": row.param_description,
            "sort_order": row.sort_order,
            "is_preset": row.is_preset,
        }
        for row in rows
    ]


def _list_product_reference_blockers(db: Session, *, product_id: int) -> list[str]:
    blockers: list[str] = []

    total_orders = db.execute(
        select(func.count())
        .select_from(ProductionOrder)
        .where(ProductionOrder.product_id == product_id)
    ).scalar_one()
    if total_orders > 0:
        blockers.append(f"存在 {total_orders} 条生产工单")

    production_records = db.execute(
        select(func.count())
        .select_from(ProductionRecord)
        .join(ProductionOrderProcess, ProductionOrderProcess.id == ProductionRecord.order_process_id)
        .join(ProductionOrder, ProductionOrder.id == ProductionOrderProcess.order_id)
        .where(ProductionOrder.product_id == product_id)
    ).scalar_one()
    if production_records > 0:
        blockers.append(f"存在 {production_records} 条生产记录")

    first_article_records = db.execute(
        select(func.count())
        .select_from(FirstArticleRecord)
        .join(ProductionOrder, ProductionOrder.id == FirstArticleRecord.order_id)
        .where(ProductionOrder.product_id == product_id)
    ).scalar_one()
    if first_article_records > 0:
        blockers.append(f"存在 {first_article_records} 条首件质检记录")

    scrap_records = db.execute(
        select(func.count())
        .select_from(ProductionScrapStatistics)
        .where(ProductionScrapStatistics.product_id == product_id)
    ).scalar_one()
    if scrap_records > 0:
        blockers.append(f"存在 {scrap_records} 条报废统计记录")

    repair_orders = db.execute(
        select(func.count())
        .select_from(RepairOrder)
        .where(RepairOrder.product_id == product_id)
    ).scalar_one()
    if repair_orders > 0:
        blockers.append(f"存在 {repair_orders} 条维修订单")

    defect_rows = db.execute(
        select(func.count())
        .select_from(RepairDefectPhenomenon)
        .where(RepairDefectPhenomenon.product_id == product_id)
    ).scalar_one()
    if defect_rows > 0:
        blockers.append(f"存在 {defect_rows} 条维修不良现象记录")

    cause_rows = db.execute(
        select(func.count())
        .select_from(RepairCause)
        .where(RepairCause.product_id == product_id)
    ).scalar_one()
    if cause_rows > 0:
        blockers.append(f"存在 {cause_rows} 条维修原因记录")

    return blockers


def _get_product_version_delete_blocker(
    db: Session,
    *,
    product_id: int,
    version: int,
    version_label: str,
) -> str | None:
    referenced_orders = (
        db.execute(
            select(ProductionOrder.order_code)
            .where(
                ProductionOrder.product_id == product_id,
                ProductionOrder.product_version == version,
            )
            .order_by(ProductionOrder.id.asc())
        )
        .scalars()
        .all()
    )
    if referenced_orders:
        sample_order_codes = referenced_orders[:3]
        order_summary = "、".join(sample_order_codes)
        if len(referenced_orders) > len(sample_order_codes):
            order_summary = f"{order_summary} 等 {len(referenced_orders)} 条生产工单"
        return f"草稿版本 {version_label} 已被生产工单引用（{order_summary}），无法删除"
    return None


def _list_open_orders_for_product(
    db: Session, *, product_id: int
) -> list[ProductionOrder]:
    return (
        db.execute(
            select(ProductionOrder)
            .where(
                ProductionOrder.product_id == product_id,
                ProductionOrder.status.in_(
                    [ORDER_STATUS_PENDING, ORDER_STATUS_IN_PROGRESS]
                ),
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
    in_progress_orders = sum(
        1 for row in open_orders if row.status == ORDER_STATUS_IN_PROGRESS
    )

    requires_confirmation = False
    reason_text: str | None = None
    if normalized_operation == "update_parameters":
        requires_confirmation = (
            product.lifecycle_status == PRODUCT_LIFECYCLE_ACTIVE
            and len(open_orders) > 0
        )
        if requires_confirmation:
            reason_text = "Active product has unfinished orders"
    elif normalized_operation == "lifecycle":
        if normalized_target_status is None:
            raise ValueError("target_status is required for lifecycle impact analysis")
        requires_confirmation = (
            normalized_target_status == PRODUCT_LIFECYCLE_INACTIVE
            and len(open_orders) > 0
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


def get_product_version_parameters(
    db: Session,
    *,
    product: Product,
    version: int,
) -> tuple[ProductRevision, list[ProductRevisionParameter]]:
    revision = get_product_version(db, product_id=product.id, version=version)
    if revision is None:
        raise ValueError("版本不存在")
    rows = _ensure_revision_parameters_materialized(
        db,
        product=product,
        revision=revision,
    )
    return revision, rows


def get_effective_product_parameters(
    db: Session,
    *,
    product: Product,
) -> tuple[ProductRevision, list[ProductRevisionParameter]]:
    revision = get_effective_revision(db, product=product)
    if revision is None:
        raise ValueError("该产品暂无生效版本")
    rows = _ensure_revision_parameters_materialized(
        db,
        product=product,
        revision=revision,
    )
    return revision, rows


def update_product_version_parameters(
    db: Session,
    *,
    product: Product,
    version: int,
    items: list[tuple[str, str, str, str, str]],
    remark: str,
    operator: User,
    confirmed: bool = False,
) -> list[str]:
    revision, current_parameters = get_product_version_parameters(
        db,
        product=product,
        version=version,
    )
    if revision.lifecycle_status != PRODUCT_LIFECYCLE_DRAFT:
        raise ValueError("只有草稿版本可以维护参数")

    normalized_remark = remark.strip()
    if not normalized_remark:
        raise ValueError("Remark is required")

    if (
        product.lifecycle_status == PRODUCT_LIFECYCLE_ACTIVE
        and product.effective_version == revision.version
    ):
        impact = analyze_product_impact(
            db,
            product=product,
            operation="update_parameters",
        )
        if impact.requires_confirmation and not confirmed:
            raise ValueError(
                "Impact confirmation required before updating active product"
            )

    normalized_items = _normalize_parameter_items(items)
    normalized_by_name = {str(item["name"]): item for item in normalized_items}
    product_name_item = normalized_by_name.get(PRODUCT_NAME_PARAMETER_KEY)
    if product_name_item is None:
        raise ValueError("Product name parameter cannot be deleted")
    product_name_item["category"] = PRODUCT_NAME_PARAMETER_CATEGORY
    product_name_item["type"] = PRODUCT_NAME_PARAMETER_TYPE
    product_name_item["value"] = product.name

    changed_keys = _calculate_changed_keys(
        current_parameters=current_parameters,
        next_items=normalized_items,
    )
    if not changed_keys:
        raise ValueError("No parameter changes detected")

    before_snapshot = _snapshot_signature(
        _build_snapshot_payload(
            product_name=product.name, parameters=current_parameters
        )
    )
    after_payload = _build_snapshot_payload_from_items(
        product_name=product.name,
        items=normalized_items,
    )
    after_snapshot = _snapshot_signature(after_payload)
    change_type_map = _classify_parameter_change_types(
        current_parameters=current_parameters,
        next_items=normalized_items,
    )

    _replace_revision_parameters(
        db,
        product=product,
        revision=revision,
        items=normalized_items,
    )
    revision.snapshot_json = after_snapshot
    revision.note = normalized_remark
    revision.action = "update_parameters"

    if revision.version == product.current_version:
        _sync_current_parameter_rows(db, product=product, items=normalized_items)

    for change_type in ("add", "edit", "delete"):
        typed_keys = change_type_map[change_type]
        if not typed_keys:
            continue
        db.add(
            ProductParameterHistory(
                product_id=product.id,
                revision_id=revision.id,
                version=revision.version,
                operator_user_id=operator.id,
                operator_username=operator.username,
                remark=normalized_remark,
                change_type=change_type,
                changed_keys=typed_keys,
                before_snapshot=before_snapshot,
                after_snapshot=after_snapshot,
            )
        )
    product.updated_at = datetime.now(UTC)
    db.flush()
    return changed_keys


def update_product_parameters(
    db: Session,
    *,
    product: Product,
    items: list[tuple[str, str, str, str, str]],
    remark: str,
    operator: User,
    confirmed: bool = False,
) -> list[str]:
    current_revision = get_current_revision(db, product=product)
    if current_revision is None:
        raise ValueError("当前版本不存在")
    changed_keys = update_product_version_parameters(
        db,
        product=product,
        version=current_revision.version,
        items=items,
        remark=remark,
        operator=operator,
        confirmed=confirmed,
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
    del (
        operator
    )  # lifecycle transition currently does not create a separate revision row.

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
        effective_revision = get_effective_revision(db, product=product)
        if product.effective_version <= 0 or effective_revision is None:
            raise ValueError(
                "产品当前无生效版本，不能直接启用；请前往版本管理准备并生效版本后再启用产品"
            )
        product.effective_at = datetime.now(UTC)
        product.inactive_reason = None
    else:
        product.inactive_reason = normalized_reason

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


def get_product_version(
    db: Session, *, product_id: int, version: int
) -> ProductRevision | None:
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
            select(ProductRevision).where(
                ProductRevision.product_id == product_id,
                ProductRevision.lifecycle_status == PRODUCT_LIFECYCLE_DRAFT,
            )
        )
        .scalars()
        .first()
    )


def _next_product_revision_version(db: Session, product_id: int) -> int:
    max_existing = (
        db.execute(
            select(func.coalesce(func.max(ProductRevision.version), 0)).where(
                ProductRevision.product_id == product_id
            )
        ).scalar()
        or 0
    )
    return max_existing + 1


def _next_version_label(db: Session, product_id: int) -> str:
    labels = (
        db.execute(
            select(ProductRevision.version_label).where(
                ProductRevision.product_id == product_id
            )
        )
        .scalars()
        .all()
    )
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
    next_version = _next_product_revision_version(db, product.id)
    product.current_version = next_version
    db.flush()

    source_revision = get_effective_revision(
        db, product=product
    ) or get_product_version(
        db,
        product_id=product.id,
        version=max(next_version - 1, 1),
    )
    source_parameters = []
    if source_revision is not None:
        source_parameters = _build_revision_items_from_rows(
            _ensure_revision_parameters_materialized(
                db,
                product=product,
                revision=source_revision,
            )
        )

    revision = _create_product_revision_snapshot(
        db,
        product=product,
        version=next_version,
        lifecycle_status=PRODUCT_LIFECYCLE_DRAFT,
        action="create",
        note=None,
        operator=operator,
        version_label=version_label,
        parameter_items=source_parameters or None,
    )
    _append_revision_history(
        db,
        product=product,
        revision=revision,
        operator=operator,
        change_type="create",
        remark=f"创建草稿版本 {revision.version_label}",
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

    source_parameters = _ensure_revision_parameters_materialized(
        db,
        product=product,
        revision=source,
    )
    if not source_parameters:
        raise ValueError("来源版本参数为空，无法复制")

    version_label = _next_version_label(db, product.id)
    next_version = _next_product_revision_version(db, product.id)
    product.current_version = next_version
    db.flush()

    revision = _create_product_revision_snapshot(
        db,
        product=product,
        version=next_version,
        lifecycle_status=PRODUCT_LIFECYCLE_DRAFT,
        action="copy",
        note=f"Copied from {source.version_label}",
        operator=operator,
        source_revision_id=source.id,
        version_label=version_label,
        parameter_items=[
            {
                "name": row.param_key,
                "category": row.param_category,
                "type": row.param_type,
                "value": row.param_value,
                "description": row.param_description,
                "sort_order": row.sort_order,
                "is_preset": row.is_preset,
            }
            for row in source_parameters
        ],
    )
    _append_revision_history(
        db,
        product=product,
        revision=revision,
        operator=operator,
        change_type="copy",
        remark=f"从 {source.version_label} 复制生成草稿版本 {revision.version_label}",
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
    expected_effective_version: int | None,
    operator: User,
) -> ProductRevision:
    revision = get_product_version(db, product_id=product.id, version=version)
    if revision is None:
        raise ValueError("版本不存在")
    if revision.lifecycle_status != PRODUCT_LIFECYCLE_DRAFT:
        raise ValueError("只有草稿版本可以生效")
    if product.lifecycle_status != PRODUCT_LIFECYCLE_ACTIVE:
        raise ValueError("产品已停用，请先启用产品后再生效版本")

    if (
        expected_effective_version is not None
        and product.effective_version != expected_effective_version
    ):
        raise ValueError("当前已有其他版本抢先生效，请刷新版本列表后重试")

    revision_parameters = _ensure_revision_parameters_materialized(
        db,
        product=product,
        revision=revision,
    )
    if not revision_parameters:
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
        if (
            row.id != revision.id
            and row.lifecycle_status == PRODUCT_LIFECYCLE_EFFECTIVE
        ):
            row.lifecycle_status = PRODUCT_LIFECYCLE_OBSOLETE

    revision.lifecycle_status = PRODUCT_LIFECYCLE_EFFECTIVE
    revision.action = "activate"
    product.lifecycle_status = PRODUCT_LIFECYCLE_ACTIVE
    product.effective_version = version
    product.current_version = version
    product.effective_at = datetime.now(UTC)
    product.inactive_reason = None
    product.updated_at = datetime.now(UTC)
    _sync_current_parameters_from_revision(
        db,
        product=product,
        revision=revision,
    )
    _append_revision_history(
        db,
        product=product,
        revision=revision,
        operator=operator,
        change_type="activate",
        remark=f"版本 {revision.version_label} 已生效",
    )

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
    if revision.lifecycle_status not in {
        PRODUCT_LIFECYCLE_EFFECTIVE,
        PRODUCT_LIFECYCLE_OBSOLETE,
    }:
        raise ValueError("只有已生效或已失效的版本可以停用")

    revision.lifecycle_status = PRODUCT_LIFECYCLE_DISABLED
    if product.effective_version == version:
        product.effective_version = 0
        product.effective_at = None
        if not _has_any_effective_revision(
            db,
            product_id=product.id,
            exclude_version=version,
        ):
            product.lifecycle_status = PRODUCT_LIFECYCLE_INACTIVE
            product.inactive_reason = NO_EFFECTIVE_VERSION_INACTIVE_REASON
    product.updated_at = datetime.now(UTC)
    _append_revision_history(
        db,
        product=product,
        revision=revision,
        operator=operator,
        change_type="disable",
        remark=f"版本 {revision.version_label} 已停用",
    )

    db.commit()
    db.refresh(revision)
    return revision


def update_product_version_note(
    db: Session,
    *,
    product_id: int,
    version: int,
    note: str,
    operator: User | None = None,
) -> ProductRevision:
    revision = get_product_version(db, product_id=product_id, version=version)
    if revision is None:
        raise ValueError("版本不存在")
    previous_note = revision.note
    revision.note = note.strip() or None
    if operator is not None and previous_note != revision.note:
        product = get_product_by_id(db, product_id)
        if product is not None:
            append_product_history_event(
                db,
                product=product,
                operator=operator,
                change_type="update_version_note",
                remark=f"更新版本 {revision.version_label} 备注",
                changed_keys=["note"],
                before_snapshot=json.dumps(
                    {"version": revision.version, "note": previous_note},
                    ensure_ascii=False,
                ),
                after_snapshot=json.dumps(
                    {"version": revision.version, "note": revision.note},
                    ensure_ascii=False,
                ),
            )
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
    version_delete_blocker = _get_product_version_delete_blocker(
        db,
        product_id=product.id,
        version=revision.version,
        version_label=revision.version_label,
    )
    if version_delete_blocker is not None:
        raise ValueError(version_delete_blocker)

    # Ensure at least one non-draft revision remains
    other_revisions = (
        db.execute(
            select(ProductRevision).where(
                ProductRevision.product_id == product.id,
                ProductRevision.id != revision.id,
            )
        )
        .scalars()
        .all()
    )
    if not other_revisions:
        raise ValueError("产品至少需要保留一个版本记录，无法删除唯一版本")

    fallback_current_revision = get_effective_revision(db, product=product)

    _append_revision_history(
        db,
        product=product,
        revision=revision,
        operator=operator,
        change_type="delete",
        remark=f"删除草稿版本 {revision.version_label}",
        before_snapshot=revision.snapshot_json,
        after_snapshot="{}",
    )

    db.delete(revision)
    if product.current_version == version:
        if (
            fallback_current_revision is not None
            and fallback_current_revision.id != revision.id
        ):
            product.current_version = fallback_current_revision.version
            _sync_current_parameters_from_revision(
                db,
                product=product,
                revision=fallback_current_revision,
            )
        else:
            remaining_versions = [
                row.version for row in other_revisions if row.id != revision.id
            ]
            product.current_version = (
                max(remaining_versions) if remaining_versions else 0
            )
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
    target_revision = get_product_version(
        db, product_id=product.id, version=target_version
    )
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
    current_revision = get_current_revision(db, product=product)
    if current_revision is None:
        raise ValueError("当前版本不存在")
    current_parameters = _ensure_revision_parameters_materialized(
        db,
        product=product,
        revision=current_revision,
    )
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

    _sync_current_parameter_rows(db, product=product, items=next_items)

    after_snapshot = _snapshot_signature(target_snapshot)
    product.name = candidate_name
    product.updated_at = datetime.now(UTC)
    product.current_version = _next_product_revision_version(db, product.id)
    revision_status = PRODUCT_LIFECYCLE_DRAFT
    if product.lifecycle_status == PRODUCT_LIFECYCLE_ACTIVE:
        product.effective_version = product.current_version
        product.effective_at = datetime.now(UTC)
        revision_status = PRODUCT_LIFECYCLE_EFFECTIVE

    rollback_note = (note or "").strip() or f"Rollback to v{target_version}"
    history_row = ProductParameterHistory(
        product_id=product.id,
        operator_user_id=operator.id,
        operator_username=operator.username,
        remark=rollback_note,
        change_type="rollback",
        changed_keys=changed_keys,
        before_snapshot=before_snapshot,
        after_snapshot=after_snapshot,
    )
    db.add(history_row)
    db.flush()
    revision = _create_product_revision_snapshot(
        db,
        product=product,
        version=product.current_version,
        lifecycle_status=revision_status,
        action="rollback",
        note=rollback_note,
        operator=operator,
        source_revision_id=target_revision.id,
        parameter_items=next_items,
    )
    history_row.revision_id = revision.id
    history_row.version = revision.version
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
    revision_id: int | None = None,
    version: int | None = None,
    page: int,
    page_size: int,
) -> tuple[int, list[ProductParameterHistory]]:
    stmt = select(ProductParameterHistory).where(
        ProductParameterHistory.product_id == product_id
    )
    if revision_id is not None:
        stmt = stmt.where(ProductParameterHistory.revision_id == revision_id)
    elif version is not None:
        stmt = stmt.where(ProductParameterHistory.version == version)
    stmt = stmt.options(selectinload(ProductParameterHistory.revision)).order_by(
        ProductParameterHistory.created_at.desc(),
        ProductParameterHistory.id.desc(),
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
