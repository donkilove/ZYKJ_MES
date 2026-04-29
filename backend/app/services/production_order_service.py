from __future__ import annotations

import base64
import csv
import io
import json
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
    REPAIR_STATUS_IN_REPAIR,
    SUB_ORDER_STATUS_DONE,
    SUB_ORDER_STATUS_IN_PROGRESS,
    SUB_ORDER_STATUS_PENDING,
    order_status_label,
    pipeline_mode_label,
)
from app.core.product_lifecycle import PRODUCT_LIFECYCLE_ACTIVE
from app.core.authz_catalog import (
    PERM_PROD_MY_ORDERS_PROXY,
    PERM_PROD_ORDERS_DETAIL_ALL,
    PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE,
    PERM_PROD_ORDERS_PIPELINE_MODE_VIEW_ALL,
)
from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.process import Process
from app.models.first_article_record import FirstArticleRecord
from app.models.first_article_review_session import FirstArticleReviewSession
from app.models.order_sub_order_pipeline_instance import ProcessPipelineInstance
from app.models.production_assist_authorization import ProductionAssistAuthorization
from app.models.process_stage import ProcessStage
from app.models.product import Product
from app.models.repair_order import RepairOrder
from app.models.role import Role
from app.models.supplier import Supplier
from app.models.product_process_template import ProductProcessTemplate
from app.models.product_process_template_step import ProductProcessTemplateStep
from app.models.production_record import ProductionRecord
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_sub_order import ProductionSubOrder
from app.models.order_event_log import OrderEventLog
from app.models.user import User
from app.services.message_service import create_message_for_users
from app.services.quality_supplier_service import (
    get_enabled_supplier_for_order,
    get_supplier_by_id,
)
from app.services.assist_authorization_service import (
    ASSIST_STATUS_APPROVED,
    ASSIST_STATUS_CONSUMED,
)
from app.services.authz_service import has_permission
from app.services.production_event_log_service import add_order_event_log


def _message_recipient_user_ids_for_order(
    db: Session, *, order: ProductionOrder
) -> list[int]:
    rows = (
        db.execute(
            select(User.id)
            .join(User.roles)
            .where(
                User.is_deleted.is_(False),
                User.is_active.is_(True),
                Role.code.in_((ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN)),
            )
            .distinct()
        )
        .scalars()
        .all()
    )
    recipient_ids = {int(user_id) for user_id in rows}
    if order.created_by_user_id is not None:
        recipient_ids.add(int(order.created_by_user_id))
    return sorted(recipient_ids)


def _notify_order_changed(
    db: Session,
    *,
    order: ProductionOrder,
    operator: User,
    event_code: str,
    title: str,
    summary: str,
) -> None:
    recipient_user_ids = _message_recipient_user_ids_for_order(db, order=order)
    if not recipient_user_ids:
        return
    create_message_for_users(
        db,
        message_type="notice",
        priority="important",
        title=title,
        summary=summary,
        content=summary,
        source_module="production",
        source_type="production_order",
        source_id=str(order.id),
        source_code=order.order_code,
        target_page_code="production",
        target_tab_code="production_order_management",
        target_route_payload_json=json.dumps(
            {
                "action": "detail",
                "order_id": order.id,
                "order_code": order.order_code,
            },
            ensure_ascii=False,
        ),
        recipient_user_ids=recipient_user_ids,
        dedupe_key=f"production_order_{event_code}_{order.id}_{int(order.updated_at.timestamp()) if order.updated_at else 'now'}",
        created_by_user_id=operator.id,
    )


def _normalize_process_codes(process_codes: Iterable[str]) -> list[str]:
    normalized = [item.strip() for item in process_codes if item and item.strip()]
    return list(dict.fromkeys(normalized))


def _normalize_route_process_codes(process_codes: Iterable[str]) -> list[str]:
    return [item.strip() for item in process_codes if item and item.strip()]


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


def is_pipeline_process_selected_for_order(
    *,
    order: ProductionOrder,
    process_code: str,
) -> bool:
    return process_code in _pipeline_selected_code_set(order)


def _is_parallel_edge_enabled(
    *,
    order: ProductionOrder,
    previous_process_code: str,
    current_process_code: str,
) -> bool:
    selected_codes = _pipeline_selected_code_set(order)
    if not selected_codes:
        return False
    return (
        previous_process_code in selected_codes
        and current_process_code in selected_codes
    )


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


def get_active_pipeline_instance_for_sub_order(
    db: Session,
    *,
    sub_order_id: int,
    order_process_id: int,
) -> ProcessPipelineInstance | None:
    rows = (
        db.execute(
            select(ProcessPipelineInstance)
            .where(
                ProcessPipelineInstance.sub_order_id == sub_order_id,
                ProcessPipelineInstance.order_process_id == order_process_id,
                ProcessPipelineInstance.is_active.is_(True),
            )
            .order_by(ProcessPipelineInstance.id.asc())
        )
        .scalars()
        .all()
    )
    if not rows:
        return None
    if len(rows) > 1:
        raise RuntimeError(
            "Multiple active pipeline instances found for current sub-order"
        )
    return rows[0]


def get_active_pipeline_instance_for_process(
    db: Session,
    *,
    order_process_id: int,
    pipeline_instance_id: int,
) -> ProcessPipelineInstance | None:
    return (
        db.execute(
            select(ProcessPipelineInstance)
            .where(
                ProcessPipelineInstance.id == pipeline_instance_id,
                ProcessPipelineInstance.order_process_id == order_process_id,
                ProcessPipelineInstance.is_active.is_(True),
            )
        )
        .scalars()
        .first()
    )


def allocate_pipeline_instance_for_process(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
    preferred_pipeline_seq: int | None = None,
    preferred_pipeline_link_id: str | None = None,
) -> ProcessPipelineInstance:
    existing_rows = (
        db.execute(
            select(ProcessPipelineInstance)
            .where(
                ProcessPipelineInstance.order_id == order.id,
                ProcessPipelineInstance.order_process_id == process_row.id,
                ProcessPipelineInstance.is_active.is_(True),
            )
            .order_by(ProcessPipelineInstance.pipeline_seq.asc(), ProcessPipelineInstance.id.asc())
            .with_for_update()
        )
        .scalars()
        .all()
    )

    used_seqs = {int(row.pipeline_seq) for row in existing_rows}
    if preferred_pipeline_seq is not None:
        pipeline_seq = int(preferred_pipeline_seq)
        if pipeline_seq in used_seqs:
            raise RuntimeError("Current process pipeline instance already exists for requested sequence")
    else:
        pipeline_seq = 1
        while pipeline_seq in used_seqs:
            pipeline_seq += 1

    previous_process = _find_previous_process_row(order=order, process_row=process_row)
    pipeline_link_id = (preferred_pipeline_link_id or "").strip() or None
    if previous_process is not None and _is_parallel_edge_enabled(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        if pipeline_link_id is None:
            previous_instance = get_active_pipeline_instance_for_process_sequence(
                db,
                order_id=order.id,
                order_process_id=previous_process.id,
                pipeline_seq=pipeline_seq,
            )
            if previous_instance is not None:
                pipeline_link_id = previous_instance.pipeline_link_id

    if not pipeline_link_id:
        pipeline_link_id = f"PL{order.id}-{pipeline_seq}-{uuid4().hex[:10]}"

    pipeline_no = f"P{order.id}-{process_row.process_order}-{pipeline_seq}-{uuid4().hex[:6]}"
    row = ProcessPipelineInstance(
        pipeline_link_id=pipeline_link_id,
        sub_order_id=None,
        order_id=order.id,
        order_process_id=process_row.id,
        process_code=process_row.process_code,
        pipeline_seq=pipeline_seq,
        pipeline_instance_no=pipeline_no,
        is_active=True,
        invalid_reason=None,
        invalidated_at=None,
    )
    db.add(row)
    db.flush()
    return row


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


def _resolve_processes_by_codes(
    db: Session, process_codes: list[str]
) -> tuple[list[Process], list[str]]:
    if not process_codes:
        return [], []
    stmt = (
        select(Process)
        .where(Process.code.in_(process_codes))
        .options(selectinload(Process.stage))
    )
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


def _set_order_supplier_snapshot(*, order: ProductionOrder, supplier: Supplier) -> None:
    order.supplier_id = supplier.id
    order.supplier_name = supplier.name


def _resolve_supplier_for_pending_order_update(
    db: Session,
    *,
    order: ProductionOrder,
    supplier_id: int,
) -> Supplier:
    if order.supplier_id == supplier_id:
        supplier = get_supplier_by_id(db, supplier_id)
        if supplier is None:
            raise ValueError("供应商不存在或已停用")
        return supplier
    return get_enabled_supplier_for_order(db, supplier_id=supplier_id)


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
    stage_rows = (
        db.execute(select(ProcessStage).where(ProcessStage.id.in_(stage_ids)))
        .scalars()
        .all()
    )
    process_rows = (
        db.execute(
            select(Process)
            .where(Process.id.in_(process_ids))
            .options(selectinload(Process.stage))
        )
        .scalars()
        .all()
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
            raise ValueError(
                f"Process {process.code} does not belong to stage {stage.code}"
            )
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
        template = (
            _resolve_template(db, template_id=template_id, product_id=product_id)
            if template_id
            else None
        )
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
        process_codes_in_template = [
            item.process_code
            for item in sorted(template.steps, key=lambda item: item.step_order)
        ]
        processes, missing_codes = _resolve_processes_by_codes(
            db, process_codes_in_template
        )
        if missing_codes:
            raise ValueError(
                f"Template process codes not found: {', '.join(missing_codes)}"
            )
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

    normalized_codes = _normalize_route_process_codes(process_codes)
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
    return []


def _recalculate_order_current_process(order: ProductionOrder) -> None:
    sorted_processes = sorted(
        order.processes, key=lambda item: (item.process_order, item.id)
    )
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
    return


def ensure_sub_orders_visible_quantity(
    db: Session,
    *,
    process_row: ProductionOrderProcess,
    target_visible_quantity: int,
) -> bool:
    return False


def get_order_by_id(
    db: Session, order_id: int, *, with_relations: bool = False
) -> ProductionOrder | None:
    stmt = select(ProductionOrder).where(ProductionOrder.id == order_id)
    if with_relations:
        stmt = stmt.options(
            selectinload(ProductionOrder.product),
            selectinload(ProductionOrder.created_by),
            selectinload(ProductionOrder.processes)
            .selectinload(ProductionOrderProcess.sub_orders)
            .selectinload(ProductionSubOrder.operator),
            selectinload(ProductionOrder.production_records).selectinload(
                ProductionRecord.operator
            ),
            selectinload(ProductionOrder.event_logs).selectinload(
                OrderEventLog.operator
            ),
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
    exists_stmt = select(
        exists().where(
            ProductionSubOrder.operator_user_id == current_user.id,
            ProductionSubOrder.order_process_id == ProductionOrderProcess.id,
            ProductionOrderProcess.order_id == order_id,
        )
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
            ProductionAssistAuthorization.status.in_(
                [ASSIST_STATUS_APPROVED, ASSIST_STATUS_CONSUMED]
            ),
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
        update(ProcessPipelineInstance)
        .where(
            ProcessPipelineInstance.order_id == order_id,
            ProcessPipelineInstance.is_active.is_(True),
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
    return 0


def get_active_pipeline_instance_for_process_sequence(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    pipeline_seq: int,
) -> ProcessPipelineInstance | None:
    rows = (
        db.execute(
            select(ProcessPipelineInstance)
            .where(
                ProcessPipelineInstance.order_id == order_id,
                ProcessPipelineInstance.order_process_id == order_process_id,
                ProcessPipelineInstance.pipeline_seq == pipeline_seq,
                ProcessPipelineInstance.is_active.is_(True),
            )
            .order_by(ProcessPipelineInstance.id.asc())
        )
        .scalars()
        .all()
    )
    if not rows:
        return None
    if len(rows) > 1:
        raise RuntimeError(
            "Multiple active pipeline instances found for same process sequence"
        )
    return rows[0]


def get_active_pipeline_instance_for_link_id(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    pipeline_link_id: str,
) -> ProcessPipelineInstance | None:
    rows = (
        db.execute(
            select(ProcessPipelineInstance)
            .where(
                ProcessPipelineInstance.order_id == order_id,
                ProcessPipelineInstance.order_process_id == order_process_id,
                ProcessPipelineInstance.pipeline_link_id == pipeline_link_id,
                ProcessPipelineInstance.is_active.is_(True),
            )
            .order_by(ProcessPipelineInstance.id.asc())
        )
        .scalars()
        .all()
    )
    if not rows:
        return None
    if len(rows) > 1:
        raise RuntimeError("Multiple active pipeline instances found for same link id")
    return rows[0]


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
        requested_codes=_parse_pipeline_process_codes_text(
            order.pipeline_process_codes
        ),
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
        raise ValueError(
            "Order has fewer than 2 processes and cannot enable pipeline mode"
        )
    route_codes = [row.process_code for row in process_rows]
    selected_codes = _ordered_selected_pipeline_codes(
        route_process_codes=route_codes,
        requested_codes=process_codes,
    )
    if enabled and len(selected_codes) < 2:
        raise ValueError(
            "At least two valid process codes are required when enabling pipeline mode"
        )
    invalid_codes = [
        code
        for code in _normalize_process_codes(process_codes)
        if code not in route_codes
    ]
    if invalid_codes:
        raise ValueError(
            f"Invalid process codes for order route: {', '.join(invalid_codes)}"
        )

    if enabled:
        first_code = selected_codes[0]
        first_row = next(
            (row for row in process_rows if row.process_code == first_code), None
        )
        if first_row is None:
            raise ValueError("Selected first process does not exist in order route")
        first_available = max(
            first_row.visible_quantity - first_row.completed_quantity, 0
        )
        if first_available <= 0:
            raise ValueError(
                f"Cannot enable pipeline mode: first selected process {first_code} has no producible quantity"
            )

    previous_enabled = bool(order.pipeline_enabled)
    previous_codes = _ordered_selected_pipeline_codes(
        route_process_codes=route_codes,
        requested_codes=_parse_pipeline_process_codes_text(
            order.pipeline_process_codes
        ),
    )

    if not enabled and previous_enabled:
        unfinished_selected_rows = [
            row
            for row in process_rows
            if row.process_code in previous_codes and row.status != PROCESS_STATUS_COMPLETED
        ]
        if unfinished_selected_rows:
            raise RuntimeError("存在未完成工序，不能关闭流水线模式")

    order.pipeline_enabled = bool(enabled)
    order.pipeline_process_codes = _pipeline_process_codes_to_text(
        selected_codes if enabled else []
    )

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
    _notify_order_changed(
        db,
        order=order,
        operator=operator,
        event_code="pipeline_updated",
        title=f"生产订单并行模式已更新：{order.order_code}",
        summary=(
            f"订单 {order.order_code} 的并行模式已{'开启' if enabled else '关闭'}，"
            f"工序范围：{', '.join(selected_codes) if selected_codes else '无'}。"
        ),
    )
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
    stmt = select(ProductionOrder).join(
        Product, Product.id == ProductionOrder.product_id
    )
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


def _order_process_has_history(db: Session, *, order_process_id: int) -> bool:
    has_first_article = db.execute(
        select(FirstArticleRecord.id).where(FirstArticleRecord.order_process_id == order_process_id)
    ).first()
    if has_first_article is not None:
        return True
    has_production = db.execute(
        select(ProductionRecord.id).where(ProductionRecord.order_process_id == order_process_id)
    ).first()
    if has_production is not None:
        return True
    has_repair = db.execute(
        select(RepairOrder.id).where(RepairOrder.source_order_process_id == order_process_id)
    ).first()
    return has_repair is not None


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
    for template_step, (stage, process) in zip(
        template_steps, route_steps, strict=True
    ):
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
        raise ValueError(
            "New template name is required when save_as_template is enabled"
        )
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
    supplier_id: int,
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
    product = (
        db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    )
    if not product:
        raise ValueError("Product not found")
    if product.lifecycle_status != PRODUCT_LIFECYCLE_ACTIVE:
        raise ValueError("Product is not active")
    supplier = get_enabled_supplier_for_order(db, supplier_id=supplier_id)

    route_steps, selected_template = _resolve_route_steps(
        db,
        product_id=product_id,
        template_id=template_id,
        process_steps=process_steps,
        process_codes=process_codes,
    )
    final_template = selected_template
    if (
        process_steps
        and selected_template
        and not _is_template_route_match(
            route_steps=route_steps, template=selected_template
        )
    ):
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
        supplier_id=supplier.id,
        supplier_name=supplier.name,
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
    _set_order_supplier_snapshot(order=order, supplier=supplier)
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
            "supplier_id": order.supplier_id,
            "supplier_name": order.supplier_name,
            "quantity": order.quantity,
            "process_codes": resolved_process_codes,
            "process_template_id": order.process_template_id,
        },
    )
    db.commit()
    db.refresh(order)
    _notify_order_changed(
        db,
        order=order,
        operator=operator,
        event_code="created",
        title=f"生产订单已创建：{order.order_code}",
        summary=f"订单 {order.order_code} 已创建，数量 {order.quantity}，可进入订单管理查看详情。",
    )
    return order


def update_order(
    db: Session,
    *,
    order: ProductionOrder,
    product_id: int,
    supplier_id: int,
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
        blocking_count = db.execute(
            select(func.count()).select_from(ProductionOrderProcess).where(
                ProductionOrderProcess.order_id == order.id,
                ProductionOrderProcess.status.in_(
                    [PROCESS_STATUS_IN_PROGRESS, PROCESS_STATUS_PARTIAL]
                ),
            )
        ).scalar() or 0
        if blocking_count > 0:
            raise ValueError("存在正在生产中的工序（in_progress/partial），请先完成当前工序后再修改订单")
    if quantity <= 0:
        raise ValueError("Quantity must be greater than 0")
    product = (
        db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    )
    if not product:
        raise ValueError("Product not found")
    if product.lifecycle_status != PRODUCT_LIFECYCLE_ACTIVE:
        raise ValueError("Product is not active")
    supplier = _resolve_supplier_for_pending_order_update(
        db,
        order=order,
        supplier_id=supplier_id,
    )

    route_steps, selected_template = _resolve_route_steps(
        db,
        product_id=product_id,
        template_id=template_id,
        process_steps=process_steps,
        process_codes=process_codes,
    )
    final_template = selected_template
    if (
        process_steps
        and selected_template
        and not _is_template_route_match(
            route_steps=route_steps, template=selected_template
        )
    ):
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

    existing_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == order.id)
            .options(selectinload(ProductionOrderProcess.sub_orders))
            .order_by(ProductionOrderProcess.process_order.asc(), ProductionOrderProcess.id.asc())
            .with_for_update()
        )
        .scalars()
        .all()
    )

    order.product_id = product_id
    order.supplier_id = supplier.id
    order.supplier_name = supplier.name
    order.quantity = quantity
    order.start_date = start_date
    order.due_date = due_date
    order.remark = (remark or "").strip() or None
    order.status = ORDER_STATUS_PENDING
    order.current_process_code = resolved_process_codes[0]
    order.pipeline_enabled = False
    order.pipeline_process_codes = ""
    _set_order_product_snapshot(order=order, product=product)
    _set_order_supplier_snapshot(order=order, supplier=supplier)
    _set_order_template_snapshot(order=order, template=final_template)

    process_rows: list[ProductionOrderProcess] = []
    for idx, (stage, process) in enumerate(route_steps, start=1):
        existing_row = existing_rows[idx - 1] if idx <= len(existing_rows) else None
        if existing_row is None:
            row = ProductionOrderProcess(
                order_id=order.id,
                process_id=process.id,
                stage_id=stage.id,
                stage_code=stage.code,
                stage_name=stage.name,
                process_code=process.code,
                process_name=process.name,
                process_order=idx,
                status=PROCESS_STATUS_PENDING,
                visible_quantity=order.quantity if idx == 1 else 0,
                completed_quantity=0,
            )
            db.add(row)
            process_rows.append(row)
            continue

        has_history = _order_process_has_history(db, order_process_id=existing_row.id)
        changed_snapshot = (
            existing_row.process_id != process.id
            or existing_row.stage_id != stage.id
            or existing_row.process_code != process.code
            or existing_row.stage_code != stage.code
        )
        if has_history and changed_snapshot:
            raise RuntimeError("存在历史记录绑定的工序，不能通过改单直接替换；请保留历史工序并追加后续工序")

        existing_row.process_id = process.id
        existing_row.stage_id = stage.id
        existing_row.stage_code = stage.code
        existing_row.stage_name = stage.name
        existing_row.process_code = process.code
        existing_row.process_name = process.name
        existing_row.process_order = idx
        if not has_history:
            existing_row.status = PROCESS_STATUS_PENDING
            existing_row.completed_quantity = 0
            existing_row.visible_quantity = order.quantity if idx == 1 else 0
        elif idx == 1:
            existing_row.visible_quantity = max(int(existing_row.completed_quantity or 0), order.quantity)
        process_rows.append(existing_row)

    for extra_row in existing_rows[len(route_steps):]:
        if _order_process_has_history(db, order_process_id=extra_row.id):
            raise RuntimeError("存在历史记录绑定的尾部工序，不能通过改单直接删除")
        db.delete(extra_row)

    db.flush()

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="order_updated",
        event_title="订单已更新",
        event_detail=f"订单 {order.order_code} 已更新并重建工序路线。",
        operator_user_id=operator.id,
        payload={
            "quantity": order.quantity,
            "supplier_id": order.supplier_id,
            "supplier_name": order.supplier_name,
            "process_codes": resolved_process_codes,
            "process_template_id": order.process_template_id,
        },
    )
    db.commit()
    db.refresh(order)
    _notify_order_changed(
        db,
        order=order,
        operator=operator,
        event_code="updated",
        title=f"生产订单已更新：{order.order_code}",
        summary=f"订单 {order.order_code} 已更新工序路线或基础信息，请及时复核。",
    )
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
    _notify_order_changed(
        db,
        order=order,
        operator=operator,
        event_code="deleted",
        title=f"生产订单已删除：{order.order_code}",
        summary=f"订单 {order.order_code} 已被删除，相关计划请同步调整。",
    )


def complete_order_manually(
    db: Session,
    *,
    order: ProductionOrder,
    operator: User,
) -> ProductionOrder:
    if order.status == ORDER_STATUS_COMPLETED:
        return order

    # 4C：订单还有 in_repair 维修单时拒绝手工完工，避免维修回流与手工收口互相打架。
    pending_repairs = (
        db.execute(
            select(RepairOrder.repair_order_code)
            .where(
                RepairOrder.source_order_id == order.id,
                RepairOrder.status == REPAIR_STATUS_IN_REPAIR,
            )
            .order_by(RepairOrder.id.asc())
        )
        .scalars()
        .all()
    )
    if pending_repairs:
        raise RuntimeError(
            "Order has in-progress repair orders that must be completed first: "
            + ", ".join(pending_repairs)
        )

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
            sub.completed_quantity = max(sub.completed_quantity, row.visible_quantity)
            sub.status = SUB_ORDER_STATUS_DONE

    order.status = ORDER_STATUS_COMPLETED
    order.current_process_code = None

    cascaded = _cascade_close_order_relations(
        db,
        order_id=order.id,
        reason="order_completed_manual",
    )

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="order_completed_manual",
        event_title="订单手工完工",
        event_detail=f"订单 {order.order_code} 已被手工标记为完工。",
        operator_user_id=operator.id,
        payload={
            "cancelled_review_session_ids": cascaded["cancelled_review_session_ids"],
            "consumed_assist_authorization_ids": cascaded[
                "consumed_assist_authorization_ids"
            ],
            "invalidated_pipeline_instance_count": cascaded[
                "invalidated_pipeline_instance_count"
            ],
        },
    )
    db.commit()
    db.refresh(order)
    _notify_order_changed(
        db,
        order=order,
        operator=operator,
        event_code="completed_manual",
        title=f"生产订单已手工完工：{order.order_code}",
        summary=f"订单 {order.order_code} 已被手工标记完工，请核对收尾数据。",
    )
    return order


def _cascade_close_order_relations(
    db: Session,
    *,
    order_id: int,
    reason: str,
) -> dict[str, object]:
    now = datetime.now(UTC)

    # 1A：把仍 pending 的首件扫码会话置为 cancelled，避免会话依然能被扫码提交。
    review_session_ids = list(
        db.execute(
            select(FirstArticleReviewSession.id)
            .where(
                FirstArticleReviewSession.order_id == order_id,
                FirstArticleReviewSession.status == "pending",
            )
            .order_by(FirstArticleReviewSession.id.asc())
        )
        .scalars()
        .all()
    )
    if review_session_ids:
        db.execute(
            update(FirstArticleReviewSession)
            .where(FirstArticleReviewSession.id.in_(review_session_ids))
            .values(status="cancelled", updated_at=now)
        )

    # 2A：把 approved 但未 consumed 的代班授权置为 consumed，避免授权挂死阻塞重挂。
    assist_authorization_ids = list(
        db.execute(
            select(ProductionAssistAuthorization.id)
            .where(
                ProductionAssistAuthorization.order_id == order_id,
                ProductionAssistAuthorization.status == ASSIST_STATUS_APPROVED,
            )
            .order_by(ProductionAssistAuthorization.id.asc())
        )
        .scalars()
        .all()
    )
    if assist_authorization_ids:
        db.execute(
            update(ProductionAssistAuthorization)
            .where(
                ProductionAssistAuthorization.id.in_(assist_authorization_ids)
            )
            .values(status=ASSIST_STATUS_CONSUMED, consumed_at=now, updated_at=now)
        )

    # 3A：直接复用既有 helper 失活仍生效的并行实例。
    invalidated_count = _invalidate_pipeline_instances_for_order(
        db,
        order_id=order_id,
        reason=reason,
    )

    return {
        "cancelled_review_session_ids": review_session_ids,
        "consumed_assist_authorization_ids": assist_authorization_ids,
        "invalidated_pipeline_instance_count": invalidated_count,
    }


def _build_my_order_item(
    db: Session,
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
    process_remaining = max(
        process_row.visible_quantity - process_row.completed_quantity, 0
    )
    sub_remaining = process_remaining
    active_operator_count = (
        db.query(ProductionSubOrder)
        .filter(
            ProductionSubOrder.status == SUB_ORDER_STATUS_IN_PROGRESS,
            ProductionSubOrder.order_process_id == process_row.id,
        )
        .count()
    )
    if sub_order is not None:
        sub_remaining = max(
            process_row.visible_quantity - process_row.completed_quantity - active_operator_count, 0
        )
        is_in_progress = sub_order.status == SUB_ORDER_STATUS_IN_PROGRESS
    else:
        is_in_progress = False
    max_producible = (
        min(process_remaining, sub_remaining)
        if sub_order is not None
        else 0
    )

    can_first_article = False
    can_end_production = False
    pipeline_start_allowed = False
    pipeline_end_allowed = False
    pipeline_mode_enabled = bool(order.pipeline_enabled)
    pipeline_instance = None
    pipeline_process_selected = False
    if is_operator_context:
        sub_order_pending = sub_order is None or sub_order.status == SUB_ORDER_STATUS_PENDING
        sub_order_in_progress = sub_order is not None and sub_order.status == SUB_ORDER_STATUS_IN_PROGRESS
        pool_remaining = max(
            process_row.visible_quantity - process_row.completed_quantity - active_operator_count, 0
        )
        pipeline_process_selected = is_pipeline_process_selected_for_order(
            order=order,
            process_code=process_row.process_code,
        )
        if pipeline_process_selected and sub_order is not None:
            pipeline_instance = get_active_pipeline_instance_for_sub_order(
                db,
                sub_order_id=sub_order.id,
                order_process_id=process_row.id,
            )
        first_article_base = (
            process_row.status
            in {
                PROCESS_STATUS_PENDING,
                PROCESS_STATUS_IN_PROGRESS,
                PROCESS_STATUS_PARTIAL,
            }
            and sub_order_pending
            and pool_remaining > 0
            and (not pipeline_process_selected or pipeline_instance is not None)
        )
        end_production_base = (
            process_row.status in {PROCESS_STATUS_IN_PROGRESS, PROCESS_STATUS_PARTIAL}
            and sub_order_in_progress
            and pool_remaining + 1 > 0
            and (not pipeline_process_selected or pipeline_instance is not None)
        )
        pipeline_start_allowed = (
            first_article_base
            and is_pipeline_start_allowed_for_process(
                order=order,
                process_row=process_row,
            )
        )
        pipeline_end_allowed = (
            end_production_base
            and is_pipeline_end_allowed_for_process(
                order=order,
                process_row=process_row,
            )
        )
        can_first_article = pipeline_start_allowed
        can_end_production = pipeline_end_allowed

    if can_first_article_override is not None:
        can_first_article = can_first_article_override
        pipeline_start_allowed = can_first_article_override
    if can_end_production_override is not None:
        can_end_production = can_end_production_override
        pipeline_end_allowed = can_end_production_override

    can_apply_assist = False
    can_create_manual_repair = False
    if is_operator_context and sub_order is not None:
        can_create_manual_repair = (
            sub_order.status in {SUB_ORDER_STATUS_PENDING, SUB_ORDER_STATUS_IN_PROGRESS}
            and max_producible > 0
        )
        can_apply_assist = (
            assist_authorization_id is None
            and sub_order.status
            in {SUB_ORDER_STATUS_PENDING, SUB_ORDER_STATUS_IN_PROGRESS}
            and (
                max_producible > 0
                or sub_order.status == SUB_ORDER_STATUS_IN_PROGRESS
                or (
                    pipeline_mode_enabled
                    and sub_order.status == SUB_ORDER_STATUS_PENDING
                    and pipeline_start_allowed
                )
            )
        )

    return {
        "order_id": order.id,
        "order_code": order.order_code,
        "product_id": order.product_id,
        "product_name": order.product.name if order.product else "",
        "supplier_name": order.supplier_name,
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
        "user_assigned_quantity": None,
        "user_completed_quantity": sub_order.completed_quantity if sub_order else None,
        "operator_user_id": sub_order.operator_user_id if sub_order else None,
        "operator_username": sub_order.operator.username
        if sub_order and sub_order.operator
        else None,
        "work_view": work_view,
        "assist_authorization_id": assist_authorization_id,
        "pipeline_instance_id": pipeline_instance.id if pipeline_instance else None,
        "pipeline_instance_no": pipeline_instance.pipeline_instance_no
        if pipeline_instance
        else None,
        "pipeline_mode_enabled": pipeline_mode_enabled,
        "pipeline_start_allowed": pipeline_start_allowed,
        "pipeline_end_allowed": pipeline_end_allowed,
        "max_producible_quantity": max_producible,
        "can_first_article": can_first_article,
        "can_end_production": can_end_production,
        "can_apply_assist": can_apply_assist,
        "can_create_manual_repair": can_create_manual_repair,
        "due_date": order.due_date,
        "remark": order.remark,
        "updated_at": order.updated_at,
    }


def _collect_my_order_items(
    db: Session,
    *,
    current_user: User,
    keyword: str | None,
    view_mode: str = "own",
    proxy_operator_user_id: int | None = None,
    order_status: str | None = None,
    current_process_id: int | None = None,
    exact_order_id: int | None = None,
    exact_order_process_id: int | None = None,
) -> list[dict[str, object]]:
    if view_mode not in {"own", "proxy", "assist"}:
        raise ValueError("Invalid work view mode")

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
        proxy_operator = db.get(User, proxy_operator_user_id)
        if proxy_operator is None:
            raise ValueError("proxy_operator_user_id is invalid")
        stmt = (
            select(ProductionSubOrder)
            .join(ProductionSubOrder.order_process)
            .join(ProductionOrderProcess.order)
            .where(
                ProductionSubOrder.operator_user_id == proxy_operator_user_id,
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
            stmt = stmt.where(
                ProductionSubOrder.order_process_id == exact_order_process_id
            )
        if keyword:
            like_pattern = f"%{keyword.strip()}%"
            stmt = stmt.join(Product, Product.id == ProductionOrder.product_id).where(
                or_(
                    ProductionOrder.order_code.ilike(like_pattern),
                    Product.name.ilike(like_pattern),
                    ProductionOrder.supplier_name.ilike(like_pattern),
                    ProductionOrderProcess.process_code.ilike(like_pattern),
                    ProductionOrderProcess.process_name.ilike(like_pattern),
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
                    db,
                    order=order,
                    process_row=process_row,
                    sub_order=sub_order,
                    is_operator_context=True,
                    work_view="proxy",
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
                selectinload(ProductionAssistAuthorization.order).selectinload(
                    ProductionOrder.product
                ),
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
            stmt = stmt.where(
                ProductionAssistAuthorization.order_process_id == exact_order_process_id
            )
        assist_rows = db.execute(stmt).scalars().all()
        for assist_row in assist_rows:
            order = assist_row.order
            process_row = assist_row.order_process
            if order is None or process_row is None:
                continue
            if (
                order.status == ORDER_STATUS_COMPLETED
                or process_row.status == PROCESS_STATUS_COMPLETED
            ):
                continue
            sub_order = (
                db.execute(
                    select(ProductionSubOrder)
                    .where(
                        ProductionSubOrder.order_process_id == process_row.id,
                        ProductionSubOrder.operator_user_id
                        == assist_row.target_operator_user_id,
                    )
                    .options(selectinload(ProductionSubOrder.operator))
                )
                .scalars()
                .first()
            )
            if keyword:
                key = keyword.strip().lower()
                if (
                    key
                    and key not in order.order_code.lower()
                    and key not in (order.product.name if order.product else "").lower()
                    and key not in (order.supplier_name or "").lower()
                    and key not in (process_row.process_code or "").lower()
                    and key not in (process_row.process_name or "").lower()
                ):
                    continue

            process_remaining = max(
                process_row.visible_quantity - process_row.completed_quantity, 0
            )
            in_progress_count = (
                db.execute(
                    select(func.count())
                    .select_from(ProductionSubOrder)
                    .where(
                        ProductionSubOrder.order_process_id == process_row.id,
                        ProductionSubOrder.status == SUB_ORDER_STATUS_IN_PROGRESS,
                    )
                ).scalar()
                or 0
            )
            pool_remaining = max(process_remaining - in_progress_count, 0)
            sub_order_pending = sub_order is None or sub_order.status == SUB_ORDER_STATUS_PENDING
            sub_order_in_progress = sub_order is not None and sub_order.status == SUB_ORDER_STATUS_IN_PROGRESS
            max_producible = pool_remaining + (1 if sub_order_in_progress else 0)
            can_first_article = (
                assist_row.first_article_used_at is None
                and process_row.status
                in {
                    PROCESS_STATUS_PENDING,
                    PROCESS_STATUS_IN_PROGRESS,
                    PROCESS_STATUS_PARTIAL,
                }
                and pool_remaining > 0
                and sub_order_pending
                and is_pipeline_start_allowed_for_process(
                    order=order, process_row=process_row
                )
            )
            can_end_production = (
                assist_row.end_production_used_at is None
                and process_row.status
                in {PROCESS_STATUS_IN_PROGRESS, PROCESS_STATUS_PARTIAL}
                and sub_order_in_progress
                and max_producible > 0
                and is_pipeline_end_allowed_for_process(
                    order=order, process_row=process_row
                )
            )
            items.append(
                _build_my_order_item(
                    db,
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
    else:
        stmt = (
            select(ProductionOrderProcess)
            .join(ProductionOrderProcess.order)
            .options(
                selectinload(ProductionOrderProcess.order).selectinload(
                    ProductionOrder.product
                ),
                selectinload(ProductionOrderProcess.sub_orders),
            )
            .where(
                ProductionOrderProcess.visible_quantity > 0,
                ProductionOrder.status != ORDER_STATUS_COMPLETED,
                ProductionOrderProcess.status != PROCESS_STATUS_COMPLETED,
            )
            .order_by(ProductionOrder.updated_at.desc(), ProductionOrderProcess.id.desc())
        )
        if exact_order_id is not None:
            stmt = stmt.where(ProductionOrder.id == exact_order_id)
        if exact_order_process_id is not None:
            stmt = stmt.where(ProductionOrderProcess.id == exact_order_process_id)
        if keyword:
            like_pattern = f"%{keyword.strip()}%"
            stmt = stmt.outerjoin(Product, Product.id == ProductionOrder.product_id).where(
                or_(
                    ProductionOrder.order_code.ilike(like_pattern),
                    Product.name.ilike(like_pattern),
                    ProductionOrder.supplier_name.ilike(like_pattern),
                    ProductionOrderProcess.process_code.ilike(like_pattern),
                    ProductionOrderProcess.process_name.ilike(like_pattern),
                )
            )
        process_rows = db.execute(stmt).scalars().all()
        user_process_codes = {
            process.code
            for process in db.execute(
                select(Process.code)
                .select_from(User)
                .join(User.roles)
                .join(User.processes)
                .where(User.id == current_user.id, User.is_active.is_(True))
            ).scalars().all()
        }
        for process_row in process_rows:
            if process_row.process_code not in user_process_codes:
                continue
            sub_order = next(
                (
                    sub
                    for sub in process_row.sub_orders
                    if sub.operator_user_id == current_user.id
                ),
                None,
            )
            items.append(
                _build_my_order_item(
                    db,
                    order=process_row.order,
                    process_row=process_row,
                    sub_order=sub_order,
                    is_operator_context=True,
                    work_view="own",
                )
            )

    if order_status is not None or current_process_id is not None:
        filtered_items: list[dict[str, object]] = []
        for item in items:
            if (
                order_status is not None
                and str(item.get("order_status") or "") != order_status
            ):
                continue
            if current_process_id is not None:
                current_process_value = item.get("current_process_id")
                try:
                    process_id_value = (
                        int(current_process_value)
                        if current_process_value is not None
                        else 0
                    )
                except (TypeError, ValueError):
                    continue
                if process_id_value != current_process_id:
                    continue
            filtered_items.append(item)
        items = filtered_items

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
    order_status: str | None = None,
    current_process_id: int | None = None,
) -> tuple[int, list[dict[str, object]]]:
    items = _collect_my_order_items(
        db,
        current_user=current_user,
        keyword=keyword,
        view_mode=view_mode,
        proxy_operator_user_id=proxy_operator_user_id,
        order_status=order_status,
        current_process_id=current_process_id,
        exact_order_id=None,
    )
    total = len(items)
    offset = (page - 1) * page_size
    return total, items[offset : offset + page_size]


def _my_order_quantity_summary(item: dict[str, object]) -> str:
    visible_quantity = int(item.get("visible_quantity") or 0)
    process_completed_quantity = int(item.get("process_completed_quantity") or 0)
    user_completed_quantity = item.get("user_completed_quantity")
    completed_quantity = (
        int(user_completed_quantity)
        if user_completed_quantity is not None
        else process_completed_quantity
    )
    return f"可见{visible_quantity} / 完成{completed_quantity}"


def _my_order_work_view_label(work_view: str | None) -> str:
    if work_view == "proxy":
        return "代理操作员视角"
    if work_view == "assist":
        return "我的代班工单"
    return "我的工单"


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


def export_my_orders_csv(
    db: Session,
    *,
    current_user: User,
    keyword: str | None = None,
    view_mode: str = "own",
    proxy_operator_user_id: int | None = None,
    order_status: str | None = None,
    current_process_id: int | None = None,
) -> dict[str, object]:
    items = _collect_my_order_items(
        db,
        current_user=current_user,
        keyword=keyword,
        view_mode=view_mode,
        proxy_operator_user_id=proxy_operator_user_id,
        order_status=order_status,
        current_process_id=current_process_id,
        exact_order_id=None,
        exact_order_process_id=None,
    )
    headers = [
        "订单编号",
        "产品型号",
        "供应商",
        "工序",
        "数量概况",
        "状态",
        "交货日期",
        "备注",
        "工单视角",
        "操作员",
        "更新时间",
    ]
    csv_rows: list[list[str]] = []
    for item in items:
        due_date = item.get("due_date")
        updated_at = item.get("updated_at")
        csv_rows.append(
            [
                str(item.get("order_code") or ""),
                str(item.get("product_name") or ""),
                str(item.get("supplier_name") or ""),
                str(item.get("current_process_name") or ""),
                _my_order_quantity_summary(item),
                order_status_label(str(item.get("order_status") or "")),
                str(due_date) if due_date else "",
                str(item.get("remark") or ""),
                _my_order_work_view_label(str(item.get("work_view") or "own")),
                str(item.get("operator_username") or ""),
                updated_at.strftime("%Y-%m-%d %H:%M:%S") if updated_at else "",
            ]
        )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for row in csv_rows:
        writer.writerow(row)
    content_b64 = base64.b64encode(output.getvalue().encode("utf-8-sig")).decode(
        "ascii"
    )
    file_name = f"my_orders_{datetime.now(UTC).strftime('%Y%m%d%H%M%S')}.csv"
    return {
        "file_name": file_name,
        "mime_type": "text/csv",
        "content_base64": content_b64,
        "exported_count": len(csv_rows),
    }


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
        "订单号",
        "产品名称",
        "产品版本",
        "数量",
        "当前状态",
        "当前工序",
        "工艺模板",
        "模板版本",
        "并行模式",
        "开始日期",
        "交期",
        "创建人",
        "更新时间",
    ]
    csv_rows = []
    for row in rows:
        process_rows = sorted(
            row.processes, key=lambda item: (item.process_order, item.id)
        )
        current_process = next(
            (item for item in process_rows if item.status != PROCESS_STATUS_COMPLETED),
            None,
        )
        if current_process is None and row.current_process_code:
            current_process = next(
                (
                    item
                    for item in process_rows
                    if item.process_code == row.current_process_code
                ),
                None,
            )
        csv_rows.append(
            [
                row.order_code,
                row.product.name if row.product else "",
                row.product_version or "",
                row.quantity,
                order_status_label(row.status),
                current_process.process_name if current_process else "",
                row.process_template_name or "",
                row.process_template_version or "",
                pipeline_mode_label(bool(row.pipeline_enabled)),
                str(row.start_date) if row.start_date else "",
                str(row.due_date) if row.due_date else "",
                row.created_by.username if row.created_by else "",
                row.updated_at.strftime("%Y-%m-%d %H:%M:%S") if row.updated_at else "",
            ]
        )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for r in csv_rows:
        writer.writerow(r)
    content_b64 = base64.b64encode(output.getvalue().encode("utf-8-sig")).decode(
        "ascii"
    )
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
    process_keyword: str | None = None,
    pipeline_instance_no: str | None = None,
    is_active: bool | None = None,
    page: int = 1,
    page_size: int = 100,
) -> tuple[int, list[ProcessPipelineInstance]]:
    from sqlalchemy.orm import joinedload

    stmt = select(ProcessPipelineInstance).options(
        joinedload(ProcessPipelineInstance.order),
        joinedload(ProcessPipelineInstance.order_process),
    )
    if order_id is not None:
        stmt = stmt.where(ProcessPipelineInstance.order_id == order_id)
    if order_code is not None and order_code.strip():
        stmt = stmt.join(
            ProductionOrder,
            ProductionOrder.id == ProcessPipelineInstance.order_id,
            isouter=False,
        ).where(ProductionOrder.order_code.ilike(f"%{order_code.strip()}%"))
    if order_process_id is not None:
        stmt = stmt.where(
            ProcessPipelineInstance.order_process_id == order_process_id
        )
    if process_keyword is not None and process_keyword.strip():
        like_pattern = f"%{process_keyword.strip()}%"
        stmt = stmt.join(
            ProductionOrderProcess,
            ProductionOrderProcess.id == ProcessPipelineInstance.order_process_id,
            isouter=False,
        ).where(
            or_(
                ProcessPipelineInstance.process_code.ilike(like_pattern),
                ProductionOrderProcess.process_name.ilike(like_pattern),
            )
        )
    if pipeline_instance_no is not None and pipeline_instance_no.strip():
        stmt = stmt.where(
            ProcessPipelineInstance.pipeline_instance_no.ilike(
                f"%{pipeline_instance_no.strip()}%"
            )
        )
    if is_active is not None:
        stmt = stmt.where(ProcessPipelineInstance.is_active == is_active)
    stmt = stmt.order_by(
        ProcessPipelineInstance.order_id.asc(),
        ProcessPipelineInstance.pipeline_seq.asc(),
        ProcessPipelineInstance.id.asc(),
    )
    rows = db.execute(stmt).unique().scalars().all()
    total = len(rows)
    offset = (page - 1) * page_size
    return total, rows[offset : offset + page_size]
