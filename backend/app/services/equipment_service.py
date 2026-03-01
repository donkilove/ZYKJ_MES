from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.orm import Session, selectinload

from app.core.equipment_process import (
    is_valid_equipment_process_code,
    map_location_to_process_code,
)
from app.core.rbac import (
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.models.equipment import Equipment
from app.models.maintenance_item import MaintenanceItem
from app.models.maintenance_plan import MaintenancePlan
from app.models.maintenance_record import MaintenanceRecord
from app.models.maintenance_work_order import MaintenanceWorkOrder
from app.models.role import Role
from app.models.user import User

WORK_ORDER_STATUS_PENDING = "pending"
WORK_ORDER_STATUS_IN_PROGRESS = "in_progress"
WORK_ORDER_STATUS_DONE = "done"
WORK_ORDER_STATUS_OVERDUE = "overdue"
WORK_ORDER_STATUS_CANCELLED = "cancelled"

WORK_ORDER_STATUS_ACTIVE = {
    WORK_ORDER_STATUS_PENDING,
    WORK_ORDER_STATUS_IN_PROGRESS,
    WORK_ORDER_STATUS_OVERDUE,
}
WORK_ORDER_STATUS_ALL = {
    WORK_ORDER_STATUS_PENDING,
    WORK_ORDER_STATUS_IN_PROGRESS,
    WORK_ORDER_STATUS_DONE,
    WORK_ORDER_STATUS_OVERDUE,
    WORK_ORDER_STATUS_CANCELLED,
}

MAINTENANCE_ITEM_DEFAULT_DURATION_MINUTES = 60
WORK_ORDER_VIEW_ALL_ROLE_CODES = {
    ROLE_SYSTEM_ADMIN,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
}
WORK_ORDER_EXECUTE_ALL_ROLE_CODES = {
    ROLE_SYSTEM_ADMIN,
    ROLE_PRODUCTION_ADMIN,
}


def _normalize_name(name: str, *, field_name: str) -> str:
    normalized = name.strip()
    if not normalized:
        raise ValueError(f"{field_name} is required")
    return normalized


def _normalize_optional_text(value: str | None) -> str:
    if value is None:
        return ""
    return value.strip()


def _normalize_execution_process_code(code: str) -> str:
    normalized = code.strip()
    if not normalized:
        raise ValueError("Execution process is required")
    if not is_valid_equipment_process_code(normalized):
        raise ValueError("Execution process is invalid")
    return normalized


def _resolve_plan_cycle_days(item: MaintenanceItem) -> int:
    if item.default_cycle_days <= 0:
        raise ValueError("Default cycle days must be greater than 0")
    return item.default_cycle_days


def _recalculate_next_due_date(*, start_date: date, cycle_days: int, today: date | None = None) -> date:
    anchor = today or date.today()
    if anchor <= start_date:
        return start_date
    elapsed_days = (anchor - start_date).days
    rounds = (elapsed_days + cycle_days - 1) // cycle_days
    return start_date + timedelta(days=rounds * cycle_days)


def _can_view_all_work_orders(role_codes: set[str]) -> bool:
    return bool(role_codes.intersection(WORK_ORDER_VIEW_ALL_ROLE_CODES))


def _can_execute_all_work_orders(role_codes: set[str]) -> bool:
    return bool(role_codes.intersection(WORK_ORDER_EXECUTE_ALL_ROLE_CODES))


def _ensure_work_order_process_permission(
    *,
    row: MaintenanceWorkOrder,
    current_user_role_codes: set[str],
    current_user_process_codes: set[str],
) -> None:
    if _can_execute_all_work_orders(current_user_role_codes):
        return

    process_code = (row.source_execution_process_code or "").strip()
    if not process_code:
        raise ValueError("Work order process is missing")
    if process_code not in current_user_process_codes:
        raise ValueError("Access denied")


def get_equipment_by_id(db: Session, equipment_id: int) -> Equipment | None:
    stmt = select(Equipment).where(Equipment.id == equipment_id)
    return db.execute(stmt).scalars().first()


def get_equipment_by_name(db: Session, name: str) -> Equipment | None:
    stmt = select(Equipment).where(Equipment.name == name)
    return db.execute(stmt).scalars().first()


def get_equipment_by_code(db: Session, code: str) -> Equipment | None:
    stmt = select(Equipment).where(Equipment.code == code)
    return db.execute(stmt).scalars().first()


def list_equipment(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    enabled: bool | None,
) -> tuple[int, list[Equipment]]:
    stmt = select(Equipment)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                Equipment.code.ilike(like_pattern),
                Equipment.name.ilike(like_pattern),
                Equipment.model.ilike(like_pattern),
                Equipment.location.ilike(like_pattern),
                Equipment.owner_name.ilike(like_pattern),
            )
        )
    if enabled is not None:
        stmt = stmt.where(Equipment.is_enabled.is_(enabled))

    stmt = stmt.order_by(Equipment.id.asc())
    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    rows = db.execute(stmt.offset(offset).limit(page_size)).scalars().all()
    return total, rows


def create_equipment(
    db: Session,
    *,
    code: str,
    name: str,
    model: str,
    location: str,
    owner_name: str,
) -> Equipment:
    normalized_code = _normalize_name(code, field_name="Equipment code")
    if get_equipment_by_code(db, normalized_code):
        raise ValueError("Equipment code already exists")

    normalized_name = _normalize_name(name, field_name="Equipment name")

    row = Equipment(
        code=normalized_code,
        name=normalized_name,
        model=_normalize_optional_text(model),
        location=_normalize_optional_text(location),
        owner_name=_normalize_optional_text(owner_name),
        is_enabled=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def update_equipment(
    db: Session,
    *,
    row: Equipment,
    code: str,
    name: str,
    model: str,
    location: str,
    owner_name: str,
) -> Equipment:
    normalized_code = _normalize_name(code, field_name="Equipment code")
    existing = get_equipment_by_code(db, normalized_code)
    if existing and existing.id != row.id:
        raise ValueError("Equipment code already exists")

    row.code = normalized_code
    row.name = _normalize_name(name, field_name="Equipment name")
    row.model = _normalize_optional_text(model)
    row.location = _normalize_optional_text(location)
    row.owner_name = _normalize_optional_text(owner_name)
    db.commit()
    db.refresh(row)
    return row


def toggle_equipment(db: Session, *, row: Equipment, enabled: bool) -> Equipment:
    row.is_enabled = enabled
    db.commit()
    db.refresh(row)
    return row


def disable_equipment(db: Session, *, row: Equipment) -> Equipment:
    return toggle_equipment(db, row=row, enabled=False)


def delete_equipment(db: Session, *, row: Equipment) -> None:
    has_plan = db.execute(
        select(MaintenancePlan.id).where(MaintenancePlan.equipment_id == row.id).limit(1)
    ).scalars().first()
    if has_plan is not None:
        raise ValueError("Equipment is referenced by maintenance plans")

    unfinished_count = db.execute(
        select(func.count())
        .select_from(MaintenanceWorkOrder)
        .where(
            MaintenanceWorkOrder.equipment_id == row.id,
            MaintenanceWorkOrder.status != WORK_ORDER_STATUS_DONE,
        )
    ).scalar_one()
    if unfinished_count > 0:
        raise ValueError("Equipment has unfinished work orders")

    db.execute(
        update(MaintenanceWorkOrder)
        .where(
            MaintenanceWorkOrder.equipment_id == row.id,
            MaintenanceWorkOrder.status == WORK_ORDER_STATUS_DONE,
        )
        .values(equipment_id=None)
    )

    db.delete(row)
    db.commit()


def list_active_system_admin_owners(db: Session) -> list[User]:
    stmt = (
        select(User)
        .join(User.roles)
        .where(
            Role.code == ROLE_SYSTEM_ADMIN,
            User.is_active.is_(True),
        )
        .order_by(User.username.asc())
    )
    return db.execute(stmt).scalars().unique().all()


def get_maintenance_item_by_id(db: Session, item_id: int) -> MaintenanceItem | None:
    stmt = select(MaintenanceItem).where(MaintenanceItem.id == item_id)
    return db.execute(stmt).scalars().first()


def get_maintenance_item_by_name(db: Session, name: str) -> MaintenanceItem | None:
    stmt = select(MaintenanceItem).where(MaintenanceItem.name == name)
    return db.execute(stmt).scalars().first()


def list_maintenance_items(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    enabled: bool | None,
) -> tuple[int, list[MaintenanceItem]]:
    stmt = select(MaintenanceItem)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(MaintenanceItem.name.ilike(like_pattern))
    if enabled is not None:
        stmt = stmt.where(MaintenanceItem.is_enabled.is_(enabled))

    stmt = stmt.order_by(MaintenanceItem.id.asc())
    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    rows = db.execute(stmt.offset(offset).limit(page_size)).scalars().all()
    return total, rows


def create_maintenance_item(
    db: Session,
    *,
    name: str,
    default_cycle_days: int,
) -> MaintenanceItem:
    normalized_name = _normalize_name(name, field_name="Maintenance item name")
    if get_maintenance_item_by_name(db, normalized_name):
        raise ValueError("Maintenance item name already exists")
    if default_cycle_days <= 0:
        raise ValueError("Default cycle days must be greater than 0")

    row = MaintenanceItem(
        name=normalized_name,
        category="",
        default_cycle_days=default_cycle_days,
        default_duration_minutes=MAINTENANCE_ITEM_DEFAULT_DURATION_MINUTES,
        is_enabled=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def update_maintenance_item(
    db: Session,
    *,
    row: MaintenanceItem,
    name: str,
    default_cycle_days: int,
) -> MaintenanceItem:
    normalized_name = _normalize_name(name, field_name="Maintenance item name")
    existing = get_maintenance_item_by_name(db, normalized_name)
    if existing and existing.id != row.id:
        raise ValueError("Maintenance item name already exists")
    if default_cycle_days <= 0:
        raise ValueError("Default cycle days must be greater than 0")

    cycle_changed = row.default_cycle_days != default_cycle_days
    row.name = normalized_name
    row.category = ""
    row.default_cycle_days = default_cycle_days
    if row.default_duration_minutes <= 0:
        row.default_duration_minutes = MAINTENANCE_ITEM_DEFAULT_DURATION_MINUTES

    if cycle_changed:
        plans = db.execute(
            select(MaintenancePlan).where(MaintenancePlan.item_id == row.id)
        ).scalars().all()
        for plan in plans:
            plan.cycle_days = default_cycle_days
            plan.next_due_date = _recalculate_next_due_date(
                start_date=plan.start_date,
                cycle_days=default_cycle_days,
            )

    db.commit()
    db.refresh(row)
    return row


def toggle_maintenance_item(db: Session, *, row: MaintenanceItem, enabled: bool) -> MaintenanceItem:
    row.is_enabled = enabled
    db.commit()
    db.refresh(row)
    return row


def disable_maintenance_item(db: Session, *, row: MaintenanceItem) -> MaintenanceItem:
    return toggle_maintenance_item(db, row=row, enabled=False)


def delete_maintenance_item(db: Session, *, row: MaintenanceItem) -> None:
    has_plan = db.execute(
        select(MaintenancePlan.id).where(MaintenancePlan.item_id == row.id).limit(1)
    ).scalars().first()
    if has_plan is not None:
        raise ValueError("Maintenance item is referenced by maintenance plans")

    unfinished_count = db.execute(
        select(func.count())
        .select_from(MaintenanceWorkOrder)
        .where(
            MaintenanceWorkOrder.item_id == row.id,
            MaintenanceWorkOrder.status != WORK_ORDER_STATUS_DONE,
        )
    ).scalar_one()
    if unfinished_count > 0:
        raise ValueError("Maintenance item has unfinished work orders")

    db.execute(
        update(MaintenanceWorkOrder)
        .where(
            MaintenanceWorkOrder.item_id == row.id,
            MaintenanceWorkOrder.status == WORK_ORDER_STATUS_DONE,
        )
        .values(item_id=None)
    )

    db.delete(row)
    db.commit()


def get_maintenance_plan_by_id(db: Session, plan_id: int) -> MaintenancePlan | None:
    stmt = (
        select(MaintenancePlan)
        .where(MaintenancePlan.id == plan_id)
        .options(
            selectinload(MaintenancePlan.equipment),
            selectinload(MaintenancePlan.item),
            selectinload(MaintenancePlan.default_executor),
        )
    )
    return db.execute(stmt).scalars().first()


def _validate_plan_relations(
    db: Session,
    *,
    equipment_id: int,
    item_id: int,
) -> tuple[Equipment, MaintenanceItem]:
    equipment = get_equipment_by_id(db, equipment_id)
    if not equipment:
        raise ValueError("Equipment not found")
    if not equipment.is_enabled:
        raise ValueError("Equipment is disabled")

    item = get_maintenance_item_by_id(db, item_id)
    if not item:
        raise ValueError("Maintenance item not found")
    if not item.is_enabled:
        raise ValueError("Maintenance item is disabled")

    return equipment, item


def list_maintenance_plans(
    db: Session,
    *,
    page: int,
    page_size: int,
    equipment_id: int | None,
    item_id: int | None,
    enabled: bool | None,
) -> tuple[int, list[MaintenancePlan]]:
    filters = []
    if equipment_id is not None:
        filters.append(MaintenancePlan.equipment_id == equipment_id)
    if item_id is not None:
        filters.append(MaintenancePlan.item_id == item_id)
    if enabled is not None:
        filters.append(MaintenancePlan.is_enabled.is_(enabled))

    count_stmt = select(func.count()).select_from(
        select(MaintenancePlan.id).where(*filters).subquery()
    )
    total = db.execute(count_stmt).scalar_one()

    offset = (page - 1) * page_size
    stmt = (
        select(MaintenancePlan)
        .where(*filters)
        .options(
            selectinload(MaintenancePlan.equipment),
            selectinload(MaintenancePlan.item),
            selectinload(MaintenancePlan.default_executor),
        )
        .order_by(MaintenancePlan.id.asc())
        .offset(offset)
        .limit(page_size)
    )
    rows = db.execute(stmt).scalars().all()
    return total, rows


def create_maintenance_plan(
    db: Session,
    *,
    equipment_id: int,
    item_id: int,
    execution_process_code: str,
    estimated_duration_minutes: int | None,
    start_date: date,
    next_due_date: date | None,
    default_executor_user_id: int | None,
) -> MaintenancePlan:
    _, item = _validate_plan_relations(db, equipment_id=equipment_id, item_id=item_id)
    cycle_days = _resolve_plan_cycle_days(item)
    normalized_process_code = _normalize_execution_process_code(execution_process_code)
    if estimated_duration_minutes is not None and estimated_duration_minutes <= 0:
        raise ValueError("Estimated duration minutes must be greater than 0")

    existing = db.execute(
        select(MaintenancePlan).where(
            MaintenancePlan.equipment_id == equipment_id,
            MaintenancePlan.item_id == item_id,
        )
    ).scalars().first()
    if existing:
        raise ValueError("Maintenance plan already exists for this equipment and item")

    if default_executor_user_id is not None:
        executor = db.execute(
            select(User).where(User.id == default_executor_user_id)
        ).scalars().first()
        if not executor:
            raise ValueError("Default executor user not found")

    resolved_next_due_date = next_due_date or start_date
    if resolved_next_due_date < start_date:
        raise ValueError("Next due date cannot be earlier than start date")

    row = MaintenancePlan(
        equipment_id=equipment_id,
        item_id=item_id,
        cycle_days=cycle_days,
        execution_process_code=normalized_process_code,
        estimated_duration_minutes=estimated_duration_minutes,
        start_date=start_date,
        next_due_date=resolved_next_due_date,
        default_executor_user_id=default_executor_user_id,
        is_enabled=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return get_maintenance_plan_by_id(db, row.id) or row


def update_maintenance_plan(
    db: Session,
    *,
    row: MaintenancePlan,
    equipment_id: int,
    item_id: int,
    execution_process_code: str,
    estimated_duration_minutes: int | None,
    start_date: date,
    next_due_date: date | None,
    default_executor_user_id: int | None,
) -> MaintenancePlan:
    _, item = _validate_plan_relations(db, equipment_id=equipment_id, item_id=item_id)
    cycle_days = _resolve_plan_cycle_days(item)
    normalized_process_code = _normalize_execution_process_code(execution_process_code)
    if estimated_duration_minutes is not None and estimated_duration_minutes <= 0:
        raise ValueError("Estimated duration minutes must be greater than 0")

    duplicate = db.execute(
        select(MaintenancePlan).where(
            MaintenancePlan.id != row.id,
            MaintenancePlan.equipment_id == equipment_id,
            MaintenancePlan.item_id == item_id,
        )
    ).scalars().first()
    if duplicate:
        raise ValueError("Maintenance plan already exists for this equipment and item")

    if default_executor_user_id is not None:
        executor = db.execute(
            select(User).where(User.id == default_executor_user_id)
        ).scalars().first()
        if not executor:
            raise ValueError("Default executor user not found")

    resolved_next_due_date = next_due_date or row.next_due_date
    if resolved_next_due_date < start_date:
        raise ValueError("Next due date cannot be earlier than start date")

    row.equipment_id = equipment_id
    row.item_id = item_id
    row.cycle_days = cycle_days
    row.execution_process_code = normalized_process_code
    row.estimated_duration_minutes = estimated_duration_minutes
    row.start_date = start_date
    row.next_due_date = resolved_next_due_date
    row.default_executor_user_id = default_executor_user_id
    db.commit()
    db.refresh(row)
    return get_maintenance_plan_by_id(db, row.id) or row


def toggle_maintenance_plan(db: Session, *, row: MaintenancePlan, enabled: bool) -> MaintenancePlan:
    row.is_enabled = enabled
    db.commit()
    db.refresh(row)
    return get_maintenance_plan_by_id(db, row.id) or row


def delete_maintenance_plan(db: Session, *, row: MaintenancePlan) -> None:
    unfinished_count = db.execute(
        select(func.count())
        .select_from(MaintenanceWorkOrder)
        .where(
            MaintenanceWorkOrder.plan_id == row.id,
            MaintenanceWorkOrder.status != WORK_ORDER_STATUS_DONE,
        )
    ).scalar_one()
    if unfinished_count > 0:
        raise ValueError("Maintenance plan has unfinished work orders")

    db.execute(
        update(MaintenanceWorkOrder)
        .where(
            MaintenanceWorkOrder.plan_id == row.id,
            MaintenanceWorkOrder.status == WORK_ORDER_STATUS_DONE,
        )
        .values(plan_id=None)
    )
    db.delete(row)
    db.commit()


def refresh_overdue_work_orders(db: Session) -> int:
    today = date.today()
    rows = db.execute(
        select(MaintenanceWorkOrder).where(
            MaintenanceWorkOrder.status == WORK_ORDER_STATUS_PENDING,
            MaintenanceWorkOrder.due_date < today,
        )
    ).scalars().all()
    if not rows:
        return 0
    for row in rows:
        row.status = WORK_ORDER_STATUS_OVERDUE
    db.commit()
    return len(rows)


def get_work_order_by_id(db: Session, work_order_id: int) -> MaintenanceWorkOrder | None:
    stmt = (
        select(MaintenanceWorkOrder)
        .where(MaintenanceWorkOrder.id == work_order_id)
        .options(
            selectinload(MaintenanceWorkOrder.equipment),
            selectinload(MaintenanceWorkOrder.item),
            selectinload(MaintenanceWorkOrder.executor),
        )
    )
    return db.execute(stmt).scalars().first()


def generate_work_order_for_plan(
    db: Session,
    *,
    row: MaintenancePlan,
) -> tuple[MaintenanceWorkOrder, bool]:
    if not row.is_enabled:
        raise ValueError("Maintenance plan is disabled")

    refresh_overdue_work_orders(db)

    active_existing = db.execute(
        select(MaintenanceWorkOrder).where(
            MaintenanceWorkOrder.plan_id == row.id,
            MaintenanceWorkOrder.status.in_(WORK_ORDER_STATUS_ACTIVE),
        )
    ).scalars().first()
    if active_existing:
        existing = get_work_order_by_id(db, active_existing.id) or active_existing
        return existing, False

    due_date = row.next_due_date

    equipment = row.equipment or get_equipment_by_id(db, row.equipment_id)
    item = row.item or get_maintenance_item_by_id(db, row.item_id)
    if equipment is None:
        raise ValueError("Equipment not found")
    if item is None:
        raise ValueError("Maintenance item not found")
    current_cycle_days = _resolve_plan_cycle_days(item)
    row.cycle_days = current_cycle_days
    if not is_valid_equipment_process_code(row.execution_process_code):
        row.execution_process_code = map_location_to_process_code(equipment.location)

    same_due_existing = db.execute(
        select(MaintenanceWorkOrder).where(
            MaintenanceWorkOrder.plan_id == row.id,
            MaintenanceWorkOrder.due_date == due_date,
        )
    ).scalars().first()
    if same_due_existing:
        existing = get_work_order_by_id(db, same_due_existing.id) or same_due_existing
        return existing, False

    status = (
        WORK_ORDER_STATUS_OVERDUE if due_date < date.today() else WORK_ORDER_STATUS_PENDING
    )
    work_order = MaintenanceWorkOrder(
        plan_id=row.id,
        equipment_id=row.equipment_id,
        item_id=row.item_id,
        source_plan_id=row.id,
        source_plan_cycle_days=current_cycle_days,
        source_plan_start_date=row.start_date,
        source_equipment_id=row.equipment_id,
        source_equipment_code=equipment.code,
        source_equipment_name=equipment.name,
        source_item_id=row.item_id,
        source_item_name=item.name,
        source_execution_process_code=row.execution_process_code,
        due_date=due_date,
        status=status,
        executor_user_id=row.default_executor_user_id,
    )
    db.add(work_order)
    row.next_due_date = due_date + timedelta(days=current_cycle_days)
    db.commit()
    db.refresh(work_order)
    db.refresh(row)
    return get_work_order_by_id(db, work_order.id) or work_order, True


def generate_due_work_orders_for_today(db: Session) -> tuple[int, int, int]:
    refresh_overdue_work_orders(db)
    today = date.today()

    plans = db.execute(
        select(MaintenancePlan)
        .join(Equipment, MaintenancePlan.equipment_id == Equipment.id)
        .join(MaintenanceItem, MaintenancePlan.item_id == MaintenanceItem.id)
        .where(
            MaintenancePlan.is_enabled.is_(True),
            Equipment.is_enabled.is_(True),
            MaintenanceItem.is_enabled.is_(True),
            MaintenancePlan.next_due_date <= today,
        )
        .order_by(MaintenancePlan.id.asc())
    ).scalars().all()

    created_count = 0
    existing_count = 0
    for plan in plans:
        _, created = generate_work_order_for_plan(db, row=plan)
        if created:
            created_count += 1
        else:
            existing_count += 1
    return len(plans), created_count, existing_count


def list_work_orders(
    db: Session,
    *,
    page: int,
    page_size: int,
    status: str | None,
    keyword: str | None,
    mine: bool,
    current_user_id: int | None,
    current_user_role_codes: list[str],
    current_user_process_codes: list[str],
    done_only: bool,
    executor_user_id: int | None,
    start_date: date | None,
    end_date: date | None,
) -> tuple[int, list[MaintenanceWorkOrder]]:
    refresh_overdue_work_orders(db)

    filters = []
    role_code_set = {code.strip() for code in current_user_role_codes if code and code.strip()}
    process_code_set = {code.strip() for code in current_user_process_codes if code and code.strip()}

    if not _can_view_all_work_orders(role_code_set):
        if not process_code_set:
            return 0, []
        filters.append(MaintenanceWorkOrder.source_execution_process_code.in_(process_code_set))

    if done_only:
        filters.append(MaintenanceWorkOrder.status == WORK_ORDER_STATUS_DONE)
    elif status:
        if status not in WORK_ORDER_STATUS_ALL:
            raise ValueError(f"Invalid status: {status}")
        filters.append(MaintenanceWorkOrder.status == status)
    else:
        filters.append(MaintenanceWorkOrder.status != WORK_ORDER_STATUS_DONE)

    if mine:
        if current_user_id is None:
            raise ValueError("Current user is required for mine filter")
        filters.append(MaintenanceWorkOrder.executor_user_id == current_user_id)

    if executor_user_id is not None:
        filters.append(MaintenanceWorkOrder.executor_user_id == executor_user_id)

    if start_date is not None:
        start_dt = datetime.combine(start_date, time.min, tzinfo=UTC)
        filters.append(
            and_(
                MaintenanceWorkOrder.completed_at.is_not(None),
                MaintenanceWorkOrder.completed_at >= start_dt,
            )
        )
    if end_date is not None:
        end_dt = datetime.combine(end_date + timedelta(days=1), time.min, tzinfo=UTC)
        filters.append(
            and_(
                MaintenanceWorkOrder.completed_at.is_not(None),
                MaintenanceWorkOrder.completed_at < end_dt,
            )
        )

    stmt = select(MaintenanceWorkOrder)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                MaintenanceWorkOrder.source_equipment_name.ilike(like_pattern),
                MaintenanceWorkOrder.source_item_name.ilike(like_pattern),
                MaintenanceWorkOrder.result_summary.ilike(like_pattern),
                MaintenanceWorkOrder.result_remark.ilike(like_pattern),
            )
        )
    stmt = stmt.where(*filters)

    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    rows = db.execute(
        stmt.options(
            selectinload(MaintenanceWorkOrder.equipment),
            selectinload(MaintenanceWorkOrder.item),
            selectinload(MaintenanceWorkOrder.executor),
        )
        .order_by(
            MaintenanceWorkOrder.due_date.desc(),
            MaintenanceWorkOrder.id.desc(),
        )
        .offset(offset)
        .limit(page_size)
    ).scalars().all()
    return total, rows


def list_maintenance_records(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    executor_user_id: int | None,
    start_date: date | None,
    end_date: date | None,
) -> tuple[int, list[MaintenanceRecord]]:
    filters = []

    if executor_user_id is not None:
        filters.append(MaintenanceRecord.executor_user_id == executor_user_id)

    if start_date is not None:
        start_dt = datetime.combine(start_date, time.min, tzinfo=UTC)
        filters.append(MaintenanceRecord.completed_at >= start_dt)
    if end_date is not None:
        end_dt = datetime.combine(end_date + timedelta(days=1), time.min, tzinfo=UTC)
        filters.append(MaintenanceRecord.completed_at < end_dt)

    stmt = select(MaintenanceRecord).where(*filters)
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                MaintenanceRecord.source_equipment_name.ilike(like_pattern),
                MaintenanceRecord.source_item_name.ilike(like_pattern),
                MaintenanceRecord.result_summary.ilike(like_pattern),
                MaintenanceRecord.result_remark.ilike(like_pattern),
                MaintenanceRecord.executor_username.ilike(like_pattern),
            )
        )

    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    rows = db.execute(
        stmt.order_by(
            MaintenanceRecord.completed_at.desc(),
            MaintenanceRecord.id.desc(),
        )
        .offset(offset)
        .limit(page_size)
    ).scalars().all()
    return total, rows


def start_work_order(
    db: Session,
    *,
    row: MaintenanceWorkOrder,
    operator: User,
    current_user_role_codes: list[str],
    current_user_process_codes: list[str],
) -> MaintenanceWorkOrder:
    refresh_overdue_work_orders(db)
    db.refresh(row)

    _ensure_work_order_process_permission(
        row=row,
        current_user_role_codes={
            code.strip() for code in current_user_role_codes if code and code.strip()
        },
        current_user_process_codes={
            code.strip() for code in current_user_process_codes if code and code.strip()
        },
    )

    if row.status not in {WORK_ORDER_STATUS_PENDING, WORK_ORDER_STATUS_OVERDUE}:
        raise ValueError("Work order cannot be started in current status")

    row.status = WORK_ORDER_STATUS_IN_PROGRESS
    row.started_at = datetime.now(UTC)
    if row.executor_user_id is None:
        row.executor_user_id = operator.id
    db.commit()
    db.refresh(row)
    return get_work_order_by_id(db, row.id) or row


def complete_work_order(
    db: Session,
    *,
    row: MaintenanceWorkOrder,
    operator: User,
    current_user_role_codes: list[str],
    current_user_process_codes: list[str],
    result_summary: str,
    result_remark: str | None,
    attachment_link: str | None,
) -> MaintenanceWorkOrder:
    normalized_summary = _normalize_name(result_summary, field_name="Result summary")
    summary_alias_map = {
        "完成": "完成",
        "失败": "失败",
        "瀹屾垚": "完成",
        "澶辫触": "失败",
    }
    normalized_summary = summary_alias_map.get(normalized_summary)
    if normalized_summary is None:
        raise ValueError("Result summary must be 完成 or 失败")

    normalized_remark = _normalize_optional_text(result_remark)
    if normalized_summary == "失败" and not normalized_remark:
        raise ValueError("Exception report is required when result summary is 失败")

    _ensure_work_order_process_permission(
        row=row,
        current_user_role_codes={
            code.strip() for code in current_user_role_codes if code and code.strip()
        },
        current_user_process_codes={
            code.strip() for code in current_user_process_codes if code and code.strip()
        },
    )

    if row.status != WORK_ORDER_STATUS_IN_PROGRESS:
        raise ValueError("Work order can only be completed when in progress")

    row.status = WORK_ORDER_STATUS_DONE
    row.completed_at = datetime.now(UTC)
    if row.executor_user_id is None:
        row.executor_user_id = operator.id
    row.result_summary = normalized_summary
    row.result_remark = normalized_remark or None
    row.attachment_link = _normalize_optional_text(attachment_link) or None

    existing_record = db.execute(
        select(MaintenanceRecord).where(MaintenanceRecord.work_order_id == row.id).limit(1)
    ).scalars().first()
    if existing_record is None:
        if row.executor_user_id == operator.id:
            executor_username = operator.username
        elif row.executor_user_id is None:
            executor_username = ""
        else:
            executor_username = (
                db.execute(select(User.username).where(User.id == row.executor_user_id)).scalar_one_or_none()
                or ""
            )

        db.add(
            MaintenanceRecord(
                work_order_id=row.id,
                source_plan_id=row.source_plan_id,
                source_plan_cycle_days=row.source_plan_cycle_days,
                source_plan_start_date=row.source_plan_start_date,
                source_equipment_id=row.source_equipment_id,
                source_equipment_code=row.source_equipment_code,
                source_equipment_name=row.source_equipment_name,
                source_item_id=row.source_item_id,
                source_item_name=row.source_item_name,
                due_date=row.due_date,
                executor_user_id=row.executor_user_id,
                executor_username=executor_username,
                completed_at=row.completed_at,
                result_summary=normalized_summary,
                result_remark=row.result_remark,
                attachment_link=row.attachment_link,
            )
        )

    db.commit()
    db.refresh(row)
    return get_work_order_by_id(db, row.id) or row
