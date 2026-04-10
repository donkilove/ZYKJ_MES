from datetime import date as date_type

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_any_permission, require_permission
from app.db.session import get_db
from app.models.equipment import Equipment
from app.models.equipment_rule import EquipmentRule
from app.models.equipment_runtime_parameter import EquipmentRuntimeParameter
from app.models.maintenance_item import MaintenanceItem
from app.models.maintenance_plan import MaintenancePlan
from app.models.maintenance_record import MaintenanceRecord
from app.models.maintenance_work_order import MaintenanceWorkOrder
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.services.audit_service import write_audit_log
from app.schemas.equipment import (
    EquipmentDetailResult,
    EquipmentExportResult,
    EquipmentLedgerItem,
    EquipmentLedgerListResult,
    EquipmentLedgerUpsertRequest,
    EquipmentOwnerOption,
    EquipmentOwnerOptionListResult,
    MaintenanceItemEntry,
    MaintenanceItemListResult,
    MaintenanceItemUpsertRequest,
    MaintenancePlanGenerateResult,
    MaintenancePlanItem,
    MaintenancePlanListResult,
    MaintenanceRecordDetail,
    MaintenanceRecordItem,
    MaintenanceRecordListResult,
    MaintenancePlanToggleRequest,
    MaintenancePlanUpsertRequest,
    MaintenanceWorkOrderCompleteRequest,
    MaintenanceWorkOrderDetail,
    MaintenanceWorkOrderItem,
    MaintenanceWorkOrderListResult,
    ToggleEnabledRequest,
)
from app.schemas.equipment_rule import (
    EquipmentRuleItem,
    EquipmentRuleListResult,
    EquipmentRuleUpsertRequest,
    EquipmentRuntimeParameterItem,
    EquipmentRuntimeParameterListResult,
    EquipmentRuntimeParameterUpsertRequest,
)
from app.services.equipment_service import (
    cancel_work_order,
    complete_work_order,
    create_equipment,
    create_maintenance_item,
    create_maintenance_plan,
    derive_attachment_name,
    delete_equipment,
    delete_maintenance_item,
    delete_maintenance_plan,
    export_equipment_ledger_csv,
    export_maintenance_items_csv,
    export_maintenance_plans_csv,
    export_maintenance_records_csv,
    export_work_orders_csv,
    ensure_maintenance_record_view_permission,
    ensure_work_order_view_permission,
    generate_work_order_for_plan,
    get_equipment_by_id,
    get_equipment_detail,
    get_maintenance_item_by_id,
    get_maintenance_plan_by_id,
    get_maintenance_record_by_id,
    get_work_order_by_id,
    list_active_owners,
    list_active_system_admin_owners,
    list_equipment,
    list_maintenance_items,
    list_maintenance_plans,
    list_maintenance_records,
    list_work_orders,
    start_work_order,
    toggle_equipment,
    toggle_maintenance_item,
    toggle_maintenance_plan,
    update_equipment,
    update_maintenance_item,
    update_maintenance_plan,
)
from app.services.equipment_rule_service import (
    create_equipment_rule,
    create_runtime_parameter,
    delete_equipment_rule,
    delete_runtime_parameter,
    list_equipment_rules,
    list_runtime_parameters,
    toggle_runtime_parameter,
    toggle_equipment_rule,
    update_equipment_rule,
    update_runtime_parameter,
)
from app.services.craft_service import get_stage_by_code, resolve_user_stage_codes
from app.services.authz_service import has_permission


router = APIRouter()


def _current_user_role_codes(current_user: User) -> list[str]:
    return [role.code for role in current_user.roles]


def _current_user_stage_codes(db: Session, current_user: User) -> list[str]:
    return sorted(
        resolve_user_stage_codes(
            db,
            process_codes=[process.code for process in current_user.processes],
        )
    )


def _raise_visibility_error(error: ValueError) -> None:
    detail = str(error)
    error_status = (
        status.HTTP_403_FORBIDDEN
        if detail == "Access denied"
        else status.HTTP_400_BAD_REQUEST
    )
    raise HTTPException(status_code=error_status, detail=detail)


def to_equipment_item(row: Equipment) -> EquipmentLedgerItem:
    return EquipmentLedgerItem(
        id=row.id,
        code=row.code,
        name=row.name,
        model=row.model,
        location=row.location,
        owner_name=row.owner_name,
        remark=row.remark,
        is_enabled=row.is_enabled,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_maintenance_item(row: MaintenanceItem) -> MaintenanceItemEntry:
    return MaintenanceItemEntry(
        id=row.id,
        name=row.name,
        category=row.category,
        default_cycle_days=row.default_cycle_days,
        default_duration_minutes=row.default_duration_minutes,
        standard_description=row.standard_description,
        is_enabled=row.is_enabled,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_maintenance_plan_item(db: Session, row: MaintenancePlan) -> MaintenancePlanItem:
    stage = get_stage_by_code(db, row.execution_process_code)
    execution_process_name = stage.name if stage else row.execution_process_code
    return MaintenancePlanItem(
        id=row.id,
        equipment_id=row.equipment_id,
        equipment_name=row.equipment.name if row.equipment else "-",
        item_id=row.item_id,
        item_name=row.item.name if row.item else "-",
        cycle_days=row.cycle_days,
        execution_process_code=row.execution_process_code,
        execution_process_name=execution_process_name,
        estimated_duration_minutes=row.estimated_duration_minutes,
        start_date=row.start_date,
        next_due_date=row.next_due_date,
        default_executor_user_id=row.default_executor_user_id,
        default_executor_username=(
            row.default_executor.username if row.default_executor else None
        ),
        is_enabled=row.is_enabled,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_work_order_item(row: MaintenanceWorkOrder) -> MaintenanceWorkOrderItem:
    return MaintenanceWorkOrderItem(
        id=row.id,
        plan_id=row.plan_id,
        equipment_id=row.equipment_id,
        equipment_name=row.source_equipment_name
        or (row.equipment.name if row.equipment else "-"),
        source_equipment_code=row.source_equipment_code or None,
        item_id=row.item_id,
        item_name=row.source_item_name or (row.item.name if row.item else "-"),
        source_item_name=row.source_item_name or None,
        source_execution_process_code=row.source_execution_process_code or None,
        due_date=row.due_date,
        status=row.status,  # type: ignore[arg-type]
        executor_user_id=row.executor_user_id,
        executor_username=row.executor.username if row.executor else None,
        started_at=row.started_at,
        completed_at=row.completed_at,
        result_summary=row.result_summary,
        result_remark=row.result_remark,
        attachment_link=row.attachment_link,
        attachment_name=derive_attachment_name(row.attachment_link),
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_maintenance_record_item(row: MaintenanceRecord) -> MaintenanceRecordItem:
    return MaintenanceRecordItem(
        id=row.id,
        work_order_id=row.work_order_id,
        equipment_name=row.source_equipment_name or "-",
        item_name=row.source_item_name or "-",
        due_date=row.due_date,
        executor_user_id=row.executor_user_id,
        executor_username=row.executor_username or None,
        completed_at=row.completed_at,
        result_summary=row.result_summary,
        result_remark=row.result_remark,
        attachment_link=row.attachment_link,
        attachment_name=derive_attachment_name(row.attachment_link),
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _build_source_plan_summary(
    *,
    source_plan_id: int | None,
    source_plan_cycle_days: int | None,
    source_plan_start_date: date_type | None,
) -> str | None:
    parts: list[str] = []
    if source_plan_id is not None:
        parts.append(f"计划#{source_plan_id}")
    if source_plan_cycle_days is not None:
        parts.append(f"周期{source_plan_cycle_days}天")
    if source_plan_start_date is not None:
        parts.append(f"起始{source_plan_start_date.isoformat()}")
    if not parts:
        return None
    return " / ".join(parts)


def _build_work_order_detail(
    db: Session,
    row: MaintenanceWorkOrder,
) -> MaintenanceWorkOrderDetail:
    base = to_work_order_item(row)
    record_row = (
        db.execute(
            select(MaintenanceRecord.id)
            .where(MaintenanceRecord.work_order_id == row.id)
            .limit(1)
        )
        .scalars()
        .first()
    )
    return MaintenanceWorkOrderDetail(
        **base.model_dump(),
        source_plan_id=row.source_plan_id,
        source_plan_cycle_days=row.source_plan_cycle_days,
        source_plan_start_date=row.source_plan_start_date,
        source_plan_summary=_build_source_plan_summary(
            source_plan_id=row.source_plan_id,
            source_plan_cycle_days=row.source_plan_cycle_days,
            source_plan_start_date=row.source_plan_start_date,
        ),
        source_equipment_name=row.source_equipment_name or None,
        source_item_id=row.source_item_id,
        record_id=record_row,
    )


def _build_record_detail(
    db: Session, row: MaintenanceRecord
) -> MaintenanceRecordDetail:
    base = to_maintenance_record_item(row)
    source_plan_id = row.source_plan_id
    source_plan_cycle_days = row.source_plan_cycle_days
    source_plan_start_date = row.source_plan_start_date
    source_equipment_name = row.source_equipment_name or None
    source_execution_process_code = row.source_execution_process_code or None
    needs_work_order_lookup = any(
        value in (None, "")
        for value in (
            source_plan_id,
            source_plan_cycle_days,
            source_plan_start_date,
            source_equipment_name,
            source_execution_process_code,
        )
    )
    source_work_order = (
        get_work_order_by_id(db, row.work_order_id) if needs_work_order_lookup else None
    )
    if source_work_order is not None:
        if source_plan_id is None:
            source_plan_id = source_work_order.source_plan_id
        if source_plan_cycle_days is None:
            source_plan_cycle_days = source_work_order.source_plan_cycle_days
        if source_plan_start_date is None:
            source_plan_start_date = source_work_order.source_plan_start_date
        if source_equipment_name is None:
            source_equipment_name = source_work_order.source_equipment_name or None
        source_execution_process_code = source_execution_process_code or (
            source_work_order.source_execution_process_code or None
        )
    return MaintenanceRecordDetail(
        **base.model_dump(),
        source_plan_id=source_plan_id,
        source_plan_cycle_days=source_plan_cycle_days,
        source_plan_start_date=source_plan_start_date,
        source_plan_summary=_build_source_plan_summary(
            source_plan_id=source_plan_id,
            source_plan_cycle_days=source_plan_cycle_days,
            source_plan_start_date=source_plan_start_date,
        ),
        source_equipment_code=row.source_equipment_code or None,
        source_equipment_name=source_equipment_name,
        source_execution_process_code=source_execution_process_code,
        source_item_id=row.source_item_id,
        source_item_name=row.source_item_name or None,
    )


@router.get("/admin-owners", response_model=ApiResponse[EquipmentOwnerOptionListResult])
def get_admin_owners(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.admin_owners.list")),
) -> ApiResponse[EquipmentOwnerOptionListResult]:
    users = list_active_system_admin_owners(db)
    return success_response(
        EquipmentOwnerOptionListResult(
            total=len(users),
            items=[
                EquipmentOwnerOption(
                    id=user.id, username=user.username, full_name=user.full_name
                )
                for user in users
            ],
        )
    )


@router.get("/ledger", response_model=ApiResponse[EquipmentLedgerListResult])
def get_equipment_ledger(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    location_keyword: str | None = Query(default=None),
    owner_name: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.ledger.list")),
) -> ApiResponse[EquipmentLedgerListResult]:
    total, rows = list_equipment(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        enabled=enabled,
        location_keyword=location_keyword,
        owner_name=owner_name,
    )
    return success_response(
        EquipmentLedgerListResult(
            total=total, items=[to_equipment_item(row) for row in rows]
        )
    )


@router.post(
    "/ledger",
    response_model=ApiResponse[EquipmentLedgerItem],
    status_code=status.HTTP_201_CREATED,
)
def create_equipment_ledger(
    payload: EquipmentLedgerUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.ledger.create")),
) -> ApiResponse[EquipmentLedgerItem]:
    try:
        row = create_equipment(
            db,
            code=payload.code,
            name=payload.name,
            model=payload.model,
            location=payload.location,
            owner_name=payload.owner_name,
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    write_audit_log(
        db,
        action_code="equipment.ledger.create",
        action_name="新增设备台账",
        target_type="equipment",
        target_id=str(row.id),
        target_name=row.name,
        operator=current_user,
        after_data={"code": row.code, "name": row.name, "model": row.model},
    )
    db.commit()
    return success_response(to_equipment_item(row), message="created")


@router.put("/ledger/{equipment_id}", response_model=ApiResponse[EquipmentLedgerItem])
def update_equipment_ledger(
    equipment_id: int,
    payload: EquipmentLedgerUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.ledger.update")),
) -> ApiResponse[EquipmentLedgerItem]:
    row = get_equipment_by_id(db, equipment_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found"
        )

    try:
        updated = update_equipment(
            db,
            row=row,
            code=payload.code,
            name=payload.name,
            model=payload.model,
            location=payload.location,
            owner_name=payload.owner_name,
            remark=payload.remark,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(to_equipment_item(updated), message="updated")


@router.post(
    "/ledger/{equipment_id}/toggle", response_model=ApiResponse[EquipmentLedgerItem]
)
def toggle_equipment_ledger(
    equipment_id: int,
    payload: ToggleEnabledRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.ledger.toggle")),
) -> ApiResponse[EquipmentLedgerItem]:
    row = get_equipment_by_id(db, equipment_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found"
        )
    updated = toggle_equipment(db, row=row, enabled=payload.enabled)
    return success_response(to_equipment_item(updated), message="updated")


@router.post(
    "/ledger/{equipment_id}/disable", response_model=ApiResponse[EquipmentLedgerItem]
)
def disable_equipment_ledger(
    equipment_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.ledger.toggle")),
) -> ApiResponse[EquipmentLedgerItem]:
    row = get_equipment_by_id(db, equipment_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found"
        )
    updated = toggle_equipment(db, row=row, enabled=False)
    return success_response(to_equipment_item(updated), message="disabled")


@router.delete("/ledger/{equipment_id}", response_model=ApiResponse[dict[str, bool]])
def delete_equipment_ledger(
    equipment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.ledger.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = get_equipment_by_id(db, equipment_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found"
        )
    _name = row.name
    _code = row.code
    try:
        delete_equipment(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="equipment.ledger.delete",
        action_name="删除设备台账",
        target_type="equipment",
        target_id=str(equipment_id),
        target_name=_name,
        operator=current_user,
        after_data={"code": _code, "name": _name},
    )
    db.commit()
    return success_response({"deleted": True}, message="deleted")


@router.get("/items", response_model=ApiResponse[MaintenanceItemListResult])
def get_maintenance_items(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    category: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.items.list")),
) -> ApiResponse[MaintenanceItemListResult]:
    total, rows = list_maintenance_items(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        enabled=enabled,
        category=category,
    )
    return success_response(
        MaintenanceItemListResult(
            total=total,
            items=[to_maintenance_item(row) for row in rows],
        )
    )


@router.post(
    "/items",
    response_model=ApiResponse[MaintenanceItemEntry],
    status_code=status.HTTP_201_CREATED,
)
def create_maintenance_item_api(
    payload: MaintenanceItemUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.items.create")),
) -> ApiResponse[MaintenanceItemEntry]:
    try:
        row = create_maintenance_item(
            db,
            name=payload.name,
            default_cycle_days=payload.default_cycle_days,
            category=payload.category,
            default_duration_minutes=payload.default_duration_minutes,
            standard_description=payload.standard_description,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_maintenance_item(row), message="created")


@router.put("/items/{item_id}", response_model=ApiResponse[MaintenanceItemEntry])
def update_maintenance_item_api(
    item_id: int,
    payload: MaintenanceItemUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.items.update")),
) -> ApiResponse[MaintenanceItemEntry]:
    row = get_maintenance_item_by_id(db, item_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance item not found"
        )

    try:
        updated = update_maintenance_item(
            db,
            row=row,
            name=payload.name,
            default_cycle_days=payload.default_cycle_days,
            category=payload.category,
            default_duration_minutes=payload.default_duration_minutes,
            standard_description=payload.standard_description,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(to_maintenance_item(updated), message="updated")


@router.post(
    "/items/{item_id}/toggle", response_model=ApiResponse[MaintenanceItemEntry]
)
def toggle_maintenance_item_api(
    item_id: int,
    payload: ToggleEnabledRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.items.toggle")),
) -> ApiResponse[MaintenanceItemEntry]:
    row = get_maintenance_item_by_id(db, item_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance item not found"
        )
    updated = toggle_maintenance_item(db, row=row, enabled=payload.enabled)
    return success_response(to_maintenance_item(updated), message="updated")


@router.post(
    "/items/{item_id}/disable", response_model=ApiResponse[MaintenanceItemEntry]
)
def disable_maintenance_item_api(
    item_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.items.toggle")),
) -> ApiResponse[MaintenanceItemEntry]:
    row = get_maintenance_item_by_id(db, item_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance item not found"
        )
    updated = toggle_maintenance_item(db, row=row, enabled=False)
    return success_response(to_maintenance_item(updated), message="disabled")


@router.delete("/items/{item_id}", response_model=ApiResponse[dict[str, bool]])
def delete_maintenance_item_api(
    item_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.items.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = get_maintenance_item_by_id(db, item_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance item not found"
        )
    try:
        delete_maintenance_item(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.get("/plans", response_model=ApiResponse[MaintenancePlanListResult])
def get_maintenance_plans(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    equipment_id: int | None = Query(default=None, ge=1),
    item_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=None),
    execution_process_code: str | None = Query(default=None),
    default_executor_user_id: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.plans.list")),
) -> ApiResponse[MaintenancePlanListResult]:
    total, rows = list_maintenance_plans(
        db,
        page=page,
        page_size=page_size,
        equipment_id=equipment_id,
        item_id=item_id,
        enabled=enabled,
        execution_process_code=execution_process_code,
        default_executor_user_id=default_executor_user_id,
    )
    return success_response(
        MaintenancePlanListResult(
            total=total,
            items=[to_maintenance_plan_item(db, row) for row in rows],
        )
    )


@router.post(
    "/plans",
    response_model=ApiResponse[MaintenancePlanItem],
    status_code=status.HTTP_201_CREATED,
)
def create_maintenance_plan_api(
    payload: MaintenancePlanUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.plans.create")),
) -> ApiResponse[MaintenancePlanItem]:
    try:
        row = create_maintenance_plan(
            db,
            equipment_id=payload.equipment_id,
            item_id=payload.item_id,
            cycle_days=payload.cycle_days,
            execution_process_code=payload.execution_process_code,
            estimated_duration_minutes=payload.estimated_duration_minutes,
            start_date=payload.start_date,
            next_due_date=payload.next_due_date,
            default_executor_user_id=payload.default_executor_user_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_maintenance_plan_item(db, row), message="created")


@router.put("/plans/{plan_id}", response_model=ApiResponse[MaintenancePlanItem])
def update_maintenance_plan_api(
    plan_id: int,
    payload: MaintenancePlanUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.plans.update")),
) -> ApiResponse[MaintenancePlanItem]:
    row = get_maintenance_plan_by_id(db, plan_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance plan not found"
        )
    try:
        updated = update_maintenance_plan(
            db,
            row=row,
            equipment_id=payload.equipment_id,
            item_id=payload.item_id,
            cycle_days=payload.cycle_days,
            execution_process_code=payload.execution_process_code,
            estimated_duration_minutes=payload.estimated_duration_minutes,
            start_date=payload.start_date,
            next_due_date=payload.next_due_date,
            default_executor_user_id=payload.default_executor_user_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_maintenance_plan_item(db, updated), message="updated")


@router.post("/plans/{plan_id}/toggle", response_model=ApiResponse[MaintenancePlanItem])
def toggle_maintenance_plan_api(
    plan_id: int,
    payload: MaintenancePlanToggleRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.plans.toggle")),
) -> ApiResponse[MaintenancePlanItem]:
    row = get_maintenance_plan_by_id(db, plan_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance plan not found"
        )
    updated = toggle_maintenance_plan(db, row=row, enabled=payload.enabled)
    return success_response(to_maintenance_plan_item(db, updated), message="updated")


@router.delete("/plans/{plan_id}", response_model=ApiResponse[dict[str, bool]])
def delete_maintenance_plan_api(
    plan_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.plans.delete")),
) -> ApiResponse[dict[str, bool]]:
    row = get_maintenance_plan_by_id(db, plan_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance plan not found"
        )
    try:
        delete_maintenance_plan(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response({"deleted": True}, message="deleted")


@router.post(
    "/plans/{plan_id}/generate",
    response_model=ApiResponse[MaintenancePlanGenerateResult],
)
def generate_plan_work_order_api(
    plan_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.plans.generate")),
) -> ApiResponse[MaintenancePlanGenerateResult]:
    row = get_maintenance_plan_by_id(db, plan_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance plan not found"
        )
    try:
        work_order, created = generate_work_order_for_plan(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    refreshed_plan = get_maintenance_plan_by_id(db, plan_id)
    next_due_date = (
        refreshed_plan.next_due_date if refreshed_plan else row.next_due_date
    )
    return success_response(
        MaintenancePlanGenerateResult(
            created=created,
            work_order_id=work_order.id,
            due_date=work_order.due_date,
            next_due_date=next_due_date,
        ),
        message="generated" if created else "exists",
    )


@router.get("/executions", response_model=ApiResponse[MaintenanceWorkOrderListResult])
def get_maintenance_executions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    status_filter: str | None = Query(default=None, alias="status"),
    keyword: str | None = Query(default=None),
    mine: bool = Query(default=False),
    mine_only: bool = Query(default=False),
    due_date_start: date_type | None = Query(default=None),
    due_date_end: date_type | None = Query(default=None),
    stage_code: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.executions.list")),
) -> ApiResponse[MaintenanceWorkOrderListResult]:
    try:
        total, rows = list_work_orders(
            db,
            page=page,
            page_size=page_size,
            status=status_filter,
            keyword=keyword,
            mine=mine or mine_only,
            current_user_id=current_user.id,
            current_user_role_codes=[role.code for role in current_user.roles],
            current_user_stage_codes=sorted(
                resolve_user_stage_codes(
                    db,
                    process_codes=[process.code for process in current_user.processes],
                )
            ),
            done_only=False,
            executor_user_id=None,
            start_date=None,
            end_date=None,
            due_date_start=due_date_start,
            due_date_end=due_date_end,
            stage_code_filter=stage_code,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(
        MaintenanceWorkOrderListResult(
            total=total,
            items=[to_work_order_item(row) for row in rows],
        )
    )


@router.post(
    "/executions/{work_order_id}/start",
    response_model=ApiResponse[MaintenanceWorkOrderItem],
)
def start_maintenance_execution(
    work_order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.executions.start")),
) -> ApiResponse[MaintenanceWorkOrderItem]:
    row = get_work_order_by_id(db, work_order_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Work order not found"
        )
    try:
        updated = start_work_order(
            db,
            row=row,
            operator=current_user,
            current_user_role_codes=_current_user_role_codes(current_user),
            current_user_stage_codes=_current_user_stage_codes(db, current_user),
        )
    except ValueError as error:
        _raise_visibility_error(error)
    return success_response(to_work_order_item(updated), message="started")


@router.post(
    "/executions/{work_order_id}/complete",
    response_model=ApiResponse[MaintenanceWorkOrderItem],
)
def complete_maintenance_execution(
    work_order_id: int,
    payload: MaintenanceWorkOrderCompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.executions.complete")),
) -> ApiResponse[MaintenanceWorkOrderItem]:
    row = get_work_order_by_id(db, work_order_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Work order not found"
        )
    try:
        updated = complete_work_order(
            db,
            row=row,
            operator=current_user,
            current_user_role_codes=_current_user_role_codes(current_user),
            current_user_stage_codes=_current_user_stage_codes(db, current_user),
            result_summary=payload.result_summary,
            result_remark=payload.result_remark,
            attachment_link=payload.attachment_link,
        )
    except ValueError as error:
        _raise_visibility_error(error)
    write_audit_log(
        db,
        action_code="equipment.work_order.complete",
        action_name="完成保养工单",
        target_type="maintenance_work_order",
        target_id=str(work_order_id),
        target_name=f"{updated.equipment.name if updated.equipment else ''} / {updated.item.name if updated.item else ''}",
        operator=current_user,
        after_data={
            "result_summary": payload.result_summary,
            "result_remark": payload.result_remark,
        },
    )
    db.commit()
    return success_response(to_work_order_item(updated), message="completed")


@router.get("/records", response_model=ApiResponse[MaintenanceRecordListResult])
def get_maintenance_records(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    executor_id: int | None = Query(default=None, ge=1),
    result_summary: str | None = Query(default=None),
    equipment_id: int | None = Query(default=None, ge=1),
    start_date: date_type | None = Query(default=None),
    end_date: date_type | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.records.list")),
) -> ApiResponse[MaintenanceRecordListResult]:
    if start_date is not None and end_date is not None and start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date cannot be greater than end_date",
        )

    try:
        total, rows = list_maintenance_records(
            db,
            page=page,
            page_size=page_size,
            keyword=keyword,
            executor_user_id=executor_id,
            result_summary=result_summary,
            equipment_id=equipment_id,
            current_user_role_codes=_current_user_role_codes(current_user),
            current_user_stage_codes=_current_user_stage_codes(db, current_user),
            start_date=start_date,
            end_date=end_date,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        MaintenanceRecordListResult(
            total=total,
            items=[to_maintenance_record_item(row) for row in rows],
        )
    )


@router.get("/owners", response_model=ApiResponse[EquipmentOwnerOptionListResult])
def get_all_owners(
    db: Session = Depends(get_db),
    _: User = Depends(
        require_any_permission(
            [
                "equipment.admin_owners.list",
                "equipment.plan_owner_options.list",
                "equipment.record_executor_options.list",
            ]
        )
    ),
) -> ApiResponse[EquipmentOwnerOptionListResult]:
    users = list_active_owners(db)
    return success_response(
        EquipmentOwnerOptionListResult(
            total=len(users),
            items=[
                EquipmentOwnerOption(
                    id=user.id, username=user.username, full_name=user.full_name
                )
                for user in users
            ],
        )
    )


@router.get(
    "/ledger/{equipment_id}/detail", response_model=ApiResponse[EquipmentDetailResult]
)
def get_equipment_detail_api(
    equipment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.ledger.list")),
) -> ApiResponse[EquipmentDetailResult]:
    result = get_equipment_detail(
        db,
        equipment_id,
        current_user_role_codes=_current_user_role_codes(current_user),
        current_user_stage_codes=_current_user_stage_codes(db, current_user),
        can_view_plans=has_permission(
            db, user=current_user, permission_code="equipment.plans.list"
        ),
        can_view_executions=has_permission(
            db, user=current_user, permission_code="equipment.executions.list"
        ),
        can_view_records=has_permission(
            db, user=current_user, permission_code="equipment.records.list"
        ),
    )
    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found"
        )
    (
        row,
        active_plan_count,
        pending_work_order_count,
        active_plans_scope_limited,
        pending_work_orders_scope_limited,
        recent_records_scope_limited,
        active_plans,
        pending_work_orders,
        recent_records,
    ) = result
    return success_response(
        EquipmentDetailResult(
            id=row.id,
            code=row.code,
            name=row.name,
            model=row.model,
            location=row.location,
            owner_name=row.owner_name,
            remark=row.remark,
            is_enabled=row.is_enabled,
            created_at=row.created_at,
            updated_at=row.updated_at,
            active_plan_count=active_plan_count,
            pending_work_order_count=pending_work_order_count,
            active_plans_scope_limited=active_plans_scope_limited,
            pending_work_orders_scope_limited=pending_work_orders_scope_limited,
            recent_records_scope_limited=recent_records_scope_limited,
            active_plans=[to_maintenance_plan_item(db, plan) for plan in active_plans],
            pending_work_orders=[
                to_work_order_item(work_order) for work_order in pending_work_orders
            ],
            recent_records=[to_maintenance_record_item(r) for r in recent_records],
        )
    )


@router.get(
    "/executions/{work_order_id}/detail",
    response_model=ApiResponse[MaintenanceWorkOrderDetail],
)
def get_work_order_detail_api(
    work_order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.executions.list")),
) -> ApiResponse[MaintenanceWorkOrderDetail]:
    row = get_work_order_by_id(db, work_order_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Work order not found"
        )
    try:
        ensure_work_order_view_permission(
            row=row,
            current_user_role_codes=_current_user_role_codes(current_user),
            current_user_stage_codes=_current_user_stage_codes(db, current_user),
        )
    except ValueError as error:
        _raise_visibility_error(error)
    return success_response(_build_work_order_detail(db, row))


@router.post(
    "/executions/{work_order_id}/cancel",
    response_model=ApiResponse[MaintenanceWorkOrderItem],
)
def cancel_maintenance_execution(
    work_order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.executions.cancel")),
) -> ApiResponse[MaintenanceWorkOrderItem]:
    row = get_work_order_by_id(db, work_order_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Work order not found"
        )
    try:
        updated = cancel_work_order(
            db,
            row=row,
            operator=current_user,
            current_user_role_codes=_current_user_role_codes(current_user),
            current_user_stage_codes=_current_user_stage_codes(db, current_user),
        )
    except ValueError as error:
        _raise_visibility_error(error)
    write_audit_log(
        db,
        action_code="equipment.work_order.cancel",
        action_name="取消保养工单",
        target_type="maintenance_work_order",
        target_id=str(work_order_id),
        target_name=f"{updated.equipment.name if updated.equipment else ''} / {updated.item.name if updated.item else ''}",
        operator=current_user,
        after_data={"status": "cancelled"},
    )
    db.commit()
    return success_response(to_work_order_item(updated), message="cancelled")


@router.get(
    "/records/{record_id}/detail", response_model=ApiResponse[MaintenanceRecordDetail]
)
def get_maintenance_record_detail_api(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.records.list")),
) -> ApiResponse[MaintenanceRecordDetail]:
    row = get_maintenance_record_by_id(db, record_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        )
    try:
        ensure_maintenance_record_view_permission(
            db,
            row=row,
            current_user_role_codes=_current_user_role_codes(current_user),
            current_user_stage_codes=_current_user_stage_codes(db, current_user),
        )
    except ValueError as error:
        _raise_visibility_error(error)
    return success_response(_build_record_detail(db, row))


@router.get("/ledger/export", response_model=ApiResponse[EquipmentExportResult])
def export_equipment_ledger_api(
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    location_keyword: str | None = Query(default=None),
    owner_name: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.ledger.list")),
) -> ApiResponse[EquipmentExportResult]:
    result = export_equipment_ledger_csv(
        db,
        keyword=keyword,
        enabled=enabled,
        location_keyword=location_keyword,
        owner_name=owner_name,
    )
    return success_response(EquipmentExportResult(**result))


@router.get("/items/export", response_model=ApiResponse[EquipmentExportResult])
def export_maintenance_items_api(
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    category: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.items.list")),
) -> ApiResponse[EquipmentExportResult]:
    result = export_maintenance_items_csv(
        db, keyword=keyword, enabled=enabled, category=category
    )
    return success_response(EquipmentExportResult(**result))


@router.get("/plans/export", response_model=ApiResponse[EquipmentExportResult])
def export_maintenance_plans_api(
    equipment_id: int | None = Query(default=None, ge=1),
    item_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=None),
    execution_process_code: str | None = Query(default=None),
    default_executor_user_id: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.plans.list")),
) -> ApiResponse[EquipmentExportResult]:
    result = export_maintenance_plans_csv(
        db,
        equipment_id=equipment_id,
        item_id=item_id,
        enabled=enabled,
        execution_process_code=execution_process_code,
        default_executor_user_id=default_executor_user_id,
    )
    return success_response(EquipmentExportResult(**result))


@router.get("/records/export", response_model=ApiResponse[EquipmentExportResult])
def export_maintenance_records_api(
    keyword: str | None = Query(default=None),
    executor_id: int | None = Query(default=None, ge=1),
    result_summary: str | None = Query(default=None),
    equipment_id: int | None = Query(default=None, ge=1),
    start_date: date_type | None = Query(default=None),
    end_date: date_type | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.records.list")),
) -> ApiResponse[EquipmentExportResult]:
    result = export_maintenance_records_csv(
        db,
        keyword=keyword,
        executor_user_id=executor_id,
        result_summary=result_summary,
        equipment_id=equipment_id,
        current_user_role_codes=_current_user_role_codes(current_user),
        current_user_stage_codes=_current_user_stage_codes(db, current_user),
        start_date=start_date,
        end_date=end_date,
    )
    return success_response(EquipmentExportResult(**result))


@router.get("/executions/export", response_model=ApiResponse[EquipmentExportResult])
def export_work_orders_api(
    status_filter: str | None = Query(default=None, alias="status"),
    keyword: str | None = Query(default=None),
    due_date_start: date_type | None = Query(default=None),
    due_date_end: date_type | None = Query(default=None),
    stage_code: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.executions.list")),
) -> ApiResponse[EquipmentExportResult]:
    result = export_work_orders_csv(
        db,
        status=status_filter,
        keyword=keyword,
        due_date_start=due_date_start,
        due_date_end=due_date_end,
        stage_code=stage_code,
        current_user_role_codes=_current_user_role_codes(current_user),
        current_user_stage_codes=_current_user_stage_codes(db, current_user),
    )
    return success_response(EquipmentExportResult(**result))


# ── 设备规则 ──────────────────────────────────────────────────────────────────


@router.get("/rules", response_model=ApiResponse[EquipmentRuleListResult])
def list_equipment_rules_api(
    equipment_id: int | None = Query(default=None),
    keyword: str | None = Query(default=None),
    is_enabled: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.rules.list")),
) -> ApiResponse[EquipmentRuleListResult]:
    result = list_equipment_rules(
        db,
        equipment_id=equipment_id,
        keyword=keyword,
        is_enabled=is_enabled,
        page=page,
        page_size=page_size,
    )
    return success_response(result)


@router.post("/rules", response_model=ApiResponse[EquipmentRuleItem])
def create_equipment_rule_api(
    payload: EquipmentRuleUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.rules.manage")),
) -> ApiResponse[EquipmentRuleItem]:
    from app.schemas.equipment_rule import EquipmentRuleItem as _Item

    try:
        row = create_equipment_rule(db, payload=payload)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="equipment.rules.create",
        action_name="新增设备规则",
        target_type="equipment_rule",
        target_id=str(row.id),
        target_name=row.rule_name,
        operator=current_user,
        after_data={"rule_name": row.rule_name, "rule_type": row.rule_type},
    )
    db.commit()
    db.refresh(row)
    return success_response(_Item.model_validate(row, from_attributes=True))


@router.put("/rules/{rule_id}", response_model=ApiResponse[EquipmentRuleItem])
def update_equipment_rule_api(
    rule_id: int,
    payload: EquipmentRuleUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.rules.manage")),
) -> ApiResponse[EquipmentRuleItem]:
    from app.schemas.equipment_rule import EquipmentRuleItem as _Item

    row = db.get(EquipmentRule, rule_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Rule not found"
        )
    try:
        row = update_equipment_rule(db, row=row, payload=payload)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="equipment.rules.update",
        action_name="编辑设备规则",
        target_type="equipment_rule",
        target_id=str(row.id),
        target_name=row.rule_name,
        operator=current_user,
        after_data={"rule_name": row.rule_name, "rule_type": row.rule_type},
    )
    db.commit()
    db.refresh(row)
    return success_response(_Item.model_validate(row, from_attributes=True))


@router.patch("/rules/{rule_id}/toggle", response_model=ApiResponse[EquipmentRuleItem])
def toggle_equipment_rule_api(
    rule_id: int,
    payload: ToggleEnabledRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.rules.manage")),
) -> ApiResponse[EquipmentRuleItem]:
    from app.schemas.equipment_rule import EquipmentRuleItem as _Item

    row = db.get(EquipmentRule, rule_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Rule not found"
        )
    row = toggle_equipment_rule(db, row=row, enabled=payload.enabled)
    write_audit_log(
        db,
        action_code="equipment.rules.toggle",
        action_name="启停设备规则",
        target_type="equipment_rule",
        target_id=str(row.id),
        target_name=row.rule_name,
        operator=current_user,
        after_data={"is_enabled": row.is_enabled},
    )
    db.commit()
    db.refresh(row)
    return success_response(_Item.model_validate(row, from_attributes=True))


@router.delete("/rules/{rule_id}", response_model=ApiResponse[None])
def delete_equipment_rule_api(
    rule_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("equipment.rules.manage")),
) -> ApiResponse[None]:
    row = db.get(EquipmentRule, rule_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Rule not found"
        )
    name = row.rule_name
    delete_equipment_rule(db, row=row)
    write_audit_log(
        db,
        action_code="equipment.rules.delete",
        action_name="删除设备规则",
        target_type="equipment_rule",
        target_id=str(rule_id),
        target_name=name,
        operator=current_user,
    )
    db.commit()
    return success_response(None, message="deleted")


# ── 运行参数 ──────────────────────────────────────────────────────────────────


@router.get(
    "/runtime-parameters",
    response_model=ApiResponse[EquipmentRuntimeParameterListResult],
)
def list_runtime_parameters_api(
    equipment_id: int | None = Query(default=None),
    equipment_type: str | None = Query(default=None),
    keyword: str | None = Query(default=None),
    is_enabled: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("equipment.runtime_parameters.list")),
) -> ApiResponse[EquipmentRuntimeParameterListResult]:
    result = list_runtime_parameters(
        db,
        equipment_id=equipment_id,
        equipment_type=equipment_type,
        keyword=keyword,
        is_enabled=is_enabled,
        page=page,
        page_size=page_size,
    )
    return success_response(result)


@router.post(
    "/runtime-parameters", response_model=ApiResponse[EquipmentRuntimeParameterItem]
)
def create_runtime_parameter_api(
    payload: EquipmentRuntimeParameterUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("equipment.runtime_parameters.manage")
    ),
) -> ApiResponse[EquipmentRuntimeParameterItem]:
    from app.schemas.equipment_rule import EquipmentRuntimeParameterItem as _Item

    try:
        row = create_runtime_parameter(db, payload=payload)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="equipment.runtime_parameters.create",
        action_name="新增运行参数",
        target_type="equipment_runtime_parameter",
        target_id=str(row.id),
        target_name=row.param_name,
        operator=current_user,
        after_data={"param_code": row.param_code, "param_name": row.param_name},
    )
    db.commit()
    db.refresh(row)
    return success_response(_Item.model_validate(row, from_attributes=True))


@router.put(
    "/runtime-parameters/{param_id}",
    response_model=ApiResponse[EquipmentRuntimeParameterItem],
)
def update_runtime_parameter_api(
    param_id: int,
    payload: EquipmentRuntimeParameterUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("equipment.runtime_parameters.manage")
    ),
) -> ApiResponse[EquipmentRuntimeParameterItem]:
    from app.schemas.equipment_rule import EquipmentRuntimeParameterItem as _Item

    row = db.get(EquipmentRuntimeParameter, param_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Parameter not found"
        )
    try:
        row = update_runtime_parameter(db, row=row, payload=payload)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    write_audit_log(
        db,
        action_code="equipment.runtime_parameters.update",
        action_name="编辑运行参数",
        target_type="equipment_runtime_parameter",
        target_id=str(row.id),
        target_name=row.param_name,
        operator=current_user,
        after_data={"param_code": row.param_code, "param_name": row.param_name},
    )
    db.commit()
    db.refresh(row)
    return success_response(_Item.model_validate(row, from_attributes=True))


@router.delete("/runtime-parameters/{param_id}", response_model=ApiResponse[None])
def delete_runtime_parameter_api(
    param_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("equipment.runtime_parameters.manage")
    ),
) -> ApiResponse[None]:
    row = db.get(EquipmentRuntimeParameter, param_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Parameter not found"
        )
    name = row.param_name
    delete_runtime_parameter(db, row=row)
    write_audit_log(
        db,
        action_code="equipment.runtime_parameters.delete",
        action_name="删除运行参数",
        target_type="equipment_runtime_parameter",
        target_id=str(param_id),
        target_name=name,
        operator=current_user,
    )
    db.commit()
    return success_response(None, message="deleted")


@router.patch(
    "/runtime-parameters/{param_id}/toggle",
    response_model=ApiResponse[EquipmentRuntimeParameterItem],
)
def toggle_runtime_parameter_api(
    param_id: int,
    payload: ToggleEnabledRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission("equipment.runtime_parameters.manage")
    ),
) -> ApiResponse[EquipmentRuntimeParameterItem]:
    from app.schemas.equipment_rule import EquipmentRuntimeParameterItem as _Item

    row = db.get(EquipmentRuntimeParameter, param_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Parameter not found"
        )
    row = toggle_runtime_parameter(db, row=row, enabled=payload.enabled)
    write_audit_log(
        db,
        action_code="equipment.runtime_parameters.toggle",
        action_name="启停运行参数",
        target_type="equipment_runtime_parameter",
        target_id=str(row.id),
        target_name=row.param_name,
        operator=current_user,
        after_data={"is_enabled": row.is_enabled},
    )
    db.commit()
    db.refresh(row)
    return success_response(_Item.model_validate(row, from_attributes=True))
