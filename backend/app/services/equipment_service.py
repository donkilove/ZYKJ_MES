from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.models.equipment import Equipment
from app.models.maintenance_item import MaintenanceItem
from app.models.maintenance_plan import MaintenancePlan
from app.models.maintenance_work_order import MaintenanceWorkOrder
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


def _normalize_name(name: str, *, field_name: str) -> str:
    normalized = name.strip()
    if not normalized:
        raise ValueError(f"{field_name} is required")
    return normalized


def _normalize_optional_text(value: str | None) -> str:
    if value is None:
        return ""
    return value.strip()


def get_equipment_by_id(db: Session, equipment_id: int) -> Equipment | None:
    stmt = select(Equipment).where(Equipment.id == equipment_id)
    return db.execute(stmt).scalars().first()


def get_equipment_by_name(db: Session, name: str) -> Equipment | None:
    stmt = select(Equipment).where(Equipment.name == name)
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
    name: str,
    model: str,
    location: str,
    owner_name: str,
) -> Equipment:
    normalized_name = _normalize_name(name, field_name="Equipment name")
    if get_equipment_by_name(db, normalized_name):
        raise ValueError("Equipment name already exists")

    row = Equipment(
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
    name: str,
    model: str,
    location: str,
    owner_name: str,
) -> Equipment:
    normalized_name = _normalize_name(name, field_name="Equipment name")
    existing = get_equipment_by_name(db, normalized_name)
    if existing and existing.id != row.id:
        raise ValueError("Equipment name already exists")

    row.name = normalized_name
    row.model = _normalize_optional_text(model)
    row.location = _normalize_optional_text(location)
    row.owner_name = _normalize_optional_text(owner_name)
    db.commit()
    db.refresh(row)
    return row


def disable_equipment(db: Session, *, row: Equipment) -> Equipment:
    row.is_enabled = False
    db.commit()
    db.refresh(row)
    return row


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
        stmt = stmt.where(
            or_(
                MaintenanceItem.name.ilike(like_pattern),
                MaintenanceItem.category.ilike(like_pattern),
            )
        )
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
    category: str,
    default_cycle_days: int,
    default_duration_minutes: int,
) -> MaintenanceItem:
    normalized_name = _normalize_name(name, field_name="Maintenance item name")
    if get_maintenance_item_by_name(db, normalized_name):
        raise ValueError("Maintenance item name already exists")
    if default_cycle_days <= 0:
        raise ValueError("Default cycle days must be greater than 0")
    if default_duration_minutes <= 0:
        raise ValueError("Default duration minutes must be greater than 0")

    row = MaintenanceItem(
        name=normalized_name,
        category=_normalize_optional_text(category),
        default_cycle_days=default_cycle_days,
        default_duration_minutes=default_duration_minutes,
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
    category: str,
    default_cycle_days: int,
    default_duration_minutes: int,
) -> MaintenanceItem:
    normalized_name = _normalize_name(name, field_name="Maintenance item name")
    existing = get_maintenance_item_by_name(db, normalized_name)
    if existing and existing.id != row.id:
        raise ValueError("Maintenance item name already exists")
    if default_cycle_days <= 0:
        raise ValueError("Default cycle days must be greater than 0")
    if default_duration_minutes <= 0:
        raise ValueError("Default duration minutes must be greater than 0")

    row.name = normalized_name
    row.category = _normalize_optional_text(category)
    row.default_cycle_days = default_cycle_days
    row.default_duration_minutes = default_duration_minutes
    db.commit()
    db.refresh(row)
    return row


def disable_maintenance_item(db: Session, *, row: MaintenanceItem) -> MaintenanceItem:
    row.is_enabled = False
    db.commit()
    db.refresh(row)
    return row


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
    cycle_days: int,
    estimated_duration_minutes: int | None,
    start_date: date,
    next_due_date: date | None,
    default_executor_user_id: int | None,
) -> MaintenancePlan:
    _validate_plan_relations(db, equipment_id=equipment_id, item_id=item_id)
    if cycle_days <= 0:
        raise ValueError("Cycle days must be greater than 0")
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
    cycle_days: int,
    estimated_duration_minutes: int | None,
    start_date: date,
    next_due_date: date | None,
    default_executor_user_id: int | None,
) -> MaintenancePlan:
    _validate_plan_relations(db, equipment_id=equipment_id, item_id=item_id)
    if cycle_days <= 0:
        raise ValueError("Cycle days must be greater than 0")
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
        due_date=due_date,
        status=status,
        executor_user_id=row.default_executor_user_id,
    )
    db.add(work_order)
    row.next_due_date = due_date + timedelta(days=row.cycle_days)
    db.commit()
    db.refresh(work_order)
    db.refresh(row)
    return get_work_order_by_id(db, work_order.id) or work_order, True


def list_work_orders(
    db: Session,
    *,
    page: int,
    page_size: int,
    status: str | None,
    keyword: str | None,
    mine: bool,
    current_user_id: int | None,
    done_only: bool,
    executor_user_id: int | None,
    start_date: date | None,
    end_date: date | None,
) -> tuple[int, list[MaintenanceWorkOrder]]:
    refresh_overdue_work_orders(db)

    filters = []
    if done_only:
        filters.append(MaintenanceWorkOrder.status == WORK_ORDER_STATUS_DONE)
    elif status:
        if status not in WORK_ORDER_STATUS_ALL:
            raise ValueError(f"Invalid status: {status}")
        filters.append(MaintenanceWorkOrder.status == status)

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

    stmt = (
        select(MaintenanceWorkOrder)
        .join(Equipment, MaintenanceWorkOrder.equipment_id == Equipment.id)
        .join(MaintenanceItem, MaintenanceWorkOrder.item_id == MaintenanceItem.id)
    )
    if keyword:
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                Equipment.name.ilike(like_pattern),
                MaintenanceItem.name.ilike(like_pattern),
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


def start_work_order(
    db: Session,
    *,
    row: MaintenanceWorkOrder,
    operator: User,
) -> MaintenanceWorkOrder:
    refresh_overdue_work_orders(db)
    db.refresh(row)

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
    result_summary: str,
    result_remark: str | None,
    attachment_link: str | None,
) -> MaintenanceWorkOrder:
    normalized_summary = _normalize_name(result_summary, field_name="Result summary")
    if row.status != WORK_ORDER_STATUS_IN_PROGRESS:
        raise ValueError("Work order can only be completed when in progress")

    row.status = WORK_ORDER_STATUS_DONE
    row.completed_at = datetime.now(UTC)
    if row.executor_user_id is None:
        row.executor_user_id = operator.id
    row.result_summary = normalized_summary
    row.result_remark = _normalize_optional_text(result_remark) or None
    row.attachment_link = _normalize_optional_text(attachment_link) or None
    db.commit()
    db.refresh(row)
    return get_work_order_by_id(db, row.id) or row
