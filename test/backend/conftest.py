from __future__ import annotations

import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import Session, sessionmaker

ROOT_DIR = Path(__file__).resolve().parents[2]
BACKEND_DIR = ROOT_DIR / "backend"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.rbac import ROLE_DEFINITIONS  # noqa: E402
from app.core.security import get_password_hash  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.models.daily_verification_code import DailyVerificationCode  # noqa: E402
from app.models.equipment import Equipment  # noqa: E402
from app.models.first_article_record import FirstArticleRecord  # noqa: E402
from app.models.maintenance_item import MaintenanceItem  # noqa: E402
from app.models.maintenance_plan import MaintenancePlan  # noqa: E402
from app.models.maintenance_work_order import MaintenanceWorkOrder  # noqa: E402
from app.models.order_event_log import OrderEventLog  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.product_process_template import ProductProcessTemplate  # noqa: E402
from app.models.product_process_template_step import ProductProcessTemplateStep  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.production_record import ProductionRecord  # noqa: E402
from app.models.production_sub_order import ProductionSubOrder  # noqa: E402
from app.models.registration_request import RegistrationRequest  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.user import User  # noqa: E402


_DEDUPED_INDEX_NAMES = False


def _dedupe_metadata_index_names() -> None:
    """SQLite create_all requires globally unique index names."""
    global _DEDUPED_INDEX_NAMES
    if _DEDUPED_INDEX_NAMES:
        return

    seen: dict[str, str] = {}
    for table in Base.metadata.tables.values():
        for idx in table.indexes:
            if not idx.name:
                continue
            if idx.name in seen:
                idx.name = f"{idx.name}_{table.name}"
            seen[idx.name] = table.name
    _DEDUPED_INDEX_NAMES = True


class DataFactory:
    def __init__(self, db: Session):
        self.db = db
        self._seq = 0

    def _next(self, prefix: str) -> str:
        self._seq += 1
        return f"{prefix}{self._seq}"

    def role(self, *, code: str | None = None, name: str | None = None) -> Role:
        code = code or self._next("role_")
        row = self.db.execute(select(Role).where(Role.code == code)).scalars().first()
        if row is not None:
            return row
        row = Role(code=code, name=name or code)
        self.db.add(row)
        self.db.flush()
        return row

    def ensure_default_roles(self) -> dict[str, Role]:
        result: dict[str, Role] = {}
        for item in ROLE_DEFINITIONS:
            role = self.role(code=str(item["code"]), name=str(item["name"]))
            result[role.code] = role
        return result

    def stage(
        self,
        *,
        code: str | None = None,
        name: str | None = None,
        sort_order: int = 0,
        is_enabled: bool = True,
    ) -> ProcessStage:
        if code is None:
            code = f"S{self._seq + 1:02d}"
        row = ProcessStage(
            code=code,
            name=name or f"stage-{code}",
            sort_order=sort_order,
            is_enabled=is_enabled,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def process(
        self,
        *,
        code: str | None = None,
        name: str | None = None,
        stage: ProcessStage | None = None,
        is_enabled: bool = True,
    ) -> Process:
        stage = stage or self.stage(code="01")
        if code is None:
            code = f"{stage.code}-01"
        row = Process(
            code=code,
            name=name or f"process-{code}",
            stage_id=stage.id,
            is_enabled=is_enabled,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def user(
        self,
        *,
        username: str | None = None,
        role_codes: list[str] | None = None,
        processes: list[Process] | None = None,
        is_active: bool = True,
        password: str = "Passw0rd!",
    ) -> User:
        self.ensure_default_roles()
        username = username or self._next("user_")
        roles: list[Role] = []
        for code in role_codes or []:
            role = self.db.execute(select(Role).where(Role.code == code)).scalars().first()
            if role is None:
                role = self.role(code=code, name=code)
            roles.append(role)

        row = User(
            username=username,
            full_name=username,
            password_hash=get_password_hash(password),
            is_active=is_active,
            is_superuser=False,
        )
        row.roles = roles
        row.processes = processes or []
        self.db.add(row)
        self.db.flush()
        return row

    def product(self, *, name: str | None = None) -> Product:
        row = Product(
            name=name or self._next("product_"),
            parameter_template_initialized=False,
            lifecycle_status="effective",
            current_version=1,
            effective_version=1,
            effective_at=None,
            inactive_reason=None,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def product_template(
        self,
        *,
        product: Product,
        steps: list[tuple[int, ProcessStage, Process]],
        template_name: str = "模板",
        version: int = 1,
        is_default: bool = True,
        is_enabled: bool = True,
        operator: User | None = None,
    ) -> ProductProcessTemplate:
        row = ProductProcessTemplate(
            product_id=product.id,
            template_name=template_name,
            version=version,
            is_default=is_default,
            is_enabled=is_enabled,
            created_by_user_id=operator.id if operator else None,
            updated_by_user_id=operator.id if operator else None,
        )
        self.db.add(row)
        self.db.flush()
        for step_order, stage, process in steps:
            row.steps.append(
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
        self.db.flush()
        return row

    def order(
        self,
        *,
        product: Product,
        order_code: str | None = None,
        quantity: int = 10,
        status: str = "pending",
        current_process_code: str | None = None,
        created_by: User | None = None,
    ) -> ProductionOrder:
        row = ProductionOrder(
            order_code=order_code or self._next("ORD-"),
            product_id=product.id,
            product_version=product.effective_version if product.effective_version > 0 else product.current_version,
            quantity=quantity,
            status=status,
            current_process_code=current_process_code,
            created_by_user_id=created_by.id if created_by else None,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def order_process(
        self,
        *,
        order: ProductionOrder,
        process: Process,
        stage: ProcessStage,
        process_order: int,
        status: str = "pending",
        visible_quantity: int = 0,
        completed_quantity: int = 0,
    ) -> ProductionOrderProcess:
        row = ProductionOrderProcess(
            order_id=order.id,
            process_id=process.id,
            stage_id=stage.id,
            stage_code=stage.code,
            stage_name=stage.name,
            process_code=process.code,
            process_name=process.name,
            process_order=process_order,
            status=status,
            visible_quantity=visible_quantity,
            completed_quantity=completed_quantity,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def sub_order(
        self,
        *,
        process_row: ProductionOrderProcess,
        operator: User,
        assigned_quantity: int,
        completed_quantity: int = 0,
        status: str = "pending",
        is_visible: bool = True,
    ) -> ProductionSubOrder:
        row = ProductionSubOrder(
            order_process_id=process_row.id,
            operator_user_id=operator.id,
            assigned_quantity=assigned_quantity,
            completed_quantity=completed_quantity,
            status=status,
            is_visible=is_visible,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def production_record(
        self,
        *,
        order: ProductionOrder,
        process_row: ProductionOrderProcess,
        operator: User,
        quantity: int,
        record_type: str = "production",
        sub_order: ProductionSubOrder | None = None,
    ) -> ProductionRecord:
        row = ProductionRecord(
            order_id=order.id,
            order_process_id=process_row.id,
            sub_order_id=sub_order.id if sub_order else None,
            operator_user_id=operator.id,
            production_quantity=quantity,
            record_type=record_type,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def first_article(
        self,
        *,
        order: ProductionOrder,
        process_row: ProductionOrderProcess,
        operator: User,
        verification_date,
        verification_code: str = "123456",
        result: str = "passed",
    ) -> FirstArticleRecord:
        row = FirstArticleRecord(
            order_id=order.id,
            order_process_id=process_row.id,
            operator_user_id=operator.id,
            verification_date=verification_date,
            verification_code=verification_code,
            result=result,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def verification_code(self, *, verify_date, code: str, created_by: User | None = None) -> DailyVerificationCode:
        row = DailyVerificationCode(
            verify_date=verify_date,
            code=code,
            created_by_user_id=created_by.id if created_by else None,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def equipment(self, *, code: str | None = None, name: str | None = None, is_enabled: bool = True) -> Equipment:
        row = Equipment(
            code=code or self._next("EQ"),
            name=name or self._next("设备"),
            model="",
            location="",
            owner_name="",
            is_enabled=is_enabled,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def maintenance_item(
        self,
        *,
        name: str | None = None,
        default_cycle_days: int = 30,
        is_enabled: bool = True,
    ) -> MaintenanceItem:
        row = MaintenanceItem(
            name=name or self._next("保养项"),
            category="",
            default_cycle_days=default_cycle_days,
            default_duration_minutes=60,
            is_enabled=is_enabled,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def maintenance_plan(
        self,
        *,
        equipment: Equipment,
        item: MaintenanceItem,
        start_date,
        next_due_date,
        execution_process_code: str,
        cycle_days: int | None = None,
        is_enabled: bool = True,
        default_executor: User | None = None,
    ) -> MaintenancePlan:
        row = MaintenancePlan(
            equipment_id=equipment.id,
            item_id=item.id,
            cycle_days=cycle_days or item.default_cycle_days,
            execution_process_code=execution_process_code,
            estimated_duration_minutes=60,
            start_date=start_date,
            next_due_date=next_due_date,
            default_executor_user_id=default_executor.id if default_executor else None,
            is_enabled=is_enabled,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def work_order(
        self,
        *,
        due_date,
        status: str,
        execution_process_code: str,
        plan: MaintenancePlan | None = None,
        equipment: Equipment | None = None,
        item: MaintenanceItem | None = None,
        executor: User | None = None,
    ) -> MaintenanceWorkOrder:
        row = MaintenanceWorkOrder(
            plan_id=plan.id if plan else None,
            equipment_id=equipment.id if equipment else None,
            item_id=item.id if item else None,
            source_plan_id=plan.id if plan else None,
            source_plan_cycle_days=plan.cycle_days if plan else None,
            source_plan_start_date=plan.start_date if plan else None,
            source_equipment_id=equipment.id if equipment else None,
            source_equipment_code=equipment.code if equipment else "",
            source_equipment_name=equipment.name if equipment else "",
            source_item_id=item.id if item else None,
            source_item_name=item.name if item else "",
            source_execution_process_code=execution_process_code,
            due_date=due_date,
            status=status,
            executor_user_id=executor.id if executor else None,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def registration_request(self, *, account: str, password_hash: str = "hash") -> RegistrationRequest:
        row = RegistrationRequest(account=account, password_hash=password_hash)
        self.db.add(row)
        self.db.flush()
        return row

    def order_event(self, *, order_id: int, event_type: str = "event", title: str = "title") -> OrderEventLog:
        row = OrderEventLog(
            order_id=order_id,
            event_type=event_type,
            event_title=title,
            event_detail=None,
            operator_user_id=None,
            payload_json=None,
        )
        self.db.add(row)
        self.db.flush()
        return row


@pytest.fixture
def db_engine(tmp_path):
    db_file = tmp_path / "test_backend.sqlite3"
    engine = create_engine(f"sqlite+pysqlite:///{db_file}", future=True)
    _dedupe_metadata_index_names()

    @event.listens_for(engine, "connect")
    def _set_sqlite_pragma(dbapi_connection, _):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(engine)
    try:
        yield engine
    finally:
        Base.metadata.drop_all(engine)
        engine.dispose()


@pytest.fixture
def db(db_engine):
    session_local = sessionmaker(bind=db_engine, autoflush=False, autocommit=False, expire_on_commit=False)
    session = session_local()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


@pytest.fixture
def factory(db: Session) -> DataFactory:
    return DataFactory(db)
