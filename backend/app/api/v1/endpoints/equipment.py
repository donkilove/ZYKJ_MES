from datetime import date as date_type

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_role_codes
from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.db.session import get_db
from app.models.equipment import Equipment
from app.models.maintenance_item import MaintenanceItem
from app.models.maintenance_plan import MaintenancePlan
from app.models.maintenance_work_order import MaintenanceWorkOrder
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.equipment import (
    EquipmentLedgerItem,
    EquipmentLedgerListResult,
    EquipmentLedgerUpsertRequest,
    MaintenanceItemEntry,
    MaintenanceItemListResult,
    MaintenanceItemUpsertRequest,
    MaintenancePlanGenerateResult,
    MaintenancePlanItem,
    MaintenancePlanListResult,
    MaintenancePlanToggleRequest,
    MaintenancePlanUpsertRequest,
    MaintenanceWorkOrderCompleteRequest,
    MaintenanceWorkOrderItem,
    MaintenanceWorkOrderListResult,
)
from app.services.equipment_service import (
    complete_work_order,
    create_equipment,
    create_maintenance_item,
    create_maintenance_plan,
    disable_equipment,
    disable_maintenance_item,
    generate_work_order_for_plan,
    get_equipment_by_id,
    get_maintenance_item_by_id,
    get_maintenance_plan_by_id,
    get_work_order_by_id,
    list_equipment,
    list_maintenance_items,
    list_maintenance_plans,
    list_work_orders,
    start_work_order,
    toggle_maintenance_plan,
    update_equipment,
    update_maintenance_item,
    update_maintenance_plan,
)


router = APIRouter()

EQUIPMENT_READ_ROLE_CODES = [ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN]
EQUIPMENT_WRITE_ROLE_CODES = [ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN]
EXECUTION_READ_ROLE_CODES = [ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR]
EXECUTION_WRITE_ROLE_CODES = [ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR]
RECORD_READ_ROLE_CODES = [
    ROLE_SYSTEM_ADMIN,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_OPERATOR,
]


def to_equipment_item(row: Equipment) -> EquipmentLedgerItem:
    return EquipmentLedgerItem(
        id=row.id,
        name=row.name,
        model=row.model,
        location=row.location,
        owner_name=row.owner_name,
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
        is_enabled=row.is_enabled,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_maintenance_plan_item(row: MaintenancePlan) -> MaintenancePlanItem:
    return MaintenancePlanItem(
        id=row.id,
        equipment_id=row.equipment_id,
        equipment_name=row.equipment.name if row.equipment else "-",
        item_id=row.item_id,
        item_name=row.item.name if row.item else "-",
        cycle_days=row.cycle_days,
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
        equipment_name=row.equipment.name if row.equipment else "-",
        item_id=row.item_id,
        item_name=row.item.name if row.item else "-",
        due_date=row.due_date,
        status=row.status,  # type: ignore[arg-type]
        executor_user_id=row.executor_user_id,
        executor_username=row.executor.username if row.executor else None,
        started_at=row.started_at,
        completed_at=row.completed_at,
        result_summary=row.result_summary,
        result_remark=row.result_remark,
        attachment_link=row.attachment_link,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.get("/ledger", response_model=ApiResponse[EquipmentLedgerListResult])
def get_equipment_ledger(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_READ_ROLE_CODES)),
) -> ApiResponse[EquipmentLedgerListResult]:
    total, rows = list_equipment(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        enabled=enabled,
    )
    return success_response(
        EquipmentLedgerListResult(total=total, items=[to_equipment_item(row) for row in rows])
    )


@router.post(
    "/ledger",
    response_model=ApiResponse[EquipmentLedgerItem],
    status_code=status.HTTP_201_CREATED,
)
def create_equipment_ledger(
    payload: EquipmentLedgerUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[EquipmentLedgerItem]:
    try:
        row = create_equipment(
            db,
            name=payload.name,
            model=payload.model,
            location=payload.location,
            owner_name=payload.owner_name,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(to_equipment_item(row), message="created")


@router.put("/ledger/{equipment_id}", response_model=ApiResponse[EquipmentLedgerItem])
def update_equipment_ledger(
    equipment_id: int,
    payload: EquipmentLedgerUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[EquipmentLedgerItem]:
    row = get_equipment_by_id(db, equipment_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found")

    try:
        updated = update_equipment(
            db,
            row=row,
            name=payload.name,
            model=payload.model,
            location=payload.location,
            owner_name=payload.owner_name,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(to_equipment_item(updated), message="updated")


@router.post("/ledger/{equipment_id}/disable", response_model=ApiResponse[EquipmentLedgerItem])
def disable_equipment_ledger(
    equipment_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[EquipmentLedgerItem]:
    row = get_equipment_by_id(db, equipment_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found")
    updated = disable_equipment(db, row=row)
    return success_response(to_equipment_item(updated), message="disabled")


@router.get("/items", response_model=ApiResponse[MaintenanceItemListResult])
def get_maintenance_items(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_READ_ROLE_CODES)),
) -> ApiResponse[MaintenanceItemListResult]:
    total, rows = list_maintenance_items(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        enabled=enabled,
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
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenanceItemEntry]:
    try:
        row = create_maintenance_item(
            db,
            name=payload.name,
            category=payload.category,
            default_cycle_days=payload.default_cycle_days,
            default_duration_minutes=payload.default_duration_minutes,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_maintenance_item(row), message="created")


@router.put("/items/{item_id}", response_model=ApiResponse[MaintenanceItemEntry])
def update_maintenance_item_api(
    item_id: int,
    payload: MaintenanceItemUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenanceItemEntry]:
    row = get_maintenance_item_by_id(db, item_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance item not found")

    try:
        updated = update_maintenance_item(
            db,
            row=row,
            name=payload.name,
            category=payload.category,
            default_cycle_days=payload.default_cycle_days,
            default_duration_minutes=payload.default_duration_minutes,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(to_maintenance_item(updated), message="updated")


@router.post("/items/{item_id}/disable", response_model=ApiResponse[MaintenanceItemEntry])
def disable_maintenance_item_api(
    item_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenanceItemEntry]:
    row = get_maintenance_item_by_id(db, item_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance item not found")
    updated = disable_maintenance_item(db, row=row)
    return success_response(to_maintenance_item(updated), message="disabled")


@router.get("/plans", response_model=ApiResponse[MaintenancePlanListResult])
def get_maintenance_plans(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    equipment_id: int | None = Query(default=None, ge=1),
    item_id: int | None = Query(default=None, ge=1),
    enabled: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_READ_ROLE_CODES)),
) -> ApiResponse[MaintenancePlanListResult]:
    total, rows = list_maintenance_plans(
        db,
        page=page,
        page_size=page_size,
        equipment_id=equipment_id,
        item_id=item_id,
        enabled=enabled,
    )
    return success_response(
        MaintenancePlanListResult(
            total=total,
            items=[to_maintenance_plan_item(row) for row in rows],
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
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenancePlanItem]:
    try:
        row = create_maintenance_plan(
            db,
            equipment_id=payload.equipment_id,
            item_id=payload.item_id,
            cycle_days=payload.cycle_days,
            estimated_duration_minutes=payload.estimated_duration_minutes,
            start_date=payload.start_date,
            next_due_date=payload.next_due_date,
            default_executor_user_id=payload.default_executor_user_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_maintenance_plan_item(row), message="created")


@router.put("/plans/{plan_id}", response_model=ApiResponse[MaintenancePlanItem])
def update_maintenance_plan_api(
    plan_id: int,
    payload: MaintenancePlanUpsertRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenancePlanItem]:
    row = get_maintenance_plan_by_id(db, plan_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance plan not found")
    try:
        updated = update_maintenance_plan(
            db,
            row=row,
            equipment_id=payload.equipment_id,
            item_id=payload.item_id,
            cycle_days=payload.cycle_days,
            estimated_duration_minutes=payload.estimated_duration_minutes,
            start_date=payload.start_date,
            next_due_date=payload.next_due_date,
            default_executor_user_id=payload.default_executor_user_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_maintenance_plan_item(updated), message="updated")


@router.post("/plans/{plan_id}/toggle", response_model=ApiResponse[MaintenancePlanItem])
def toggle_maintenance_plan_api(
    plan_id: int,
    payload: MaintenancePlanToggleRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenancePlanItem]:
    row = get_maintenance_plan_by_id(db, plan_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance plan not found")
    updated = toggle_maintenance_plan(db, row=row, enabled=payload.enabled)
    return success_response(to_maintenance_plan_item(updated), message="updated")


@router.post("/plans/{plan_id}/generate", response_model=ApiResponse[MaintenancePlanGenerateResult])
def generate_plan_work_order_api(
    plan_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes(EQUIPMENT_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenancePlanGenerateResult]:
    row = get_maintenance_plan_by_id(db, plan_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Maintenance plan not found")
    try:
        work_order, created = generate_work_order_for_plan(db, row=row)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    refreshed_plan = get_maintenance_plan_by_id(db, plan_id)
    next_due_date = refreshed_plan.next_due_date if refreshed_plan else row.next_due_date
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
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes(EXECUTION_READ_ROLE_CODES)),
) -> ApiResponse[MaintenanceWorkOrderListResult]:
    try:
        total, rows = list_work_orders(
            db,
            page=page,
            page_size=page_size,
            status=status_filter,
            keyword=keyword,
            mine=mine,
            current_user_id=current_user.id,
            done_only=False,
            executor_user_id=None,
            start_date=None,
            end_date=None,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(
        MaintenanceWorkOrderListResult(
            total=total,
            items=[to_work_order_item(row) for row in rows],
        )
    )


@router.post("/executions/{work_order_id}/start", response_model=ApiResponse[MaintenanceWorkOrderItem])
def start_maintenance_execution(
    work_order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes(EXECUTION_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenanceWorkOrderItem]:
    row = get_work_order_by_id(db, work_order_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Work order not found")
    try:
        updated = start_work_order(db, row=row, operator=current_user)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_work_order_item(updated), message="started")


@router.post(
    "/executions/{work_order_id}/complete",
    response_model=ApiResponse[MaintenanceWorkOrderItem],
)
def complete_maintenance_execution(
    work_order_id: int,
    payload: MaintenanceWorkOrderCompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes(EXECUTION_WRITE_ROLE_CODES)),
) -> ApiResponse[MaintenanceWorkOrderItem]:
    row = get_work_order_by_id(db, work_order_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Work order not found")
    try:
        updated = complete_work_order(
            db,
            row=row,
            operator=current_user,
            result_summary=payload.result_summary,
            result_remark=payload.result_remark,
            attachment_link=payload.attachment_link,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))
    return success_response(to_work_order_item(updated), message="completed")


@router.get("/records", response_model=ApiResponse[MaintenanceWorkOrderListResult])
def get_maintenance_records(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    executor_id: int | None = Query(default=None, ge=1),
    start_date: date_type | None = Query(default=None),
    end_date: date_type | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes(RECORD_READ_ROLE_CODES)),
) -> ApiResponse[MaintenanceWorkOrderListResult]:
    if (
        start_date is not None
        and end_date is not None
        and start_date > end_date
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date cannot be greater than end_date",
        )

    try:
        total, rows = list_work_orders(
            db,
            page=page,
            page_size=page_size,
            status=None,
            keyword=keyword,
            mine=False,
            current_user_id=current_user.id,
            done_only=True,
            executor_user_id=executor_id,
            start_date=start_date,
            end_date=end_date,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    return success_response(
        MaintenanceWorkOrderListResult(
            total=total,
            items=[to_work_order_item(row) for row in rows],
        )
    )
