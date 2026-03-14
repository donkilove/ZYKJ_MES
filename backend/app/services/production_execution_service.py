from __future__ import annotations

from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_PENDING,
    RECORD_TYPE_FIRST_ARTICLE,
    RECORD_TYPE_PRODUCTION,
    SUB_ORDER_STATUS_DONE,
    SUB_ORDER_STATUS_IN_PROGRESS,
    SUB_ORDER_STATUS_PENDING,
)
from app.models.daily_verification_code import DailyVerificationCode
from app.models.first_article_record import FirstArticleRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_sub_order import ProductionSubOrder
from app.models.user import User
from app.services.assist_authorization_service import (
    ASSIST_OP_END_PRODUCTION,
    ASSIST_OP_FIRST_ARTICLE,
    get_usable_assist_authorization_for_operation,
    mark_assist_authorization_used,
)
from app.services.production_event_log_service import add_order_event_log
from app.services.production_order_service import (
    ensure_sub_orders_visible_quantity,
    is_pipeline_parallel_edge_for_processes,
)
from app.services.production_repair_service import create_repair_order


def _get_today_verification_code(
    db: Session,
    *,
    operator_user_id: int,
) -> DailyVerificationCode:
    today = date.today()
    row = db.execute(
        select(DailyVerificationCode)
        .where(DailyVerificationCode.verify_date == today)
        .with_for_update()
    ).scalars().first()
    if row:
        return row
    row = DailyVerificationCode(
        verify_date=today,
        code=settings.production_default_verification_code,
        created_by_user_id=operator_user_id,
    )
    db.add(row)
    db.flush()
    return row


def _lock_order_and_process(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
) -> tuple[ProductionOrder, ProductionOrderProcess]:
    order = db.execute(
        select(ProductionOrder).where(ProductionOrder.id == order_id).with_for_update()
    ).scalars().first()
    if not order:
        raise ValueError("Order not found")

    process_row = db.execute(
        select(ProductionOrderProcess)
        .where(
            ProductionOrderProcess.id == order_process_id,
            ProductionOrderProcess.order_id == order_id,
        )
        .with_for_update()
    ).scalars().first()
    if not process_row:
        raise ValueError("Order process not found")
    return order, process_row


def _lock_sub_order(
    db: Session,
    *,
    order_process_id: int,
    operator_user_id: int,
) -> ProductionSubOrder:
    row = db.execute(
        select(ProductionSubOrder)
        .where(
            ProductionSubOrder.order_process_id == order_process_id,
            ProductionSubOrder.operator_user_id == operator_user_id,
        )
        .with_for_update()
    ).scalars().first()
    if not row:
        raise ValueError("Sub-order assignment not found for current user")
    if not row.is_visible:
        raise ValueError("Sub-order is not visible for current user")
    return row


def _activate_visible_sub_orders(
    db: Session,
    *,
    order_process_id: int,
) -> None:
    rows = (
        db.execute(
            select(ProductionSubOrder)
            .where(
                ProductionSubOrder.order_process_id == order_process_id,
                ProductionSubOrder.is_visible.is_(True),
                ProductionSubOrder.status == SUB_ORDER_STATUS_PENDING,
            )
            .with_for_update()
        )
        .scalars()
        .all()
    )
    for row in rows:
        if row.assigned_quantity > row.completed_quantity:
            row.status = SUB_ORDER_STATUS_IN_PROGRESS


def _lock_previous_process(
    db: Session,
    *,
    order_id: int,
    process_order: int,
) -> ProductionOrderProcess | None:
    if process_order <= 1:
        return None
    return db.execute(
        select(ProductionOrderProcess)
        .where(
            ProductionOrderProcess.order_id == order_id,
            ProductionOrderProcess.process_order == process_order - 1,
        )
        .with_for_update()
    ).scalars().first()


def _is_start_gate_allowed(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> bool:
    previous_process = _lock_previous_process(
        db,
        order_id=order.id,
        process_order=process_row.process_order,
    )
    if previous_process is None:
        return True
    if is_pipeline_parallel_edge_for_processes(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        return previous_process.completed_quantity > 0
    return previous_process.status == PROCESS_STATUS_COMPLETED


def _is_end_gate_allowed(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> bool:
    previous_process = _lock_previous_process(
        db,
        order_id=order.id,
        process_order=process_row.process_order,
    )
    if previous_process is None:
        return True
    if is_pipeline_parallel_edge_for_processes(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        return previous_process.completed_quantity > 0
    return True


def _refresh_order_status(db: Session, *, order: ProductionOrder) -> None:
    process_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == order.id)
            .order_by(ProductionOrderProcess.process_order.asc(), ProductionOrderProcess.id.asc())
            .with_for_update()
        )
        .scalars()
        .all()
    )
    all_completed = all(row.status == PROCESS_STATUS_COMPLETED for row in process_rows)
    if all_completed and process_rows:
        order.status = ORDER_STATUS_COMPLETED
        order.current_process_code = None
        return

    order.status = ORDER_STATUS_IN_PROGRESS
    for row in process_rows:
        if row.status != PROCESS_STATUS_COMPLETED:
            order.current_process_code = row.process_code
            break


def submit_first_article(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    verification_code: str,
    remark: str | None,
    operator: User,
    effective_operator_user_id: int | None = None,
    assist_authorization_id: int | None = None,
) -> tuple[ProductionOrder, ProductionOrderProcess, ProductionSubOrder]:
    order, process_row = _lock_order_and_process(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    if order.status == ORDER_STATUS_COMPLETED:
        raise ValueError("Order already completed")
    if process_row.status not in {PROCESS_STATUS_PENDING, PROCESS_STATUS_PARTIAL}:
        raise ValueError("Current process does not allow first-article operation")

    effective_user_id = effective_operator_user_id or operator.id
    assist_row = None
    if effective_user_id != operator.id:
        if not assist_authorization_id:
            raise ValueError("Assist authorization is required for cross-user operation")
        assist_row = get_usable_assist_authorization_for_operation(
            db,
            authorization_id=assist_authorization_id,
            order_id=order_id,
            order_process_id=order_process_id,
            target_operator_user_id=effective_user_id,
            helper_user_id=operator.id,
            operation=ASSIST_OP_FIRST_ARTICLE,
        )

    sub_order = _lock_sub_order(
        db,
        order_process_id=process_row.id,
        operator_user_id=effective_user_id,
    )
    if sub_order.status != SUB_ORDER_STATUS_PENDING:
        raise ValueError("Current sub-order does not allow first-article operation")

    process_remaining = max(process_row.visible_quantity - process_row.completed_quantity, 0)
    sub_remaining = max(sub_order.assigned_quantity - sub_order.completed_quantity, 0)
    if min(process_remaining, sub_remaining) <= 0:
        raise ValueError("No producible quantity available for current user")
    if not _is_start_gate_allowed(db, order=order, process_row=process_row):
        raise ValueError("Current process is blocked by pipeline start gate")

    code_row = _get_today_verification_code(db, operator_user_id=operator.id)
    if verification_code.strip() != code_row.code:
        raise ValueError("Invalid verification code")

    process_row.status = PROCESS_STATUS_IN_PROGRESS
    _activate_visible_sub_orders(db, order_process_id=process_row.id)
    sub_order.status = SUB_ORDER_STATUS_IN_PROGRESS
    sub_order.is_visible = True
    order.status = ORDER_STATUS_IN_PROGRESS
    if not order.current_process_code:
        order.current_process_code = process_row.process_code

    first_article_row = FirstArticleRecord(
        order_id=order.id,
        order_process_id=process_row.id,
        operator_user_id=operator.id,
        verification_date=date.today(),
        verification_code=verification_code.strip(),
        result="passed",
        remark=(remark or "").strip() or None,
    )
    db.add(first_article_row)
    db.add(
        ProductionRecord(
            order_id=order.id,
            order_process_id=process_row.id,
            sub_order_id=sub_order.id,
            operator_user_id=operator.id,
            production_quantity=0,
            record_type=RECORD_TYPE_FIRST_ARTICLE,
        )
    )
    add_order_event_log(
        db,
        order_id=order.id,
        event_type="first_article_passed",
        event_title="首件通过",
        event_detail=(
            f"{operator.username} 在工序 {process_row.process_name} 提交首件并开工。"
            if not remark
            else f"{operator.username} 在工序 {process_row.process_name} 提交首件并开工。{remark.strip()}"
        ),
        operator_user_id=operator.id,
        payload={
            "order_process_id": process_row.id,
            "process_code": process_row.process_code,
            "operator_user_id": operator.id,
            "effective_operator_user_id": effective_user_id,
            "assist_authorization_id": assist_row.id if assist_row else None,
        },
    )
    if assist_row is not None:
        mark_assist_authorization_used(
            db,
            authorization_row=assist_row,
            operation=ASSIST_OP_FIRST_ARTICLE,
        )
    db.commit()
    db.refresh(order)
    db.refresh(process_row)
    db.refresh(sub_order)
    return order, process_row, sub_order


def end_production(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    quantity: int,
    remark: str | None,
    operator: User,
    effective_operator_user_id: int | None = None,
    assist_authorization_id: int | None = None,
    defect_items: list[dict[str, object]] | None = None,
) -> tuple[ProductionOrder, ProductionOrderProcess, ProductionSubOrder]:
    if quantity <= 0:
        raise ValueError("Quantity must be greater than 0")

    order, process_row = _lock_order_and_process(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    if order.status == ORDER_STATUS_COMPLETED:
        raise ValueError("Order already completed")
    if process_row.status != PROCESS_STATUS_IN_PROGRESS:
        raise ValueError("Current process is not in progress")

    effective_user_id = effective_operator_user_id or operator.id
    assist_row = None
    if effective_user_id != operator.id:
        if not assist_authorization_id:
            raise ValueError("Assist authorization is required for cross-user operation")
        assist_row = get_usable_assist_authorization_for_operation(
            db,
            authorization_id=assist_authorization_id,
            order_id=order_id,
            order_process_id=order_process_id,
            target_operator_user_id=effective_user_id,
            helper_user_id=operator.id,
            operation=ASSIST_OP_END_PRODUCTION,
        )

    sub_order = _lock_sub_order(
        db,
        order_process_id=process_row.id,
        operator_user_id=effective_user_id,
    )
    if sub_order.status != SUB_ORDER_STATUS_IN_PROGRESS:
        raise ValueError("Current sub-order is not in progress")

    process_remaining = max(process_row.visible_quantity - process_row.completed_quantity, 0)
    sub_remaining = max(sub_order.assigned_quantity - sub_order.completed_quantity, 0)
    max_producible = min(process_remaining, sub_remaining)
    if max_producible <= 0:
        raise ValueError("No producible quantity available for current user")
    if quantity > max_producible:
        raise RuntimeError(f"Concurrent update detected. Max producible quantity is {max_producible}")
    if not _is_end_gate_allowed(db, order=order, process_row=process_row):
        raise ValueError("Current process is blocked by pipeline end gate")

    process_row.completed_quantity += quantity
    sub_order.completed_quantity += quantity

    if process_row.completed_quantity >= order.quantity:
        process_row.completed_quantity = order.quantity
        process_row.status = PROCESS_STATUS_COMPLETED
    else:
        process_row.status = PROCESS_STATUS_PARTIAL

    if sub_order.completed_quantity >= sub_order.assigned_quantity:
        sub_order.status = SUB_ORDER_STATUS_DONE
        sub_order.is_visible = False
    else:
        sub_order.status = SUB_ORDER_STATUS_PENDING
        sub_order.is_visible = True

    next_process = db.execute(
        select(ProductionOrderProcess)
        .where(
            ProductionOrderProcess.order_id == order.id,
            ProductionOrderProcess.process_order == process_row.process_order + 1,
        )
        .with_for_update()
    ).scalars().first()
    if next_process:
        parallel_edge = is_pipeline_parallel_edge_for_processes(
            order=order,
            previous_process_code=process_row.process_code,
            current_process_code=next_process.process_code,
        )
        if parallel_edge:
            target_visible = min(process_row.completed_quantity, order.quantity)
        elif process_row.status == PROCESS_STATUS_COMPLETED:
            target_visible = order.quantity
        else:
            target_visible = next_process.visible_quantity
        if target_visible > next_process.visible_quantity:
            next_process.visible_quantity = target_visible
        ensure_sub_orders_visible_quantity(
            db,
            process_row=next_process,
            target_visible_quantity=next_process.visible_quantity,
        )

    repair_row = None
    if defect_items:
        defect_quantity = sum(
            int(item.get("quantity") or 0)
            for item in defect_items
            if isinstance(item, dict)
        )
        if defect_quantity > 0:
            repair_row = create_repair_order(
                db,
                order_id=order.id,
                order_process_id=process_row.id,
                sender=operator,
                production_quantity=quantity + defect_quantity,
                defect_items=defect_items,
                auto_created=True,
            )

    db.add(
        ProductionRecord(
            order_id=order.id,
            order_process_id=process_row.id,
            sub_order_id=sub_order.id,
            operator_user_id=operator.id,
            production_quantity=quantity,
            record_type=RECORD_TYPE_PRODUCTION,
        )
    )
    add_order_event_log(
        db,
        order_id=order.id,
        event_type="production_reported",
        event_title="报工完成",
        event_detail=(
            f"{operator.username} 在工序 {process_row.process_name} 报工 {quantity} 件。"
            if not remark
            else f"{operator.username} 在工序 {process_row.process_name} 报工 {quantity} 件。{remark.strip()}"
        ),
        operator_user_id=operator.id,
        payload={
            "order_process_id": process_row.id,
            "process_code": process_row.process_code,
            "quantity": quantity,
            "operator_user_id": operator.id,
            "effective_operator_user_id": effective_user_id,
            "assist_authorization_id": assist_row.id if assist_row else None,
            "repair_order_id": repair_row.id if repair_row else None,
            "repair_order_code": repair_row.repair_order_code if repair_row else None,
        },
    )
    if assist_row is not None:
        mark_assist_authorization_used(
            db,
            authorization_row=assist_row,
            operation=ASSIST_OP_END_PRODUCTION,
        )

    _refresh_order_status(db, order=order)
    db.commit()
    db.refresh(order)
    db.refresh(process_row)
    db.refresh(sub_order)
    return order, process_row, sub_order
