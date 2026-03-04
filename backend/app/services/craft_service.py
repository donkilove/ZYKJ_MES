from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_PENDING,
)
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.product import Product
from app.models.product_process_template import ProductProcessTemplate
from app.models.product_process_template_step import ProductProcessTemplateStep
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.user import User
from app.services.production_order_service import ensure_sub_orders_visible_quantity


@dataclass(slots=True)
class TemplateSyncConflictReason:
    order_id: int
    order_code: str
    reason: str


@dataclass(slots=True)
class TemplateSyncResult:
    total: int
    synced: int
    skipped: int
    reasons: list[TemplateSyncConflictReason]


class TemplateSyncConflictError(RuntimeError):
    def __init__(self, result: TemplateSyncResult) -> None:
        self.result = result
        super().__init__("Template update finished with conflicts")


def _normalize_text(value: str, *, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} is required")
    return normalized


def _get_stage_by_id(db: Session, stage_id: int) -> ProcessStage | None:
    return db.execute(select(ProcessStage).where(ProcessStage.id == stage_id)).scalars().first()


def get_stage_by_code(db: Session, stage_code: str) -> ProcessStage | None:
    return db.execute(select(ProcessStage).where(ProcessStage.code == stage_code)).scalars().first()


def get_stage_by_id(db: Session, stage_id: int) -> ProcessStage | None:
    return _get_stage_by_id(db, stage_id)


def list_stages(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    enabled: bool | None,
) -> tuple[int, list[ProcessStage]]:
    stmt = select(ProcessStage)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                ProcessStage.code.ilike(like_pattern),
                ProcessStage.name.ilike(like_pattern),
            )
        )
    if enabled is not None:
        stmt = stmt.where(ProcessStage.is_enabled.is_(enabled))

    stmt = stmt.order_by(ProcessStage.sort_order.asc(), ProcessStage.id.asc())
    total = db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one()
    rows = db.execute(stmt.offset((page - 1) * page_size).limit(page_size)).scalars().all()
    return int(total), rows


def create_stage(
    db: Session,
    *,
    code: str,
    name: str,
    sort_order: int,
) -> ProcessStage:
    normalized_code = _normalize_text(code, field_name="Stage code")
    normalized_name = _normalize_text(name, field_name="Stage name")
    if get_stage_by_code(db, normalized_code):
        raise ValueError("Stage code already exists")

    row = ProcessStage(
        code=normalized_code,
        name=normalized_name,
        sort_order=sort_order,
        is_enabled=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def update_stage(
    db: Session,
    *,
    row: ProcessStage,
    name: str,
    sort_order: int,
    is_enabled: bool,
    code: str | None = None,
) -> ProcessStage:
    if code is not None:
        normalized_code = _normalize_text(code, field_name="Stage code")
        if normalized_code != row.code:
            existing = db.execute(select(ProcessStage).where(ProcessStage.code == normalized_code)).scalars().first()
            if existing:
                raise ValueError("Stage code already exists")
            row.code = normalized_code
    row.name = _normalize_text(name, field_name="Stage name")
    row.sort_order = sort_order
    row.is_enabled = is_enabled
    db.commit()
    db.refresh(row)
    return row


def delete_stage(db: Session, *, row: ProcessStage) -> None:
    process_ref = db.execute(select(Process.id).where(Process.stage_id == row.id).limit(1)).scalars().first()
    if process_ref is not None:
        raise ValueError("Stage is referenced by processes")
    template_ref = (
        db.execute(select(ProductProcessTemplateStep.id).where(ProductProcessTemplateStep.stage_id == row.id).limit(1))
        .scalars()
        .first()
    )
    if template_ref is not None:
        raise ValueError("Stage is referenced by templates")
    order_ref = db.execute(select(ProductionOrderProcess.id).where(ProductionOrderProcess.stage_id == row.id).limit(1)).scalars().first()
    if order_ref is not None:
        raise ValueError("Stage is referenced by orders")
    db.delete(row)
    db.commit()


def list_craft_processes(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    stage_id: int | None,
    enabled: bool | None,
) -> tuple[int, list[Process]]:
    stmt = select(Process).options(selectinload(Process.stage))
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                Process.code.ilike(like_pattern),
                Process.name.ilike(like_pattern),
            )
        )
    if stage_id is not None:
        stmt = stmt.where(Process.stage_id == stage_id)
    if enabled is not None:
        stmt = stmt.where(Process.is_enabled.is_(enabled))

    stmt = stmt.order_by(Process.id.asc())
    total = db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one()
    rows = db.execute(stmt.offset((page - 1) * page_size).limit(page_size)).scalars().all()
    return int(total), rows


def create_process(
    db: Session,
    *,
    code: str,
    name: str,
    stage_id: int,
) -> Process:
    normalized_code = _normalize_text(code, field_name="Process code")
    normalized_name = _normalize_text(name, field_name="Process name")
    if db.execute(select(Process).where(Process.code == normalized_code)).scalars().first():
        raise ValueError("Process code already exists")
    stage = _get_stage_by_id(db, stage_id)
    if not stage:
        raise ValueError("Stage not found")
    if not stage.is_enabled:
        raise ValueError("Stage is disabled")

    row = Process(
        code=normalized_code,
        name=normalized_name,
        stage_id=stage.id,
        is_enabled=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def update_process(
    db: Session,
    *,
    row: Process,
    name: str,
    stage_id: int,
    is_enabled: bool,
    code: str | None = None,
) -> Process:
    if code is not None:
        normalized_code = _normalize_text(code, field_name="Process code")
        if normalized_code != row.code:
            existing = db.execute(select(Process).where(Process.code == normalized_code)).scalars().first()
            if existing:
                raise ValueError("Process code already exists")
            row.code = normalized_code
    stage = _get_stage_by_id(db, stage_id)
    if not stage:
        raise ValueError("Stage not found")
    row.name = _normalize_text(name, field_name="Process name")
    row.stage_id = stage.id
    row.is_enabled = is_enabled
    db.commit()
    db.refresh(row)
    return row


def delete_process(db: Session, *, row: Process) -> None:
    template_ref = (
        db.execute(select(ProductProcessTemplateStep.id).where(ProductProcessTemplateStep.process_id == row.id).limit(1))
        .scalars()
        .first()
    )
    if template_ref is not None:
        raise ValueError("Process is referenced by templates")
    order_ref = db.execute(select(ProductionOrderProcess.id).where(ProductionOrderProcess.process_id == row.id).limit(1)).scalars().first()
    if order_ref is not None:
        raise ValueError("Process is referenced by orders")
    db.delete(row)
    db.commit()


def _set_product_default_template(db: Session, *, product_id: int, template_id: int) -> None:
    rows = db.execute(
        select(ProductProcessTemplate).where(
            ProductProcessTemplate.product_id == product_id,
            ProductProcessTemplate.is_enabled.is_(True),
        )
    ).scalars().all()
    for row in rows:
        row.is_default = row.id == template_id


def _load_template_step_process_map(
    db: Session,
    *,
    steps: list[tuple[int, int, int]],
) -> list[tuple[int, ProcessStage, Process]]:
    if not steps:
        raise ValueError("At least one process step is required")
    stage_ids = {item[1] for item in steps}
    process_ids = {item[2] for item in steps}

    stage_rows = db.execute(select(ProcessStage).where(ProcessStage.id.in_(stage_ids))).scalars().all()
    process_rows = db.execute(select(Process).where(Process.id.in_(process_ids))).scalars().all()
    stage_by_id = {row.id: row for row in stage_rows}
    process_by_id = {row.id: row for row in process_rows}

    result: list[tuple[int, ProcessStage, Process]] = []
    for step_order, stage_id, process_id in sorted(steps, key=lambda item: item[0]):
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
        result.append((step_order, stage, process))
    return result


def _replace_template_steps(
    db: Session,
    *,
    template: ProductProcessTemplate,
    steps: list[tuple[int, ProcessStage, Process]],
) -> None:
    template.steps = []
    db.flush()
    for step_order, stage, process in steps:
        template.steps.append(
            ProductProcessTemplateStep(
                step_order=step_order,
                stage_id=stage.id,
                stage_code=stage.code,
                stage_name=stage.name,
                process_id=process.id,
                process_code=process.code,
                process_name=process.name,
            )
        )
    db.flush()


def _build_template_steps_payload(
    steps: list[dict[str, int]],
) -> list[tuple[int, int, int]]:
    if not steps:
        raise ValueError("At least one process step is required")
    seen_orders: set[int] = set()
    result: list[tuple[int, int, int]] = []
    for item in steps:
        step_order = int(item["step_order"])
        if step_order in seen_orders:
            raise ValueError("step_order cannot be duplicated")
        seen_orders.add(step_order)
        result.append((step_order, int(item["stage_id"]), int(item["process_id"])))
    return result


def list_templates(
    db: Session,
    *,
    page: int,
    page_size: int,
    product_id: int | None,
    keyword: str | None,
    enabled: bool | None,
) -> tuple[int, list[ProductProcessTemplate]]:
    stmt = (
        select(ProductProcessTemplate)
        .options(
            selectinload(ProductProcessTemplate.product),
            selectinload(ProductProcessTemplate.created_by),
            selectinload(ProductProcessTemplate.updated_by),
        )
        .join(Product, Product.id == ProductProcessTemplate.product_id)
    )
    if product_id is not None:
        stmt = stmt.where(ProductProcessTemplate.product_id == product_id)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                Product.name.ilike(like_pattern),
                ProductProcessTemplate.template_name.ilike(like_pattern),
            )
        )
    if enabled is not None:
        stmt = stmt.where(ProductProcessTemplate.is_enabled.is_(enabled))
    stmt = stmt.order_by(
        ProductProcessTemplate.product_id.asc(),
        ProductProcessTemplate.is_default.desc(),
        ProductProcessTemplate.updated_at.desc(),
        ProductProcessTemplate.id.desc(),
    )
    total = db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one()
    rows = db.execute(stmt.offset((page - 1) * page_size).limit(page_size)).scalars().all()
    return int(total), rows


def get_template_by_id(db: Session, template_id: int) -> ProductProcessTemplate | None:
    return (
        db.execute(
            select(ProductProcessTemplate)
            .where(ProductProcessTemplate.id == template_id)
            .options(
                selectinload(ProductProcessTemplate.product),
                selectinload(ProductProcessTemplate.created_by),
                selectinload(ProductProcessTemplate.updated_by),
                selectinload(ProductProcessTemplate.steps),
            )
        )
        .scalars()
        .first()
    )


def create_template(
    db: Session,
    *,
    product_id: int,
    template_name: str,
    is_default: bool,
    steps: list[dict[str, int]],
    operator: User,
) -> ProductProcessTemplate:
    product = db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    if not product:
        raise ValueError("Product not found")
    normalized_name = _normalize_text(template_name, field_name="Template name")
    existing_name = (
        db.execute(
            select(ProductProcessTemplate).where(
                ProductProcessTemplate.product_id == product_id,
                ProductProcessTemplate.template_name == normalized_name,
                ProductProcessTemplate.is_enabled.is_(True),
            )
        )
        .scalars()
        .first()
    )
    if existing_name:
        raise ValueError("Template name already exists under this product")

    step_payload = _build_template_steps_payload(steps)
    step_processes = _load_template_step_process_map(db, steps=step_payload)

    row = ProductProcessTemplate(
        product_id=product_id,
        template_name=normalized_name,
        version=1,
        is_default=is_default,
        is_enabled=True,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
    )
    db.add(row)
    db.flush()
    _replace_template_steps(db, template=row, steps=step_processes)

    if is_default:
        _set_product_default_template(db, product_id=product_id, template_id=row.id)
    else:
        has_default = (
            db.execute(
                select(ProductProcessTemplate.id).where(
                    ProductProcessTemplate.product_id == product_id,
                    ProductProcessTemplate.is_enabled.is_(True),
                    ProductProcessTemplate.is_default.is_(True),
                )
            )
            .scalars()
            .first()
        )
        if has_default is None:
            row.is_default = True

    db.commit()
    db.refresh(row)
    return get_template_by_id(db, row.id) or row


def _count_future_production_records(db: Session, *, order_process_ids: list[int]) -> int:
    if not order_process_ids:
        return 0
    count = db.execute(
        select(func.count())
        .select_from(ProductionRecord)
        .where(
            ProductionRecord.order_process_id.in_(order_process_ids),
            ProductionRecord.production_quantity > 0,
        )
    ).scalar_one()
    return int(count or 0)


def _create_order_process_row(
    *,
    order_id: int,
    step_order: int,
    stage: ProcessStage,
    process: Process,
    visible_quantity: int,
) -> ProductionOrderProcess:
    return ProductionOrderProcess(
        order_id=order_id,
        process_id=process.id,
        stage_id=stage.id,
        stage_code=stage.code,
        stage_name=stage.name,
        process_code=process.code,
        process_name=process.name,
        process_order=step_order,
        status=PROCESS_STATUS_PENDING,
        visible_quantity=max(0, visible_quantity),
        completed_quantity=0,
    )


def _sync_template_to_orders(
    db: Session,
    *,
    template: ProductProcessTemplate,
    step_processes: list[tuple[int, ProcessStage, Process]],
) -> TemplateSyncResult:
    orders = (
        db.execute(
            select(ProductionOrder)
            .where(
                ProductionOrder.process_template_id == template.id,
                ProductionOrder.status != ORDER_STATUS_COMPLETED,
            )
            .options(
                selectinload(ProductionOrder.processes),
            )
            .order_by(ProductionOrder.id.asc())
        )
        .scalars()
        .all()
    )
    reasons: list[TemplateSyncConflictReason] = []
    synced = 0

    for order in orders:
        existing_rows = sorted(order.processes, key=lambda item: (item.process_order, item.id))
        if order.status == ORDER_STATUS_PENDING:
            order.processes = []
            db.flush()
            for idx, (_, stage, process) in enumerate(step_processes):
                row = _create_order_process_row(
                    order_id=order.id,
                    step_order=idx + 1,
                    stage=stage,
                    process=process,
                    visible_quantity=order.quantity if idx == 0 else 0,
                )
                db.add(row)
                db.flush()
                ensure_sub_orders_visible_quantity(
                    db,
                    process_row=row,
                    target_visible_quantity=row.visible_quantity,
                )
            if step_processes:
                order.current_process_code = step_processes[0][2].code
            synced += 1
            continue

        if order.status != ORDER_STATUS_IN_PROGRESS:
            reasons.append(
                TemplateSyncConflictReason(
                    order_id=order.id,
                    order_code=order.order_code,
                    reason=f"Unsupported order status: {order.status}",
                )
            )
            continue

        current_row = next((row for row in existing_rows if row.status != PROCESS_STATUS_COMPLETED), None)
        if not current_row:
            reasons.append(
                TemplateSyncConflictReason(
                    order_id=order.id,
                    order_code=order.order_code,
                    reason="Current process not found",
                )
            )
            continue

        matched_index = -1
        for idx, (_, stage, process) in enumerate(step_processes):
            if process.code == current_row.process_code and stage.code == (current_row.stage_code or stage.code):
                matched_index = idx
                break
        if matched_index < 0:
            reasons.append(
                TemplateSyncConflictReason(
                    order_id=order.id,
                    order_code=order.order_code,
                    reason="Current process cannot align with template",
                )
            )
            continue

        future_rows = [row for row in existing_rows if row.process_order > current_row.process_order]
        if future_rows:
            future_ids = [row.id for row in future_rows]
            if _count_future_production_records(db, order_process_ids=future_ids) > 0:
                reasons.append(
                    TemplateSyncConflictReason(
                        order_id=order.id,
                        order_code=order.order_code,
                        reason="Future process already has production records",
                    )
                )
                continue

        for row in future_rows:
            db.delete(row)
        db.flush()

        append_steps = step_processes[matched_index + 1 :]
        base_order = current_row.process_order
        for offset, (_, stage, process) in enumerate(append_steps, start=1):
            visible_quantity = current_row.completed_quantity if offset == 1 else 0
            row = _create_order_process_row(
                order_id=order.id,
                step_order=base_order + offset,
                stage=stage,
                process=process,
                visible_quantity=visible_quantity,
            )
            db.add(row)
            db.flush()
            ensure_sub_orders_visible_quantity(
                db,
                process_row=row,
                target_visible_quantity=row.visible_quantity,
            )
        synced += 1

    return TemplateSyncResult(
        total=len(orders),
        synced=synced,
        skipped=max(len(orders) - synced, 0),
        reasons=reasons,
    )


def update_template(
    db: Session,
    *,
    template: ProductProcessTemplate,
    template_name: str,
    is_default: bool,
    is_enabled: bool,
    steps: list[dict[str, int]],
    sync_orders: bool,
    operator: User,
) -> tuple[ProductProcessTemplate, TemplateSyncResult]:
    normalized_name = _normalize_text(template_name, field_name="Template name")
    existing_name = (
        db.execute(
            select(ProductProcessTemplate)
            .where(
                ProductProcessTemplate.product_id == template.product_id,
                ProductProcessTemplate.template_name == normalized_name,
                ProductProcessTemplate.id != template.id,
                ProductProcessTemplate.is_enabled.is_(True),
            )
        )
        .scalars()
        .first()
    )
    if existing_name:
        raise ValueError("Template name already exists under this product")

    step_payload = _build_template_steps_payload(steps)
    step_processes = _load_template_step_process_map(db, steps=step_payload)

    template.template_name = normalized_name
    template.is_default = is_default
    template.is_enabled = is_enabled
    template.updated_by_user_id = operator.id
    template.version += 1
    _replace_template_steps(db, template=template, steps=step_processes)

    if template.is_default and template.is_enabled:
        _set_product_default_template(db, product_id=template.product_id, template_id=template.id)

    sync_result = TemplateSyncResult(total=0, synced=0, skipped=0, reasons=[])
    if sync_orders:
        sync_result = _sync_template_to_orders(
            db,
            template=template,
            step_processes=step_processes,
        )
    db.commit()
    db.refresh(template)

    if sync_result.skipped > 0:
        raise TemplateSyncConflictError(sync_result)
    return get_template_by_id(db, template.id) or template, sync_result


def delete_template(db: Session, *, template: ProductProcessTemplate) -> None:
    active_ref = (
        db.execute(
            select(ProductionOrder.id).where(
                ProductionOrder.process_template_id == template.id,
                ProductionOrder.status != ORDER_STATUS_COMPLETED,
            )
        )
        .scalars()
        .first()
    )
    if active_ref is not None:
        raise ValueError("Template is referenced by unfinished orders")
    db.delete(template)
    db.commit()


def is_valid_stage_code(db: Session, code: str) -> bool:
    normalized = code.strip()
    if not normalized:
        return False
    row = db.execute(
        select(ProcessStage.id).where(
            ProcessStage.code == normalized,
            ProcessStage.is_enabled.is_(True),
        )
    ).scalars().first()
    return row is not None


def list_enabled_stage_options(db: Session) -> list[ProcessStage]:
    return (
        db.execute(
            select(ProcessStage)
            .where(ProcessStage.is_enabled.is_(True))
            .order_by(ProcessStage.sort_order.asc(), ProcessStage.id.asc())
        )
        .scalars()
        .all()
    )


def resolve_user_stage_codes(db: Session, *, process_codes: list[str]) -> set[str]:
    normalized_codes = sorted({code.strip() for code in process_codes if code and code.strip()})
    if not normalized_codes:
        return set()
    rows = (
        db.execute(
            select(ProcessStage.code)
            .join(Process, and_(Process.stage_id == ProcessStage.id, Process.is_enabled.is_(True)))
            .where(Process.code.in_(normalized_codes))
        )
        .scalars()
        .all()
    )
    return {row for row in rows if row}

