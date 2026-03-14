from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.craft_system_master_template import CraftSystemMasterTemplate
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.product_process_template import ProductProcessTemplate
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.craft import (
    CraftKanbanProcessItem,
    CraftKanbanProcessMetricsResult,
    CraftKanbanSampleItem,
    CraftProcessCreate,
    CraftProcessItem,
    CraftProcessListResult,
    CraftProcessUpdate,
    ProcessStageCreate,
    ProcessStageItem,
    ProcessStageListResult,
    ProcessStageUpdate,
    ProductProcessTemplateCreate,
    TemplateBatchExportItem,
    TemplateBatchExportResult,
    TemplateBatchImportRequest,
    TemplateBatchImportResult,
    TemplateBatchImportResultItem,
    ProductProcessTemplateDetail,
    ProductProcessTemplateItem,
    ProductProcessTemplateListResult,
    TemplateImpactAnalysisResult,
    TemplateImpactOrderItem,
    TemplatePublishRequest,
    TemplateRollbackRequest,
    TemplateVersionCompareResult,
    TemplateVersionDiffItem,
    TemplateVersionItem,
    TemplateVersionListResult,
    TemplateStepPayload,
    ProductProcessTemplateUpdate,
    ProductProcessTemplateUpdateResult,
    SystemMasterTemplateItem,
    SystemMasterTemplateStepItem,
    SystemMasterTemplateUpsertRequest,
    TemplateStepItem,
    TemplateSyncOrderConflict,
    TemplateSyncResult,
    TemplateCopyRequest,
    StageReferenceItem,
    StageReferenceResult,
    ProcessReferenceItem,
    ProcessReferenceResult,
)
from app.services.craft_service import (
    TemplateSyncConflictError,
    analyze_template_impact,
    compare_template_versions,
    create_process,
    export_templates,
    get_craft_kanban_process_metrics,
    import_templates,
    list_template_versions,
    publish_template,
    rollback_template_to_version,
    create_system_master_template,
    create_stage,
    create_template,
    copy_template,
    archive_template,
    unarchive_template,
    delete_process,
    delete_stage,
    delete_template,
    get_system_master_template,
    get_stage_by_id,
    get_template_by_id,
    get_stage_references,
    get_process_references,
    list_craft_processes,
    list_stages,
    list_templates,
    update_process,
    update_system_master_template,
    update_stage,
    update_template,
)


router = APIRouter()


def _to_stage_item(row: ProcessStage) -> ProcessStageItem:
    return ProcessStageItem(
        id=row.id,
        code=row.code,
        name=row.name,
        sort_order=row.sort_order,
        is_enabled=row.is_enabled,
        process_count=len(row.processes) if row.processes is not None else 0,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_process_item(row: Process) -> CraftProcessItem:
    stage = row.stage
    return CraftProcessItem(
        id=row.id,
        code=row.code,
        name=row.name,
        stage_id=row.stage_id,
        stage_code=stage.code if stage else None,
        stage_name=stage.name if stage else None,
        is_enabled=row.is_enabled,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_template_item(row: ProductProcessTemplate) -> ProductProcessTemplateItem:
    return ProductProcessTemplateItem(
        id=row.id,
        product_id=row.product_id,
        product_name=row.product.name if row.product else "",
        template_name=row.template_name,
        version=row.version,
        lifecycle_status=row.lifecycle_status,
        published_version=row.published_version,
        is_default=row.is_default,
        is_enabled=row.is_enabled,
        created_by_user_id=row.created_by_user_id,
        created_by_username=row.created_by.username if row.created_by else None,
        updated_by_user_id=row.updated_by_user_id,
        updated_by_username=row.updated_by.username if row.updated_by else None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_template_detail(row: ProductProcessTemplate) -> ProductProcessTemplateDetail:
    steps = sorted(row.steps, key=lambda item: (item.step_order, item.id))
    return ProductProcessTemplateDetail(
        template=_to_template_item(row),
        steps=[
            TemplateStepItem(
                id=step.id,
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
                created_at=step.created_at,
                updated_at=step.updated_at,
            )
            for step in steps
        ],
    )


def _to_system_master_template_item(row: CraftSystemMasterTemplate) -> SystemMasterTemplateItem:
    steps = sorted(row.steps, key=lambda item: (item.step_order, item.id))
    return SystemMasterTemplateItem(
        id=row.id,
        version=row.version,
        created_by_user_id=row.created_by_user_id,
        created_by_username=row.created_by.username if row.created_by else None,
        updated_by_user_id=row.updated_by_user_id,
        updated_by_username=row.updated_by.username if row.updated_by else None,
        created_at=row.created_at,
        updated_at=row.updated_at,
        steps=[
            SystemMasterTemplateStepItem(
                id=step.id,
                step_order=step.step_order,
                stage_id=step.stage_id,
                stage_code=step.stage_code,
                stage_name=step.stage_name,
                process_id=step.process_id,
                process_code=step.process_code,
                process_name=step.process_name,
                created_at=step.created_at,
                updated_at=step.updated_at,
            )
            for step in steps
        ],
    )


def _to_kanban_result_item(result) -> CraftKanbanProcessMetricsResult:
    return CraftKanbanProcessMetricsResult(
        product_id=result.product.id,
        product_name=result.product.name,
        items=[
            CraftKanbanProcessItem(
                stage_id=item.stage_id,
                stage_code=item.stage_code,
                stage_name=item.stage_name,
                process_id=item.process_id,
                process_code=item.process_code,
                process_name=item.process_name,
                samples=[
                    CraftKanbanSampleItem(
                        order_process_id=sample.order_process_id,
                        order_id=sample.order_id,
                        order_code=sample.order_code,
                        start_at=sample.start_at,
                        end_at=sample.end_at,
                        work_minutes=sample.work_minutes,
                        production_qty=sample.production_qty,
                        capacity_per_hour=sample.capacity_per_hour,
                    )
                    for sample in item.samples
                ],
            )
            for item in result.items
        ],
    )


def _to_impact_result_item(
    *,
    total_orders: int,
    pending_orders: int,
    in_progress_orders: int,
    syncable_orders: int,
    blocked_orders: int,
    items: list[TemplateImpactOrderItem],
) -> TemplateImpactAnalysisResult:
    return TemplateImpactAnalysisResult(
        total_orders=total_orders,
        pending_orders=pending_orders,
        in_progress_orders=in_progress_orders,
        syncable_orders=syncable_orders,
        blocked_orders=blocked_orders,
        items=items,
    )


def _to_template_update_result(row: ProductProcessTemplate) -> ProductProcessTemplateUpdateResult:
    return ProductProcessTemplateUpdateResult(
        detail=_to_template_detail(row),
        sync_result=TemplateSyncResult(total=0, synced=0, skipped=0, reasons=[]),
    )


def _to_stage_reference_result(result) -> StageReferenceResult:
    return StageReferenceResult(
        stage_id=result.stage_id,
        stage_code=result.stage_code,
        stage_name=result.stage_name,
        total=result.total,
        items=[
            StageReferenceItem(
                ref_type=item.ref_type,
                ref_id=item.ref_id,
                ref_name=item.ref_name,
                detail=item.detail,
            )
            for item in result.items
        ],
    )


def _to_process_reference_result(result) -> ProcessReferenceResult:
    return ProcessReferenceResult(
        process_id=result.process_id,
        process_code=result.process_code,
        process_name=result.process_name,
        total=result.total,
        items=[
            ProcessReferenceItem(
                ref_type=item.ref_type,
                ref_id=item.ref_id,
                ref_name=item.ref_name,
                detail=item.detail,
            )
            for item in result.items
        ],
    )


@router.get("/stages", response_model=ApiResponse[ProcessStageListResult])
def get_stages(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.list")),
) -> ApiResponse[ProcessStageListResult]:
    total, rows = list_stages(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        enabled=enabled,
    )
    return success_response(ProcessStageListResult(total=total, items=[_to_stage_item(row) for row in rows]))


@router.post("/stages", response_model=ApiResponse[ProcessStageItem], status_code=status.HTTP_201_CREATED)
def create_stage_api(
    payload: ProcessStageCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.create")),
) -> ApiResponse[ProcessStageItem]:
    try:
        row = create_stage(
            db,
            code=payload.code,
            name=payload.name,
            sort_order=payload.sort_order,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_stage_item(row), message="created")


@router.put("/stages/{stage_id}", response_model=ApiResponse[ProcessStageItem])
def update_stage_api(
    stage_id: int,
    payload: ProcessStageUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.update")),
) -> ApiResponse[ProcessStageItem]:
    row = get_stage_by_id(db, stage_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stage not found")
    try:
        updated = update_stage(
            db,
            row=row,
            name=payload.name,
            sort_order=payload.sort_order,
            is_enabled=payload.is_enabled,
            code=payload.code,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_stage_item(updated), message="updated")


@router.delete("/stages/{stage_id}", response_model=ApiResponse[dict[str, bool]])
def delete_stage_api(
    stage_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = get_stage_by_id(db, stage_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stage not found")
    try:
        delete_stage(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.get("/processes", response_model=ApiResponse[CraftProcessListResult])
def get_processes_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=200, ge=1, le=500),
    keyword: str | None = Query(default=None),
    stage_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.list")),
) -> ApiResponse[CraftProcessListResult]:
    total, rows = list_craft_processes(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        stage_id=stage_id,
        enabled=enabled,
    )
    return success_response(CraftProcessListResult(total=total, items=[_to_process_item(row) for row in rows]))


@router.post("/processes", response_model=ApiResponse[CraftProcessItem], status_code=status.HTTP_201_CREATED)
def create_process_api(
    payload: CraftProcessCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.create")),
) -> ApiResponse[CraftProcessItem]:
    try:
        row = create_process(
            db,
            code=payload.code,
            name=payload.name,
            stage_id=payload.stage_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_process_item(row), message="created")


@router.put("/processes/{process_id}", response_model=ApiResponse[CraftProcessItem])
def update_process_api(
    process_id: int,
    payload: CraftProcessUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.update")),
) -> ApiResponse[CraftProcessItem]:
    row = db.execute(select(Process).where(Process.id == process_id).options(selectinload(Process.stage))).scalars().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Process not found")
    try:
        updated = update_process(
            db,
            row=row,
            name=payload.name,
            stage_id=payload.stage_id,
            is_enabled=payload.is_enabled,
            code=payload.code,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    updated = db.execute(select(Process).where(Process.id == updated.id).options(selectinload(Process.stage))).scalars().first() or updated
    return success_response(_to_process_item(updated), message="updated")


@router.delete("/processes/{process_id}", response_model=ApiResponse[dict[str, bool]])
def delete_process_api(
    process_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = db.execute(select(Process).where(Process.id == process_id)).scalars().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Process not found")
    try:
        delete_process(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.get("/system-master-template", response_model=ApiResponse[SystemMasterTemplateItem | None])
def get_system_master_template_api(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.system_master_template.view")),
) -> ApiResponse[SystemMasterTemplateItem | None]:
    row = get_system_master_template(db)
    if row is None:
        return success_response(None)
    return success_response(_to_system_master_template_item(row))


@router.post("/system-master-template", response_model=ApiResponse[SystemMasterTemplateItem], status_code=status.HTTP_201_CREATED)
def create_system_master_template_api(
    payload: SystemMasterTemplateUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.system_master_template.create")),
) -> ApiResponse[SystemMasterTemplateItem]:
    try:
        row = create_system_master_template(
            db,
            steps=[item.model_dump() for item in payload.steps],
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_system_master_template_item(row), message="created")


@router.put("/system-master-template", response_model=ApiResponse[SystemMasterTemplateItem])
def update_system_master_template_api(
    payload: SystemMasterTemplateUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.system_master_template.update")),
) -> ApiResponse[SystemMasterTemplateItem]:
    try:
        row = update_system_master_template(
            db,
            steps=[item.model_dump() for item in payload.steps],
            operator=current_user,
        )
    except LookupError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error))
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_system_master_template_item(row), message="updated")


@router.get("/kanban/process-metrics", response_model=ApiResponse[CraftKanbanProcessMetricsResult])
def get_craft_kanban_process_metrics_api(
    product_id: int = Query(ge=1),
    limit: int = Query(default=5, ge=1, le=20),
    stage_id: int | None = Query(default=None, ge=1),
    process_id: int | None = Query(default=None, ge=1),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.kanban.process_metrics.view")),
) -> ApiResponse[CraftKanbanProcessMetricsResult]:
    try:
        result = get_craft_kanban_process_metrics(
            db,
            product_id=product_id,
            limit=limit,
            stage_id=stage_id if isinstance(stage_id, int) else None,
            process_id=process_id if isinstance(process_id, int) else None,
            start_date=start_date if isinstance(start_date, datetime) else None,
            end_date=end_date if isinstance(end_date, datetime) else None,
        )
    except ValueError as error:
        message = str(error)
        if message == "Product not found":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=message)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)
    return success_response(_to_kanban_result_item(result))


@router.get("/templates", response_model=ApiResponse[ProductProcessTemplateListResult])
def get_templates_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    product_id: int | None = Query(default=None, ge=1),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=True),
    lifecycle_status: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.list")),
) -> ApiResponse[ProductProcessTemplateListResult]:
    total, rows = list_templates(
        db,
        page=page,
        page_size=page_size,
        product_id=product_id,
        keyword=keyword,
        enabled=enabled,
        lifecycle_status=lifecycle_status,
    )
    return success_response(ProductProcessTemplateListResult(total=total, items=[_to_template_item(row) for row in rows]))


@router.post("/templates", response_model=ApiResponse[ProductProcessTemplateDetail], status_code=status.HTTP_201_CREATED)
def create_template_api(
    payload: ProductProcessTemplateCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.create")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    try:
        row = create_template(
            db,
            product_id=payload.product_id,
            template_name=payload.template_name,
            is_default=payload.is_default,
            lifecycle_status=payload.lifecycle_status,
            steps=[item.model_dump() for item in payload.steps],
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_template_detail(row), message="created")


@router.get("/templates/export", response_model=ApiResponse[TemplateBatchExportResult])
def export_templates_api(
    product_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.export")),
) -> ApiResponse[TemplateBatchExportResult]:
    try:
        rows = export_templates(
            db,
            product_id=product_id,
            enabled=enabled,
            lifecycle_status=lifecycle_status,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    items: list[TemplateBatchExportItem] = []
    for row in rows:
        steps = sorted(row.steps, key=lambda item: (item.step_order, item.id))
        items.append(
            TemplateBatchExportItem(
                product_id=row.product_id,
                product_name=row.product.name if row.product else "",
                template_name=row.template_name,
                is_default=row.is_default,
                is_enabled=row.is_enabled,
                lifecycle_status=row.lifecycle_status,
                steps=[
                    TemplateStepPayload(
                        step_order=step.step_order,
                        stage_id=step.stage_id,
                        process_id=step.process_id,
                    )
                    for step in steps
                ],
            )
        )
    return success_response(
        TemplateBatchExportResult(
            total=len(items),
            exported_at=datetime.now(UTC),
            items=items,
        )
    )


@router.post("/templates/import", response_model=ApiResponse[TemplateBatchImportResult])
def import_templates_api(
    payload: TemplateBatchImportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.import")),
) -> ApiResponse[TemplateBatchImportResult]:
    rows, created, updated, skipped, errors = import_templates(
        db,
        items=[item.model_dump() for item in payload.items],
        overwrite_existing=payload.overwrite_existing,
        publish_after_import=payload.publish_after_import,
        operator=current_user,
    )
    items = [
        TemplateBatchImportResultItem(
            template_id=row.id,
            product_id=row.product_id,
            product_name=row.product.name if row.product else "",
            template_name=row.template_name,
            action="updated" if row.version > 1 else "created",
            lifecycle_status=row.lifecycle_status,
            published_version=row.published_version,
        )
        for row in rows
    ]
    return success_response(
        TemplateBatchImportResult(
            total=len(payload.items),
            created=created,
            updated=updated,
            skipped=skipped,
            items=items,
            errors=errors,
        ),
        message="imported",
    )


@router.get("/templates/{template_id}", response_model=ApiResponse[ProductProcessTemplateDetail])
def get_template_detail_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.detail")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    return success_response(_to_template_detail(row))


@router.get("/templates/{template_id}/impact-analysis", response_model=ApiResponse[TemplateImpactAnalysisResult])
def get_template_impact_analysis_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.impact.analysis")),
) -> ApiResponse[TemplateImpactAnalysisResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        impact = analyze_template_impact(db, template=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    items = [
        TemplateImpactOrderItem(
            order_id=item.order_id,
            order_code=item.order_code,
            order_status=item.order_status or "",
            syncable=item.reason == "",
            reason=item.reason or None,
        )
        for item in impact.items
    ]
    return success_response(
        _to_impact_result_item(
            total_orders=impact.total_orders,
            pending_orders=impact.pending_orders,
            in_progress_orders=impact.in_progress_orders,
            syncable_orders=impact.syncable_orders,
            blocked_orders=impact.blocked_orders,
            items=items,
        )
    )


@router.post("/templates/{template_id}/publish", response_model=ApiResponse[ProductProcessTemplateUpdateResult])
def publish_template_api(
    template_id: int,
    payload: TemplatePublishRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.publish")),
) -> ApiResponse[ProductProcessTemplateUpdateResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        updated, sync_result = publish_template(
            db,
            template=row,
            operator=current_user,
            apply_order_sync=payload.apply_order_sync,
            confirmed=payload.confirmed,
            note=payload.note,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        ProductProcessTemplateUpdateResult(
            detail=_to_template_detail(updated),
            sync_result=TemplateSyncResult(
                total=sync_result.total,
                synced=sync_result.synced,
                skipped=sync_result.skipped,
                reasons=[
                    TemplateSyncOrderConflict(
                        order_id=item.order_id,
                        order_code=item.order_code,
                        reason=item.reason,
                    )
                    for item in sync_result.reasons
                ],
            ),
        ),
        message="published",
    )


@router.get("/templates/{template_id}/versions", response_model=ApiResponse[TemplateVersionListResult])
def list_template_versions_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.versions.list")),
) -> ApiResponse[TemplateVersionListResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    versions = list_template_versions(db, template_id=row.id)
    items = [
        TemplateVersionItem(
            version=item.version,
            action=item.action,
            note=item.note,
            source_version=item.source_revision.version if item.source_revision else None,
            created_by_user_id=item.created_by_user_id,
            created_by_username=item.created_by.username if item.created_by else None,
            created_at=item.created_at,
        )
        for item in versions
    ]
    return success_response(TemplateVersionListResult(total=len(items), items=items))


@router.get("/templates/{template_id}/versions/compare", response_model=ApiResponse[TemplateVersionCompareResult])
def compare_template_versions_api(
    template_id: int,
    from_version: int = Query(ge=1),
    to_version: int = Query(ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.versions.compare")),
) -> ApiResponse[TemplateVersionCompareResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        result = compare_template_versions(
            db,
            template=row,
            from_version=from_version,
            to_version=to_version,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        TemplateVersionCompareResult(
            from_version=result.from_version,
            to_version=result.to_version,
            added_steps=result.added_steps,
            removed_steps=result.removed_steps,
            changed_steps=result.changed_steps,
            items=[
                TemplateVersionDiffItem(
                    step_order=item.step_order,
                    diff_type=item.diff_type,
                    from_stage_code=item.from_stage_code,
                    from_process_code=item.from_process_code,
                    to_stage_code=item.to_stage_code,
                    to_process_code=item.to_process_code,
                )
                for item in result.items
            ],
        )
    )


@router.post("/templates/{template_id}/rollback", response_model=ApiResponse[ProductProcessTemplateUpdateResult])
def rollback_template_api(
    template_id: int,
    payload: TemplateRollbackRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.rollback")),
) -> ApiResponse[ProductProcessTemplateUpdateResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        updated, sync_result = rollback_template_to_version(
            db,
            template=row,
            target_version=payload.target_version,
            operator=current_user,
            apply_order_sync=payload.apply_order_sync,
            confirmed=payload.confirmed,
            note=payload.note,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        ProductProcessTemplateUpdateResult(
            detail=_to_template_detail(updated),
            sync_result=TemplateSyncResult(
                total=sync_result.total,
                synced=sync_result.synced,
                skipped=sync_result.skipped,
                reasons=[
                    TemplateSyncOrderConflict(
                        order_id=item.order_id,
                        order_code=item.order_code,
                        reason=item.reason,
                    )
                    for item in sync_result.reasons
                ],
            ),
        ),
        message="rolled_back",
    )


@router.put("/templates/{template_id}", response_model=ApiResponse[ProductProcessTemplateUpdateResult])
def update_template_api(
    template_id: int,
    payload: ProductProcessTemplateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateUpdateResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        updated, sync_result = update_template(
            db,
            template=row,
            template_name=payload.template_name,
            is_default=payload.is_default,
            is_enabled=payload.is_enabled,
            steps=[item.model_dump() for item in payload.steps],
            sync_orders=payload.sync_orders,
            operator=current_user,
        )
    except TemplateSyncConflictError as error:
        sync_result = TemplateSyncResult(
            total=error.result.total,
            synced=error.result.synced,
            skipped=error.result.skipped,
            reasons=[
                TemplateSyncOrderConflict(
                    order_id=item.order_id,
                    order_code=item.order_code,
                    reason=item.reason,
                )
                for item in error.result.reasons
            ],
        )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "message": "Template updated but some orders were skipped",
                "sync_result": sync_result.model_dump(),
            },
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        ProductProcessTemplateUpdateResult(
            detail=_to_template_detail(updated),
            sync_result=TemplateSyncResult(
                total=sync_result.total,
                synced=sync_result.synced,
                skipped=sync_result.skipped,
                reasons=[
                    TemplateSyncOrderConflict(
                        order_id=item.order_id,
                        order_code=item.order_code,
                        reason=item.reason,
                    )
                    for item in sync_result.reasons
                ],
            ),
        ),
        message="updated",
    )


@router.delete("/templates/{template_id}", response_model=ApiResponse[dict[str, bool]])
def delete_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        delete_template(db, template=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.post("/templates/{template_id}/copy", response_model=ApiResponse[ProductProcessTemplateDetail], status_code=status.HTTP_201_CREATED)
def copy_template_api(
    template_id: int,
    body: TemplateCopyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.create")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        new_row = copy_template(db, template=row, new_name=body.new_name, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_template_detail(new_row), message="created")


@router.post("/templates/{template_id}/archive", response_model=ApiResponse[ProductProcessTemplateDetail])
def archive_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        updated = archive_template(db, template=row, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_template_detail(updated), message="archived")


@router.post("/templates/{template_id}/unarchive", response_model=ApiResponse[ProductProcessTemplateDetail])
def unarchive_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        updated = unarchive_template(db, template=row, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_template_detail(updated), message="unarchived")


@router.get("/stages/{stage_id}/references", response_model=ApiResponse[StageReferenceResult])
def get_stage_references_api(
    stage_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.list")),
) -> ApiResponse[StageReferenceResult]:
    row = get_stage_by_id(db, stage_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stage not found")
    result = get_stage_references(db, stage=row)
    return success_response(_to_stage_reference_result(result))


@router.get("/processes/{process_id}/references", response_model=ApiResponse[ProcessReferenceResult])
def get_process_references_api(
    process_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.list")),
) -> ApiResponse[ProcessReferenceResult]:
    row = db.execute(select(Process).where(Process.id == process_id)).scalars().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Process not found")
    result = get_process_references(db, process=row)
    return success_response(_to_process_reference_result(result))
