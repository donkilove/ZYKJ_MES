from __future__ import annotations

import base64
import csv
import io
import json
from datetime import UTC, datetime
from dataclasses import dataclass
from math import ceil
from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_PENDING,
    RECORD_TYPE_FIRST_ARTICLE,
    RECORD_TYPE_PRODUCTION,
)
from app.models.craft_system_master_template import CraftSystemMasterTemplate
from app.models.craft_system_master_template_revision import CraftSystemMasterTemplateRevision
from app.models.craft_system_master_template_revision_step import CraftSystemMasterTemplateRevisionStep
from app.models.craft_system_master_template_step import CraftSystemMasterTemplateStep
from app.models.maintenance_plan import MaintenancePlan
from app.models.maintenance_work_order import MaintenanceWorkOrder
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.product import Product
from app.models.product_process_template import ProductProcessTemplate
from app.models.product_process_template_revision import ProductProcessTemplateRevision
from app.models.product_process_template_revision_step import ProductProcessTemplateRevisionStep
from app.models.product_process_template_step import ProductProcessTemplateStep
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.repair_cause import RepairCause
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
from app.models.repair_return_route import RepairReturnRoute
from app.models.user import User
from app.services.process_code_rule import (
    ensure_process_code_unique,
    get_stage_for_process_write,
    validate_process_code_matches_stage,
)
from app.services.production_order_service import ensure_sub_orders_visible_quantity


SYSTEM_MASTER_TEMPLATE_SINGLETON_ID = 1
TEMPLATE_LIFECYCLE_DRAFT = "draft"
TEMPLATE_LIFECYCLE_PUBLISHED = "published"
TEMPLATE_LIFECYCLE_ARCHIVED = "archived"
TEMPLATE_LIFECYCLE_OPTIONS = {
    TEMPLATE_LIFECYCLE_DRAFT,
    TEMPLATE_LIFECYCLE_PUBLISHED,
    TEMPLATE_LIFECYCLE_ARCHIVED,
}


@dataclass(slots=True)
class SystemMasterTemplateResolveResult:
    template: CraftSystemMasterTemplate | None
    skip_reason: str | None


@dataclass(slots=True)
class TemplateSyncConflictReason:
    order_id: int
    order_code: str
    reason: str
    order_status: str | None = None


@dataclass(slots=True)
class TemplateSyncResult:
    total: int
    synced: int
    skipped: int
    reasons: list[TemplateSyncConflictReason]


@dataclass(slots=True)
class TemplateImpactResult:
    total_orders: int
    pending_orders: int
    in_progress_orders: int
    syncable_orders: int
    blocked_orders: int
    items: list[TemplateSyncConflictReason]


@dataclass(slots=True)
class TemplateVersionCompareRow:
    step_order: int
    diff_type: str
    from_stage_code: str | None
    from_process_code: str | None
    to_stage_code: str | None
    to_process_code: str | None


@dataclass(slots=True)
class TemplateVersionCompareResult:
    from_version: int
    to_version: int
    added_steps: int
    removed_steps: int
    changed_steps: int
    items: list[TemplateVersionCompareRow]


@dataclass(slots=True)
class TemplateStepPayloadItem:
    step_order: int
    stage_id: int
    process_id: int
    standard_minutes: int = 0
    is_key_process: bool = False
    step_remark: str = ""


@dataclass(slots=True)
class TemplateStepResolvedItem:
    step_order: int
    stage: ProcessStage
    process: Process
    standard_minutes: int
    is_key_process: bool
    step_remark: str


@dataclass(slots=True)
class CraftKanbanSample:
    order_process_id: int
    order_id: int
    order_code: str
    start_at: datetime
    end_at: datetime
    work_minutes: int
    production_qty: int
    capacity_per_hour: float


@dataclass(slots=True)
class CraftKanbanProcessMetricsRow:
    stage_id: int | None
    stage_code: str | None
    stage_name: str | None
    process_id: int
    process_code: str
    process_name: str
    samples: list[CraftKanbanSample]


@dataclass(slots=True)
class CraftKanbanProcessMetricsResult:
    product: Product
    items: list[CraftKanbanProcessMetricsRow]


class TemplateSyncConflictError(RuntimeError):
    def __init__(self, result: TemplateSyncResult) -> None:
        self.result = result
        super().__init__("Template update finished with conflicts")


def _normalize_text(value: str, *, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} is required")
    return normalized


def _normalize_remark(value: str | None) -> str:
    return (value or "").strip()


def _normalize_template_lifecycle_status(value: str | None) -> str:
    normalized = (value or TEMPLATE_LIFECYCLE_DRAFT).strip().lower()
    if normalized not in TEMPLATE_LIFECYCLE_OPTIONS:
        raise ValueError("Invalid template lifecycle status")
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
    rows = db.execute(
        stmt.offset((page - 1) * page_size).limit(page_size).options(selectinload(ProcessStage.processes))
    ).scalars().all()
    return int(total), rows


def create_stage(
    db: Session,
    *,
    code: str,
    name: str,
    sort_order: int,
    remark: str = "",
) -> ProcessStage:
    normalized_code = _normalize_text(code, field_name="Stage code")
    normalized_name = _normalize_text(name, field_name="Stage name")
    if get_stage_by_code(db, normalized_code):
        raise ValueError("Stage code already exists")
    existing_name = db.execute(select(ProcessStage).where(ProcessStage.name == normalized_name)).scalars().first()
    if existing_name:
        raise ValueError("Stage name already exists")

    row = ProcessStage(
        code=normalized_code,
        name=normalized_name,
        sort_order=sort_order,
        is_enabled=True,
        remark=_normalize_remark(remark),
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
    remark: str | None = None,
) -> ProcessStage:
    if code is not None:
        normalized_code = _normalize_text(code, field_name="Stage code")
        if normalized_code != row.code:
            existing = db.execute(select(ProcessStage).where(ProcessStage.code == normalized_code)).scalars().first()
            if existing:
                raise ValueError("Stage code already exists")
            row.code = normalized_code
    normalized_name = _normalize_text(name, field_name="Stage name")
    if normalized_name != row.name:
        existing_name = db.execute(select(ProcessStage).where(ProcessStage.name == normalized_name)).scalars().first()
        if existing_name:
            raise ValueError("Stage name already exists")
    row.name = normalized_name
    row.sort_order = sort_order
    row.is_enabled = is_enabled
    if remark is not None:
        row.remark = _normalize_remark(remark)
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
    system_master_ref = (
        db.execute(
            select(CraftSystemMasterTemplateStep.id).where(CraftSystemMasterTemplateStep.stage_id == row.id).limit(1)
        )
        .scalars()
        .first()
    )
    if system_master_ref is not None:
        raise ValueError("Stage is referenced by system master template")
    system_master_revision_ref = (
        db.execute(
            select(CraftSystemMasterTemplateRevisionStep.id).where(
                CraftSystemMasterTemplateRevisionStep.stage_id == row.id
            ).limit(1)
        )
        .scalars()
        .first()
    )
    if system_master_revision_ref is not None:
        raise ValueError("Stage is referenced by system master template revisions")
    template_revision_ref = (
        db.execute(
            select(ProductProcessTemplateRevisionStep.id).where(
                ProductProcessTemplateRevisionStep.stage_id == row.id
            ).limit(1)
        )
        .scalars()
        .first()
    )
    if template_revision_ref is not None:
        raise ValueError("Stage is referenced by template revisions")
    order_ref = db.execute(select(ProductionOrderProcess.id).where(ProductionOrderProcess.stage_id == row.id).limit(1)).scalars().first()
    if order_ref is not None:
        raise ValueError("Stage is referenced by orders")
    user_ref = db.execute(select(User.id).where(User.stage_id == row.id).limit(1)).scalars().first()
    if user_ref is not None:
        raise ValueError("Stage is referenced by users")
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


def _ensure_process_name_unique_in_stage(
    db: Session,
    *,
    stage_id: int,
    name: str,
    exclude_process_id: int | None = None,
) -> None:
    stmt = select(Process.id).where(Process.stage_id == stage_id, Process.name == name)
    if exclude_process_id is not None:
        stmt = stmt.where(Process.id != exclude_process_id)
    existing = db.execute(stmt).scalars().first()
    if existing is not None:
        raise ValueError("Process name already exists in this stage")


def create_process(
    db: Session,
    *,
    code: str,
    name: str,
    stage_id: int,
    remark: str = "",
) -> Process:
    stage = get_stage_for_process_write(db, stage_id=stage_id, require_enabled=True)
    normalized_code = validate_process_code_matches_stage(code=code, stage=stage)
    normalized_name = _normalize_text(name, field_name="Process name")
    ensure_process_code_unique(db, code=normalized_code)
    _ensure_process_name_unique_in_stage(db, stage_id=stage.id, name=normalized_name)

    row = Process(
        code=normalized_code,
        name=normalized_name,
        stage_id=stage.id,
        is_enabled=True,
        remark=_normalize_remark(remark),
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
    remark: str | None = None,
) -> Process:
    stage = get_stage_for_process_write(db, stage_id=stage_id)
    candidate_code = code if code is not None else row.code
    normalized_code = validate_process_code_matches_stage(code=candidate_code, stage=stage)
    if normalized_code != row.code:
        ensure_process_code_unique(db, code=normalized_code, exclude_process_id=row.id)
    row.code = normalized_code
    normalized_name = _normalize_text(name, field_name="Process name")
    if normalized_name != row.name or stage.id != row.stage_id:
        _ensure_process_name_unique_in_stage(
            db, stage_id=stage.id, name=normalized_name, exclude_process_id=row.id
        )
    row.name = normalized_name
    row.stage_id = stage.id
    row.is_enabled = is_enabled
    if remark is not None:
        row.remark = _normalize_remark(remark)
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
    system_master_ref = (
        db.execute(
            select(CraftSystemMasterTemplateStep.id).where(CraftSystemMasterTemplateStep.process_id == row.id).limit(1)
        )
        .scalars()
        .first()
    )
    if system_master_ref is not None:
        raise ValueError("Process is referenced by system master template")
    system_master_revision_ref = (
        db.execute(
            select(CraftSystemMasterTemplateRevisionStep.id).where(
                CraftSystemMasterTemplateRevisionStep.process_id == row.id
            ).limit(1)
        )
        .scalars()
        .first()
    )
    if system_master_revision_ref is not None:
        raise ValueError("Process is referenced by system master template revisions")
    template_revision_ref = (
        db.execute(
            select(ProductProcessTemplateRevisionStep.id).where(
                ProductProcessTemplateRevisionStep.process_id == row.id
            ).limit(1)
        )
        .scalars()
        .first()
    )
    if template_revision_ref is not None:
        raise ValueError("Process is referenced by template revisions")
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
            ProductProcessTemplate.lifecycle_status == TEMPLATE_LIFECYCLE_PUBLISHED,
        )
    ).scalars().all()
    for row in rows:
        row.is_default = row.id == template_id


def _load_template_step_process_map(
    db: Session,
    *,
    steps: list[TemplateStepPayloadItem],
) -> list[TemplateStepResolvedItem]:
    if not steps:
        raise ValueError("At least one process step is required")
    stage_ids = {item.stage_id for item in steps}
    process_ids = {item.process_id for item in steps}

    stage_rows = db.execute(select(ProcessStage).where(ProcessStage.id.in_(stage_ids))).scalars().all()
    process_rows = db.execute(select(Process).where(Process.id.in_(process_ids))).scalars().all()
    stage_by_id = {row.id: row for row in stage_rows}
    process_by_id = {row.id: row for row in process_rows}

    result: list[TemplateStepResolvedItem] = []
    for item in sorted(steps, key=lambda payload: payload.step_order):
        stage = stage_by_id.get(item.stage_id)
        process = process_by_id.get(item.process_id)
        if not stage:
            raise ValueError(f"Stage not found: {item.stage_id}")
        if not process:
            raise ValueError(f"Process not found: {item.process_id}")
        if process.stage_id != stage.id:
            raise ValueError(f"Process {process.code} does not belong to stage {stage.code}")
        if not stage.is_enabled:
            raise ValueError(f"Stage disabled: {stage.code}")
        if not process.is_enabled:
            raise ValueError(f"Process disabled: {process.code}")
        result.append(
            TemplateStepResolvedItem(
                step_order=item.step_order,
                stage=stage,
                process=process,
                standard_minutes=max(int(item.standard_minutes), 0),
                is_key_process=bool(item.is_key_process),
                step_remark=(item.step_remark or "").strip(),
            )
        )
    return result


def _replace_template_steps(
    db: Session,
    *,
    template: ProductProcessTemplate,
    steps: list[TemplateStepResolvedItem],
) -> None:
    template.steps = []
    db.flush()
    for item in steps:
        template.steps.append(
            ProductProcessTemplateStep(
                step_order=item.step_order,
                stage_id=item.stage.id,
                stage_code=item.stage.code,
                stage_name=item.stage.name,
                process_id=item.process.id,
                process_code=item.process.code,
                process_name=item.process.name,
                standard_minutes=item.standard_minutes,
                is_key_process=item.is_key_process,
                step_remark=item.step_remark,
            )
        )
    db.flush()


def _build_template_steps_payload(
    steps: list[dict[str, object]],
) -> list[TemplateStepPayloadItem]:
    if not steps:
        raise ValueError("At least one process step is required")
    seen_orders: set[int] = set()
    result: list[TemplateStepPayloadItem] = []
    for item in steps:
        step_order = int(item["step_order"])
        if step_order in seen_orders:
            raise ValueError("step_order cannot be duplicated")
        seen_orders.add(step_order)
        result.append(
            TemplateStepPayloadItem(
                step_order=step_order,
                stage_id=int(item["stage_id"]),
                process_id=int(item["process_id"]),
                standard_minutes=max(int(item.get("standard_minutes") or 0), 0),
                is_key_process=bool(item.get("is_key_process") or False),
                step_remark=str(item.get("step_remark") or "").strip(),
            )
        )
    return result


def _build_steps_payload_from_template_row(
    template: ProductProcessTemplate,
) -> list[TemplateStepPayloadItem]:
    sorted_steps = sorted(template.steps, key=lambda item: (item.step_order, item.id))
    return [
            TemplateStepPayloadItem(
                step_order=step.step_order,
                stage_id=step.stage_id,
                process_id=step.process_id,
                standard_minutes=step.standard_minutes,
                is_key_process=step.is_key_process,
                step_remark=step.step_remark,
            )
        for step in sorted_steps
    ]


def list_templates(
    db: Session,
    *,
    page: int,
    page_size: int,
    product_id: int | None,
    keyword: str | None,
    enabled: bool | None,
    lifecycle_status: str | None = None,
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
    if lifecycle_status is not None:
        stmt = stmt.where(
            ProductProcessTemplate.lifecycle_status
            == _normalize_template_lifecycle_status(lifecycle_status)
        )
    stmt = stmt.order_by(
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


def _create_template_revision_snapshot(
    db: Session,
    *,
    template: ProductProcessTemplate,
    operator: User | None,
    action: str,
    note: str | None = None,
    source_revision_id: int | None = None,
) -> ProductProcessTemplateRevision:
    revision = ProductProcessTemplateRevision(
        template_id=template.id,
        version=template.published_version,
        action=action,
        note=(note or "").strip() or None,
        source_revision_id=source_revision_id,
        created_by_user_id=operator.id if operator else template.updated_by_user_id,
    )
    db.add(revision)
    db.flush()

    sorted_steps = sorted(template.steps, key=lambda item: (item.step_order, item.id))
    for step in sorted_steps:
        revision.steps.append(
            ProductProcessTemplateRevisionStep(
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
                standard_minutes=step.standard_minutes,
                is_key_process=step.is_key_process,
                step_remark=step.step_remark,
            )
        )
    db.flush()
    return revision


def list_template_versions(
    db: Session,
    *,
    template_id: int,
) -> list[ProductProcessTemplateRevision]:
    return (
        db.execute(
            select(ProductProcessTemplateRevision)
            .where(ProductProcessTemplateRevision.template_id == template_id)
            .options(selectinload(ProductProcessTemplateRevision.created_by))
            .order_by(ProductProcessTemplateRevision.version.desc(), ProductProcessTemplateRevision.id.desc())
        )
        .scalars()
        .all()
    )


def get_template_version(
    db: Session,
    *,
    template_id: int,
    version: int,
) -> ProductProcessTemplateRevision | None:
    return (
        db.execute(
            select(ProductProcessTemplateRevision)
            .where(
                ProductProcessTemplateRevision.template_id == template_id,
                ProductProcessTemplateRevision.version == version,
            )
            .options(selectinload(ProductProcessTemplateRevision.steps))
        )
        .scalars()
        .first()
    )


def get_system_master_template(db: Session) -> CraftSystemMasterTemplate | None:
    return (
        db.execute(
            select(CraftSystemMasterTemplate)
            .where(CraftSystemMasterTemplate.id == SYSTEM_MASTER_TEMPLATE_SINGLETON_ID)
            .options(
                selectinload(CraftSystemMasterTemplate.created_by),
                selectinload(CraftSystemMasterTemplate.updated_by),
                selectinload(CraftSystemMasterTemplate.steps),
            )
        )
        .scalars()
        .first()
    )


def _replace_system_master_template_steps(
    db: Session,
    *,
    template: CraftSystemMasterTemplate,
    steps: list[TemplateStepResolvedItem],
) -> None:
    template.steps = []
    db.flush()
    for item in steps:
        template.steps.append(
            CraftSystemMasterTemplateStep(
                step_order=item.step_order,
                stage_id=item.stage.id,
                stage_code=item.stage.code,
                stage_name=item.stage.name,
                process_id=item.process.id,
                process_code=item.process.code,
                process_name=item.process.name,
                standard_minutes=item.standard_minutes,
                is_key_process=item.is_key_process,
                step_remark=item.step_remark,
            )
        )
    db.flush()


def _create_system_master_revision_snapshot(
    db: Session,
    *,
    template: CraftSystemMasterTemplate,
    operator: User | None,
    action: str,
    note: str | None = None,
) -> CraftSystemMasterTemplateRevision:
    revision = CraftSystemMasterTemplateRevision(
        template_id=template.id,
        version=template.version,
        action=action,
        note=(note or "").strip() or None,
        created_by_user_id=operator.id if operator else template.updated_by_user_id,
    )
    db.add(revision)
    db.flush()

    sorted_steps = sorted(template.steps, key=lambda item: (item.step_order, item.id))
    for step in sorted_steps:
        revision.steps.append(
            CraftSystemMasterTemplateRevisionStep(
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
                standard_minutes=step.standard_minutes,
                is_key_process=step.is_key_process,
                step_remark=step.step_remark,
            )
        )
    db.flush()
    return revision


def create_system_master_template(
    db: Session,
    *,
    steps: list[dict[str, object]],
    operator: User,
) -> CraftSystemMasterTemplate:
    existing = get_system_master_template(db)
    if existing is not None:
        raise ValueError("System master template already exists")

    step_payload = _build_template_steps_payload(steps)
    step_processes = _load_template_step_process_map(db, steps=step_payload)

    row = CraftSystemMasterTemplate(
        id=SYSTEM_MASTER_TEMPLATE_SINGLETON_ID,
        version=1,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
    )
    db.add(row)
    db.flush()
    _replace_system_master_template_steps(db, template=row, steps=step_processes)
    _create_system_master_revision_snapshot(
        db,
        template=row,
        operator=operator,
        action="create",
        note="System master template created",
    )
    db.commit()
    return get_system_master_template(db) or row


def update_system_master_template(
    db: Session,
    *,
    steps: list[dict[str, object]],
    operator: User,
) -> CraftSystemMasterTemplate:
    row = get_system_master_template(db)
    if row is None:
        raise LookupError("System master template not found")

    step_payload = _build_template_steps_payload(steps)
    step_processes = _load_template_step_process_map(db, steps=step_payload)

    row.version += 1
    row.updated_by_user_id = operator.id
    _replace_system_master_template_steps(db, template=row, steps=step_processes)
    _create_system_master_revision_snapshot(
        db,
        template=row,
        operator=operator,
        action="update",
        note=f"System master template updated to v{row.version}",
    )
    db.commit()
    return get_system_master_template(db) or row


def list_system_master_template_versions(
    db: Session,
) -> SystemMasterTemplateVersionResult:
    def _load_rows() -> list[CraftSystemMasterTemplateRevision]:
        return (
            db.execute(
                select(CraftSystemMasterTemplateRevision)
                .where(CraftSystemMasterTemplateRevision.template_id == SYSTEM_MASTER_TEMPLATE_SINGLETON_ID)
                .options(
                    selectinload(CraftSystemMasterTemplateRevision.created_by),
                    selectinload(CraftSystemMasterTemplateRevision.steps),
                )
                .order_by(
                    CraftSystemMasterTemplateRevision.version.desc(),
                    CraftSystemMasterTemplateRevision.id.desc(),
                )
            )
            .scalars()
            .all()
        )

    rows = _load_rows()
    if not rows:
        template = get_system_master_template(db)
        if template is not None:
            _create_system_master_revision_snapshot(
                db,
                template=template,
                operator=template.updated_by,
                action="snapshot",
                note=f"Auto snapshot for existing system master v{template.version}",
            )
            db.commit()
            rows = _load_rows()
    return SystemMasterTemplateVersionResult(total=len(rows), items=rows)


def resolve_system_master_template(db: Session) -> SystemMasterTemplateResolveResult:
    template = get_system_master_template(db)
    if template is None:
        return SystemMasterTemplateResolveResult(
            template=None,
            skip_reason="No system master template configured",
        )

    steps = sorted(template.steps, key=lambda item: (item.step_order, item.id))
    if not steps:
        return SystemMasterTemplateResolveResult(
            template=None,
            skip_reason="Configured system master template has no steps",
        )

    try:
        _load_template_step_process_map(
            db,
            steps=[
                TemplateStepPayloadItem(
                    step_order=step.step_order,
                    stage_id=step.stage_id,
                    process_id=step.process_id,
                )
                for step in steps
            ],
        )
    except ValueError as error:
        return SystemMasterTemplateResolveResult(
            template=None,
            skip_reason=f"Configured system master template invalid: {error}",
        )

    return SystemMasterTemplateResolveResult(template=template, skip_reason=None)


def create_template(
    db: Session,
    *,
    product_id: int,
    template_name: str,
    is_default: bool,
    lifecycle_status: str = TEMPLATE_LIFECYCLE_PUBLISHED,
    remark: str = "",
    steps: list[dict[str, object]],
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
    normalized_status = _normalize_template_lifecycle_status(lifecycle_status)
    is_published = normalized_status == TEMPLATE_LIFECYCLE_PUBLISHED

    row = ProductProcessTemplate(
        product_id=product_id,
        template_name=normalized_name,
        version=1,
        lifecycle_status=normalized_status,
        published_version=1 if is_published else 0,
        is_default=is_default,
        is_enabled=True,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
        remark=_normalize_remark(remark),
        source_type="manual",
    )
    db.add(row)
    db.flush()
    _replace_template_steps(db, template=row, steps=step_processes)

    if is_default and is_published:
        _set_product_default_template(db, product_id=product_id, template_id=row.id)
    elif is_published:
        has_default = (
            db.execute(
                select(ProductProcessTemplate.id).where(
                    ProductProcessTemplate.product_id == product_id,
                    ProductProcessTemplate.is_enabled.is_(True),
                    ProductProcessTemplate.lifecycle_status == TEMPLATE_LIFECYCLE_PUBLISHED,
                    ProductProcessTemplate.is_default.is_(True),
                )
            )
            .scalars()
            .first()
        )
        if has_default is None:
            row.is_default = True
    else:
        row.is_default = is_default

    if is_published:
        _create_template_revision_snapshot(
            db,
            template=row,
            operator=operator,
            action="publish",
            note="Template created and published",
        )

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
    step_processes: list[TemplateStepResolvedItem],
    dry_run: bool = False,
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
            if not dry_run:
                order.processes = []
                db.flush()
                for idx, step in enumerate(step_processes):
                    row = _create_order_process_row(
                        order_id=order.id,
                        step_order=idx + 1,
                        stage=step.stage,
                        process=step.process,
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
                    order.current_process_code = step_processes[0].process.code
            synced += 1
            continue

        if order.status != ORDER_STATUS_IN_PROGRESS:
            reasons.append(
                TemplateSyncConflictReason(
                    order_id=order.id,
                    order_code=order.order_code,
                    reason=f"Unsupported order status: {order.status}",
                    order_status=order.status,
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
                    order_status=order.status,
                )
            )
            continue

        matched_index = -1
        for idx, step in enumerate(step_processes):
            stage = step.stage
            process = step.process
            if process.code == current_row.process_code and stage.code == (current_row.stage_code or stage.code):
                matched_index = idx
                break
        if matched_index < 0:
            reasons.append(
                TemplateSyncConflictReason(
                    order_id=order.id,
                    order_code=order.order_code,
                    reason="Current process cannot align with template",
                    order_status=order.status,
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
                        order_status=order.status,
                    )
                )
                continue

        if not dry_run:
            for row in future_rows:
                db.delete(row)
            db.flush()

            append_steps = step_processes[matched_index + 1 :]
            base_order = current_row.process_order
            for offset, step in enumerate(append_steps, start=1):
                visible_quantity = current_row.completed_quantity if offset == 1 else 0
                row = _create_order_process_row(
                    order_id=order.id,
                    step_order=base_order + offset,
                    stage=step.stage,
                    process=step.process,
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
    remark: str | None = None,
    steps: list[dict[str, object]],
    sync_orders: bool,
    operator: User,
) -> tuple[ProductProcessTemplate, TemplateSyncResult]:
    del sync_orders  # Sync is handled by explicit publish/rollback actions.
    if template.lifecycle_status != TEMPLATE_LIFECYCLE_DRAFT:
        raise ValueError("已发布或已归档模板不可直接编辑，请先创建草稿后再修改")

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
    if remark is not None:
        template.remark = _normalize_remark(remark)
    template.lifecycle_status = TEMPLATE_LIFECYCLE_DRAFT
    template.updated_by_user_id = operator.id
    template.version += 1
    _replace_template_steps(db, template=template, steps=step_processes)

    if (
        template.is_default
        and template.is_enabled
        and template.lifecycle_status == TEMPLATE_LIFECYCLE_PUBLISHED
    ):
        _set_product_default_template(db, product_id=template.product_id, template_id=template.id)

    sync_result = TemplateSyncResult(total=0, synced=0, skipped=0, reasons=[])
    db.commit()
    db.refresh(template)

    return get_template_by_id(db, template.id) or template, sync_result


def create_template_draft(
    db: Session,
    *,
    template: ProductProcessTemplate,
    operator: User,
) -> ProductProcessTemplate:
    if template.lifecycle_status == TEMPLATE_LIFECYCLE_DRAFT:
        raise ValueError("当前模板已是草稿版本")
    template.lifecycle_status = TEMPLATE_LIFECYCLE_DRAFT
    template.version += 1
    template.updated_by_user_id = operator.id
    db.commit()
    db.refresh(template)
    return get_template_by_id(db, template.id) or template


def set_template_enabled(
    db: Session,
    *,
    template: ProductProcessTemplate,
    is_enabled: bool,
    operator: User,
) -> ProductProcessTemplate:
    if template.is_enabled == is_enabled:
        return get_template_by_id(db, template.id) or template

    template.is_enabled = is_enabled
    template.updated_by_user_id = operator.id
    template.version += 1

    # Disabled templates cannot continue as default templates.
    if not is_enabled and template.is_default:
        template.is_default = False

    if (
        is_enabled
        and template.is_default
        and template.lifecycle_status == TEMPLATE_LIFECYCLE_PUBLISHED
    ):
        _set_product_default_template(
            db,
            product_id=template.product_id,
            template_id=template.id,
        )

    db.commit()
    db.refresh(template)
    return get_template_by_id(db, template.id) or template


def analyze_template_impact(
    db: Session,
    *,
    template: ProductProcessTemplate,
) -> TemplateImpactResult:
    step_payload = _build_steps_payload_from_template_row(template)
    step_processes = _load_template_step_process_map(db, steps=step_payload)
    preview = _sync_template_to_orders(
        db,
        template=template,
        step_processes=step_processes,
        dry_run=True,
    )
    reason_by_order_id = {item.order_id: item.reason for item in preview.reasons}
    status_by_order_id = {item.order_id: item.order_status for item in preview.reasons}
    blocked_order_ids = set(reason_by_order_id.keys())

    active_orders = db.execute(
        select(ProductionOrder.id, ProductionOrder.order_code, ProductionOrder.status).where(
            ProductionOrder.process_template_id == template.id,
            ProductionOrder.status != ORDER_STATUS_COMPLETED,
        )
    ).all()

    pending_count = 0
    in_progress_count = 0
    items: list[TemplateSyncConflictReason] = []
    for order_id, order_code, order_status in active_orders:
        if order_status == ORDER_STATUS_PENDING:
            pending_count += 1
        elif order_status == ORDER_STATUS_IN_PROGRESS:
            in_progress_count += 1

        reason = reason_by_order_id.get(order_id)
        if order_id in blocked_order_ids:
            items.append(
                TemplateSyncConflictReason(
                    order_id=order_id,
                    order_code=order_code,
                    reason=reason or "Blocked",
                    order_status=order_status,
                )
            )
        else:
            items.append(
                TemplateSyncConflictReason(
                    order_id=order_id,
                    order_code=order_code,
                    reason="",
                    order_status=order_status,
                )
            )

    return TemplateImpactResult(
        total_orders=len(active_orders),
        pending_orders=pending_count,
        in_progress_orders=in_progress_count,
        syncable_orders=max(preview.synced, 0),
        blocked_orders=max(preview.skipped, 0),
        items=items,
    )


def publish_template(
    db: Session,
    *,
    template: ProductProcessTemplate,
    operator: User,
    apply_order_sync: bool,
    confirmed: bool,
    expected_version: int | None = None,
    note: str | None = None,
) -> tuple[ProductProcessTemplate, TemplateSyncResult]:
    if not template.is_enabled:
        raise ValueError("Disabled template cannot be published")
    if expected_version is not None and template.version != expected_version:
        raise ValueError("Template has been updated by another user, please refresh and retry")

    step_payload = _build_steps_payload_from_template_row(template)
    if not step_payload:
        raise ValueError("Template has no steps")
    step_processes = _load_template_step_process_map(db, steps=step_payload)
    preview = _sync_template_to_orders(
        db,
        template=template,
        step_processes=step_processes,
        dry_run=True,
    )

    if apply_order_sync and preview.total > 0 and not confirmed:
        raise ValueError("Impact confirmation required before applying order sync")

    sync_result = TemplateSyncResult(total=0, synced=0, skipped=0, reasons=[])
    if apply_order_sync:
        sync_result = _sync_template_to_orders(
            db,
            template=template,
            step_processes=step_processes,
            dry_run=False,
        )

    template.lifecycle_status = TEMPLATE_LIFECYCLE_PUBLISHED
    template.published_version = max(template.published_version, 0) + 1
    template.version += 1
    template.updated_by_user_id = operator.id

    if template.is_default and template.is_enabled:
        _set_product_default_template(db, product_id=template.product_id, template_id=template.id)

    _create_template_revision_snapshot(
        db,
        template=template,
        operator=operator,
        action="publish",
        note=note,
    )
    db.commit()
    db.refresh(template)
    return get_template_by_id(db, template.id) or template, sync_result


def compare_template_versions(
    db: Session,
    *,
    template: ProductProcessTemplate,
    from_version: int,
    to_version: int,
) -> TemplateVersionCompareResult:
    from_row = get_template_version(db, template_id=template.id, version=from_version)
    to_row = get_template_version(db, template_id=template.id, version=to_version)
    if from_row is None:
        raise ValueError(f"Version not found: {from_version}")
    if to_row is None:
        raise ValueError(f"Version not found: {to_version}")

    from_by_order = {step.step_order: step for step in from_row.steps}
    to_by_order = {step.step_order: step for step in to_row.steps}
    step_orders = sorted(set(from_by_order.keys()) | set(to_by_order.keys()))

    rows: list[TemplateVersionCompareRow] = []
    added = 0
    removed = 0
    changed = 0
    for step_order in step_orders:
        left = from_by_order.get(step_order)
        right = to_by_order.get(step_order)
        if left is None and right is not None:
            added += 1
            rows.append(
                TemplateVersionCompareRow(
                    step_order=step_order,
                    diff_type="added",
                    from_stage_code=None,
                    from_process_code=None,
                    to_stage_code=right.stage_code,
                    to_process_code=right.process_code,
                )
            )
            continue
        if left is not None and right is None:
            removed += 1
            rows.append(
                TemplateVersionCompareRow(
                    step_order=step_order,
                    diff_type="removed",
                    from_stage_code=left.stage_code,
                    from_process_code=left.process_code,
                    to_stage_code=None,
                    to_process_code=None,
                )
            )
            continue
        assert left is not None and right is not None
        has_change = (
            left.stage_code != right.stage_code
            or left.process_code != right.process_code
        )
        if has_change:
            changed += 1
            rows.append(
                TemplateVersionCompareRow(
                    step_order=step_order,
                    diff_type="changed",
                    from_stage_code=left.stage_code,
                    from_process_code=left.process_code,
                    to_stage_code=right.stage_code,
                    to_process_code=right.process_code,
                )
            )

    return TemplateVersionCompareResult(
        from_version=from_version,
        to_version=to_version,
        added_steps=added,
        removed_steps=removed,
        changed_steps=changed,
        items=rows,
    )


def rollback_template_to_version(
    db: Session,
    *,
    template: ProductProcessTemplate,
    target_version: int,
    operator: User,
    apply_order_sync: bool,
    confirmed: bool,
    note: str | None = None,
) -> tuple[ProductProcessTemplate, TemplateSyncResult]:
    target_revision = get_template_version(db, template_id=template.id, version=target_version)
    if target_revision is None:
        raise ValueError(f"Version not found: {target_version}")

    payload = [
        TemplateStepPayloadItem(
            step_order=step.step_order,
            stage_id=step.stage_id,
            process_id=step.process_id,
        )
        for step in sorted(target_revision.steps, key=lambda item: (item.step_order, item.id))
    ]
    step_processes = _load_template_step_process_map(db, steps=payload)

    preview = _sync_template_to_orders(
        db,
        template=template,
        step_processes=step_processes,
        dry_run=True,
    )
    if apply_order_sync and preview.total > 0 and not confirmed:
        raise ValueError("Impact confirmation required before applying order sync")

    _replace_template_steps(db, template=template, steps=step_processes)
    template.lifecycle_status = TEMPLATE_LIFECYCLE_PUBLISHED
    template.published_version = max(template.published_version, 0) + 1
    template.version += 1
    template.updated_by_user_id = operator.id

    if template.is_default and template.is_enabled:
        _set_product_default_template(db, product_id=template.product_id, template_id=template.id)

    sync_result = TemplateSyncResult(total=0, synced=0, skipped=0, reasons=[])
    if apply_order_sync:
        sync_result = _sync_template_to_orders(
            db,
            template=template,
            step_processes=step_processes,
            dry_run=False,
        )

    _create_template_revision_snapshot(
        db,
        template=template,
        operator=operator,
        action="rollback",
        note=note or f"Rollback to v{target_version}",
        source_revision_id=target_revision.id,
    )
    db.commit()
    db.refresh(template)
    return get_template_by_id(db, template.id) or template, sync_result


def _build_craft_kanban_sample(order_process: ProductionOrderProcess) -> CraftKanbanSample | None:
    records = list(order_process.production_records or [])
    if not records:
        return None

    first_article_times = [
        _normalize_kanban_datetime(record.created_at)
        for record in records
        if record.record_type == RECORD_TYPE_FIRST_ARTICLE and record.created_at is not None
    ]
    production_points = [
        (
            _normalize_kanban_datetime(record.created_at),
            int(record.production_quantity or 0),
        )
        for record in records
        if record.record_type == RECORD_TYPE_PRODUCTION and record.created_at is not None
    ]
    if not production_points:
        return None

    production_qty = int(sum(quantity for _, quantity in production_points))
    if production_qty <= 0:
        return None

    start_at = min(first_article_times) if first_article_times else min(created_at for created_at, _ in production_points)
    end_at = max(created_at for created_at, _ in production_points)
    if end_at < start_at:
        return None

    elapsed_seconds = (end_at - start_at).total_seconds()
    work_minutes = max(1, ceil(elapsed_seconds / 60.0))
    capacity_per_hour = round(production_qty / (work_minutes / 60.0), 2)

    return CraftKanbanSample(
        order_process_id=order_process.id,
        order_id=order_process.order_id,
        order_code=order_process.order.order_code if order_process.order else "",
        start_at=start_at,
        end_at=end_at,
        work_minutes=work_minutes,
        production_qty=production_qty,
        capacity_per_hour=capacity_per_hour,
    )


def _normalize_kanban_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value
    return value.astimezone(UTC).replace(tzinfo=None)


def get_craft_kanban_process_metrics(
    db: Session,
    *,
    product_id: int,
    limit: int = 5,
    stage_id: int | None = None,
    process_id: int | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
) -> CraftKanbanProcessMetricsResult:
    normalized_limit = max(1, min(int(limit), 20))
    product = db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    if product is None:
        raise ValueError("Product not found")

    filters = [
        ProductionOrder.product_id == product_id,
        ProductionOrderProcess.status == PROCESS_STATUS_COMPLETED,
    ]
    if stage_id is not None:
        filters.append(ProductionOrderProcess.stage_id == stage_id)
    if process_id is not None:
        filters.append(ProductionOrderProcess.process_id == process_id)
    if start_date is not None:
        filters.append(ProductionOrderProcess.updated_at >= _normalize_kanban_datetime(start_date))
    if end_date is not None:
        filters.append(ProductionOrderProcess.updated_at <= _normalize_kanban_datetime(end_date))

    completed_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .join(ProductionOrder, ProductionOrder.id == ProductionOrderProcess.order_id)
            .where(*filters)
            .options(
                selectinload(ProductionOrderProcess.order),
                selectinload(ProductionOrderProcess.production_records),
            )
            .order_by(ProductionOrderProcess.id.desc())
        )
        .scalars()
        .all()
    )

    process_rows: dict[int, CraftKanbanProcessMetricsRow] = {}
    for order_process in completed_rows:
        sample = _build_craft_kanban_sample(order_process)
        if sample is None:
            continue

        bucket = process_rows.get(order_process.process_id)
        if bucket is None:
            bucket = CraftKanbanProcessMetricsRow(
                stage_id=order_process.stage_id,
                stage_code=order_process.stage_code,
                stage_name=order_process.stage_name,
                process_id=order_process.process_id,
                process_code=order_process.process_code,
                process_name=order_process.process_name,
                samples=[],
            )
            process_rows[order_process.process_id] = bucket
        bucket.samples.append(sample)

    stage_ids = [item.stage_id for item in process_rows.values() if item.stage_id is not None]
    stage_sort_map: dict[int, int] = {}
    if stage_ids:
        stage_rows = db.execute(
            select(ProcessStage.id, ProcessStage.sort_order).where(ProcessStage.id.in_(set(stage_ids)))
        ).all()
        stage_sort_map = {int(stage_id): int(sort_order) for stage_id, sort_order in stage_rows}

    items: list[CraftKanbanProcessMetricsRow] = []
    for row in process_rows.values():
        latest_samples = sorted(
            row.samples,
            key=lambda item: (item.end_at, item.order_process_id),
            reverse=True,
        )[:normalized_limit]
        row.samples = sorted(latest_samples, key=lambda item: (item.end_at, item.order_process_id))
        items.append(row)

    items.sort(
        key=lambda item: (
            stage_sort_map.get(item.stage_id or -1, 10**9),
            item.process_code,
            item.process_id,
        )
    )
    return CraftKanbanProcessMetricsResult(product=product, items=items)


def export_craft_kanban_process_metrics_csv(
    db: Session,
    *,
    product_id: int,
    stage_id: int | None = None,
    process_id: int | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    limit: int = 5,
) -> dict[str, object]:
    result = get_craft_kanban_process_metrics(
        db,
        product_id=product_id,
        stage_id=stage_id,
        process_id=process_id,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )

    csv_rows: list[list[object]] = []
    for process_row in result.items:
        for sample in process_row.samples:
            csv_rows.append(
                [
                    result.product.id,
                    result.product.name,
                    process_row.stage_code or "",
                    process_row.stage_name or "",
                    process_row.process_code,
                    process_row.process_name,
                    sample.order_id,
                    sample.order_code,
                    sample.start_at.isoformat(),
                    sample.end_at.isoformat(),
                    sample.work_minutes,
                    sample.production_qty,
                    sample.capacity_per_hour,
                ]
            )

    content_base64 = _craft_csv_base64(
        [
            "product_id",
            "product_name",
            "stage_code",
            "stage_name",
            "process_code",
            "process_name",
            "order_id",
            "order_code",
            "start_at",
            "end_at",
            "work_minutes",
            "production_qty",
            "capacity_per_hour",
        ],
        csv_rows,
    )
    return {
        "file_name": f"craft_kanban_metrics_product_{result.product.id}.csv",
        "mime_type": "text/csv",
        "content_base64": content_base64,
        "exported_count": len(csv_rows),
    }


def export_templates(
    db: Session,
    *,
    product_id: int | None = None,
    keyword: str | None = None,
    product_category: str | None = None,
    is_default: bool | None = None,
    enabled: bool | None = None,
    lifecycle_status: str | None = None,
    updated_from: datetime | None = None,
    updated_to: datetime | None = None,
) -> list[ProductProcessTemplate]:
    stmt = (
        select(ProductProcessTemplate)
        .options(
            selectinload(ProductProcessTemplate.product),
            selectinload(ProductProcessTemplate.steps),
        )
        .join(Product, Product.id == ProductProcessTemplate.product_id)
        .order_by(
            ProductProcessTemplate.product_id.asc(),
            ProductProcessTemplate.updated_at.desc(),
            ProductProcessTemplate.id.desc(),
        )
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
    if product_category:
        stmt = stmt.where(Product.category == product_category.strip())
    if is_default is not None:
        stmt = stmt.where(ProductProcessTemplate.is_default.is_(is_default))
    if enabled is not None:
        stmt = stmt.where(ProductProcessTemplate.is_enabled.is_(enabled))
    if lifecycle_status is not None:
        normalized_status = _normalize_template_lifecycle_status(lifecycle_status)
        stmt = stmt.where(ProductProcessTemplate.lifecycle_status == normalized_status)
    if updated_from is not None:
        stmt = stmt.where(ProductProcessTemplate.updated_at >= _normalize_kanban_datetime(updated_from))
    if updated_to is not None:
        stmt = stmt.where(ProductProcessTemplate.updated_at <= _normalize_kanban_datetime(updated_to))
    return db.execute(stmt).scalars().all()


def import_templates(
    db: Session,
    *,
    items: list[dict[str, object]],
    overwrite_existing: bool,
    publish_after_import: bool,
    operator: User,
) -> tuple[list[ProductProcessTemplate], int, int, int, list[str]]:
    created = 0
    updated = 0
    skipped = 0
    errors: list[str] = []
    touched_rows: list[ProductProcessTemplate] = []

    for idx, item in enumerate(items):
        item_label = f"第{idx + 1}条"
        try:
            with db.begin_nested():
                raw_product_id = item.get("product_id")
                raw_product_name = str(item.get("product_name") or "").strip()
                if raw_product_id is not None:
                    product = db.execute(select(Product).where(Product.id == int(raw_product_id))).scalars().first()
                elif raw_product_name:
                    product = db.execute(select(Product).where(Product.name == raw_product_name)).scalars().first()
                else:
                    errors.append(f"{item_label}：product_id 或 product_name 不能同时为空")
                    skipped += 1
                    continue
                if product is None:
                    errors.append(f"{item_label}：找不到产品 {raw_product_name or raw_product_id}")
                    skipped += 1
                    continue

                template_name = _normalize_text(str(item.get("template_name") or ""), field_name="Template name")
                existing = (
                    db.execute(
                        select(ProductProcessTemplate)
                        .where(
                            ProductProcessTemplate.product_id == product.id,
                            ProductProcessTemplate.template_name == template_name,
                        )
                        .options(selectinload(ProductProcessTemplate.steps))
                        .order_by(ProductProcessTemplate.id.desc())
                    )
                    .scalars()
                    .first()
                )
                if existing is not None and not overwrite_existing:
                    skipped += 1
                    continue

                lifecycle_status = _normalize_template_lifecycle_status(
                    TEMPLATE_LIFECYCLE_PUBLISHED if publish_after_import else str(item.get("lifecycle_status") or "draft")
                )
                is_published = lifecycle_status == TEMPLATE_LIFECYCLE_PUBLISHED
                is_default = bool(item.get("is_default", False))
                is_enabled = bool(item.get("is_enabled", True))
                steps = item.get("steps")
                if not isinstance(steps, list):
                    errors.append(f"{item_label}（{template_name}）：steps 必须是列表")
                    skipped += 1
                    continue
                step_payload = _build_template_steps_payload([dict(step) for step in steps])
                step_processes = _load_template_step_process_map(db, steps=step_payload)

                if existing is None:
                    row = ProductProcessTemplate(
                        product_id=product.id,
                        template_name=template_name,
                        version=1,
                        lifecycle_status=lifecycle_status,
                        published_version=1 if is_published else 0,
                        is_default=is_default,
                        is_enabled=is_enabled,
                        created_by_user_id=operator.id,
                        updated_by_user_id=operator.id,
                        source_type="manual",
                    )
                    db.add(row)
                    db.flush()
                    _replace_template_steps(db, template=row, steps=step_processes)
                    if is_published:
                        _create_template_revision_snapshot(
                            db,
                            template=row,
                            operator=operator,
                            action="import",
                            note="Batch import",
                        )
                        if row.is_default and row.is_enabled:
                            _set_product_default_template(db, product_id=row.product_id, template_id=row.id)
                    touched_rows.append(row)
                    created += 1
                    continue

                existing.is_default = is_default
                existing.is_enabled = is_enabled
                existing.lifecycle_status = lifecycle_status
                existing.version += 1
                existing.updated_by_user_id = operator.id
                if is_published:
                    existing.published_version = max(existing.published_version, 0) + 1
                _replace_template_steps(db, template=existing, steps=step_processes)
                if is_published:
                    _create_template_revision_snapshot(
                        db,
                        template=existing,
                        operator=operator,
                        action="import",
                        note="Batch import overwrite",
                    )
                    if existing.is_default and existing.is_enabled:
                        _set_product_default_template(db, product_id=existing.product_id, template_id=existing.id)

                touched_rows.append(existing)
                updated += 1
        except ValueError as exc:
            errors.append(f"{item_label}：{exc}")
            skipped += 1

    db.commit()
    return touched_rows, created, updated, skipped, errors


def delete_template(db: Session, *, template: ProductProcessTemplate) -> None:
    any_order_ref = (
        db.execute(
            select(ProductionOrder.id).where(
                ProductionOrder.process_template_id == template.id,
            )
        )
        .scalars()
        .first()
    )
    if any_order_ref is not None:
        raise ValueError("Template is referenced by production orders")
    if template.published_version > 0 or template.revisions:
        raise ValueError("Template already has published versions or history, please archive instead of deleting")
    db.delete(template)
    db.commit()


def copy_template(
    db: Session,
    *,
    template: ProductProcessTemplate,
    new_name: str,
    operator: User,
) -> ProductProcessTemplate:
    normalized_name = _normalize_text(new_name, field_name="Template name")
    existing_name = (
        db.execute(
            select(ProductProcessTemplate).where(
                ProductProcessTemplate.product_id == template.product_id,
                ProductProcessTemplate.template_name == normalized_name,
                ProductProcessTemplate.is_enabled.is_(True),
            )
        )
        .scalars()
        .first()
    )
    if existing_name:
        raise ValueError("Template name already exists under this product")

    row = ProductProcessTemplate(
        product_id=template.product_id,
        template_name=normalized_name,
        version=1,
        lifecycle_status=TEMPLATE_LIFECYCLE_DRAFT,
        published_version=0,
        is_default=False,
        is_enabled=True,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
        source_type="template",
        source_template_id=template.id,
        source_template_name=template.template_name,
        source_template_version=template.version,
        source_product_id=template.product_id,
    )
    db.add(row)
    db.flush()

    sorted_steps = sorted(template.steps, key=lambda item: (item.step_order, item.id))
    for step in sorted_steps:
        row.steps.append(
            ProductProcessTemplateStep(
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
                standard_minutes=step.standard_minutes,
                is_key_process=step.is_key_process,
                step_remark=step.step_remark,
            )
        )
    db.flush()
    db.commit()
    db.refresh(row)
    return get_template_by_id(db, row.id) or row


def copy_template_from_system_master(
    db: Session,
    *,
    system_master: CraftSystemMasterTemplate,
    product_id: int,
    new_name: str,
    operator: User,
) -> ProductProcessTemplate:
    """从系统母版套版，创建指定产品的工艺模板草稿。"""
    normalized_name = _normalize_text(new_name, field_name="Template name")
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

    row = ProductProcessTemplate(
        product_id=product_id,
        template_name=normalized_name,
        version=1,
        lifecycle_status=TEMPLATE_LIFECYCLE_DRAFT,
        published_version=0,
        is_default=False,
        is_enabled=True,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
        source_type="system_master",
        source_system_master_version=system_master.version,
    )
    db.add(row)
    db.flush()

    sorted_steps = sorted(system_master.steps, key=lambda s: (s.step_order, s.id))
    for step in sorted_steps:
        row.steps.append(
            ProductProcessTemplateStep(
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
                standard_minutes=step.standard_minutes,
                is_key_process=step.is_key_process,
                step_remark=step.step_remark,
            )
        )
    db.flush()
    db.commit()
    db.refresh(row)
    return get_template_by_id(db, row.id) or row


def copy_template_to_product(
    db: Session,
    *,
    template: ProductProcessTemplate,
    target_product_id: int,
    new_name: str,
    operator: User,
) -> ProductProcessTemplate:
    """跨产品复制模板，来源记录保留在 template_name 中。"""
    normalized_name = _normalize_text(new_name, field_name="Template name")
    existing_name = (
        db.execute(
            select(ProductProcessTemplate).where(
                ProductProcessTemplate.product_id == target_product_id,
                ProductProcessTemplate.template_name == normalized_name,
                ProductProcessTemplate.is_enabled.is_(True),
            )
        )
        .scalars()
        .first()
    )
    if existing_name:
        raise ValueError("Template name already exists under target product")

    row = ProductProcessTemplate(
        product_id=target_product_id,
        template_name=normalized_name,
        version=1,
        lifecycle_status=TEMPLATE_LIFECYCLE_DRAFT,
        published_version=0,
        is_default=False,
        is_enabled=True,
        created_by_user_id=operator.id,
        updated_by_user_id=operator.id,
        source_type="cross_product_template",
        source_template_id=template.id,
        source_template_name=template.template_name,
        source_template_version=template.version,
        source_product_id=template.product_id,
    )
    db.add(row)
    db.flush()

    sorted_steps = sorted(template.steps, key=lambda s: (s.step_order, s.id))
    for step in sorted_steps:
        row.steps.append(
            ProductProcessTemplateStep(
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
                standard_minutes=step.standard_minutes,
                is_key_process=step.is_key_process,
                step_remark=step.step_remark,
            )
        )
    db.flush()
    db.commit()
    db.refresh(row)
    return get_template_by_id(db, row.id) or row


def archive_template(
    db: Session,
    *,
    template: ProductProcessTemplate,
    operator: User,
) -> ProductProcessTemplate:
    if template.lifecycle_status == TEMPLATE_LIFECYCLE_ARCHIVED:
        raise ValueError("Template is already archived")
    if template.lifecycle_status != TEMPLATE_LIFECYCLE_PUBLISHED:
        raise ValueError("Only published templates can be archived")
    template.lifecycle_status = TEMPLATE_LIFECYCLE_ARCHIVED
    template.is_default = False
    template.updated_by_user_id = operator.id
    db.commit()
    db.refresh(template)
    return get_template_by_id(db, template.id) or template


def unarchive_template(
    db: Session,
    *,
    template: ProductProcessTemplate,
    operator: User,
) -> ProductProcessTemplate:
    if template.lifecycle_status != TEMPLATE_LIFECYCLE_ARCHIVED:
        raise ValueError("Template is not archived")
    template.lifecycle_status = TEMPLATE_LIFECYCLE_PUBLISHED
    template.updated_by_user_id = operator.id
    db.commit()
    db.refresh(template)
    return get_template_by_id(db, template.id) or template


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


def list_enabled_process_options(
    db: Session,
    *,
    stage_id: int | None = None,
) -> list[Process]:
    stmt = select(Process).options(selectinload(Process.stage)).where(Process.is_enabled.is_(True))
    if stage_id is not None:
        stmt = stmt.where(Process.stage_id == stage_id)
    stmt = stmt.order_by(Process.stage_id.asc(), Process.code.asc(), Process.id.asc())
    return db.execute(stmt).scalars().all()


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


@dataclass(slots=True)
class ReferenceItem:
    ref_type: str
    ref_id: int
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None  # none / low / high
    risk_note: str | None = None


@dataclass(slots=True)
class StageReferenceResult:
    stage_id: int
    stage_code: str
    stage_name: str
    total: int
    items: list[ReferenceItem]


@dataclass(slots=True)
class ProcessReferenceResult:
    process_id: int
    process_code: str
    process_name: str
    total: int
    items: list[ReferenceItem]


@dataclass(slots=True)
class ProductTemplateReferenceRow:
    template_id: int
    template_name: str
    lifecycle_status: str
    ref_type: str
    ref_id: int
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None
    risk_note: str | None = None


@dataclass(slots=True)
class ProductTemplateReferenceResult:
    product_id: int
    product_name: str
    total_templates: int
    total_references: int
    items: list[ProductTemplateReferenceRow]


@dataclass(slots=True)
class SystemMasterTemplateVersionResult:
    total: int
    items: list[CraftSystemMasterTemplateRevision]


def get_stage_references(db: Session, *, stage: ProcessStage) -> StageReferenceResult:
    items: list[ReferenceItem] = []

    processes = (
        db.execute(select(Process).where(Process.stage_id == stage.id).order_by(Process.id.asc()))
        .scalars()
        .all()
    )
    process_codes = [p.code for p in processes if p.code]
    for p in processes:
        items.append(
            ReferenceItem(
                ref_type="process",
                ref_id=p.id,
                ref_name=p.name,
                detail=p.code,
                ref_status="正在使用" if p.is_enabled else "历史引用",
                jump_module="craft",
                jump_target=f"process-management?process_id={p.id}",
            )
        )

    users = (
        db.execute(
            select(User)
            .where(User.stage_id == stage.id, User.is_deleted.is_(False))
            .order_by(User.id.asc())
        )
        .scalars()
        .all()
    )
    for u in users:
        items.append(
            ReferenceItem(
                ref_type="user",
                ref_id=u.id,
                ref_name=u.username,
                detail=u.full_name,
                ref_status="正在使用",
                jump_module="user",
                jump_target=f"user-management?user_id={u.id}",
            )
        )

    system_master_template_ids = (
        db.execute(
            select(CraftSystemMasterTemplateStep.template_id)
            .where(CraftSystemMasterTemplateStep.stage_id == stage.id)
            .distinct()
        )
        .scalars()
        .all()
    )
    if system_master_template_ids:
        system_master_templates = db.execute(
            select(CraftSystemMasterTemplate)
            .where(CraftSystemMasterTemplate.id.in_(system_master_template_ids))
            .order_by(CraftSystemMasterTemplate.id.asc())
        ).scalars().all()
        for template in system_master_templates:
            items.append(
                ReferenceItem(
                    ref_type="system_master_template",
                    ref_id=template.id,
                    ref_name=template.name if hasattr(template, "name") and template.name else "系统母版",
                    detail=f"v{template.version}",
                    ref_status="正在使用",
                    jump_module="craft",
                    jump_target="process-configuration?system_master=1",
                    risk_level="low",
                    risk_note="工段被系统母版引用，删除前请先从母版中移除该工段",
                )
            )

    system_master_revision_rows = (
        db.execute(
            select(CraftSystemMasterTemplateRevision)
            .join(
                CraftSystemMasterTemplateRevisionStep,
                CraftSystemMasterTemplateRevisionStep.revision_id == CraftSystemMasterTemplateRevision.id,
            )
            .where(CraftSystemMasterTemplateRevisionStep.stage_id == stage.id)
            .order_by(CraftSystemMasterTemplateRevision.version.desc(), CraftSystemMasterTemplateRevision.id.desc())
        )
        .scalars()
        .unique()
        .all()
    )
    for revision in system_master_revision_rows:
        items.append(
            ReferenceItem(
                ref_type="system_master_revision",
                ref_id=revision.id,
                ref_name=f"系统母版历史版本 v{revision.version}",
                detail=revision.action,
                ref_status="历史引用",
                jump_module="craft",
                jump_target="process-configuration?system_master_versions=1",
                risk_level="low",
                risk_note="工段存在于系统母版历史版本中，删除会破坏历史追溯",
            )
        )

    template_step_ids = (
        db.execute(
            select(ProductProcessTemplateStep.template_id)
            .where(ProductProcessTemplateStep.stage_id == stage.id)
            .distinct()
        )
        .scalars()
        .all()
    )
    if template_step_ids:
        templates = db.execute(
            select(ProductProcessTemplate)
            .where(ProductProcessTemplate.id.in_(template_step_ids))
            .order_by(ProductProcessTemplate.id.asc())
        ).scalars().all()
        for t in templates:
            risk_level = "high" if t.lifecycle_status == "published" else "low"
            risk_note = (
                "工段被已发布模板引用，停用或删除将影响生产工单"
                if risk_level == "high"
                else "工段被草稿/归档模板引用"
            )
            items.append(
                ReferenceItem(
                    ref_type="template",
                    ref_id=t.id,
                    ref_name=t.template_name,
                    detail=t.lifecycle_status,
                    ref_status="正在使用" if t.lifecycle_status == TEMPLATE_LIFECYCLE_PUBLISHED else "历史引用",
                    jump_module="craft",
                    jump_target=f"process-configuration?template_id={t.id}",
                    risk_level=risk_level,
                    risk_note=risk_note,
                )
            )

    template_revision_rows = (
        db.execute(
            select(ProductProcessTemplateRevision)
            .join(
                ProductProcessTemplateRevisionStep,
                ProductProcessTemplateRevisionStep.revision_id == ProductProcessTemplateRevision.id,
            )
            .join(ProductProcessTemplate, ProductProcessTemplate.id == ProductProcessTemplateRevision.template_id)
            .where(ProductProcessTemplateRevisionStep.stage_id == stage.id)
            .order_by(ProductProcessTemplateRevision.created_at.desc(), ProductProcessTemplateRevision.id.desc())
        )
        .scalars()
        .unique()
        .all()
    )
    for revision in template_revision_rows:
        items.append(
            ReferenceItem(
                ref_type="template_revision",
                ref_id=revision.id,
                ref_name=f"{revision.template.template_name} 历史版本 v{revision.version}",
                detail=revision.action,
                ref_status="历史引用",
                jump_module="craft",
                jump_target=f"process-configuration?template_id={revision.template_id}&version={revision.version}",
                risk_level="low",
                risk_note="工段存在于模板历史版本中，删除会破坏版本追溯",
            )
        )

    order_process_ids = (
        db.execute(
            select(ProductionOrderProcess.order_id)
            .where(ProductionOrderProcess.stage_id == stage.id)
            .distinct()
        )
        .scalars()
        .all()
    )
    if order_process_ids:
        orders = db.execute(
            select(ProductionOrder)
            .where(ProductionOrder.id.in_(order_process_ids))
            .order_by(ProductionOrder.id.asc())
        ).scalars().all()
        for o in orders:
            active = o.status in (ORDER_STATUS_PENDING, ORDER_STATUS_IN_PROGRESS)
            items.append(
                ReferenceItem(
                    ref_type="order",
                    ref_id=o.id,
                    ref_name=o.order_code,
                    detail=o.status,
                    ref_status="正在使用" if active else "历史引用",
                    jump_module="production",
                    jump_target=f"work-order?order_id={o.id}",
                    risk_level="high" if active else "none",
                    risk_note="工段被进行中工单引用，停用将影响生产进度" if active else None,
                )
            )

    if process_codes:
        maintenance_plans = (
            db.execute(
                select(MaintenancePlan)
                .where(MaintenancePlan.execution_process_code.in_(process_codes))
                .order_by(MaintenancePlan.id.asc())
            )
            .scalars()
            .all()
        )
        for plan in maintenance_plans:
            items.append(
                ReferenceItem(
                    ref_type="maintenance_plan",
                    ref_id=plan.id,
                    ref_name=f"保养计划#{plan.id}",
                    detail=plan.execution_process_code,
                    ref_status="正在使用" if plan.is_enabled else "历史引用",
                    jump_module="equipment",
                    jump_target=f"maintenance-plan?plan_id={plan.id}",
                    risk_level="low",
                )
            )

        maintenance_work_orders = (
            db.execute(
                select(MaintenanceWorkOrder)
                .where(MaintenanceWorkOrder.source_execution_process_code.in_(process_codes))
                .order_by(MaintenanceWorkOrder.id.asc())
            )
            .scalars()
            .all()
        )
        for work_order in maintenance_work_orders:
            active = work_order.status in ("pending", "in_progress", "overdue")
            items.append(
                ReferenceItem(
                    ref_type="maintenance_order",
                    ref_id=work_order.id,
                    ref_name=f"保养工单#{work_order.id}",
                    detail=work_order.status,
                    ref_status="正在使用" if active else "历史引用",
                    jump_module="equipment",
                    jump_target=f"maintenance-work-order?work_order_id={work_order.id}",
                    risk_level="high" if active else "none",
                    risk_note="工段关联工序仍有待执行保养工单" if active else None,
                )
            )

        scrap_rows = (
            db.execute(
                select(ProductionScrapStatistics)
                .where(
                    or_(
                        ProductionScrapStatistics.process_code.in_(process_codes),
                        ProductionScrapStatistics.process_id.in_([p.id for p in processes]),
                    )
                )
                .order_by(ProductionScrapStatistics.id.asc())
            )
            .scalars()
            .all()
        )
        for row in scrap_rows:
            items.append(
                ReferenceItem(
                    ref_type="scrap_stat",
                    ref_id=row.id,
                    ref_name=f"报废统计#{row.id}",
                    detail=row.progress,
                    ref_status="历史引用" if row.progress == "applied" else "正在使用",
                    jump_module="production",
                    jump_target=f"scrap-stat?stat_id={row.id}",
                    risk_level="low",
                )
            )

        repair_defect_rows = (
            db.execute(
                select(RepairDefectPhenomenon)
                .where(
                    or_(
                        RepairDefectPhenomenon.process_code.in_(process_codes),
                        RepairDefectPhenomenon.process_id.in_([p.id for p in processes]),
                    )
                )
                .order_by(RepairDefectPhenomenon.id.asc())
            )
            .scalars()
            .all()
        )
        for row in repair_defect_rows:
            items.append(
                ReferenceItem(
                    ref_type="quality_defect",
                    ref_id=row.id,
                    ref_name=row.phenomenon,
                    detail=row.process_code,
                    ref_status="历史引用",
                    jump_module="quality",
                    jump_target=f"repair-defect?row_id={row.id}",
                    risk_level="low",
                )
            )

    return StageReferenceResult(
        stage_id=stage.id,
        stage_code=stage.code,
        stage_name=stage.name,
        total=len(items),
        items=items,
    )


def get_process_references(db: Session, *, process: Process) -> ProcessReferenceResult:
    items: list[ReferenceItem] = []

    system_master_template_ids = (
        db.execute(
            select(CraftSystemMasterTemplateStep.template_id)
            .where(CraftSystemMasterTemplateStep.process_id == process.id)
            .distinct()
        )
        .scalars()
        .all()
    )
    if system_master_template_ids:
        system_master_templates = db.execute(
            select(CraftSystemMasterTemplate)
            .where(CraftSystemMasterTemplate.id.in_(system_master_template_ids))
            .order_by(CraftSystemMasterTemplate.id.asc())
        ).scalars().all()
        for template in system_master_templates:
            items.append(
                ReferenceItem(
                    ref_type="system_master_template",
                    ref_id=template.id,
                    ref_name=template.name if hasattr(template, "name") and template.name else "系统母版",
                    detail=f"v{template.version}",
                    ref_status="正在使用",
                    jump_module="craft",
                    jump_target="process-configuration?system_master=1",
                    risk_level="low",
                    risk_note="工序被系统母版引用，删除前请先从母版中移除该工序",
                )
            )

    system_master_revision_rows = (
        db.execute(
            select(CraftSystemMasterTemplateRevision)
            .join(
                CraftSystemMasterTemplateRevisionStep,
                CraftSystemMasterTemplateRevisionStep.revision_id == CraftSystemMasterTemplateRevision.id,
            )
            .where(CraftSystemMasterTemplateRevisionStep.process_id == process.id)
            .order_by(CraftSystemMasterTemplateRevision.version.desc(), CraftSystemMasterTemplateRevision.id.desc())
        )
        .scalars()
        .unique()
        .all()
    )
    for revision in system_master_revision_rows:
        items.append(
            ReferenceItem(
                ref_type="system_master_revision",
                ref_id=revision.id,
                ref_name=f"系统母版历史版本 v{revision.version}",
                detail=revision.action,
                ref_status="历史引用",
                jump_module="craft",
                jump_target="process-configuration?system_master_versions=1",
                risk_level="low",
                risk_note="工序存在于系统母版历史版本中，删除会破坏历史追溯",
            )
        )

    template_step_ids = (
        db.execute(
            select(ProductProcessTemplateStep.template_id)
            .where(ProductProcessTemplateStep.process_id == process.id)
            .distinct()
        )
        .scalars()
        .all()
    )
    if template_step_ids:
        templates = db.execute(
            select(ProductProcessTemplate)
            .where(ProductProcessTemplate.id.in_(template_step_ids))
            .order_by(ProductProcessTemplate.id.asc())
        ).scalars().all()
        for t in templates:
            risk_level = "high" if t.lifecycle_status == "published" else "low"
            risk_note = (
                "工序被已发布模板引用，停用或删除将影响生产工单"
                if risk_level == "high"
                else "工序被草稿/归档模板引用"
            )
            items.append(
                ReferenceItem(
                    ref_type="template",
                    ref_id=t.id,
                    ref_name=t.template_name,
                    detail=t.lifecycle_status,
                    ref_status="正在使用" if t.lifecycle_status == TEMPLATE_LIFECYCLE_PUBLISHED else "历史引用",
                    jump_module="craft",
                    jump_target=f"process-configuration?template_id={t.id}",
                    risk_level=risk_level,
                    risk_note=risk_note,
                )
            )

    template_revision_rows = (
        db.execute(
            select(ProductProcessTemplateRevision)
            .join(
                ProductProcessTemplateRevisionStep,
                ProductProcessTemplateRevisionStep.revision_id == ProductProcessTemplateRevision.id,
            )
            .join(ProductProcessTemplate, ProductProcessTemplate.id == ProductProcessTemplateRevision.template_id)
            .where(ProductProcessTemplateRevisionStep.process_id == process.id)
            .order_by(ProductProcessTemplateRevision.created_at.desc(), ProductProcessTemplateRevision.id.desc())
        )
        .scalars()
        .unique()
        .all()
    )
    for revision in template_revision_rows:
        items.append(
            ReferenceItem(
                ref_type="template_revision",
                ref_id=revision.id,
                ref_name=f"{revision.template.template_name} 历史版本 v{revision.version}",
                detail=revision.action,
                ref_status="历史引用",
                jump_module="craft",
                jump_target=f"process-configuration?template_id={revision.template_id}&version={revision.version}",
                risk_level="low",
                risk_note="工序存在于模板历史版本中，删除会破坏版本追溯",
            )
        )

    order_process_ids = (
        db.execute(
            select(ProductionOrderProcess.order_id)
            .where(ProductionOrderProcess.process_id == process.id)
            .distinct()
        )
        .scalars()
        .all()
    )
    if order_process_ids:
        orders = db.execute(
            select(ProductionOrder)
            .where(ProductionOrder.id.in_(order_process_ids))
            .order_by(ProductionOrder.id.asc())
        ).scalars().all()
        for o in orders:
            active = o.status in (ORDER_STATUS_PENDING, ORDER_STATUS_IN_PROGRESS)
            items.append(
                ReferenceItem(
                    ref_type="order",
                    ref_id=o.id,
                    ref_name=o.order_code,
                    detail=o.status,
                    ref_status="正在使用" if active else "历史引用",
                    jump_module="production",
                    jump_target=f"work-order?order_id={o.id}",
                    risk_level="high" if active else "none",
                    risk_note="工序被进行中工单引用，停用将影响生产进度" if active else None,
                )
            )

    maintenance_plans = (
        db.execute(
            select(MaintenancePlan)
            .where(MaintenancePlan.execution_process_code == process.code)
            .order_by(MaintenancePlan.id.asc())
        )
        .scalars()
        .all()
    )
    for plan in maintenance_plans:
        items.append(
            ReferenceItem(
                ref_type="maintenance_plan",
                ref_id=plan.id,
                ref_name=f"保养计划#{plan.id}",
                detail=plan.execution_process_code,
                ref_status="正在使用" if plan.is_enabled else "历史引用",
                jump_module="equipment",
                jump_target=f"maintenance-plan?plan_id={plan.id}",
                risk_level="low",
            )
        )

    maintenance_work_orders = (
        db.execute(
            select(MaintenanceWorkOrder)
            .where(MaintenanceWorkOrder.source_execution_process_code == process.code)
            .order_by(MaintenanceWorkOrder.id.asc())
        )
        .scalars()
        .all()
    )
    for work_order in maintenance_work_orders:
        active = work_order.status in ("pending", "in_progress", "overdue")
        items.append(
            ReferenceItem(
                ref_type="maintenance_order",
                ref_id=work_order.id,
                ref_name=f"保养工单#{work_order.id}",
                detail=work_order.status,
                ref_status="正在使用" if active else "历史引用",
                jump_module="equipment",
                jump_target=f"maintenance-work-order?work_order_id={work_order.id}",
                risk_level="high" if active else "none",
                risk_note="工序仍关联待执行保养工单" if active else None,
            )
        )

    scrap_rows = (
        db.execute(
            select(ProductionScrapStatistics)
            .where(
                or_(
                    ProductionScrapStatistics.process_code == process.code,
                    ProductionScrapStatistics.process_id == process.id,
                )
            )
            .order_by(ProductionScrapStatistics.id.asc())
        )
        .scalars()
        .all()
    )
    for row in scrap_rows:
        items.append(
            ReferenceItem(
                ref_type="scrap_stat",
                ref_id=row.id,
                ref_name=f"报废统计#{row.id}",
                detail=row.progress,
                ref_status="历史引用" if row.progress == "applied" else "正在使用",
                jump_module="production",
                jump_target=f"scrap-stat?stat_id={row.id}",
                risk_level="low",
            )
        )

    repair_defect_rows = (
        db.execute(
            select(RepairDefectPhenomenon)
            .where(
                or_(
                    RepairDefectPhenomenon.process_code == process.code,
                    RepairDefectPhenomenon.process_id == process.id,
                )
            )
            .order_by(RepairDefectPhenomenon.id.asc())
        )
        .scalars()
        .all()
    )
    for row in repair_defect_rows:
        items.append(
            ReferenceItem(
                ref_type="quality_defect",
                ref_id=row.id,
                ref_name=row.phenomenon,
                detail=row.process_code,
                ref_status="历史引用",
                jump_module="quality",
                jump_target=f"repair-defect?row_id={row.id}",
                risk_level="low",
            )
        )

    repair_cause_rows = (
        db.execute(
            select(RepairCause)
            .where(
                or_(
                    RepairCause.process_code == process.code,
                    RepairCause.process_id == process.id,
                )
            )
            .order_by(RepairCause.id.asc())
        )
        .scalars()
        .all()
    )
    for row in repair_cause_rows:
        items.append(
            ReferenceItem(
                ref_type="quality_cause",
                ref_id=row.id,
                ref_name=row.reason,
                detail=row.process_code,
                ref_status="历史引用",
                jump_module="quality",
                jump_target=f"repair-cause?row_id={row.id}",
                risk_level="low",
            )
        )

    return_route_rows = (
        db.execute(
            select(RepairReturnRoute)
            .where(
                or_(
                    RepairReturnRoute.source_process_code == process.code,
                    RepairReturnRoute.target_process_code == process.code,
                    RepairReturnRoute.source_process_id == process.id,
                    RepairReturnRoute.target_process_id == process.id,
                )
            )
            .order_by(RepairReturnRoute.id.asc())
        )
        .scalars()
        .all()
    )
    for row in return_route_rows:
        items.append(
            ReferenceItem(
                ref_type="quality_return_route",
                ref_id=row.id,
                ref_name=f"{row.source_process_code}->{row.target_process_code}",
                detail=f"数量{row.return_quantity}",
                ref_status="历史引用",
                jump_module="quality",
                jump_target=f"repair-return-route?row_id={row.id}",
                risk_level="low",
            )
        )

    return ProcessReferenceResult(
        process_id=process.id,
        process_code=process.code,
        process_name=process.name,
        total=len(items),
        items=items,
    )


@dataclass(slots=True)
class TemplateReferenceItem:
    ref_type: str
    ref_id: int
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None
    risk_note: str | None = None


@dataclass(slots=True)
class TemplateReferenceResult:
    template_id: int
    template_name: str
    product_id: int
    product_name: str
    total: int
    items: list[TemplateReferenceItem]


def get_template_references(
    db: Session,
    *,
    template: ProductProcessTemplate,
) -> TemplateReferenceResult:
    items: list[TemplateReferenceItem] = []

    product_name = template.product.name if template.product else ""
    items.append(
        TemplateReferenceItem(
            ref_type="product",
            ref_id=template.product_id,
            ref_name=product_name or f"产品#{template.product_id}",
            detail=template.lifecycle_status,
            ref_status="正在使用" if template.is_enabled else "历史引用",
            jump_module="product",
            jump_target=f"product-management?product_id={template.product_id}",
            risk_level="none",
        )
    )

    active_orders = db.execute(
        select(ProductionOrder.id, ProductionOrder.order_code, ProductionOrder.status).where(
            ProductionOrder.process_template_id == template.id,
        )
    ).all()
    for order_id, order_code, order_status in active_orders:
        can_sync = order_status == ORDER_STATUS_PENDING
        blocked = order_status == ORDER_STATUS_IN_PROGRESS
        active = can_sync or blocked
        ref_status = "可同步" if can_sync else ("不可同步" if blocked else "历史引用")
        items.append(
            TemplateReferenceItem(
                ref_type="order",
                ref_id=order_id,
                ref_name=order_code,
                detail=order_status,
                ref_status=ref_status,
                jump_module="production",
                jump_target=f"work-order?order_id={order_id}",
                risk_level="high" if blocked else ("low" if can_sync else "none"),
                risk_note=(
                    "模板被进行中工单引用，变更将被阻断"
                    if blocked
                    else ("模板可同步到未开工工单" if can_sync else None)
                ),
            )
        )

    return TemplateReferenceResult(
        template_id=template.id,
        template_name=template.template_name,
        product_id=template.product_id,
        product_name=product_name,
        total=len(items),
        items=items,
    )


def get_product_template_references(
    db: Session,
    *,
    product: Product,
) -> ProductTemplateReferenceResult:
    templates = (
        db.execute(
            select(ProductProcessTemplate)
            .where(ProductProcessTemplate.product_id == product.id)
            .order_by(ProductProcessTemplate.updated_at.desc(), ProductProcessTemplate.id.desc())
            .options(selectinload(ProductProcessTemplate.product))
        )
        .scalars()
        .all()
    )

    rows: list[ProductTemplateReferenceRow] = []
    for template in templates:
        ref_result = get_template_references(db, template=template)
        if not ref_result.items:
            rows.append(
                ProductTemplateReferenceRow(
                    template_id=template.id,
                    template_name=template.template_name,
                    lifecycle_status=template.lifecycle_status,
                    ref_type="template",
                    ref_id=template.id,
                    ref_name=template.template_name,
                    detail="无下游引用",
                    ref_status="可同步",
                    jump_module="craft",
                    jump_target=f"process-configuration?template_id={template.id}",
                    risk_level="none",
                )
            )
            continue
        for item in ref_result.items:
            rows.append(
                ProductTemplateReferenceRow(
                    template_id=template.id,
                    template_name=template.template_name,
                    lifecycle_status=template.lifecycle_status,
                    ref_type=item.ref_type,
                    ref_id=item.ref_id,
                    ref_name=item.ref_name,
                    detail=item.detail,
                    ref_status=item.ref_status,
                    jump_module=item.jump_module,
                    jump_target=item.jump_target,
                    risk_level=item.risk_level,
                    risk_note=item.risk_note,
                )
            )

    return ProductTemplateReferenceResult(
        product_id=product.id,
        product_name=product.name,
        total_templates=len(templates),
        total_references=len(rows),
        items=rows,
    )


# ── CSV 导出 ─────────────────────────────────────────────────────────────────

def _craft_csv_base64(headers: list[str], rows: list[list[object]]) -> str:
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for row in rows:
        writer.writerow(row)
    return base64.b64encode(output.getvalue().encode("utf-8-sig")).decode("ascii")


def _craft_json_base64(payload: dict[str, object]) -> str:
    return base64.b64encode(io.StringIO(json.dumps(payload, ensure_ascii=False, indent=2)).getvalue().encode("utf-8-sig")).decode("ascii")


def export_template_detail_json(
    db: Session,
    *,
    template: ProductProcessTemplate,
) -> dict[str, object]:
    detail = get_template_by_id(db, template.id) or template
    steps = sorted(detail.steps, key=lambda item: (item.step_order, item.id))
    payload = {
        "template": {
            "id": detail.id,
            "product_id": detail.product_id,
            "product_name": detail.product.name if detail.product else "",
            "template_name": detail.template_name,
            "version": detail.version,
            "lifecycle_status": detail.lifecycle_status,
            "published_version": detail.published_version,
            "is_default": detail.is_default,
            "is_enabled": detail.is_enabled,
            "remark": detail.remark,
            "source_type": detail.source_type,
            "source_template_id": detail.source_template_id,
            "source_template_name": detail.source_template_name,
            "source_template_version": detail.source_template_version,
            "source_product_id": detail.source_product_id,
            "source_system_master_version": detail.source_system_master_version,
        },
        "steps": [
            {
                "step_order": step.step_order,
                "stage_id": step.stage_id,
                "stage_code": step.stage_code,
                "stage_name": step.stage_name,
                "process_id": step.process_id,
                "process_code": step.process_code,
                "process_name": step.process_name,
                "standard_minutes": step.standard_minutes,
                "is_key_process": step.is_key_process,
                "step_remark": step.step_remark,
            }
            for step in steps
        ],
    }
    return {
        "file_name": f"craft_template_{detail.id}.json",
        "mime_type": "application/json",
        "content_base64": _craft_json_base64(payload),
        "exported_count": len(steps),
    }


def export_template_version_json(
    db: Session,
    *,
    template: ProductProcessTemplate,
    version: int,
) -> dict[str, object]:
    revision = get_template_version(db, template_id=template.id, version=version)
    if revision is None:
        raise ValueError("Template version not found")
    steps = sorted(revision.steps, key=lambda item: (item.step_order, item.id))
    payload = {
        "template": {
            "template_id": template.id,
            "template_name": template.template_name,
            "product_id": template.product_id,
            "product_name": template.product.name if template.product else "",
        },
        "revision": {
            "version": revision.version,
            "action": revision.action,
            "note": revision.note,
            "source_revision_id": revision.source_revision_id,
        },
        "steps": [
            {
                "step_order": step.step_order,
                "stage_id": step.stage_id,
                "stage_code": step.stage_code,
                "stage_name": step.stage_name,
                "process_id": step.process_id,
                "process_code": step.process_code,
                "process_name": step.process_name,
                "standard_minutes": step.standard_minutes,
                "is_key_process": step.is_key_process,
                "step_remark": step.step_remark,
            }
            for step in steps
        ],
    }
    return {
        "file_name": f"craft_template_{template.id}_version_{version}.json",
        "mime_type": "application/json",
        "content_base64": _craft_json_base64(payload),
        "exported_count": len(steps),
    }


def export_stages_csv(
    db: Session,
    *,
    keyword: str | None = None,
    enabled: bool | None = None,
) -> dict[str, object]:
    _, rows = list_stages(db, page=1, page_size=200000, keyword=keyword, enabled=enabled)
    csv_rows: list[list[object]] = []
    for row in rows:
        csv_rows.append([
            row.code,
            row.name,
            row.sort_order,
            "启用" if row.is_enabled else "停用",
            len(row.processes) if row.processes else 0,
            row.created_at.astimezone().strftime("%Y-%m-%d %H:%M:%S") if row.created_at else "",
        ])
    content_base64 = _craft_csv_base64(
        ["工段编码", "工段名称", "排序", "状态", "工序数量", "创建时间"],
        csv_rows,
    )
    return {
        "file_name": "stages_export.csv",
        "mime_type": "text/csv",
        "content_base64": content_base64,
        "exported_count": len(csv_rows),
    }


def export_processes_csv(
    db: Session,
    *,
    keyword: str | None = None,
    stage_id: int | None = None,
    enabled: bool | None = None,
) -> dict[str, object]:
    _, rows = list_craft_processes(db, page=1, page_size=200000, keyword=keyword, stage_id=stage_id, enabled=enabled)
    csv_rows: list[list[object]] = []
    for row in rows:
        csv_rows.append([
            row.stage.code if row.stage else "",
            row.stage.name if row.stage else "",
            row.code,
            row.name,
            "启用" if row.is_enabled else "停用",
            row.created_at.astimezone().strftime("%Y-%m-%d %H:%M:%S") if row.created_at else "",
        ])
    content_base64 = _craft_csv_base64(
        ["所属工段编码", "所属工段名称", "工序编码", "工序名称", "状态", "创建时间"],
        csv_rows,
    )
    return {
        "file_name": "processes_export.csv",
        "mime_type": "text/csv",
        "content_base64": content_base64,
        "exported_count": len(csv_rows),
    }
