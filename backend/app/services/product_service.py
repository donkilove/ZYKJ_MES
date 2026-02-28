from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.product import Product
from app.models.product_parameter import ProductParameter
from app.models.product_parameter_history import ProductParameterHistory
from app.models.user import User


def _normalize_product_name(name: str) -> str:
    normalized = name.strip()
    if not normalized:
        raise ValueError("Product name is required")
    return normalized


def _normalize_parameter_items(items: list[tuple[str, str]]) -> dict[str, str]:
    normalized_map: dict[str, str] = {}
    for key, value in items:
        normalized_key = key.strip()
        if not normalized_key:
            raise ValueError("Parameter key is required")
        if normalized_key in normalized_map:
            raise ValueError(f"Duplicate parameter key: {normalized_key}")
        normalized_map[normalized_key] = value.strip()
    return normalized_map


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
    product = Product(name=normalized_name)
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


def delete_product(db: Session, product: Product) -> None:
    db.delete(product)
    db.commit()


def list_product_parameters(db: Session, product_id: int) -> list[ProductParameter]:
    stmt = (
        select(ProductParameter)
        .where(ProductParameter.product_id == product_id)
        .order_by(ProductParameter.param_key.asc())
    )
    return db.execute(stmt).scalars().all()


def update_product_parameters(
    db: Session,
    *,
    product: Product,
    items: list[tuple[str, str]],
    remark: str,
    operator: User,
) -> list[str]:
    normalized_remark = remark.strip()
    if not normalized_remark:
        raise ValueError("Remark is required")

    normalized_map = _normalize_parameter_items(items)

    current_parameters = list_product_parameters(db, product.id)
    current_map = {item.param_key: item.param_value for item in current_parameters}
    current_keys = set(current_map.keys())
    next_keys = set(normalized_map.keys())

    changed_keys = sorted(
        key for key in (current_keys | next_keys) if current_map.get(key) != normalized_map.get(key)
    )
    if not changed_keys:
        raise ValueError("No parameter changes detected")

    current_by_key = {item.param_key: item for item in current_parameters}
    for param_key, param_value in normalized_map.items():
        existing = current_by_key.get(param_key)
        if existing is None:
            db.add(
                ProductParameter(
                    product_id=product.id,
                    param_key=param_key,
                    param_value=param_value,
                )
            )
        elif existing.param_value != param_value:
            existing.param_value = param_value

    for removed_key in current_keys - next_keys:
        db.delete(current_by_key[removed_key])

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
