from __future__ import annotations

from sqlalchemy import exists, func, or_, select
from sqlalchemy.orm import Session

from app.models.production_order import ProductionOrder
from app.models.supplier import Supplier


def _normalize_supplier_name(name: str) -> str:
    normalized = name.strip()
    if not normalized:
        raise ValueError("供应商名称不能为空")
    return normalized


def get_supplier_by_id(db: Session, supplier_id: int) -> Supplier | None:
    return db.get(Supplier, supplier_id)


def list_suppliers(
    db: Session,
    *,
    keyword: str | None = None,
    enabled: bool | None = None,
) -> tuple[int, list[Supplier]]:
    stmt = select(Supplier)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                Supplier.name.ilike(like_pattern),
                Supplier.remark.ilike(like_pattern),
            )
        )
    if enabled is not None:
        stmt = stmt.where(Supplier.is_enabled == enabled)
    stmt = stmt.order_by(Supplier.is_enabled.desc(), Supplier.updated_at.desc(), Supplier.id.desc())
    total = db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one()
    rows = list(db.execute(stmt).scalars().all())
    return total, rows


def create_supplier(
    db: Session,
    *,
    name: str,
    remark: str | None,
    is_enabled: bool,
) -> Supplier:
    normalized_name = _normalize_supplier_name(name)
    existing = db.execute(
        select(Supplier).where(func.lower(Supplier.name) == normalized_name.lower())
    ).scalars().first()
    if existing is not None:
        raise ValueError("供应商名称已存在")
    row = Supplier(
        name=normalized_name,
        remark=(remark or "").strip() or None,
        is_enabled=is_enabled,
    )
    db.add(row)
    db.flush()
    db.refresh(row)
    return row


def update_supplier(
    db: Session,
    *,
    row: Supplier,
    name: str,
    remark: str | None,
    is_enabled: bool,
) -> Supplier:
    normalized_name = _normalize_supplier_name(name)
    existing = db.execute(
        select(Supplier)
        .where(func.lower(Supplier.name) == normalized_name.lower(), Supplier.id != row.id)
    ).scalars().first()
    if existing is not None:
        raise ValueError("供应商名称已存在")
    row.name = normalized_name
    row.remark = (remark or "").strip() or None
    row.is_enabled = is_enabled
    db.flush()
    db.refresh(row)
    return row


def delete_supplier(db: Session, *, row: Supplier) -> None:
    referenced = db.execute(
        select(exists().where(ProductionOrder.supplier_id == row.id))
    ).scalar()
    if referenced:
        raise RuntimeError("供应商已被生产订单引用，无法删除")
    db.delete(row)


def get_enabled_supplier_for_order(db: Session, *, supplier_id: int) -> Supplier:
    row = db.execute(
        select(Supplier).where(Supplier.id == supplier_id, Supplier.is_enabled.is_(True))
    ).scalars().first()
    if row is None:
        raise ValueError("供应商不存在或已停用")
    return row
