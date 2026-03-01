from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.core.product_parameter_template import (
    ALLOWED_PARAMETER_TYPES,
    PARAMETER_TYPE_TEXT,
    PRODUCT_PARAMETER_TEMPLATE,
    PRODUCT_PARAMETER_TEMPLATE_NAME_SET,
)
from app.models.product import Product
from app.models.product_parameter import ProductParameter
from app.models.product_parameter_history import ProductParameterHistory
from app.models.user import User


def _normalize_product_name(name: str) -> str:
    normalized = name.strip()
    if not normalized:
        raise ValueError("Product name is required")
    return normalized


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


def summarize_changed_keys(changed_keys: list[str], *, max_count: int = 3) -> str | None:
    if not changed_keys:
        return None
    preview = changed_keys[:max_count]
    if len(changed_keys) <= max_count:
        return ", ".join(preview)
    return f"{', '.join(preview)} (+{len(changed_keys) - max_count})"


def get_product_by_id(db: Session, product_id: int) -> Product | None:
    stmt = select(Product).where(Product.id == product_id)
    return db.execute(stmt).scalars().first()


def get_product_by_name(db: Session, name: str) -> Product | None:
    stmt = select(Product).where(Product.name == name)
    return db.execute(stmt).scalars().first()


def list_products(
    db: Session,
    page: int,
    page_size: int,
    keyword: str | None,
) -> tuple[int, list[Product], dict[int, ProductParameterHistory]]:
    stmt = select(Product).order_by(Product.id.asc())
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(Product.name.ilike(like_pattern))

    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    paged_stmt = stmt.offset(offset).limit(page_size)
    products = db.execute(paged_stmt).scalars().all()

    history_map = get_latest_history_map_by_product_ids(db, [product.id for product in products])
    return total, products, history_map


def create_product(db: Session, name: str) -> Product:
    normalized_name = _normalize_product_name(name)
    product = Product(name=normalized_name, parameter_template_initialized=True)
    db.add(product)
    db.flush()

    for template in PRODUCT_PARAMETER_TEMPLATE:
        db.add(
            ProductParameter(
                product_id=product.id,
                param_key=template.name,
                param_category=template.category,
                param_type=template.parameter_type,
                param_value="",
                sort_order=template.sort_order,
                is_preset=True,
            )
        )

    db.commit()
    db.refresh(product)
    return product


def delete_product(db: Session, product: Product) -> None:
    db.delete(product)
    db.commit()


def ensure_product_parameter_template_initialized(db: Session, product: Product) -> bool:
    if product.parameter_template_initialized:
        return False

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
                    param_value="",
                    sort_order=template.sort_order,
                    is_preset=True,
                )
            )
            continue

        existing.param_category = template.category
        existing.param_type = template.parameter_type
        existing.sort_order = template.sort_order
        existing.is_preset = True

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


def update_product_parameters(
    db: Session,
    *,
    product: Product,
    items: list[tuple[str, str, str, str]],
    remark: str,
    operator: User,
) -> list[str]:
    normalized_remark = remark.strip()
    if not normalized_remark:
        raise ValueError("Remark is required")

    normalized_items = _normalize_parameter_items(items)
    normalized_by_name = {
        str(item["name"]): item
        for item in normalized_items
    }

    current_parameters = list_product_parameters(db, product.id)
    current_by_name = {item.param_key: item for item in current_parameters}
    current_order = [item.param_key for item in current_parameters]
    next_order = [str(item["name"]) for item in normalized_items]

    current_name_set = set(current_by_name.keys())
    next_name_set = set(next_order)
    changed_name_set: set[str] = set()

    changed_name_set.update(current_name_set - next_name_set)
    changed_name_set.update(next_name_set - current_name_set)

    for name in current_name_set & next_name_set:
        existing = current_by_name[name]
        next_item = normalized_by_name[name]
        if (
            existing.param_category != next_item["category"]
            or existing.param_type != next_item["type"]
            or existing.param_value != next_item["value"]
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

    changed_keys = sorted(changed_name_set)
    if not changed_keys:
        raise ValueError("No parameter changes detected")

    db.execute(delete(ProductParameter).where(ProductParameter.product_id == product.id))

    for item in normalized_items:
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

    db.add(
        ProductParameterHistory(
            product_id=product.id,
            operator_user_id=operator.id,
            operator_username=operator.username,
            remark=normalized_remark,
            changed_keys=changed_keys,
        )
    )
    product.updated_at = datetime.now(UTC)

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

