from __future__ import annotations

import base64
import csv
import io
from collections.abc import Iterable
from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import exists, func, or_, select, update
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
from app.core.product_lifecycle import PRODUCT_LIFECYCLE_ACTIVE
from app.core.authz_catalog import (
    PERM_PROD_MY_ORDERS_PROXY,
    PERM_PROD_MY_ORDERS_VIEW_ALL,
    PERM_PROD_ORDERS_DETAIL_ALL,
    PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE,
    PERM_PROD_ORDERS_PIPELINE_MODE_VIEW_ALL,
)
from app.core.rbac import ROLE_OPERATOR
from app.models.process import Process
from app.models.order_sub_order_pipeline_instance import OrderSubOrderPipelineInstance
from app.models.production_assist_authorization import ProductionAssistAuthorization
from app.models.process_stage import ProcessStage
from app.models.product import Product
from app.models.product_process_template import ProductProcessTemplate
from app.models.product_process_template_step import ProductProcessTemplateStep
from app.models.production_record import ProductionRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_sub_order import ProductionSubOrder
from app.models.order_event_log import OrderEventLog
from app.models.user import User
from app.services.assist_authorization_service import ASSIST_STATUS_APPROVED, ASSIST_STATUS_CONSUMED
from app.services.authz_service import has_permission
from app.services.production_event_log_service import add_order_event_log

def _normalize_process_codes(process_codes: Iterable[str]) -> list[str]:
    normalized = [item.strip() for item in process_codes if item and item.strip()]
    deduped = list(dict.fromkeys(normalized))
    return deduped


def _parse_pipeline_process_codes_text(value: str | None) -> list[str]:
    if not value:
        return []
    return _normalize_process_codes(value.split(","))


def _pipeline_process_codes_to_text(process_codes: Iterable[str]) -> str:
    return ",".join(_normalize_process_codes(process_codes))


def _sorted_order_processes(order: ProductionOrder) -> list[ProductionOrderProcess]:
    return sorted(order.processes, key=lambda row: (row.process_order, row.id))


def _route_process_codes_from_order(order: ProductionOrder) -> list[str]:
    return [row.process_code for row in _sorted_order_processes(order)]


def _ordered_selected_pipeline_codes(
    *,
    route_process_codes: list[str],
    requested_codes: Iterable[str],
) -> list[str]:
    requested_set = set(_normalize_process_codes(requested_codes))
    if not requested_set:
        return []
    return [code for code in route_process_codes if code in requested_set]


def _pipeline_selected_code_set(order: ProductionOrder) -> set[str]:
    if not order.pipeline_enabled:
        return set()
    return set(_parse_pipeline_process_codes_text(order.pipeline_process_codes))


def _is_parallel_edge_enabled(
    *,
    order: ProductionOrder,
    previous_process_code: str,
    current_process_code: str,
) -> bool:
    selected_codes = _pipeline_selected_code_set(order)
    if not selected_codes:
        return False
    return previous_process_code in selected_codes and current_process_code in selected_codes


def is_pipeline_parallel_edge_for_processes(
    *,
    order: ProductionOrder,
    previous_process_code: str,
    current_process_code: str,
) -> bool:
    return _is_parallel_edge_enabled(
        order=order,
        previous_process_code=previous_process_code,
        current_process_code=current_process_code,
    )


def _find_previous_process_row(
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> ProductionOrderProcess | None:
    if process_row.process_order <= 1:
        return None
    return next(
        (
            row
            for row in order.processes
            if row.process_order == process_row.process_order - 1
        ),
        None,
    )


def is_pipeline_start_allowed_for_process(
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> bool:
    previous_process = _find_previous_process_row(order=order, process_row=process_row)
    if previous_process is None:
        return True
    if _is_parallel_edge_enabled(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        return previous_process.completed_quantity > 0
    return previous_process.status == PROCESS_STATUS_COMPLETED


def is_pipeline_end_allowed_for_process(
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> bool:
    previous_process = _find_previous_process_row(order=order, process_row=process_row)
    if previous_process is None:
        return True
    if _is_parallel_edge_enabled(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        return previous_process.completed_quantity > 0
    return True


def _resolve_processes_by_codes(db: Session, process_codes: list[str]) -> tuple[list[Process], list[str]]:
    if not process_codes:
        return [], []
    stmt = select(Process).where(Process.code.in_(process_codes)).options(selectinload(Process.stage))
    rows = db.execute(stmt).scalars().all()
    by_code = {row.code: row for row in rows}
    missing = [code for code in process_codes if code not in by_code]
    ordered = [by_code[code] for code in process_codes if code in by_code]
    return ordered, missing


def _resolve_template(
    db: Session,
    *,
    template_id: int,
    product_id: int,
) -> ProductProcessTemplate:
    template = (
        db.execute(
            select(ProductProcessTemplate)
            .where(ProductProcessTemplate.id == template_id)
            .options(selectinload(ProductProcessTemplate.steps))
        )
        .scalars()
        .first()
    )
    if not template:
        raise ValueError("Template not found")
    if template.product_id != product_id:
        raise ValueError("Template does not belong to selected product")
    if not template.is_enabled:
        raise ValueError("Template is disabled")
    if template.lifecycle_status != "published":
        raise ValueError("Template is not published")
    return template


def _resolve_steps_from_payload(
    db: Session,
    *,
    process_steps: list[dict[str, int]],
) -> list[tuple[ProcessStage, Process]]:
    if not process_steps:
        return []
    ordered_steps = sorted(process_steps, key=lambda item: int(item["step_order"]))
    stage_ids = {int(item["stage_id"]) for item in ordered_steps}
    process_ids = {int(item["process_id"]) for item in ordered_steps}
    stage_rows = db.execute(select(ProcessStage).where(ProcessStage.id.in_(stage_ids))).scalars().all()
    process_rows = (
        db.execute(select(Process).where(Process.id.in_(process_ids)).options(selectinload(Process.stage))).scalars().all()
    )
    stage_by_id = {row.id: row for row in stage_rows}
    process_by_id = {row.id: row for row in process_rows}

    results: list[tuple[ProcessStage, Process]] = []
    for row in ordered_steps:
        stage_id = int(row["stage_id"])
        process_id = int(row["process_id"])
        stage = stage_by_id.get(stage_id)
        process = process_by_id.get(process_id)
        if not stage:
            raise ValueError(f"Stage not found: {stage_id}")
        if not process:
            raise ValueError(f"Process not found: {process_id}")
        if process.stage_id != stage.id:
            raise ValueError(f"Process {process.code} does not belong to stage {stage.code}")
        if not stage.is_enabled:
            raise ValueError(f"Stage disabled: {stage.code}")
        if not process.is_enabled:
            raise ValueError(f"Process disabled: {process.code}")
        results.append((stage, process))
    return results


def _resolve_route_steps(
    db: Session,
    *,
    product_id: int,
    template_id: int | None,
    process_steps: list[dict[str, int]] | None,
    process_codes: list[str],
) -> tuple[list[tuple[ProcessStage, Process]], ProductProcessTemplate | None]:
    if process_steps:
        resolved = _resolve_steps_from_payload(db, process_steps=process_steps)
        if not resolved:
            raise ValueError("At least one process is required")
        template = _resolve_template(db, template_id=template_id, product_id=product_id) if template_id else None
        return resolved, template

    if template_id:
        template = _resolve_template(db, template_id=template_id, product_id=product_id)
        stage_by_code = {
            row.code: row
            for row in db.execute(
                select(ProcessStage).where(ProcessStage.is_enabled.is_(True))
            )
            .scalars()
            .all()
        }
        process_codes_in_template = [item.process_code for item in sorted(template.steps, key=lambda item: item.step_order)]
        processes, missing_codes = _resolve_processes_by_codes(db, process_codes_in_template)
        if missing_codes:
            raise ValueError(f"Template process codes not found: {', '.join(missing_codes)}")
        process_by_code = {row.code: row for row in processes}
        results: list[tuple[ProcessStage, Process]] = []
        for step in sorted(template.steps, key=lambda item: item.step_order):
            process = process_by_code.get(step.process_code)
            stage = stage_by_code.get(step.stage_code)
            if not process or not stage:
                raise ValueError("Template contains invalid stage/process")
            results.append((stage, process))
        if not results:
            raise ValueError("Template contains no process steps")
        return results, template

    normalized_codes = _normalize_process_codes(process_codes)
    if not normalized_codes:
        raise ValueError("At least one process is required")
    processes, missing_codes = _resolve_processes_by_codes(db, normalized_codes)
    if missing_codes:
        raise ValueError(f"Process codes not found: {', '.join(missing_codes)}")
    results: list[tuple[ProcessStage, Process]] = []
    for process in processes:
        if not process.stage:
            raise ValueError(f"Process stage missing: {process.code}")
        results.append((process.stage, process))
    return results, None


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
) -> bool:
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
    changed = False

    if not rows:
        _create_initial_sub_orders_for_process(
            db,
            process_row=process_row,
            visible_quantity=target,
        )
        return True

    # Backfill newly assigned operators for historical orders.
    existing_operator_ids = {row.operator_user_id for row in rows}
    operator_users = _list_operator_users_by_process_code(db, process_row.process_code)
    missing_operator_users = [user for user in operator_users if user.id not in existing_operator_ids]
    if missing_operator_users:
        for user in missing_operator_users:
            db.add(
                ProductionSubOrder(
                    order_process_id=process_row.id,
                    operator_user_id=user.id,
                    assigned_quantity=0,
                    completed_quantity=0,
                    status=SUB_ORDER_STATUS_DONE,
                    is_visible=False,
                )
            )
        db.flush()
        rows = (
            db.execute(
                select(ProductionSubOrder)
                .where(ProductionSubOrder.order_process_id == process_row.id)
                .order_by(ProductionSubOrder.operator_user_id.asc(), ProductionSubOrder.id.asc())
            )
            .scalars()
            .all()
        )
        changed = True

    assigned_total = sum(row.assigned_quantity for row in rows)
    if target > assigned_total:
        delta = target - assigned_total
        for idx in range(delta):
            row = rows[idx % len(rows)]
            row.assigned_quantity += 1
            if row.status == SUB_ORDER_STATUS_DONE and row.assigned_quantity > row.completed_quantity:
                row.status = SUB_ORDER_STATUS_PENDING
                row.is_visible = True
            changed = True

    for row in rows:
        previous_status = row.status
        previous_visible = row.is_visible
        if row.completed_quantity >= row.assigned_quantity:
            row.status = SUB_ORDER_STATUS_DONE
            row.is_visible = False
        else:
            if row.status == SUB_ORDER_STATUS_DONE:
                row.status = SUB_ORDER_STATUS_PENDING
            row.is_visible = row.assigned_quantity > 0
        if row.status != previous_status or row.is_visible != previous_visible:
            changed = True

    if changed:
        db.flush()
    return changed


def _backfill_operator_sub_orders(
    db: Session,
    *,
    current_user: User,
) -> bool:
    process_codes = _normalize_process_codes(process.code for process in current_user.processes)
    if not process_codes:
        return False

    process_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .join(ProductionOrder, ProductionOrder.id == ProductionOrderProcess.order_id)
            .where(
                ProductionOrder.status != ORDER_STATUS_COMPLETED,
                ProductionOrderProcess.status != PROCESS_STATUS_COMPLETED,
                ProductionOrderProcess.process_code.in_(process_codes),
            )
            .order_by(ProductionOrderProcess.id.asc())
        )
        .scalars()
        .all()
    )

    changed = False
    for process_row in process_rows:
        if ensure_sub_orders_visible_quantity(
            db,
            process_row=process_row,
            target_visible_quantity=process_row.visible_quantity,
        ):
            changed = True
    return changed


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


def can_user_access_order_pipeline_mode(
    db: Session,
    *,
    order_id: int,
    current_user: User,
) -> bool:
    if has_permission(
        db,
        user=current_user,
        permission_code=PERM_PROD_ORDERS_PIPELINE_MODE_VIEW_ALL,
    ):
        return True
    role_codes = {role.code for role in current_user.roles}
    if ROLE_OPERATOR not in role_codes:
        return False
    exists_stmt = (
        select(exists().where(
            ProductionSubOrder.operator_user_id == current_user.id,
            ProductionSubOrder.order_process_id == ProductionOrderProcess.id,
            ProductionOrderProcess.order_id == order_id,
        ))
    )
    return bool(db.execute(exists_stmt).scalar())


def can_user_access_order_detail(
    db: Session,
    *,
    order_id: int,
    current_user: User,
) -> bool:
    if has_permission(
        db,
        user=current_user,
        permission_code=PERM_PROD_ORDERS_DETAIL_ALL,
    ):
        return True
    role_codes = {role.code for role in current_user.roles}
    if ROLE_OPERATOR not in role_codes:
        return False

    assigned_stmt = select(
        exists().where(
            ProductionSubOrder.operator_user_id == current_user.id,
            ProductionSubOrder.order_process_id == ProductionOrderProcess.id,
            ProductionOrderProcess.order_id == order_id,
        )
    )
    if bool(db.execute(assigned_stmt).scalar()):
        return True

    assist_stmt = select(
        exists().where(
            ProductionAssistAuthorization.order_id == order_id,
            ProductionAssistAuthorization.helper_user_id == current_user.id,
            ProductionAssistAuthorization.status.in_([ASSIST_STATUS_APPROVED, ASSIST_STATUS_CONSUMED]),
        )
    )
    return bool(db.execute(assist_stmt).scalar())


def _invalidate_pipeline_instances_for_order(
    db: Session,
    *,
    order_id: int,
    reason: str,
) -> int:
    now = datetime.now(UTC)
    stmt = (
        update(OrderSubOrderPipelineInstance)
        .where(
            OrderSubOrderPipelineInstance.order_id == order_id,
            OrderSubOrderPipelineInstance.is_active.is_(True),
        )
        .values(
            is_active=False,
            invalid_reason=reason,
            invalidated_at=now,
            updated_at=now,
        )
    )
    result = db.execute(stmt)
    return int(result.rowcount or 0)


def _create_pipeline_instances_for_order(
    db: Session,
    *,
    order: ProductionOrder,
    selected_codes: list[str],
) -> int:
    if not selected_codes:
        return 0
    sub_rows = (
        db.execute(
            select(ProductionSubOrder, ProductionOrderProcess)
            .join(ProductionSubOrder.order_process)
            .where(
                ProductionOrderProcess.order_id == order.id,
                ProductionOrderProcess.process_code.in_(selected_codes),
            )
            .order_by(
                ProductionOrderProcess.process_order.asc(),
                ProductionSubOrder.operator_user_id.asc(),
                ProductionSubOrder.id.asc(),
            )
        )
        .all()
    )
    created = 0
    for pipeline_seq, (sub_order, process_row) in enumerate(sub_rows, start=1):
        pipeline_no = f"P{order.id}-{sub_order.id}-{pipeline_seq}-{uuid4().hex[:8]}"
        db.add(
            OrderSubOrderPipelineInstance(
                sub_order_id=sub_order.id,
                order_id=order.id,
                order_process_id=process_row.id,
                process_code=process_row.process_code,
                pipeline_seq=pipeline_seq,
                pipeline_sub_order_no=pipeline_no,
                is_active=True,
                invalid_reason=None,
                invalidated_at=None,
            )
        )
        created += 1
    if created:
        db.flush()
    return created


def get_order_pipeline_mode(
    db: Session,
    *,
    order_id: int,
) -> dict[str, object]:
    order = (
        db.execute(
            select(ProductionOrder)
            .where(ProductionOrder.id == order_id)
            .options(selectinload(ProductionOrder.processes))
        )
        .scalars()
        .first()
    )
    if not order:
        raise ValueError("Order not found")

    route_codes = _route_process_codes_from_order(order)
    selected_codes = _ordered_selected_pipeline_codes(
        route_process_codes=route_codes,
        requested_codes=_parse_pipeline_process_codes_text(order.pipeline_process_codes),
    )
    if not order.pipeline_enabled:
        selected_codes = []
    return {
        "order_id": order.id,
        "enabled": bool(order.pipeline_enabled),
        "process_codes": selected_codes,
        "available_process_codes": route_codes,
    }


def update_order_pipeline_mode(
    db: Session,
    *,
    order_id: int,
    enabled: bool,
    process_codes: list[str],
    operator: User,
) -> dict[str, object]:
    if not has_permission(
        db,
        user=operator,
        permission_code=PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE,
    ):
        raise PermissionError("Current user has no permission to update pipeline mode")

    order = (
        db.execute(
            select(ProductionOrder)
            .where(ProductionOrder.id == order_id)
            .options(selectinload(ProductionOrder.processes))
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if not order:
        raise ValueError("Order not found")
    if order.status == ORDER_STATUS_COMPLETED:
        raise ValueError("Completed order does not support pipeline mode update")

    process_rows = _sorted_order_processes(order)
    if len(process_rows) < 2 and enabled:
        raise ValueError("Order has fewer than 2 processes and cannot enable pipeline mode")
    route_codes = [row.process_code for row in process_rows]
    selected_codes = _ordered_selected_pipeline_codes(
        route_process_codes=route_codes,
        requested_codes=process_codes,
    )
    if enabled and len(selected_codes) < 2:
        raise ValueError("At least two valid process codes are required when enabling pipeline mode")
    invalid_codes = [code for code in _normalize_process_codes(process_codes) if code not in route_codes]
    if invalid_codes:
        raise ValueError(f"Invalid process codes for order route: {', '.join(invalid_codes)}")

    if enabled:
        first_code = selected_codes[0]
        first_row = next((row for row in process_rows if row.process_code == first_code), None)
        if first_row is None:
            raise ValueError("Selected first process does not exist in order route")
        first_available = max(first_row.visible_quantity - first_row.completed_quantity, 0)
        if first_available <= 0:
            raise ValueError(
                f"Cannot enable pipeline mode: first selected process {first_code} has no producible quantity"
            )

    previous_enabled = bool(order.pipeline_enabled)
    previous_codes = _ordered_selected_pipeline_codes(
        route_process_codes=route_codes,
        requested_codes=_parse_pipeline_process_codes_text(order.pipeline_process_codes),
    )

    order.pipeline_enabled = bool(enabled)
    order.pipeline_process_codes = _pipeline_process_codes_to_text(selected_codes if enabled else [])

    reason = "pipeline_reconfigured" if enabled else "pipeline_disabled"
    invalidated_count = _invalidate_pipeline_instances_for_order(
        db,
        order_id=order.id,
        reason=reason,
    )
    created_count = 0
    if enabled:
        created_count = _create_pipeline_instances_for_order(
            db,
            order=order,
            selected_codes=selected_codes,
        )

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="pipeline_mode_updated",
        event_title="并行模式更新",
        event_detail=(
            f"{operator.username} 将并行模式设为 {'开启' if enabled else '关闭'}；"
            f"工序: {', '.join(selected_codes) if selected_codes else '-'}"
        ),
        operator_user_id=operator.id,
        payload={
            "enabled": bool(enabled),
            "process_codes": selected_codes if enabled else [],
            "previous_enabled": previous_enabled,
            "previous_process_codes": previous_codes,
        },
    )
    if invalidated_count > 0:
        add_order_event_log(
            db,
            order_id=order.id,
            event_type="pipeline_instances_invalidated",
            event_title="并行实例失效",
            event_detail=f"已失效 {invalidated_count} 条并行实例，原因: {reason}",
            operator_user_id=operator.id,
            payload={
                "invalidated_count": invalidated_count,
                "reason": reason,
            },
        )
    if created_count > 0:
        add_order_event_log(
            db,
            order_id=order.id,
            event_type="pipeline_instances_activated",
            event_title="并行实例激活",
            event_detail=f"已激活 {created_count} 条并行实例",
            operator_user_id=operator.id,
            payload={
                "activated_count": created_count,
            },
        )

    db.commit()
    return {
        "order_id": order.id,
        "enabled": bool(order.pipeline_enabled),
        "process_codes": selected_codes if enabled else [],
        "available_process_codes": route_codes,
    }


def list_orders(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    status: str | None,
    product_name: str | None = None,
    pipeline_enabled: bool | None = None,
    start_date_from: date | None = None,
    start_date_to: date | None = None,
    due_date_from: date | None = None,
    due_date_to: date | None = None,
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
    if product_name:
        stmt = stmt.where(Product.name.ilike(f"%{product_name.strip()}%"))
    if pipeline_enabled is not None:
        stmt = stmt.where(ProductionOrder.pipeline_enabled == pipeline_enabled)
    if start_date_from:
        stmt = stmt.where(ProductionOrder.start_date >= start_date_from)
    if start_date_to:
        stmt = stmt.where(ProductionOrder.start_date <= start_date_to)
    if due_date_from:
        stmt = stmt.where(ProductionOrder.due_date >= due_date_from)
    if due_date_to:
        stmt = stmt.where(ProductionOrder.due_date <= due_date_to)

    stmt = stmt.order_by(ProductionOrder.updated_at.desc(), ProductionOrder.id.desc())
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
    route_steps: list[tuple[ProcessStage, Process]],
) -> list[ProductionOrderProcess]:
    if not route_steps:
        raise ValueError("At least one process is required")

    rows: list[ProductionOrderProcess] = []
    for idx, (stage, process) in enumerate(route_steps):
        row = ProductionOrderProcess(
            order_id=order.id,
            process_id=process.id,
            stage_id=stage.id,
            stage_code=stage.code,
            stage_name=stage.name,
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


def _route_process_codes(route_steps: list[tuple[ProcessStage, Process]]) -> list[str]:
    return [process.code for _, process in route_steps]


def _is_template_route_match(
    *,
    route_steps: list[tuple[ProcessStage, Process]],
    template: ProductProcessTemplate,
) -> bool:
    template_steps = sorted(template.steps, key=lambda item: item.step_order)
    if len(template_steps) != len(route_steps):
        return False
    for template_step, (stage, process) in zip(template_steps, route_steps, strict=True):
        if template_step.stage_code != stage.code:
            return False
        if template_step.process_code != process.code:
            return False
    return True


def _set_order_template_snapshot(
    *,
    order: ProductionOrder,
    template: ProductProcessTemplate | None,
) -> None:
    if template is None:
        order.process_template_id = None
        order.process_template_name = None
        order.process_template_version = None
        return
    order.process_template_id = template.id
    order.process_template_name = template.template_name
    order.process_template_version = template.version


def _set_order_product_snapshot(
    *,
    order: ProductionOrder,
    product: Product,
) -> None:
    if product.effective_version > 0:
        order.product_version = product.effective_version
        return
    order.product_version = max(product.current_version, 1)


def _normalize_template_name(value: str | None) -> str:
    normalized = (value or "").strip()
    if not normalized:
        raise ValueError("New template name is required when save_as_template is enabled")
    return normalized


def _save_route_as_template(
    db: Session,
    *,
    product_id: int,
    route_steps: list[tuple[ProcessStage, Process]],
    template_name: str,
    set_default: bool,
    operator: User,
) -> ProductProcessTemplate:
    normalized_template_name = _normalize_template_name(template_name)
    duplicate_template = (
        db.execute(
            select(ProductProcessTemplate.id).where(
                ProductProcessTemplate.product_id == product_id,
                ProductProcessTemplate.template_name == normalized_template_name,
                ProductProcessTemplate.is_enabled.is_(True),
            )
        )
        .scalars()
        .first()
    )
    if duplicate_template is not None:
        raise ValueError("Template name already exists under selected product")

    next_version = (
        db.execute(
            select(func.max(ProductProcessTemplate.version)).where(
                ProductProcessTemplate.product_id == product_id,
                ProductProcessTemplate.template_name == normalized_template_name,
            )
        ).scalar_one_or_none()
        or 0
    ) + 1

    template = ProductProcessTemplate(
        product_id=product_id,
        template_name=normalized_template_name,
        version=next_version,
        is_default=set_default,
        is_enabled=True,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
    )
    db.add(template)
    db.flush()

    for idx, (stage, process) in enumerate(route_steps, start=1):
        template.steps.append(
            ProductProcessTemplateStep(
                step_order=idx,
                stage_id=stage.id,
                stage_code=stage.code,
                stage_name=stage.name,
                process_id=process.id,
                process_code=process.code,
                process_name=process.name,
            )
        )
    db.flush()

    if set_default and template.lifecycle_status == "published":
        enabled_templates = (
            db.execute(
                select(ProductProcessTemplate).where(
                    ProductProcessTemplate.product_id == product_id,
                    ProductProcessTemplate.is_enabled.is_(True),
                    ProductProcessTemplate.lifecycle_status == "published",
                )
            )
            .scalars()
            .all()
        )
        for row in enabled_templates:
            row.is_default = row.id == template.id
    elif template.lifecycle_status == "published":
        has_default = (
            db.execute(
                select(ProductProcessTemplate.id).where(
                    ProductProcessTemplate.product_id == product_id,
                    ProductProcessTemplate.is_enabled.is_(True),
                    ProductProcessTemplate.lifecycle_status == "published",
                    ProductProcessTemplate.is_default.is_(True),
                )
            )
            .scalars()
            .first()
        )
        if has_default is None:
            template.is_default = True
    db.flush()
    return template


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
    template_id: int | None,
    process_steps: list[dict[str, int]] | None,
    save_as_template: bool,
    new_template_name: str | None,
    new_template_set_default: bool,
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
    if product.lifecycle_status != PRODUCT_LIFECYCLE_ACTIVE:
        raise ValueError("Product is not active")

    route_steps, selected_template = _resolve_route_steps(
        db,
        product_id=product_id,
        template_id=template_id,
        process_steps=process_steps,
        process_codes=process_codes,
    )
    final_template = selected_template
    if process_steps and selected_template and not _is_template_route_match(route_steps=route_steps, template=selected_template):
        final_template = None
    if save_as_template:
        final_template = _save_route_as_template(
            db,
            product_id=product_id,
            route_steps=route_steps,
            template_name=new_template_name,
            set_default=new_template_set_default,
            operator=operator,
        )
    resolved_process_codes = _route_process_codes(route_steps)

    order = ProductionOrder(
        order_code=normalized_order_code,
        product_id=product_id,
        quantity=quantity,
        status=ORDER_STATUS_PENDING,
        current_process_code=resolved_process_codes[0],
        pipeline_enabled=False,
        pipeline_process_codes="",
        start_date=start_date,
        due_date=due_date,
        remark=(remark or "").strip() or None,
        created_by_user_id=operator.id,
    )
    _set_order_product_snapshot(order=order, product=product)
    _set_order_template_snapshot(order=order, template=final_template)
    db.add(order)
    db.flush()

    process_rows = _build_order_process_rows(
        db,
        order=order,
        route_steps=route_steps,
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
            "process_codes": resolved_process_codes,
            "process_template_id": order.process_template_id,
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
    template_id: int | None,
    process_steps: list[dict[str, int]] | None,
    save_as_template: bool,
    new_template_name: str | None,
    new_template_set_default: bool,
    operator: User,
) -> ProductionOrder:
    if order.status != ORDER_STATUS_PENDING:
        raise ValueError("Only pending orders can be updated")
    if quantity <= 0:
        raise ValueError("Quantity must be greater than 0")
    product = db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    if not product:
        raise ValueError("Product not found")
    if product.lifecycle_status != PRODUCT_LIFECYCLE_ACTIVE:
        raise ValueError("Product is not active")

    route_steps, selected_template = _resolve_route_steps(
        db,
        product_id=product_id,
        template_id=template_id,
        process_steps=process_steps,
        process_codes=process_codes,
    )
    final_template = selected_template
    if process_steps and selected_template and not _is_template_route_match(route_steps=route_steps, template=selected_template):
        final_template = None
    if save_as_template:
        final_template = _save_route_as_template(
            db,
            product_id=product_id,
            route_steps=route_steps,
            template_name=new_template_name,
            set_default=new_template_set_default,
            operator=operator,
        )
    resolved_process_codes = _route_process_codes(route_steps)

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
    order.current_process_code = resolved_process_codes[0]
    order.pipeline_enabled = False
    order.pipeline_process_codes = ""
    _set_order_product_snapshot(order=order, product=product)
    _set_order_template_snapshot(order=order, template=final_template)

    process_rows = _build_order_process_rows(
        db,
        order=order,
        route_steps=route_steps,
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
            "process_codes": resolved_process_codes,
            "process_template_id": order.process_template_id,
        },
    )
    db.commit()
    db.refresh(order)
    return order


def delete_order(
    db: Session,
    *,
    order: ProductionOrder,
    operator: User | None = None,
) -> None:
    if order.status != ORDER_STATUS_PENDING:
        raise ValueError("Only pending orders can be deleted")
    add_order_event_log(
        db,
        order_id=order.id,
        event_type="order_deleted",
        event_title="订单已删除",
        event_detail=f"订单 {order.order_code} 被删除",
        operator_user_id=operator.id if operator else None,
        payload={"order_code": order.order_code, "status": order.status},
    )
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
    work_view: str = "own",
    assist_authorization_id: int | None = None,
    can_first_article_override: bool | None = None,
    can_end_production_override: bool | None = None,
) -> dict[str, object]:
    process_remaining = max(process_row.visible_quantity - process_row.completed_quantity, 0)
    sub_remaining = process_remaining
    if sub_order is not None:
        sub_remaining = max(sub_order.assigned_quantity - sub_order.completed_quantity, 0)
    max_producible = min(process_remaining, sub_remaining)

    can_first_article = False
    can_end_production = False
    pipeline_start_allowed = False
    pipeline_end_allowed = False
    pipeline_mode_enabled = bool(order.pipeline_enabled)
    if is_operator_context and sub_order is not None and sub_order.is_visible:
        first_article_base = (
            process_row.status in {PROCESS_STATUS_PENDING, PROCESS_STATUS_PARTIAL}
            and sub_order.status == SUB_ORDER_STATUS_PENDING
            and max_producible > 0
        )
        end_production_base = (
            process_row.status == PROCESS_STATUS_IN_PROGRESS
            and sub_order.status == SUB_ORDER_STATUS_IN_PROGRESS
            and max_producible > 0
        )
        pipeline_start_allowed = first_article_base and is_pipeline_start_allowed_for_process(
            order=order,
            process_row=process_row,
        )
        pipeline_end_allowed = end_production_base and is_pipeline_end_allowed_for_process(
            order=order,
            process_row=process_row,
        )
        can_first_article = pipeline_start_allowed
        can_end_production = pipeline_end_allowed

    if can_first_article_override is not None:
        can_first_article = can_first_article_override
        pipeline_start_allowed = can_first_article_override
    if can_end_production_override is not None:
        can_end_production = can_end_production_override
        pipeline_end_allowed = can_end_production_override

    return {
        "order_id": order.id,
        "order_code": order.order_code,
        "product_id": order.product_id,
        "product_name": order.product.name if order.product else "",
        "quantity": order.quantity,
        "order_status": order.status,
        "current_process_id": process_row.id,
        "current_stage_id": process_row.stage_id,
        "current_stage_code": process_row.stage_code,
        "current_stage_name": process_row.stage_name,
        "current_process_code": process_row.process_code,
        "current_process_name": process_row.process_name,
        "current_process_order": process_row.process_order,
        "process_status": process_row.status,
        "visible_quantity": process_row.visible_quantity,
        "process_completed_quantity": process_row.completed_quantity,
        "user_sub_order_id": sub_order.id if sub_order else None,
        "user_assigned_quantity": sub_order.assigned_quantity if sub_order else None,
        "user_completed_quantity": sub_order.completed_quantity if sub_order else None,
        "operator_user_id": sub_order.operator_user_id if sub_order else None,
        "operator_username": sub_order.operator.username if sub_order and sub_order.operator else None,
        "work_view": work_view,
        "assist_authorization_id": assist_authorization_id,
        "pipeline_mode_enabled": pipeline_mode_enabled,
        "pipeline_start_allowed": pipeline_start_allowed,
        "pipeline_end_allowed": pipeline_end_allowed,
        "max_producible_quantity": max_producible,
        "can_first_article": can_first_article,
        "can_end_production": can_end_production,
        "updated_at": order.updated_at,
    }


def _collect_my_order_items(
    db: Session,
    *,
    current_user: User,
    keyword: str | None,
    view_mode: str = "own",
    proxy_operator_user_id: int | None = None,
    exact_order_id: int | None = None,
    exact_order_process_id: int | None = None,
) -> list[dict[str, object]]:
    if view_mode not in {"own", "proxy", "assist"}:
        raise ValueError("Invalid work view mode")

    is_admin_context = has_permission(
        db,
        user=current_user,
        permission_code=PERM_PROD_MY_ORDERS_VIEW_ALL,
    )
    can_proxy_view = has_permission(
        db,
        user=current_user,
        permission_code=PERM_PROD_MY_ORDERS_PROXY,
    )

    items: list[dict[str, object]] = []
    if view_mode == "proxy":
        if not can_proxy_view:
            raise PermissionError("Current user has no permission for proxy view")
        if proxy_operator_user_id is None:
            raise ValueError("proxy_operator_user_id is required for proxy view")
        stmt = (
            select(ProductionSubOrder)
            .join(ProductionSubOrder.order_process)
            .join(ProductionOrderProcess.order)
            .where(
                ProductionSubOrder.operator_user_id == proxy_operator_user_id,
                ProductionSubOrder.is_visible.is_(True),
                ProductionOrder.status != ORDER_STATUS_COMPLETED,
                ProductionOrderProcess.status != PROCESS_STATUS_COMPLETED,
            )
            .options(
                selectinload(ProductionSubOrder.operator),
                selectinload(ProductionSubOrder.order_process)
                .selectinload(ProductionOrderProcess.order)
                .selectinload(ProductionOrder.product),
            )
            .order_by(ProductionOrder.updated_at.desc(), ProductionSubOrder.id.desc())
        )
        if exact_order_id is not None:
            stmt = stmt.where(ProductionOrder.id == exact_order_id)
        if exact_order_process_id is not None:
            stmt = stmt.where(ProductionSubOrder.order_process_id == exact_order_process_id)
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
                    work_view="proxy",
                    can_first_article_override=False,
                    can_end_production_override=False,
                )
            )
    elif view_mode == "assist":
        stmt = (
            select(ProductionAssistAuthorization)
            .where(
                ProductionAssistAuthorization.helper_user_id == current_user.id,
                ProductionAssistAuthorization.status == ASSIST_STATUS_APPROVED,
                ProductionAssistAuthorization.end_production_used_at.is_(None),
            )
            .options(
                selectinload(ProductionAssistAuthorization.order).selectinload(ProductionOrder.product),
                selectinload(ProductionAssistAuthorization.order_process),
            )
            .order_by(
                ProductionAssistAuthorization.updated_at.desc(),
                ProductionAssistAuthorization.id.desc(),
            )
        )
        if exact_order_id is not None:
            stmt = stmt.where(ProductionAssistAuthorization.order_id == exact_order_id)
        if exact_order_process_id is not None:
            stmt = stmt.where(ProductionAssistAuthorization.order_process_id == exact_order_process_id)
        assist_rows = db.execute(stmt).scalars().all()
        for assist_row in assist_rows:
            order = assist_row.order
            process_row = assist_row.order_process
            if order is None or process_row is None:
                continue
            if order.status == ORDER_STATUS_COMPLETED or process_row.status == PROCESS_STATUS_COMPLETED:
                continue
            sub_order = (
                db.execute(
                    select(ProductionSubOrder)
                    .where(
                        ProductionSubOrder.order_process_id == process_row.id,
                        ProductionSubOrder.operator_user_id == assist_row.target_operator_user_id,
                        ProductionSubOrder.is_visible.is_(True),
                    )
                    .options(selectinload(ProductionSubOrder.operator))
                )
                .scalars()
                .first()
            )
            if sub_order is None:
                continue
            if keyword:
                key = keyword.strip().lower()
                if key and key not in order.order_code.lower() and key not in (order.product.name if order.product else "").lower():
                    continue

            process_remaining = max(process_row.visible_quantity - process_row.completed_quantity, 0)
            sub_remaining = max(sub_order.assigned_quantity - sub_order.completed_quantity, 0)
            max_producible = min(process_remaining, sub_remaining)
            can_first_article = (
                assist_row.first_article_used_at is None
                and process_row.status in {PROCESS_STATUS_PENDING, PROCESS_STATUS_PARTIAL}
                and sub_order.status == SUB_ORDER_STATUS_PENDING
                and max_producible > 0
                and is_pipeline_start_allowed_for_process(order=order, process_row=process_row)
            )
            can_end_production = (
                assist_row.end_production_used_at is None
                and process_row.status == PROCESS_STATUS_IN_PROGRESS
                and sub_order.status == SUB_ORDER_STATUS_IN_PROGRESS
                and max_producible > 0
                and is_pipeline_end_allowed_for_process(order=order, process_row=process_row)
            )
            items.append(
                _build_my_order_item(
                    order=order,
                    process_row=process_row,
                    sub_order=sub_order,
                    is_operator_context=True,
                    work_view="assist",
                    assist_authorization_id=assist_row.id,
                    can_first_article_override=can_first_article,
                    can_end_production_override=can_end_production,
                )
            )
    elif is_admin_context:
        stmt = (
            select(ProductionOrder)
            .where(ProductionOrder.status != ORDER_STATUS_COMPLETED)
            .options(selectinload(ProductionOrder.product), selectinload(ProductionOrder.processes))
            .order_by(ProductionOrder.updated_at.desc(), ProductionOrder.id.desc())
        )
        if exact_order_id is not None:
            stmt = stmt.where(ProductionOrder.id == exact_order_id)
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
            if exact_order_process_id is not None:
                current_process = next((row for row in process_rows if row.id == exact_order_process_id), None)
            else:
                current_process = next(
                    (row for row in process_rows if row.status != PROCESS_STATUS_COMPLETED),
                    None,
                )
            if current_process is None:
                continue
            if current_process.status == PROCESS_STATUS_COMPLETED:
                continue
            items.append(
                _build_my_order_item(
                    order=order,
                    process_row=current_process,
                    sub_order=None,
                    is_operator_context=False,
                    work_view="own",
                )
            )
    else:
        # Historical orders may have missing sub-order rows if operators were added later.
        if _backfill_operator_sub_orders(db, current_user=current_user):
            db.commit()

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
        if exact_order_id is not None:
            stmt = stmt.where(ProductionOrder.id == exact_order_id)
        if exact_order_process_id is not None:
            stmt = stmt.where(ProductionSubOrder.order_process_id == exact_order_process_id)
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
                    work_view="own",
                )
            )

    return items


def list_my_orders(
    db: Session,
    *,
    current_user: User,
    keyword: str | None,
    page: int,
    page_size: int,
    view_mode: str = "own",
    proxy_operator_user_id: int | None = None,
) -> tuple[int, list[dict[str, object]]]:
    items = _collect_my_order_items(
        db,
        current_user=current_user,
        keyword=keyword,
        view_mode=view_mode,
        proxy_operator_user_id=proxy_operator_user_id,
        exact_order_id=None,
    )
    total = len(items)
    offset = (page - 1) * page_size
    return total, items[offset : offset + page_size]


def get_my_order_context(
    db: Session,
    *,
    order_id: int,
    order_process_id: int | None = None,
    current_user: User,
    view_mode: str = "own",
    proxy_operator_user_id: int | None = None,
) -> dict[str, object] | None:
    items = _collect_my_order_items(
        db,
        current_user=current_user,
        keyword=None,
        view_mode=view_mode,
        proxy_operator_user_id=proxy_operator_user_id,
        exact_order_id=order_id,
        exact_order_process_id=order_process_id,
    )
    if not items:
        return None
    return items[0]


def export_orders_csv(
    db: Session,
    *,
    keyword: str | None = None,
    status: str | None = None,
    product_name: str | None = None,
    pipeline_enabled: bool | None = None,
    start_date_from: date | None = None,
    start_date_to: date | None = None,
    due_date_from: date | None = None,
    due_date_to: date | None = None,
) -> dict[str, object]:
    _, rows = list_orders(
        db,
        page=1,
        page_size=10000,
        keyword=keyword,
        status=status,
        product_name=product_name,
        pipeline_enabled=pipeline_enabled,
        start_date_from=start_date_from,
        start_date_to=start_date_to,
        due_date_from=due_date_from,
        due_date_to=due_date_to,
    )
    headers = [
        "订单号", "产品名称", "产品版本", "数量", "当前状态",
        "工艺模板", "模板版本", "并行模式", "开始日期", "交期", "创建人", "更新时间",
    ]
    csv_rows = []
    for row in rows:
        csv_rows.append([
            row.order_code,
            row.product.name if row.product else "",
            row.product_version or "",
            row.quantity,
            row.status,
            row.process_template_name or "",
            row.process_template_version or "",
            "开启" if row.pipeline_enabled else "关闭",
            str(row.start_date) if row.start_date else "",
            str(row.due_date) if row.due_date else "",
            row.created_by.username if row.created_by else "",
            row.updated_at.strftime("%Y-%m-%d %H:%M:%S") if row.updated_at else "",
        ])
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for r in csv_rows:
        writer.writerow(r)
    content_b64 = base64.b64encode(output.getvalue().encode("utf-8-sig")).decode("ascii")
    file_name = f"orders_{datetime.now(UTC).strftime('%Y%m%d%H%M%S')}.csv"
    return {
        "file_name": file_name,
        "mime_type": "text/csv",
        "content_base64": content_b64,
        "exported_count": len(csv_rows),
    }


def list_pipeline_instances(
    db: Session,
    *,
    order_id: int | None = None,
    order_code: str | None = None,
    order_process_id: int | None = None,
    sub_order_id: int | None = None,
    is_active: bool | None = None,
    page: int = 1,
    page_size: int = 100,
) -> tuple[int, list[OrderSubOrderPipelineInstance]]:
    from sqlalchemy.orm import joinedload
    stmt = select(OrderSubOrderPipelineInstance).options(
        joinedload(OrderSubOrderPipelineInstance.order)
    )
    if order_id is not None:
        stmt = stmt.where(OrderSubOrderPipelineInstance.order_id == order_id)
    if order_code is not None and order_code.strip():
        stmt = stmt.join(
            ProductionOrder,
            ProductionOrder.id == OrderSubOrderPipelineInstance.order_id,
            isouter=False,
        ).where(ProductionOrder.order_code.ilike(f"%{order_code.strip()}%"))
    if order_process_id is not None:
        stmt = stmt.where(OrderSubOrderPipelineInstance.order_process_id == order_process_id)
    if sub_order_id is not None:
        stmt = stmt.where(OrderSubOrderPipelineInstance.sub_order_id == sub_order_id)
    if is_active is not None:
        stmt = stmt.where(OrderSubOrderPipelineInstance.is_active == is_active)
    stmt = stmt.order_by(
        OrderSubOrderPipelineInstance.order_id.asc(),
        OrderSubOrderPipelineInstance.pipeline_seq.asc(),
        OrderSubOrderPipelineInstance.id.asc(),
    )
    rows = db.execute(stmt).unique().scalars().all()
    total = len(rows)
    offset = (page - 1) * page_size
    return total, rows[offset: offset + page_size]
