from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import require_role_codes
from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.db.session import get_db
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.product_process_template import ProductProcessTemplate
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.craft import (
    CraftProcessCreate,
    CraftProcessItem,
    CraftProcessListResult,
    CraftProcessUpdate,
    ProcessStageCreate,
    ProcessStageItem,
    ProcessStageListResult,
    ProcessStageUpdate,
    ProductProcessTemplateCreate,
    ProductProcessTemplateDetail,
    ProductProcessTemplateItem,
    ProductProcessTemplateListResult,
    ProductProcessTemplateUpdate,
    ProductProcessTemplateUpdateResult,
    TemplateStepItem,
    TemplateSyncOrderConflict,
    TemplateSyncResult,
)
from app.services.craft_service import (
    TemplateSyncConflictError,
    create_process,
    create_stage,
    create_template,
    delete_process,
    delete_stage,
    delete_template,
    get_stage_by_id,
    get_template_by_id,
    list_craft_processes,
    list_stages,
    list_templates,
    update_process,
    update_stage,
    update_template,
)


router = APIRouter()


WRITE_ROLE_CODES = [ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN]


def _to_stage_item(row: ProcessStage) -> ProcessStageItem:
    return ProcessStageItem(
        id=row.id,
        code=row.code,
        name=row.name,
        sort_order=row.sort_order,
        is_enabled=row.is_enabled,
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


@router.get("/stages", response_model=ApiResponse[ProcessStageListResult])
def get_stages(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
) -> ApiResponse[dict[str, bool]]:
    row = db.execute(select(Process).where(Process.id == process_id)).scalars().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Process not found")
    try:
        delete_process(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.get("/templates", response_model=ApiResponse[ProductProcessTemplateListResult])
def get_templates_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    product_id: int | None = Query(default=None, ge=1),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=True),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
) -> ApiResponse[ProductProcessTemplateListResult]:
    total, rows = list_templates(
        db,
        page=page,
        page_size=page_size,
        product_id=product_id,
        keyword=keyword,
        enabled=enabled,
    )
    return success_response(ProductProcessTemplateListResult(total=total, items=[_to_template_item(row) for row in rows]))


@router.post("/templates", response_model=ApiResponse[ProductProcessTemplateDetail], status_code=status.HTTP_201_CREATED)
def create_template_api(
    payload: ProductProcessTemplateCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
) -> ApiResponse[ProductProcessTemplateDetail]:
    try:
        row = create_template(
            db,
            product_id=payload.product_id,
            template_name=payload.template_name,
            is_default=payload.is_default,
            steps=[item.model_dump() for item in payload.steps],
            operator=current_user,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(_to_template_detail(row), message="created")


@router.get("/templates/{template_id}", response_model=ApiResponse[ProductProcessTemplateDetail])
def get_template_detail_api(
    template_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
) -> ApiResponse[ProductProcessTemplateDetail]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    return success_response(_to_template_detail(row))


@router.put("/templates/{template_id}", response_model=ApiResponse[ProductProcessTemplateUpdateResult])
def update_template_api(
    template_id: int,
    payload: ProductProcessTemplateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
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
    _: User = Depends(require_role_codes(WRITE_ROLE_CODES)),
) -> ApiResponse[dict[str, bool]]:
    row = get_template_by_id(db, template_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    try:
        delete_template(db, template=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")
