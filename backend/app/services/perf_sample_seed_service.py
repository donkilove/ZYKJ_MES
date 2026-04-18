from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import UTC, date, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.models.daily_verification_code import DailyVerificationCode
from app.models.first_article_template import FirstArticleTemplate
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.product import Product
from app.models.product_revision import ProductRevision
from app.models.product_process_template import ProductProcessTemplate
from app.models.supplier import Supplier
from app.models.user import User
from app.core.product_parameter_template import (
    PRODUCT_NAME_PARAMETER_CATEGORY,
    PRODUCT_NAME_PARAMETER_KEY,
    PRODUCT_NAME_PARAMETER_TYPE,
)
from app.services.bootstrap_seed_service import seed_initial_data
from app.services.craft_service import create_template
from app.services.production_order_service import (
    _build_order_process_rows,
    create_order,
    ensure_sub_orders_visible_quantity,
)


STABLE_PRODUCT_NAME = "PERF-PRODUCT-STD-01"
STABLE_ROUTE_NAME = "PERF-ROUTE-STD-01"
STABLE_STAGE_CODE = "PERF-STAGE-STD-01"
STABLE_PROCESS_CODES = ("PERF-PROCESS-STD-01", "PERF-PROCESS-STD-02")
STABLE_SUPPLIER_NAME = "PERF-SUPPLIER-STD-01"
STABLE_TEMPLATE_NAME = "PERF-TEMPLATE-STD-01"
STABLE_FIRST_ARTICLE_TEMPLATE_NAME = "PERF-FA-TPL-STD-01"
STABLE_ORDER_CODE = "PERF-ORDER-OPEN-01"
STABLE_VERIFICATION_CODE = "VC-654321"
RUNTIME_ORDER_PREFIX = "PERF-RUN-"


@dataclass(slots=True)
class ProductionCraftSampleSeedResult:
    created_count: int
    updated_count: int
    baseline_refs: dict[str, str]
    context: dict[str, int | str]
    run_scoped_refs: list[str] = field(default_factory=list)


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _baseline_revision_snapshot(product_name: str) -> str:
    return json.dumps(
        {
            "name": product_name,
            "parameters": [
                {
                    "name": PRODUCT_NAME_PARAMETER_KEY,
                    "category": PRODUCT_NAME_PARAMETER_CATEGORY,
                    "type": PRODUCT_NAME_PARAMETER_TYPE,
                    "value": product_name,
                    "description": "",
                    "sort_order": 1,
                    "is_preset": True,
                }
            ],
        },
        ensure_ascii=False,
    )


def _get_admin_user(db: Session) -> User:
    seed_initial_data(
        db,
        admin_username=settings.bootstrap_admin_username,
        admin_password=settings.bootstrap_admin_password,
    )
    admin_user = (
        db.execute(
            select(User).where(User.username == settings.bootstrap_admin_username)
        )
        .scalars()
        .first()
    )
    if admin_user is None:
        raise ValueError("管理员账号不存在，无法创建性能样本")
    return admin_user


def _ensure_stage(db: Session, *, code: str, name: str) -> tuple[ProcessStage, bool, bool]:
    row = (
        db.execute(select(ProcessStage).where(ProcessStage.code == code))
        .scalars()
        .first()
    )
    created = False
    updated = False
    if row is None:
        row = ProcessStage(code=code, name=name, sort_order=0, is_enabled=True, remark="性能样本")
        db.add(row)
        db.flush()
        created = True
        return row, created, updated

    if row.name != name:
        row.name = name
        updated = True
    if row.sort_order != 0:
        row.sort_order = 0
        updated = True
    if not row.is_enabled:
        row.is_enabled = True
        updated = True
    if (row.remark or "") != "性能样本":
        row.remark = "性能样本"
        updated = True
    return row, created, updated


def _ensure_process(
    db: Session,
    *,
    code: str,
    name: str,
    stage: ProcessStage,
) -> tuple[Process, bool, bool]:
    row = db.execute(select(Process).where(Process.code == code)).scalars().first()
    created = False
    updated = False
    if row is None:
        row = Process(
            code=code,
            name=name,
            stage_id=stage.id,
            is_enabled=True,
            remark="性能样本",
        )
        db.add(row)
        db.flush()
        created = True
        return row, created, updated

    if row.name != name:
        row.name = name
        updated = True
    if row.stage_id != stage.id:
        row.stage_id = stage.id
        updated = True
    if not row.is_enabled:
        row.is_enabled = True
        updated = True
    if (row.remark or "") != "性能样本":
        row.remark = "性能样本"
        updated = True
    return row, created, updated


def _ensure_active_product(db: Session, *, name: str) -> tuple[Product, bool, bool]:
    row = db.execute(select(Product).where(Product.name == name)).scalars().first()
    created = False
    updated = False
    if row is None:
        row = Product(
            name=name,
            category="贴片",
            lifecycle_status="active",
            current_version=1,
            effective_version=1,
            effective_at=_now_utc(),
            remark="性能样本",
            parameter_template_initialized=True,
        )
        db.add(row)
        db.flush()
        created = True
    else:
        if row.category != "贴片":
            row.category = "贴片"
            updated = True
        if row.lifecycle_status != "active":
            row.lifecycle_status = "active"
            updated = True
        if row.current_version != 1:
            row.current_version = 1
            updated = True
        if row.effective_version != 1:
            row.effective_version = 1
            updated = True
        if row.effective_at is None:
            row.effective_at = _now_utc()
            updated = True
        if not row.parameter_template_initialized:
            row.parameter_template_initialized = True
            updated = True
        if (row.remark or "") != "性能样本":
            row.remark = "性能样本"
            updated = True
        if row.is_deleted:
            row.is_deleted = False
            updated = True

    revision = (
        db.execute(
            select(ProductRevision).where(
                ProductRevision.product_id == row.id,
                ProductRevision.version == 1,
            )
        )
        .scalars()
        .first()
    )
    if revision is None:
        db.add(
            ProductRevision(
                product_id=row.id,
                version=1,
                version_label="V1.0",
                lifecycle_status="active",
                action="snapshot",
                note="性能样本初始化",
                snapshot_json=_baseline_revision_snapshot(row.name),
            )
        )
        db.flush()
        created = created or False
    else:
        try:
            payload = json.loads(revision.snapshot_json)
        except (TypeError, ValueError):
            payload = None
        if (
            not isinstance(payload, dict)
            or payload.get("name") != row.name
            or not isinstance(payload.get("parameters"), list)
            or not any(
                isinstance(item, dict)
                and item.get("name") == PRODUCT_NAME_PARAMETER_KEY
                for item in payload.get("parameters", [])
            )
        ):
            revision.snapshot_json = _baseline_revision_snapshot(row.name)
            updated = True
    return row, created, updated


def _ensure_supplier(db: Session, *, name: str) -> tuple[Supplier, bool, bool]:
    row = db.execute(select(Supplier).where(Supplier.name == name)).scalars().first()
    created = False
    updated = False
    if row is None:
        row = Supplier(name=name, remark="性能样本", is_enabled=True)
        db.add(row)
        db.flush()
        created = True
        return row, created, updated

    if not row.is_enabled:
        row.is_enabled = True
        updated = True
    if row.remark != "性能样本":
        row.remark = "性能样本"
        updated = True
    return row, created, updated


def _ensure_template(
    db: Session,
    *,
    product: Product,
    stage: ProcessStage,
    processes: list[Process],
    operator: User,
) -> tuple[ProductProcessTemplate, bool, bool]:
    row = (
        db.execute(
            select(ProductProcessTemplate).where(
                ProductProcessTemplate.product_id == product.id,
                ProductProcessTemplate.template_name == STABLE_TEMPLATE_NAME,
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        created = create_template(
            db,
            product_id=product.id,
            template_name=STABLE_TEMPLATE_NAME,
            is_default=True,
            remark="性能样本",
            steps=[
                {
                    "step_order": 1,
                    "stage_id": stage.id,
                    "process_id": processes[0].id,
                },
                {
                    "step_order": 2,
                    "stage_id": stage.id,
                    "process_id": processes[1].id,
                },
            ],
            operator=operator,
        )
        row = created
        row.lifecycle_status = "published"
        row.published_version = row.version
        db.commit()
        db.refresh(row)
        return row, True, False

    updated = False
    if row.remark != "性能样本":
        row.remark = "性能样本"
        updated = True
    if not row.is_enabled:
        row.is_enabled = True
        updated = True
    if not row.is_default:
        row.is_default = True
        updated = True
    if row.lifecycle_status != "published":
        row.lifecycle_status = "published"
        updated = True
    if row.published_version != row.version:
        row.published_version = row.version
        updated = True
    return row, False, updated


def _ensure_first_article_template(
    db: Session,
    *,
    product: Product,
    process: Process,
) -> tuple[FirstArticleTemplate, bool, bool]:
    row = (
        db.execute(
            select(FirstArticleTemplate).where(
                FirstArticleTemplate.product_id == product.id,
                FirstArticleTemplate.process_code == process.code,
                FirstArticleTemplate.template_name
                == STABLE_FIRST_ARTICLE_TEMPLATE_NAME,
            )
        )
        .scalars()
        .first()
    )
    created = False
    updated = False
    if row is None:
        row = FirstArticleTemplate(
            product_id=product.id,
            process_code=process.code,
            template_name=STABLE_FIRST_ARTICLE_TEMPLATE_NAME,
            check_content="性能首件检查",
            test_value="通过",
            is_enabled=True,
        )
        db.add(row)
        db.flush()
        created = True
        return row, created, updated

    if row.check_content != "性能首件检查":
        row.check_content = "性能首件检查"
        updated = True
    if row.test_value != "通过":
        row.test_value = "通过"
        updated = True
    if not row.is_enabled:
        row.is_enabled = True
        updated = True
    return row, created, updated


def _ensure_today_verification_code(
    db: Session,
    *,
    operator: User,
) -> tuple[DailyVerificationCode, bool, bool]:
    today = date.today()
    row = (
        db.execute(
            select(DailyVerificationCode).where(
                DailyVerificationCode.verify_date == today
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        row = DailyVerificationCode(
            verify_date=today,
            code=STABLE_VERIFICATION_CODE,
            created_by_user_id=operator.id,
        )
        db.add(row)
        db.flush()
        return row, True, False
    updated = False
    if row.code != STABLE_VERIFICATION_CODE:
        row.code = STABLE_VERIFICATION_CODE
        updated = True
    if row.created_by_user_id is None:
        row.created_by_user_id = operator.id
        updated = True
    return row, False, updated


def _cleanup_stale_perf_templates_and_orders(
    db: Session,
    *,
    product: Product,
) -> int:
    removed = 0
    stale_orders = (
        db.execute(
            select(ProductionOrder).where(
                ProductionOrder.product_id == product.id,
                ProductionOrder.order_code.like("PERF-ORDER-%"),
                ProductionOrder.order_code != STABLE_ORDER_CODE,
            )
        )
        .scalars()
        .all()
    )
    for row in stale_orders:
        db.delete(row)
        removed += 1
    db.flush()

    stale_templates = (
        db.execute(
            select(ProductProcessTemplate).where(
                ProductProcessTemplate.product_id == product.id,
                ProductProcessTemplate.template_name.like("PERF-TPL-%"),
                ProductProcessTemplate.template_name != STABLE_TEMPLATE_NAME,
            )
        )
        .scalars()
        .all()
    )
    for row in stale_templates:
        db.delete(row)
        removed += 1
    db.flush()

    stale_processes = (
        db.execute(
            select(Process).where(
                Process.code.like(f"{STABLE_STAGE_CODE}-%"),
                Process.code.not_in(STABLE_PROCESS_CODES),
            )
        )
        .scalars()
        .all()
    )
    for row in stale_processes:
        db.delete(row)
        removed += 1
    db.flush()

    stale_stages = (
        db.execute(
            select(ProcessStage).where(
                ProcessStage.code.like("PERF-STAGE-%"),
                ProcessStage.code != STABLE_STAGE_CODE,
            )
        )
        .scalars()
        .all()
    )
    for row in stale_stages:
        db.delete(row)
        removed += 1
    db.flush()
    return removed


def _ensure_production_order(
    db: Session,
    *,
    product: Product,
    supplier: Supplier,
    template: ProductProcessTemplate,
    stage: ProcessStage,
    processes: list[Process],
    operator: User,
    order_code: str,
) -> tuple[ProductionOrder, bool, bool]:
    row = (
        db.execute(select(ProductionOrder).where(ProductionOrder.order_code == order_code))
        .scalars()
        .first()
    )
    if row is None:
        created = create_order(
            db,
            order_code=order_code,
            product_id=product.id,
            supplier_id=supplier.id,
            quantity=100,
            start_date=None,
            due_date=None,
            remark="性能样本",
            process_codes=[],
            template_id=template.id,
            process_steps=None,
            save_as_template=False,
            new_template_name=None,
            new_template_set_default=False,
            operator=operator,
        )
        return created, True, False

    updated = False
    if row.product_id != product.id:
        row.product_id = product.id
        updated = True
    if row.supplier_id != supplier.id:
        row.supplier_id = supplier.id
        updated = True
    if row.supplier_name != supplier.name:
        row.supplier_name = supplier.name
        updated = True
    if row.process_template_id != template.id:
        row.process_template_id = template.id
        updated = True
    if row.process_template_name != template.template_name:
        row.process_template_name = template.template_name
        updated = True
    if row.process_template_version != template.version:
        row.process_template_version = template.version
        updated = True
    if row.quantity != 100:
        row.quantity = 100
        updated = True
    if row.status != "pending":
        row.status = "pending"
        updated = True
    if row.current_process_code != processes[0].code:
        row.current_process_code = processes[0].code
        updated = True
    if row.remark != "性能样本":
        row.remark = "性能样本"
        updated = True

    existing_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == row.id)
            .order_by(ProductionOrderProcess.process_order.asc(), ProductionOrderProcess.id.asc())
        )
        .scalars()
        .all()
    )
    expected = [
        (1, stage.id, processes[0].id, processes[0].code),
        (2, stage.id, processes[1].id, processes[1].code),
    ]
    needs_rebuild = len(existing_rows) != 2
    if not needs_rebuild:
        for existing, (order_index, expected_stage_id, expected_process_id, expected_process_code) in zip(existing_rows, expected, strict=True):
            if (
                existing.process_order != order_index
                or existing.stage_id != expected_stage_id
                or existing.process_id != expected_process_id
                or existing.process_code != expected_process_code
            ):
                needs_rebuild = True
                break
    if needs_rebuild:
        for existing in existing_rows:
            db.delete(existing)
        db.flush()
        route_steps = [
            (stage, processes[0]),
            (stage, processes[1]),
        ]
        rebuilt_rows = _build_order_process_rows(
            db,
            order=row,
            route_steps=route_steps,
        )
        for rebuilt_row in rebuilt_rows:
            ensure_sub_orders_visible_quantity(
                db,
                process_row=rebuilt_row,
                target_visible_quantity=rebuilt_row.visible_quantity,
            )
        row.current_process_code = processes[0].code
        updated = True
    return row, False, updated


def _delete_order_by_code(db: Session, order_code: str) -> None:
    row = (
        db.execute(select(ProductionOrder).where(ProductionOrder.order_code == order_code))
        .scalars()
        .first()
    )
    if row is not None:
        db.delete(row)
        db.flush()


def build_runtime_order_ref(run_id: str) -> str:
    return f"runtime-order:{RUNTIME_ORDER_PREFIX}{run_id}-ORDER"


def seed_production_craft_samples(
    db: Session,
    *,
    run_id: str,
    mode: str = "baseline",
    cleanup_stale_perf_artifacts: bool = True,
) -> ProductionCraftSampleSeedResult:
    admin_user = _get_admin_user(db)
    created_count = 0
    updated_count = 0

    stage, created, updated = _ensure_stage(
        db, code=STABLE_STAGE_CODE, name=STABLE_STAGE_CODE
    )
    created_count += int(created)
    updated_count += int(updated)

    process_primary, created, updated = _ensure_process(
        db,
        code=STABLE_PROCESS_CODES[0],
        name=STABLE_PROCESS_CODES[0],
        stage=stage,
    )
    created_count += int(created)
    updated_count += int(updated)
    process_secondary, created, updated = _ensure_process(
        db,
        code=STABLE_PROCESS_CODES[1],
        name=STABLE_PROCESS_CODES[1],
        stage=stage,
    )
    created_count += int(created)
    updated_count += int(updated)

    product, created, updated = _ensure_active_product(db, name=STABLE_PRODUCT_NAME)
    created_count += int(created)
    updated_count += int(updated)

    if cleanup_stale_perf_artifacts:
        updated_count += _cleanup_stale_perf_templates_and_orders(db, product=product)

    supplier, created, updated = _ensure_supplier(db, name=STABLE_SUPPLIER_NAME)
    created_count += int(created)
    updated_count += int(updated)

    template, created, updated = _ensure_template(
        db,
        product=product,
        stage=stage,
        processes=[process_primary, process_secondary],
        operator=admin_user,
    )
    created_count += int(created)
    updated_count += int(updated)
    first_article_template, created, updated = _ensure_first_article_template(
        db,
        product=product,
        process=process_primary,
    )
    created_count += int(created)
    updated_count += int(updated)
    verification_code_row, created, updated = _ensure_today_verification_code(
        db,
        operator=admin_user,
    )
    created_count += int(created)
    updated_count += int(updated)

    order, created, updated = _ensure_production_order(
        db,
        product=product,
        supplier=supplier,
        template=template,
        stage=stage,
        processes=[process_primary, process_secondary],
        operator=admin_user,
        order_code=STABLE_ORDER_CODE,
    )
    created_count += int(created)
    updated_count += int(updated)

    order_process_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == order.id)
            .order_by(ProductionOrderProcess.process_order.asc(), ProductionOrderProcess.id.asc())
            .options(
                selectinload(ProductionOrderProcess.process),
                selectinload(ProductionOrderProcess.stage),
            )
        )
        .scalars()
        .all()
    )
    if len(order_process_rows) < 2:
        raise ValueError("稳定生产订单未生成至少两道工序，无法支撑 production/craft 场景")
    primary_order_process, secondary_order_process = order_process_rows[:2]

    context: dict[str, int | str] = {
        "admin_user_id": admin_user.id,
        "admin_username": admin_user.username,
        "product_id": product.id,
        "product_name": product.name,
        "product_current_version": product.current_version,
        "product_effective_version": product.effective_version,
        "stage_id": stage.id,
        "stage_code": stage.code,
        "process_id": process_primary.id,
        "process_code": process_primary.code,
        "secondary_process_id": process_secondary.id,
        "secondary_process_code": process_secondary.code,
        "supplier_id": supplier.id,
        "supplier_name": supplier.name,
        "craft_template_id": template.id,
        "craft_template_name": template.template_name,
        "first_article_template_id": first_article_template.id,
        "first_article_template_name": first_article_template.template_name,
        "verification_code": verification_code_row.code,
        "production_order_id": order.id,
        "production_order_code": order.order_code,
        "order_process_id": primary_order_process.id,
        "secondary_order_process_id": secondary_order_process.id,
    }
    run_scoped_refs: list[str] = []

    if mode == "runtime":
        runtime_order_code = f"{RUNTIME_ORDER_PREFIX}{run_id}-ORDER"
        runtime_order, created, updated = _ensure_production_order(
            db,
            product=product,
            supplier=supplier,
            template=template,
            stage=stage,
            processes=[process_primary, process_secondary],
            operator=admin_user,
            order_code=runtime_order_code,
        )
        created_count += int(created)
        updated_count += int(updated)
        context["runtime_order_id"] = runtime_order.id
        run_scoped_refs.append(build_runtime_order_ref(run_id))

    db.commit()

    return ProductionCraftSampleSeedResult(
        created_count=created_count,
        updated_count=updated_count,
        baseline_refs={
            "product": STABLE_PRODUCT_NAME,
            "route": STABLE_ROUTE_NAME,
            "order": STABLE_ORDER_CODE,
            "template": STABLE_TEMPLATE_NAME,
        },
        context=context,
        run_scoped_refs=run_scoped_refs,
    )


def reset_runtime_samples(
    db: Session,
    run_scoped_refs: list[str],
    *,
    restore_strategy: str | None,
) -> None:
    for sample_ref in reversed(run_scoped_refs):
        sample_type, sample_code = sample_ref.split(":", 1)
        if sample_type == "runtime-order":
            _delete_order_by_code(db, sample_code)
    db.commit()
    if restore_strategy == "rebuild":
        db.expire_all()
