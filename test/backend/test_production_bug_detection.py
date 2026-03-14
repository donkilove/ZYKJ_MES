from __future__ import annotations

import pytest
from sqlalchemy import select

from app.core.config import settings
from app.core.rbac import ROLE_OPERATOR, ROLE_SYSTEM_ADMIN
from app.models.production_order_process import ProductionOrderProcess
from app.services import (
    production_execution_service,
    production_order_service,
    production_repair_service,
)


def _prepare_env_for_bug_detection(db, factory):
    factory.ensure_default_roles()
    stage = factory.stage(code="91", name="bug-stage")
    process = factory.process(stage=stage, code="91-01", name="bug-process")
    operator_a = factory.user(
        username="bug_operator_a",
        role_codes=[ROLE_OPERATOR],
        processes=[process],
    )
    operator_b = factory.user(
        username="bug_operator_b",
        role_codes=[ROLE_OPERATOR],
        processes=[process],
    )
    admin = factory.user(username="bug_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    product = factory.product(name="bug-product")
    db.commit()
    return process, operator_a, operator_b, admin, product


def test_detect_multi_operator_lock_after_first_article(db, factory) -> None:
    process, operator_a, operator_b, admin, product = _prepare_env_for_bug_detection(db, factory)

    order = production_order_service.create_order(
        db,
        order_code="BUG-LOCK-01",
        product_id=product.id,
        quantity=2,
        start_date=None,
        due_date=None,
        remark="lock-bug",
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    process_row = db.execute(
        select(ProductionOrderProcess)
        .where(ProductionOrderProcess.order_id == order.id)
        .order_by(ProductionOrderProcess.process_order.asc())
    ).scalars().first()
    assert process_row is not None

    production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        verification_code=settings.production_default_verification_code,
        remark="first-by-a",
        operator=operator_a,
    )

    # Another assigned operator should be able to report after process first article is opened.
    production_execution_service.end_production(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        quantity=1,
        remark="end-by-b",
        operator=operator_b,
    )


def test_detect_manual_repair_quantity_inconsistency(db, factory) -> None:
    process, operator_a, _, admin, product = _prepare_env_for_bug_detection(db, factory)

    order = production_order_service.create_order(
        db,
        order_code="BUG-REPAIR-01",
        product_id=product.id,
        quantity=3,
        start_date=None,
        due_date=None,
        remark="repair-bug",
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    process_row = db.execute(
        select(ProductionOrderProcess)
        .where(ProductionOrderProcess.order_id == order.id)
        .order_by(ProductionOrderProcess.process_order.asc())
    ).scalars().first()
    assert process_row is not None

    # Reject inconsistent data: defect total (2) cannot exceed production quantity (1).
    with pytest.raises(ValueError):
        production_repair_service.create_manual_repair_order(
            db,
            order_id=order.id,
            order_process_id=process_row.id,
            production_quantity=1,
            defect_items=[{"phenomenon": "scratch", "quantity": 2}],
            sender=operator_a,
        )
