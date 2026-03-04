from __future__ import annotations

from collections.abc import Iterable
from datetime import date

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_PENDING,
    SUB_ORDER_STATUS_DONE,
    SUB_ORDER_STATUS_IN_PROGRESS,
    SUB_ORDER_STATUS_PENDING,
)
from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.process import Process
from app.models.product import Product
from app.models.production_record import ProductionRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_sub_order import ProductionSubOrder
from app.models.order_event_log import OrderEventLog
from app.models.user import User
from app.services.production_event_log_service import add_order_event_log


ADMIN_QUERY_ROLE_CODES = {
    ROLE_SYSTEM_ADMIN,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
}


def _normalize_process_codes(process_codes: Iterable[str]) -> list[str]:
    normalized = [item.strip() for item in process_codes if item and item.strip()]
    deduped = list(dict.fromkeys(normalized))
    return deduped


def _resolve_processes_by_codes(db: Session, process_codes: list[str]) -> tuple[list[Process], list[str]]:
    if not process_codes:
        return [], []
    stmt = select(Process).where(Process.code.in_(process_codes))
    rows = db.execute(stmt).scalars().all()
    by_code = {row.code: row for row in rows}
    missing = [code for code in process_codes if code not in by_code]
    ordered = [by_code[code] for code in process_codes if code in by_code]
    return ordered, missing


def _list_operator_users_by_process_code(db: Session, process_code: str) -> list[User]:
    stmt = (
        select(User)
        .join(User.roles)
        .join(User.processes)
        .where(
            User.is_active.is_(True),
            Process.code == process_code,
        )
        .order_by(User.id.asc())
    )
    rows = db.execute(stmt).scalars().unique().all()
    result: list[User] = []
    for row in rows:
        role_codes = {role.code for role in row.roles}
        if ROLE_OPERATOR in role_codes:
            result.append(row)
    return result


def _split_quantity_evenly(total: int, count: int) -> list[int]:
    if count <= 0:
        return []
    base = total // count
    remainder = total % count
    return [base + (1 if idx < remainder else 0) for idx in range(count)]


def _recalculate_order_current_process(order: ProductionOrder) -> None:
    sorted_processes = sorted(order.processes, key=lambda item: (item.process_order, item.id))
    for row in sorted_processes:
        if row.status != PROCESS_STATUS_COMPLETED:
            order.current_process_code = row.process_code
            return
    order.current_process_code = None


def _create_initial_sub_orders_for_process(
    db: Session,
    *,
    process_row: ProductionOrderProcess,
    visible_quantity: int,
) -> None:
    operator_users = _list_operator_users_by_process_code(db, process_row.process_code)
    if not operator_users:
        return

    assigned_quantities = _split_quantity_evenly(max(0, visible_quantity), len(operator_users))
    for user, assigned_quantity in zip(operator_users, assigned_quantities, strict=True):
        row = ProductionSubOrder(
            order_process_id=process_row.id,
            operator_user_id=user.id,
            assigned_quantity=assigned_quantity,
            completed_quantity=0,
            status=SUB_ORDER_STATUS_PENDING if assigned_quantity > 0 else SUB_ORDER_STATUS_DONE,
            is_visible=assigned_quantity > 0,
        )
        db.add(row)
    db.flush()


def ensure_sub_orders_visible_quantity(
    db: Session,
    *,
    process_row: ProductionOrderProcess,
    target_visible_quantity: int,
) -> None:
    target = max(0, target_visible_quantity)
    rows = (
        db.execute(
            select(ProductionSubOrder)
            .where(ProductionSubOrder.order_process_id == process_row.id)
            .order_by(ProductionSubOrder.operator_user_id.asc(), ProductionSubOrder.id.asc())
        )
        .scalars()
        .all()
    )

    if not rows:
        _create_initial_sub_orders_for_process(
            db,
            process_row=process_row,
            visible_quantity=target,
        )
        return

    assigned_total = sum(row.assigned_quantity for row in rows)
    if target > assigned_total:
        delta = target - assigned_total
        for idx in range(delta):
            row = rows[idx % len(rows)]
            row.assigned_quantity += 1
            if row.status == SUB_ORDER_STATUS_DONE and row.assigned_quantity > row.completed_quantity:
                row.status = SUB_ORDER_STATUS_PENDING
                row.is_visible = True

    for row in rows:
        if row.completed_quantity >= row.assigned_quantity:
            row.status = SUB_ORDER_STATUS_DONE
            row.is_visible = False
        else:
            if row.status == SUB_ORDER_STATUS_DONE:
                row.status = SUB_ORDER_STATUS_PENDING
            row.is_visible = row.assigned_quantity > 0

    db.flush()


def get_order_by_id(db: Session, order_id: int, *, with_relations: bool = False) -> ProductionOrder | None:
    stmt = select(ProductionOrder).where(ProductionOrder.id == order_id)
    if with_relations:
        stmt = stmt.options(
            selectinload(ProductionOrder.product),
            selectinload(ProductionOrder.created_by),
            selectinload(ProductionOrder.processes).selectinload(ProductionOrderProcess.sub_orders).selectinload(
                ProductionSubOrder.operator
            ),
            selectinload(ProductionOrder.production_records).selectinload(ProductionRecord.operator),
            selectinload(ProductionOrder.event_logs).selectinload(OrderEventLog.operator),
        )
    return db.execute(stmt).scalars().first()


def get_order_by_code(db: Session, order_code: str) -> ProductionOrder | None:
    stmt = select(ProductionOrder).where(ProductionOrder.order_code == order_code)
    return db.execute(stmt).scalars().first()


def list_orders(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    status: str | None,
) -> tuple[int, list[ProductionOrder]]:
    stmt = select(ProductionOrder).join(Product, Product.id == ProductionOrder.product_id)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                ProductionOrder.order_code.ilike(like_pattern),
                Product.name.ilike(like_pattern),
            )
        )
    if status:
        stmt = stmt.where(ProductionOrder.status == status.strip())

    stmt = stmt.order_by(ProductionOrder.id.desc())
    total = db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one()
    offset = (page - 1) * page_size
    rows = (
        db.execute(
            stmt.options(
                selectinload(ProductionOrder.product),
                selectinload(ProductionOrder.created_by),
                selectinload(ProductionOrder.processes),
            )
            .offset(offset)
            .limit(page_size)
        )
        .scalars()
        .all()
    )
    return total, rows


def _build_order_process_rows(
    db: Session,
    *,
    order: ProductionOrder,
    process_codes: list[str],
) -> list[ProductionOrderProcess]:
    processes, missing_codes = _resolve_processes_by_codes(db, process_codes)
    if missing_codes:
        raise ValueError(f"Process codes not found: {', '.join(missing_codes)}")
    if not processes:
        raise ValueError("At least one process is required")

    rows: list[ProductionOrderProcess] = []
    for idx, process in enumerate(processes):
        row = ProductionOrderProcess(
            order_id=order.id,
            process_id=process.id,
            process_code=process.code,
            process_name=process.name,
            process_order=idx + 1,
            status=PROCESS_STATUS_PENDING,
            visible_quantity=order.quantity if idx == 0 else 0,
            completed_quantity=0,
        )
        db.add(row)
        rows.append(row)
    db.flush()
    return rows


def create_order(
    db: Session,
    *,
    order_code: str,
    product_id: int,
    quantity: int,
    start_date: date | None,
    due_date: date | None,
    remark: str | None,
    process_codes: list[str],
    operator: User,
) -> ProductionOrder:
    normalized_order_code = order_code.strip()
    if not normalized_order_code:
        raise ValueError("Order code is required")
    if quantity <= 0:
        raise ValueError("Quantity must be greater than 0")
    if get_order_by_code(db, normalized_order_code):
        raise ValueError("Order code already exists")
    product = db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    if not product:
        raise ValueError("Product not found")

    normalized_process_codes = _normalize_process_codes(process_codes)
    if not normalized_process_codes:
        raise ValueError("At least one process is required")

    order = ProductionOrder(
        order_code=normalized_order_code,
        product_id=product_id,
        quantity=quantity,
        status=ORDER_STATUS_PENDING,
        current_process_code=normalized_process_codes[0],
        start_date=start_date,
        due_date=due_date,
        remark=(remark or "").strip() or None,
        created_by_user_id=operator.id,
    )
    db.add(order)
    db.flush()

    process_rows = _build_order_process_rows(
        db,
        order=order,
        process_codes=normalized_process_codes,
    )
    for row in process_rows:
        ensure_sub_orders_visible_quantity(
            db,
            process_row=row,
            target_visible_quantity=row.visible_quantity,
        )

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="order_created",
        event_title="订单已创建",
        event_detail=f"订单 {order.order_code} 已创建，工序数：{len(process_rows)}。",
        operator_user_id=operator.id,
        payload={
            "order_code": order.order_code,
            "quantity": order.quantity,
            "process_codes": normalized_process_codes,
        },
    )
    db.commit()
    db.refresh(order)
    return order


def update_order(
    db: Session,
    *,
    order: ProductionOrder,
    product_id: int,
    quantity: int,
    start_date: date | None,
    due_date: date | None,
    remark: str | None,
    process_codes: list[str],
    operator: User,
) -> ProductionOrder:
    if order.status != ORDER_STATUS_PENDING:
        raise ValueError("Only pending orders can be updated")
    if quantity <= 0:
        raise ValueError("Quantity must be greater than 0")
    product = db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    if not product:
        raise ValueError("Product not found")

    normalized_process_codes = _normalize_process_codes(process_codes)
    if not normalized_process_codes:
        raise ValueError("At least one process is required")

    # Rebuild process/sub-order assignment for pending orders.
    db.execute(select(ProductionOrderProcess).where(ProductionOrderProcess.order_id == order.id).with_for_update())
    order.processes = []
    db.flush()

    order.product_id = product_id
    order.quantity = quantity
    order.start_date = start_date
    order.due_date = due_date
    order.remark = (remark or "").strip() or None
    order.status = ORDER_STATUS_PENDING
    order.current_process_code = normalized_process_codes[0]

    process_rows = _build_order_process_rows(
        db,
        order=order,
        process_codes=normalized_process_codes,
    )
    for row in process_rows:
        ensure_sub_orders_visible_quantity(
            db,
            process_row=row,
            target_visible_quantity=row.visible_quantity,
        )

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="order_updated",
        event_title="订单已更新",
        event_detail=f"订单 {order.order_code} 已更新并重建工序路线。",
        operator_user_id=operator.id,
        payload={
            "quantity": order.quantity,
            "process_codes": normalized_process_codes,
        },
    )
    db.commit()
    db.refresh(order)
    return order


def delete_order(
    db: Session,
    *,
    order: ProductionOrder,
) -> None:
    if order.status != ORDER_STATUS_PENDING:
        raise ValueError("Only pending orders can be deleted")
    db.delete(order)
    db.commit()


def complete_order_manually(
    db: Session,
    *,
    order: ProductionOrder,
    operator: User,
) -> ProductionOrder:
    if order.status == ORDER_STATUS_COMPLETED:
        return order
    rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == order.id)
            .options(selectinload(ProductionOrderProcess.sub_orders))
            .order_by(ProductionOrderProcess.process_order.asc())
        )
        .scalars()
        .all()
    )
    for row in rows:
        row.visible_quantity = max(row.visible_quantity, order.quantity)
        row.completed_quantity = max(row.completed_quantity, order.quantity)
        row.status = PROCESS_STATUS_COMPLETED
        for sub in row.sub_orders:
            sub.assigned_quantity = max(sub.assigned_quantity, sub.completed_quantity)
            sub.completed_quantity = max(sub.completed_quantity, sub.assigned_quantity)
            sub.status = SUB_ORDER_STATUS_DONE
            sub.is_visible = False

    order.status = ORDER_STATUS_COMPLETED
    order.current_process_code = None

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="order_completed_manual",
        event_title="订单手工完工",
        event_detail=f"订单 {order.order_code} 已被手工标记为完工。",
        operator_user_id=operator.id,
    )
    db.commit()
    db.refresh(order)
    return order


def _build_my_order_item(
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
    sub_order: ProductionSubOrder | None,
    is_operator_context: bool,
) -> dict[str, object]:
    process_remaining = max(process_row.visible_quantity - process_row.completed_quantity, 0)
    sub_remaining = process_remaining
    if sub_order is not None:
        sub_remaining = max(sub_order.assigned_quantity - sub_order.completed_quantity, 0)
    max_producible = min(process_remaining, sub_remaining)

    can_first_article = False
    can_end_production = False
    if is_operator_context and sub_order is not None and sub_order.is_visible:
        can_first_article = (
            process_row.status in {PROCESS_STATUS_PENDING, PROCESS_STATUS_PARTIAL}
            and sub_order.status == SUB_ORDER_STATUS_PENDING
            and max_producible > 0
        )
        can_end_production = (
            process_row.status == PROCESS_STATUS_IN_PROGRESS
            and sub_order.status == SUB_ORDER_STATUS_IN_PROGRESS
            and max_producible > 0
        )

    return {
        "order_id": order.id,
        "order_code": order.order_code,
        "product_id": order.product_id,
        "product_name": order.product.name if order.product else "",
        "quantity": order.quantity,
        "order_status": order.status,
        "current_process_id": process_row.id,
        "current_process_code": process_row.process_code,
        "current_process_name": process_row.process_name,
        "current_process_order": process_row.process_order,
        "process_status": process_row.status,
        "visible_quantity": process_row.visible_quantity,
        "process_completed_quantity": process_row.completed_quantity,
        "user_sub_order_id": sub_order.id if sub_order else None,
        "user_assigned_quantity": sub_order.assigned_quantity if sub_order else None,
        "user_completed_quantity": sub_order.completed_quantity if sub_order else None,
        "max_producible_quantity": max_producible,
        "can_first_article": can_first_article,
        "can_end_production": can_end_production,
        "updated_at": order.updated_at,
    }


def list_my_orders(
    db: Session,
    *,
    current_user: User,
    keyword: str | None,
    page: int,
    page_size: int,
) -> tuple[int, list[dict[str, object]]]:
    role_codes = {role.code for role in current_user.roles}
    is_admin_context = bool(role_codes.intersection(ADMIN_QUERY_ROLE_CODES))

    items: list[dict[str, object]] = []
    if is_admin_context:
        stmt = (
            select(ProductionOrder)
            .where(ProductionOrder.status != ORDER_STATUS_COMPLETED)
            .options(selectinload(ProductionOrder.product), selectinload(ProductionOrder.processes))
            .order_by(ProductionOrder.updated_at.desc(), ProductionOrder.id.desc())
        )
        if keyword:
            like_pattern = f"%{keyword.strip()}%"
            stmt = stmt.join(Product, Product.id == ProductionOrder.product_id).where(
                or_(
                    ProductionOrder.order_code.ilike(like_pattern),
                    Product.name.ilike(like_pattern),
                )
            )
        orders = db.execute(stmt).scalars().all()
        for order in orders:
            process_rows = sorted(order.processes, key=lambda row: (row.process_order, row.id))
            current_process = next(
                (row for row in process_rows if row.status != PROCESS_STATUS_COMPLETED),
                None,
            )
            if current_process is None:
                continue
            items.append(
                _build_my_order_item(
                    order=order,
                    process_row=current_process,
                    sub_order=None,
                    is_operator_context=False,
                )
            )
    else:
        stmt = (
            select(ProductionSubOrder)
            .join(ProductionSubOrder.order_process)
            .join(ProductionOrderProcess.order)
            .where(
                ProductionSubOrder.operator_user_id == current_user.id,
                ProductionSubOrder.is_visible.is_(True),
                ProductionOrder.status != ORDER_STATUS_COMPLETED,
                ProductionOrderProcess.status != PROCESS_STATUS_COMPLETED,
            )
            .options(
                selectinload(ProductionSubOrder.order_process).selectinload(ProductionOrderProcess.order).selectinload(
                    ProductionOrder.product
                )
            )
            .order_by(ProductionOrder.updated_at.desc(), ProductionSubOrder.id.desc())
        )
        if keyword:
            like_pattern = f"%{keyword.strip()}%"
            stmt = stmt.join(Product, Product.id == ProductionOrder.product_id).where(
                or_(
                    ProductionOrder.order_code.ilike(like_pattern),
                    Product.name.ilike(like_pattern),
                )
            )
        sub_orders = db.execute(stmt).scalars().all()
        for sub_order in sub_orders:
            process_row = sub_order.order_process
            order = process_row.order
            if order is None:
                continue
            items.append(
                _build_my_order_item(
                    order=order,
                    process_row=process_row,
                    sub_order=sub_order,
                    is_operator_context=True,
                )
            )

    total = len(items)
    offset = (page - 1) * page_size
    return total, items[offset : offset + page_size]
