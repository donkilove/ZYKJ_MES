from __future__ import annotations

from functools import wraps
from datetime import UTC, datetime
import json
import logging
import time
from threading import RLock

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy.orm import Session
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import require_permission, require_permission_fast
from app.db.session import get_db
from app.models.craft_system_master_template import CraftSystemMasterTemplate
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.product import Product
from app.models.product_process_template import ProductProcessTemplate
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.services.audit_service import write_audit_log
from app.services.message_service import create_message_for_users
from app.schemas.craft import (
    CraftKanbanProcessItem,
    CraftKanbanProcessMetricsResult,
    CraftProcessLightItem,
    CraftProcessLightListResult,
    CraftKanbanSampleItem,
    CraftProcessCreate,
    CraftProcessItem,
    CraftProcessListResult,
    CraftProcessUpdate,
    ProcessStageCreate,
    ProcessStageLightItem,
    ProcessStageLightListResult,
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
    TemplateImpactReferenceItem,
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
    SystemMasterTemplateVersionItem,
    SystemMasterTemplateVersionListResult,
    SystemMasterTemplateVersionStepItem,
    SystemMasterTemplateStepItem,
    SystemMasterTemplateUpsertRequest,
    TemplateStepItem,
    TemplateSyncOrderConflict,
    TemplateSyncResult,
    TemplateCopyRequest,
    TemplateCopyFromMasterRequest,
    TemplateCopyToProductRequest,
    StageReferenceItem,
    StageReferenceResult,
    ProcessReferenceItem,
    ProcessReferenceResult,
    TemplateReferenceItem,
    TemplateReferenceResult,
    ProductTemplateReferenceResult,
    ProductTemplateReferenceRow,
    CraftExportResult,
)
from app.services.craft_service import (
    TemplateSyncConflictError,
    analyze_template_impact,
    compare_template_versions,
    create_process,
    export_craft_kanban_process_metrics_csv,
    export_template_detail_json,
    export_template_version_json,
    export_templates,
    get_craft_kanban_process_metrics,
    import_templates,
    list_template_versions,
    publish_template,
    rollback_template_to_version,
    create_system_master_template,
    create_stage,
    create_template_draft,
    create_template,
    copy_template,
    copy_template_from_system_master,
    copy_template_to_product,
    archive_template,
    unarchive_template,
    delete_process,
    delete_stage,
    delete_template,
    get_system_master_template,
    get_stage_by_id,
    get_stage_by_code,
    get_product_template_references,
    get_template_by_id,
    get_stage_references,
    get_process_by_id,
    get_process_by_code,
    get_process_references,
    get_template_references,
    list_craft_processes,
    list_enabled_process_options,
    list_enabled_stage_options,
    list_stages,
    list_enabled_process_options,
    list_enabled_stage_options,
    list_system_master_template_versions,
    list_templates,
    export_stages_csv,
    export_processes_csv,
    update_process,
    update_system_master_template,
    update_stage,
    update_template,
    set_template_enabled,
)


router = APIRouter()
logger = logging.getLogger(__name__)
_CRAFT_READ_RESPONSE_CACHE: dict[str, tuple[float, bytes]] = {}
_CRAFT_READ_RESPONSE_CACHE_LOCK = RLock()
_CRAFT_READ_RESPONSE_CACHE_TTL_SECONDS = 10
_CRAFT_PROCESS_RESPONSE_CACHE_TTL_SECONDS = 15
_CRAFT_TEMPLATE_RESPONSE_CACHE_TTL_SECONDS = 15
_CRAFT_KANBAN_RESPONSE_CACHE_TTL_SECONDS = 10


def _craft_read_cache_key(
    cache_type: str,
    payload: dict[str, object] | None = None,
) -> str:
    encoded_payload = json.dumps(
        payload or {},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return f"craft_read:{cache_type}:{encoded_payload}"


def _get_craft_read_cached_response_bytes(cache_key: str) -> bytes | None:
    with _CRAFT_READ_RESPONSE_CACHE_LOCK:
        cached = _CRAFT_READ_RESPONSE_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, payload_bytes = cached
        if expire_at <= time.monotonic():
            _CRAFT_READ_RESPONSE_CACHE.pop(cache_key, None)
            return None
        return payload_bytes


def _set_craft_read_cached_response_bytes(
    cache_key: str,
    payload: dict[str, object],
    *,
    ttl_seconds: int = _CRAFT_READ_RESPONSE_CACHE_TTL_SECONDS,
) -> bytes:
    payload_bytes = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    resolved_ttl_seconds = max(1, int(ttl_seconds))
    with _CRAFT_READ_RESPONSE_CACHE_LOCK:
        _CRAFT_READ_RESPONSE_CACHE[cache_key] = (
            time.monotonic() + resolved_ttl_seconds,
            payload_bytes,
        )
    return payload_bytes


def _invalidate_craft_read_cache() -> None:
    with _CRAFT_READ_RESPONSE_CACHE_LOCK:
        _CRAFT_READ_RESPONSE_CACHE.clear()


def _invalidate_craft_read_cache_after_success(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        result = func(*args, **kwargs)
        _invalidate_craft_read_cache()
        return result

    return wrapper


def _to_stage_item(row: ProcessStage) -> ProcessStageItem:
    return ProcessStageItem(
        id=row.id,
        code=row.code,
        name=row.name,
        sort_order=row.sort_order,
        is_enabled=row.is_enabled,
        remark=row.remark,
        process_count=len(row.processes) if row.processes is not None else 0,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_stage_light_item(row: ProcessStage) -> ProcessStageLightItem:
    return ProcessStageLightItem(
        id=row.id,
        code=row.code,
        name=row.name,
        sort_order=row.sort_order,
        is_enabled=row.is_enabled,
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
        remark=row.remark,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_process_light_item(row: Process) -> CraftProcessLightItem:
    stage = row.stage
    return CraftProcessLightItem(
        id=row.id,
        code=row.code,
        name=row.name,
        stage_id=row.stage_id,
        stage_code=stage.code if stage else None,
        stage_name=stage.name if stage else None,
        is_enabled=row.is_enabled,
    )


def _to_template_item(row: ProductProcessTemplate) -> ProductProcessTemplateItem:
    return ProductProcessTemplateItem(
        id=row.id,
        product_id=row.product_id,
        product_name=row.product.name if row.product else "",
        product_category=row.product.category if row.product else "",
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
        remark=row.remark,
        source_type=row.source_type,
        source_template_id=row.source_template_id,
        source_template_name=row.source_template_name,
        source_template_version=row.source_template_version,
        source_product_id=row.source_product_id,
        source_system_master_version=row.source_system_master_version,
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


def _to_system_master_template_item(
    row: CraftSystemMasterTemplate,
) -> SystemMasterTemplateItem:
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
    target_version: int,
    total_orders: int,
    pending_orders: int,
    in_progress_orders: int,
    syncable_orders: int,
    blocked_orders: int,
    items: list[TemplateImpactOrderItem],
    total_references: int,
    user_stage_reference_count: int,
    template_reuse_reference_count: int,
    reference_items: list[TemplateImpactReferenceItem],
) -> TemplateImpactAnalysisResult:
    return TemplateImpactAnalysisResult(
        target_version=target_version,
        total_orders=total_orders,
        pending_orders=pending_orders,
        in_progress_orders=in_progress_orders,
        syncable_orders=syncable_orders,
        blocked_orders=blocked_orders,
        items=items,
        total_references=total_references,
        user_stage_reference_count=user_stage_reference_count,
        template_reuse_reference_count=template_reuse_reference_count,
        reference_items=reference_items,
    )


def _notify_craft_template_published(
    *,
    db: Session,
    template: ProductProcessTemplate,
    operator: User,
) -> None:
    payload = {
        "action": "view_template_version",
        "template_id": template.id,
        "version": template.version,
        "target_tab_code": "production_process_config",
    }
    create_message_for_users(
        db,
        message_type="notice",
        priority="important",
        title=f"工艺模板已发布：{template.template_name} V{template.version}",
        summary=f"{operator.username} 已发布模板 {template.template_name} V{template.version}",
        content=(
            f"产品 {template.product.name if template.product else '-'} 的工艺模板"
            f" {template.template_name} 已发布到 V{template.version}。"
            "可从消息直接跳转到生产工序配置查看版本详情。"
        ),
        source_module="craft",
        source_type="product_process_template",
        source_id=str(template.id),
        source_code=f"{template.template_name}/V{template.version}",
        target_page_code="craft",
        target_tab_code="production_process_config",
        target_route_payload_json=json.dumps(payload),
        recipient_user_ids=[operator.id],
        dedupe_key=f"craft_template_published_{template.id}_{template.version}",
        created_by_user_id=operator.id,
    )


def _to_template_update_result(
    row: ProductProcessTemplate,
) -> ProductProcessTemplateUpdateResult:
    return ProductProcessTemplateUpdateResult(
        detail=_to_template_detail(row),
        sync_result=TemplateSyncResult(total=0, synced=0, skipped=0, reasons=[]),
    )


def _template_version_record_type(action: str) -> str:
    normalized = action.strip().lower()
    if normalized == "publish":
        return "publish"
    if normalized == "rollback":
        return "rollback_publish"
    if normalized in {"create", "copy", "snapshot"}:
        return "snapshot"
    return "change"


def _template_version_record_title(*, version: int, action: str) -> str:
    record_type = _template_version_record_type(action)
    if record_type == "publish":
        return f"发布记录 P{version}"
    if record_type == "rollback_publish":
        return f"回滚发布记录 P{version}"
    if record_type == "snapshot":
        return f"历史快照 P{version}"
    return f"版本变更记录 P{version}"


def _template_version_record_summary(*, action: str, source_version: int | None) -> str:
    record_type = _template_version_record_type(action)
    if record_type == "publish":
        return "草稿经发布门禁确认后成为当前生效版本"
    if record_type == "rollback_publish":
        if source_version is not None:
            return f"基于历史版本 v{source_version} 重新发布并替换当前生效版本"
        return "基于历史版本重新发布并替换当前生效版本"
    if record_type == "snapshot":
        return "仅用于追溯当时模板内容，不代表当前已生效"
    return "记录模板历史变更，是否生效以发布记录为准"


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
                ref_code=item.ref_code,
                ref_name=item.ref_name,
                detail=item.detail,
                ref_status=item.ref_status,
                jump_module=item.jump_module,
                jump_target=item.jump_target,
                risk_level=item.risk_level,
                risk_note=item.risk_note,
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
                ref_code=item.ref_code,
                ref_name=item.ref_name,
                detail=item.detail,
                ref_status=item.ref_status,
                jump_module=item.jump_module,
                jump_target=item.jump_target,
                risk_level=item.risk_level,
                risk_note=item.risk_note,
            )
            for item in result.items
        ],
    )


def _to_system_master_template_version_list_result(
    result,
) -> SystemMasterTemplateVersionListResult:
    return SystemMasterTemplateVersionListResult(
        total=result.total,
        items=[
            SystemMasterTemplateVersionItem(
                version=item.version,
                action=item.action,
                note=item.note,
                created_by_user_id=item.created_by_user_id,
                created_by_username=item.created_by.username
                if item.created_by
                else None,
                created_at=item.created_at,
                steps=[
                    SystemMasterTemplateVersionStepItem(
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
                    for step in sorted(
                        item.steps, key=lambda row: (row.step_order, row.id)
                    )
                ],
            )
            for item in result.items
        ],
    )


def _to_product_template_reference_result(result) -> ProductTemplateReferenceResult:
    return ProductTemplateReferenceResult(
        product_id=result.product_id,
        product_name=result.product_name,
        total_templates=result.total_templates,
        total_references=result.total_references,
        items=[
            ProductTemplateReferenceRow(
                template_id=item.template_id,
                template_name=item.template_name,
                lifecycle_status=item.lifecycle_status,
                ref_type=item.ref_type,
                ref_id=item.ref_id,
                ref_code=item.ref_code,
                ref_name=item.ref_name,
                detail=item.detail,
                ref_status=item.ref_status,
                jump_module=item.jump_module,
                jump_target=item.jump_target,
                risk_level=item.risk_level,
                risk_note=item.risk_note,
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
    return success_response(
        ProcessStageListResult(total=total, items=[_to_stage_item(row) for row in rows])
    )


@router.get("/stages/light", response_model=ApiResponse[ProcessStageLightListResult])
def get_stage_light_options(
    enabled: bool | None = Query(default=True),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.list")),
) -> ApiResponse[ProcessStageLightListResult]:
    rows = (
        list_enabled_stage_options(db)
        if enabled is True
        else list_stages(
            db,
            page=1,
            page_size=1000,
            keyword=None,
            enabled=enabled,
        )[1]
    )
    return success_response(
        ProcessStageLightListResult(
            total=len(rows), items=[_to_stage_light_item(row) for row in rows]
        )
    )


@router.post(
    "/stages",
    response_model=ApiResponse[ProcessStageItem],
    status_code=status.HTTP_201_CREATED,
)
@_invalidate_craft_read_cache_after_success
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
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_stage_item(row), message="created")


@router.get("/stages/detail", response_model=ApiResponse[ProcessStageItem])
def get_stage_detail_api(
    stage_id: int | None = Query(default=None, ge=1),
    stage_code: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.list")),
) -> ApiResponse[ProcessStageItem]:
    if stage_id is None and not (stage_code or "").strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="stage_id or stage_code is required",
        )
    row = None
    if stage_id is not None:
        row = get_stage_by_id(db, stage_id)
    elif stage_code is not None:
        row = get_stage_by_code(db, stage_code.strip())
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Stage not found"
        )
    row = (
        db.execute(
            select(ProcessStage)
            .where(ProcessStage.id == row.id)
            .options(selectinload(ProcessStage.processes))
        )
        .scalars()
        .first()
        or row
    )
    return success_response(_to_stage_item(row))


@router.put("/stages/{stage_id}", response_model=ApiResponse[ProcessStageItem])
@_invalidate_craft_read_cache_after_success
def update_stage_api(
    stage_id: int,
    payload: ProcessStageUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.update")),
) -> ApiResponse[ProcessStageItem]:
    row = get_stage_by_id(db, stage_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Stage not found"
        )
    try:
        updated = update_stage(
            db,
            row=row,
            name=payload.name,
            sort_order=payload.sort_order,
            is_enabled=payload.is_enabled,
            code=payload.code,
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_stage_item(updated), message="updated")


@router.delete("/stages/{stage_id}", response_model=ApiResponse[dict[str, bool]])
@_invalidate_craft_read_cache_after_success
def delete_stage_api(
    stage_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = get_stage_by_id(db, stage_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Stage not found"
        )
    try:
        delete_stage(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.get("/stages/export", response_model=ApiResponse[CraftExportResult])
def export_stages_api(
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.list")),
) -> ApiResponse[CraftExportResult]:
    result = export_stages_csv(db, keyword=keyword, enabled=enabled)
    return success_response(CraftExportResult(**result))


@router.get("/processes/export", response_model=ApiResponse[CraftExportResult])
def export_processes_api(
    keyword: str | None = Query(default=None),
    stage_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.list")),
) -> ApiResponse[CraftExportResult]:
    result = export_processes_csv(
        db, keyword=keyword, stage_id=stage_id, enabled=enabled
    )
    return success_response(CraftExportResult(**result))


@router.get("/processes", response_model=ApiResponse[CraftProcessListResult])
def get_processes_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=200, ge=1, le=500),
    keyword: str | None = Query(default=None),
    stage_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("craft.processes.list")),
) -> ApiResponse[CraftProcessListResult] | Response:
    cache_key = _craft_read_cache_key(
        "processes",
        {
            "page": page,
            "page_size": page_size,
            "keyword": keyword,
            "stage_id": stage_id,
            "enabled": enabled,
        },
    )
    cached_payload = _get_craft_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    total, rows = list_craft_processes(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        stage_id=stage_id,
        enabled=enabled,
    )
    response_payload = success_response(
        CraftProcessListResult(
            total=total, items=[_to_process_item(row) for row in rows]
        )
    ).model_dump(mode="json")
    payload_bytes = _set_craft_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_CRAFT_PROCESS_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get("/processes/light", response_model=ApiResponse[CraftProcessLightListResult])
def get_process_light_options(
    stage_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=True),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("craft.processes.list")),
) -> ApiResponse[CraftProcessLightListResult] | Response:
    cache_key = _craft_read_cache_key(
        "processes_light",
        {"stage_id": stage_id, "enabled": enabled},
    )
    cached_payload = _get_craft_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    rows = (
        list_enabled_process_options(db, stage_id=stage_id)
        if enabled is True
        else list_craft_processes(
            db,
            page=1,
            page_size=2000,
            keyword=None,
            stage_id=stage_id,
            enabled=enabled,
        )[1]
    )
    response_payload = success_response(
        CraftProcessLightListResult(
            total=len(rows), items=[_to_process_light_item(row) for row in rows]
        )
    ).model_dump(mode="json")
    payload_bytes = _set_craft_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_CRAFT_PROCESS_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.post(
    "/processes",
    response_model=ApiResponse[CraftProcessItem],
    status_code=status.HTTP_201_CREATED,
)
@_invalidate_craft_read_cache_after_success
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
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_process_item(row), message="created")


@router.get("/processes/detail", response_model=ApiResponse[CraftProcessItem])
def get_process_detail_api(
    process_id: int | None = Query(default=None, ge=1),
    process_code: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("craft.processes.list")),
) -> ApiResponse[CraftProcessItem] | Response:
    if process_id is None and not (process_code or "").strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="process_id or process_code is required",
        )
    normalized_process_code = process_code.strip() if isinstance(process_code, str) else None
    cache_key = _craft_read_cache_key(
        "process_detail",
        {"process_id": process_id, "process_code": normalized_process_code},
    )
    cached_payload = _get_craft_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    row = None
    if process_id is not None:
        row = get_process_by_id(db, process_id)
    elif normalized_process_code is not None:
        row = get_process_by_code(db, normalized_process_code)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Process not found"
        )
    response_payload = success_response(_to_process_item(row)).model_dump(mode="json")
    payload_bytes = _set_craft_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_CRAFT_PROCESS_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.put("/processes/{process_id}", response_model=ApiResponse[CraftProcessItem])
@_invalidate_craft_read_cache_after_success
def update_process_api(
    process_id: int,
    payload: CraftProcessUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.update")),
) -> ApiResponse[CraftProcessItem]:
    row = (
        db.execute(
            select(Process)
            .where(Process.id == process_id)
            .options(selectinload(Process.stage))
        )
        .scalars()
        .first()
    )
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Process not found"
        )
    try:
        updated = update_process(
            db,
            row=row,
            name=payload.name,
            stage_id=payload.stage_id,
            is_enabled=payload.is_enabled,
            code=payload.code,
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    updated = (
        db.execute(
            select(Process)
            .where(Process.id == updated.id)
            .options(selectinload(Process.stage))
        )
        .scalars()
        .first()
        or updated
    )
    return success_response(_to_process_item(updated), message="updated")


@router.delete("/processes/{process_id}", response_model=ApiResponse[dict[str, bool]])
@_invalidate_craft_read_cache_after_success
def delete_process_api(
    process_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = db.execute(select(Process).where(Process.id == process_id)).scalars().first()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Process not found"
        )
    try:
        delete_process(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.get(
    "/system-master-template",
    response_model=ApiResponse[SystemMasterTemplateItem | None],
)
def get_system_master_template_api(
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("craft.system_master_template.view")),
) -> ApiResponse[SystemMasterTemplateItem | None] | Response:
    cache_key = _craft_read_cache_key("system_master_template")
    cached_payload = _get_craft_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    row = get_system_master_template(db)
    if row is None:
        response_payload = success_response(None).model_dump(mode="json")
    else:
        response_payload = success_response(
            _to_system_master_template_item(row)
        ).model_dump(mode="json")
    payload_bytes = _set_craft_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_CRAFT_TEMPLATE_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.post(
    "/system-master-template",
    response_model=ApiResponse[SystemMasterTemplateItem],
    status_code=status.HTTP_201_CREATED,
)
@_invalidate_craft_read_cache_after_success
def create_system_master_template_api(
    payload: SystemMasterTemplateUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("craft.system_master_template.create")
    ),
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


@router.put(
    "/system-master-template", response_model=ApiResponse[SystemMasterTemplateItem]
)
@_invalidate_craft_read_cache_after_success
def update_system_master_template_api(
    payload: SystemMasterTemplateUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("craft.system_master_template.update")
    ),
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


@router.get(
    "/system-master-template/versions",
    response_model=ApiResponse[SystemMasterTemplateVersionListResult],
)
def list_system_master_template_versions_api(
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("craft.system_master_template.view")),
) -> ApiResponse[SystemMasterTemplateVersionListResult] | Response:
    cache_key = _craft_read_cache_key("system_master_template_versions")
    cached_payload = _get_craft_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    result = list_system_master_template_versions(db)
    response_payload = success_response(
        _to_system_master_template_version_list_result(result)
    ).model_dump(mode="json")
    payload_bytes = _set_craft_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_CRAFT_TEMPLATE_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get(
    "/kanban/process-metrics",
    response_model=ApiResponse[CraftKanbanProcessMetricsResult],
)
def get_craft_kanban_process_metrics_api(
    product_id: int = Query(ge=1),
    limit: int = Query(default=5, ge=1, le=100),
    stage_id: int | None = Query(default=None, ge=1),
    process_id: int | None = Query(default=None, ge=1),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("craft.kanban.process_metrics.view")),
) -> ApiResponse[CraftKanbanProcessMetricsResult] | Response:
    cache_key = _craft_read_cache_key(
        "kanban_process_metrics",
        {
            "product_id": product_id,
            "limit": limit,
            "stage_id": stage_id,
            "process_id": process_id,
            "start_date": start_date.isoformat() if start_date else None,
            "end_date": end_date.isoformat() if end_date else None,
        },
    )
    cached_payload = _get_craft_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
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
    response_payload = success_response(_to_kanban_result_item(result)).model_dump(
        mode="json"
    )
    payload_bytes = _set_craft_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_CRAFT_KANBAN_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get(
    "/kanban/process-metrics/export", response_model=ApiResponse[CraftExportResult]
)
def export_craft_kanban_process_metrics_api(
    product_id: int = Query(ge=1),
    stage_id: int | None = Query(default=None, ge=1),
    process_id: int | None = Query(default=None, ge=1),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    limit: int = Query(default=5, ge=1, le=100),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.kanban.process_metrics.view")),
) -> ApiResponse[CraftExportResult]:
    try:
        result = export_craft_kanban_process_metrics_csv(
            db,
            product_id=product_id,
            stage_id=stage_id if isinstance(stage_id, int) else None,
            process_id=process_id if isinstance(process_id, int) else None,
            start_date=start_date if isinstance(start_date, datetime) else None,
            end_date=end_date if isinstance(end_date, datetime) else None,
            limit=limit,
        )
    except ValueError as error:
        message = str(error)
        if message == "Product not found":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=message)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)
    return success_response(CraftExportResult(**result))


@router.get("/templates", response_model=ApiResponse[ProductProcessTemplateListResult])
def get_templates_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    product_id: int | None = Query(default=None, ge=1),
    keyword: str | None = Query(default=None),
    product_category: str | None = Query(default=None),
    is_default: bool | None = Query(default=None),
    enabled: bool | None = Query(default=True),
    lifecycle_status: str | None = Query(default=None),
    updated_from: datetime | None = Query(default=None),
    updated_to: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast("craft.templates.list")),
) -> ApiResponse[ProductProcessTemplateListResult] | Response:
    cache_key = _craft_read_cache_key(
        "templates",
        {
            "page": page,
            "page_size": page_size,
            "product_id": product_id,
            "keyword": keyword,
            "product_category": product_category,
            "is_default": is_default,
            "enabled": enabled,
            "lifecycle_status": lifecycle_status,
            "updated_from": updated_from.isoformat() if updated_from else None,
            "updated_to": updated_to.isoformat() if updated_to else None,
        },
    )
    cached_payload = _get_craft_read_cached_response_bytes(cache_key)
    if cached_payload is not None:
        return Response(content=cached_payload, media_type="application/json")
    total, rows = list_templates(
        db,
        page=page,
        page_size=page_size,
        product_id=product_id,
        keyword=keyword,
        product_category=product_category,
        is_default=is_default,
        enabled=enabled,
        lifecycle_status=lifecycle_status,
        updated_from=updated_from,
        updated_to=updated_to,
    )
    response_payload = success_response(
        ProductProcessTemplateListResult(
            total=total, items=[_to_template_item(row) for row in rows]
        )
    ).model_dump(mode="json")
    payload_bytes = _set_craft_read_cached_response_bytes(
        cache_key,
        response_payload,
        ttl_seconds=_CRAFT_TEMPLATE_RESPONSE_CACHE_TTL_SECONDS,
    )
    return Response(content=payload_bytes, media_type="application/json")


@router.get(
    "/templates/{template_id}/export", response_model=ApiResponse[CraftExportResult]
)
def export_template_detail_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.export")),
) -> ApiResponse[CraftExportResult]:
    row = get_template_by_id(db, template_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    result = export_template_detail_json(db, template=row)
    return success_response(CraftExportResult(**result))


@router.get(
    "/templates/{template_id}/versions/{version}/export",
    response_model=ApiResponse[CraftExportResult],
)
def export_template_version_api(
    template_id: int,
    version: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.export")),
) -> ApiResponse[CraftExportResult]:
    row = get_template_by_id(db, template_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        result = export_template_version_json(db, template=row, version=version)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error))
    return success_response(CraftExportResult(**result))


@router.post(
    "/templates",
    response_model=ApiResponse[ProductProcessTemplateDetail],
    status_code=status.HTTP_201_CREATED,
)
@_invalidate_craft_read_cache_after_success
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
            remark=payload.remark,
            steps=[item.model_dump() for item in payload.steps],
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_template_detail(row), message="created")


@router.get("/templates/export", response_model=ApiResponse[TemplateBatchExportResult])
def export_templates_api(
    product_id: int | None = Query(default=None, ge=1),
    keyword: str | None = Query(default=None),
    product_category: str | None = Query(default=None),
    is_default: bool | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    lifecycle_status: str | None = Query(default=None),
    updated_from: datetime | None = Query(default=None),
    updated_to: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.export")),
) -> ApiResponse[TemplateBatchExportResult]:
    normalized_keyword = keyword if isinstance(keyword, str) else None
    normalized_product_category = (
        product_category if isinstance(product_category, str) else None
    )
    normalized_is_default = is_default if isinstance(is_default, bool) else None
    try:
        rows = export_templates(
            db,
            product_id=product_id,
            keyword=normalized_keyword,
            product_category=normalized_product_category,
            is_default=normalized_is_default,
            enabled=enabled,
            lifecycle_status=lifecycle_status,
            updated_from=updated_from if isinstance(updated_from, datetime) else None,
            updated_to=updated_to if isinstance(updated_to, datetime) else None,
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
                source_type=row.source_type,
                source_template_name=row.source_template_name,
                source_template_version=row.source_template_version,
                source_system_master_version=row.source_system_master_version,
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
@_invalidate_craft_read_cache_after_success
def import_templates_api(
    payload: TemplateBatchImportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.import")),
) -> ApiResponse[TemplateBatchImportResult]:
    rows, created, updated, skipped, errors = import_templates(
        db,
        items=[item.model_dump() for item in payload.items],
        overwrite_existing=payload.overwrite_existing,
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


@router.get(
    "/templates/{template_id}", response_model=ApiResponse[ProductProcessTemplateDetail]
)
def get_template_detail_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.detail")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    return success_response(_to_template_detail(row))


@router.get(
    "/templates/{template_id}/impact-analysis",
    response_model=ApiResponse[TemplateImpactAnalysisResult],
)
def get_template_impact_analysis_api(
    template_id: int,
    target_version: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.impact.analysis")),
) -> ApiResponse[TemplateImpactAnalysisResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        impact = analyze_template_impact(
            db, template=row, target_version=target_version
        )
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
    reference_items = [
        TemplateImpactReferenceItem(
            ref_type=item.ref_type,
            ref_id=item.ref_id,
            ref_code=item.ref_code,
            ref_name=item.ref_name,
            detail=item.detail,
            ref_status=item.ref_status,
            jump_module=item.jump_module,
            jump_target=item.jump_target,
            risk_level=item.risk_level,
            risk_note=item.risk_note,
        )
        for item in impact.reference_items
    ]
    return success_response(
        _to_impact_result_item(
            target_version=impact.target_version,
            total_orders=impact.total_orders,
            pending_orders=impact.pending_orders,
            in_progress_orders=impact.in_progress_orders,
            syncable_orders=impact.syncable_orders,
            blocked_orders=impact.blocked_orders,
            items=items,
            total_references=impact.total_references,
            user_stage_reference_count=impact.user_stage_reference_count,
            template_reuse_reference_count=impact.template_reuse_reference_count,
            reference_items=reference_items,
        )
    )


@router.post(
    "/templates/{template_id}/publish",
    response_model=ApiResponse[ProductProcessTemplateUpdateResult],
)
@_invalidate_craft_read_cache_after_success
def publish_template_api(
    template_id: int,
    payload: TemplatePublishRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.publish")),
) -> ApiResponse[ProductProcessTemplateUpdateResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        updated, sync_result = publish_template(
            db,
            template=row,
            operator=current_user,
            apply_order_sync=payload.apply_order_sync,
            confirmed=payload.confirmed,
            expected_version=payload.expected_version,
            note=payload.note,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.publish",
        action_name="发布工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
        after_data={"version": updated.version, "note": payload.note},
    )
    db.commit()
    published_template_id = int(updated.id)
    published_version = int(updated.version)
    try:
        _notify_craft_template_published(
            db=db,
            template=updated,
            operator=current_user,
        )
    except Exception:
        db.rollback()
        logger.exception(
            "[MSG] 工艺模板发布消息创建失败: template_id=%s version=%s",
            published_template_id,
            published_version,
        )
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


@router.get(
    "/templates/{template_id}/versions",
    response_model=ApiResponse[TemplateVersionListResult],
)
def list_template_versions_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.versions.list")),
) -> ApiResponse[TemplateVersionListResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    versions = list_template_versions(db, template_id=row.id)
    items = [
        TemplateVersionItem(
            version=item.version,
            action=item.action,
            record_type=_template_version_record_type(item.action),
            record_title=_template_version_record_title(
                version=item.version,
                action=item.action,
            ),
            record_summary=_template_version_record_summary(
                action=item.action,
                source_version=item.source_revision.version if item.source_revision else None,
            ),
            note=item.note,
            source_version=item.source_revision.version
            if item.source_revision
            else None,
            created_by_user_id=item.created_by_user_id,
            created_by_username=item.created_by.username if item.created_by else None,
            created_at=item.created_at,
        )
        for item in versions
    ]
    return success_response(TemplateVersionListResult(total=len(items), items=items))


@router.get(
    "/templates/{template_id}/versions/compare",
    response_model=ApiResponse[TemplateVersionCompareResult],
)
def compare_template_versions_api(
    template_id: int,
    from_version: int = Query(ge=1),
    to_version: int = Query(ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.versions.compare")),
) -> ApiResponse[TemplateVersionCompareResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
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


@router.post(
    "/templates/{template_id}/rollback",
    response_model=ApiResponse[ProductProcessTemplateUpdateResult],
)
@_invalidate_craft_read_cache_after_success
def rollback_template_api(
    template_id: int,
    payload: TemplateRollbackRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.rollback")),
) -> ApiResponse[ProductProcessTemplateUpdateResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
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
    write_audit_log(
        db,
        action_code="craft.template.rollback",
        action_name="回滚工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
        after_data={"target_version": payload.target_version, "note": payload.note},
    )
    db.commit()
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


@router.put(
    "/templates/{template_id}",
    response_model=ApiResponse[ProductProcessTemplateUpdateResult],
)
@_invalidate_craft_read_cache_after_success
def update_template_api(
    template_id: int,
    payload: ProductProcessTemplateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateUpdateResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        updated, sync_result = update_template(
            db,
            template=row,
            template_name=payload.template_name,
            is_default=payload.is_default,
            is_enabled=payload.is_enabled,
            remark=payload.remark,
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


@router.post(
    "/templates/{template_id}/draft",
    response_model=ApiResponse[ProductProcessTemplateDetail],
)
@_invalidate_craft_read_cache_after_success
def create_template_draft_api(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        updated = create_template_draft(db, template=row, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.draft",
        action_name="创建模板草稿",
        target_type="craft_template",
        target_id=str(updated.id),
        target_name=updated.template_name,
        operator=current_user,
        after_data={
            "version": updated.version,
            "lifecycle_status": updated.lifecycle_status,
        },
    )
    return success_response(_to_template_detail(updated), message="draft_created")


@router.post(
    "/templates/{template_id}/enable",
    response_model=ApiResponse[ProductProcessTemplateDetail],
)
@_invalidate_craft_read_cache_after_success
def enable_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Template not found",
        )
    updated = set_template_enabled(
        db,
        template=row,
        is_enabled=True,
        operator=current_user,
    )
    write_audit_log(
        db,
        action_code="craft.template.enable",
        action_name="启用工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
    )
    db.commit()
    return success_response(_to_template_detail(updated), message="enabled")


@router.post(
    "/templates/{template_id}/disable",
    response_model=ApiResponse[ProductProcessTemplateDetail],
)
@_invalidate_craft_read_cache_after_success
def disable_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Template not found",
        )
    try:
        updated = set_template_enabled(
            db,
            template=row,
            is_enabled=False,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.disable",
        action_name="停用工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
    )
    db.commit()
    return success_response(_to_template_detail(updated), message="disabled")


@router.delete("/templates/{template_id}", response_model=ApiResponse[dict[str, bool]])
@_invalidate_craft_read_cache_after_success
def delete_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        delete_template(db, template=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.post(
    "/templates/{template_id}/copy",
    response_model=ApiResponse[ProductProcessTemplateDetail],
    status_code=status.HTTP_201_CREATED,
)
@_invalidate_craft_read_cache_after_success
def copy_template_api(
    template_id: int,
    body: TemplateCopyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.create")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        new_row = copy_template(
            db, template=row, new_name=body.new_name, operator=current_user
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.copy",
        action_name="复制工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
        after_data={"new_template_id": new_row.id, "new_name": new_row.template_name},
    )
    db.commit()
    return success_response(_to_template_detail(new_row), message="created")


@router.post(
    "/templates/{template_id}/copy-to-product",
    response_model=ApiResponse[ProductProcessTemplateDetail],
    status_code=status.HTTP_201_CREATED,
)
@_invalidate_craft_read_cache_after_success
def copy_template_to_product_api(
    template_id: int,
    body: TemplateCopyToProductRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.create")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        new_row = copy_template_to_product(
            db,
            template=row,
            target_product_id=body.target_product_id,
            new_name=body.new_name,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.copy",
        action_name="跨产品复制工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
        after_data={
            "new_template_id": new_row.id,
            "new_name": new_row.template_name,
            "target_product_id": body.target_product_id,
        },
    )
    db.commit()
    return success_response(_to_template_detail(new_row), message="created")


@router.post(
    "/system-master-template/copy-to-product",
    response_model=ApiResponse[ProductProcessTemplateDetail],
    status_code=status.HTTP_201_CREATED,
)
@_invalidate_craft_read_cache_after_success
def copy_system_master_to_product_api(
    body: TemplateCopyFromMasterRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.create")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    master = get_system_master_template(db)
    if not master:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="System master template not found",
        )
    try:
        new_row = copy_template_from_system_master(
            db,
            system_master=master,
            product_id=body.product_id,
            new_name=body.new_name,
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.copy",
        action_name="从系统母版套版",
        target_type="craft_template",
        target_id=str(new_row.id),
        target_name=new_row.template_name,
        operator=current_user,
        after_data={"source": "system_master", "product_id": body.product_id},
    )
    db.commit()
    return success_response(_to_template_detail(new_row), message="created")


@router.post(
    "/templates/{template_id}/archive",
    response_model=ApiResponse[ProductProcessTemplateDetail],
)
@_invalidate_craft_read_cache_after_success
def archive_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        updated = archive_template(db, template=row, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.archive",
        action_name="归档工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
    )
    db.commit()
    return success_response(_to_template_detail(updated), message="archived")


@router.post(
    "/templates/{template_id}/unarchive",
    response_model=ApiResponse[ProductProcessTemplateDetail],
)
@_invalidate_craft_read_cache_after_success
def unarchive_template_api(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("craft.templates.update")),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    try:
        updated = unarchive_template(db, template=row, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="craft.template.unarchive",
        action_name="取消归档工艺模板",
        target_type="craft_template",
        target_id=str(row.id),
        target_name=row.template_name,
        operator=current_user,
    )
    db.commit()
    return success_response(_to_template_detail(updated), message="unarchived")


@router.get(
    "/stages/{stage_id}/references", response_model=ApiResponse[StageReferenceResult]
)
def get_stage_references_api(
    stage_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.stages.list")),
) -> ApiResponse[StageReferenceResult]:
    row = get_stage_by_id(db, stage_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Stage not found"
        )
    result = get_stage_references(db, stage=row)
    return success_response(_to_stage_reference_result(result))


@router.get(
    "/processes/{process_id}/references",
    response_model=ApiResponse[ProcessReferenceResult],
)
def get_process_references_api(
    process_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.processes.list")),
) -> ApiResponse[ProcessReferenceResult]:
    row = db.execute(select(Process).where(Process.id == process_id)).scalars().first()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Process not found"
        )
    result = get_process_references(db, process=row)
    return success_response(_to_process_reference_result(result))


@router.get(
    "/templates/{template_id}/references",
    response_model=ApiResponse[TemplateReferenceResult],
)
def get_template_references_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.list")),
) -> ApiResponse[TemplateReferenceResult]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )
    result = get_template_references(db, template=row)
    return success_response(
        TemplateReferenceResult(
            template_id=result.template_id,
            template_name=result.template_name,
            product_id=result.product_id,
            product_name=result.product_name,
            total=result.total,
            order_reference_count=result.order_reference_count,
            user_stage_reference_count=result.user_stage_reference_count,
            template_reuse_reference_count=result.template_reuse_reference_count,
            blocking_reference_count=result.blocking_reference_count,
            has_blocking_references=result.has_blocking_references,
            items=[
                TemplateReferenceItem(
                    ref_type=item.ref_type,
                    ref_id=item.ref_id,
                    ref_code=item.ref_code,
                    ref_name=item.ref_name,
                    detail=item.detail,
                    ref_status=item.ref_status,
                    jump_module=item.jump_module,
                    jump_target=item.jump_target,
                    risk_level=item.risk_level,
                    risk_note=item.risk_note,
                    is_blocking=item.is_blocking,
                )
                for item in result.items
            ],
        )
    )


@router.get(
    "/products/{product_id}/template-references",
    response_model=ApiResponse[ProductTemplateReferenceResult],
)
def get_product_template_references_api(
    product_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("craft.templates.list")),
) -> ApiResponse[ProductTemplateReferenceResult]:
    product_row = (
        db.execute(select(Product).where(Product.id == product_id)).scalars().first()
    )
    if product_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Product not found"
        )
    result = get_product_template_references(db, product=product_row)
    return success_response(_to_product_template_reference_result(result))
