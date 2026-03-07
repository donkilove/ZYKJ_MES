from __future__ import annotations

from datetime import date

import pytest
from sqlalchemy import select

from app.core.config import settings
from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
)
from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_sub_order import ProductionSubOrder
from app.services import production_execution_service, production_order_service


def _prepare_order_env(db, factory):
    factory.ensure_default_roles()
    stage = factory.stage(code="41", name="测试工段", sort_order=1)
    process = factory.process(stage=stage, code="41-01", name="测试工序")
    operator = factory.user(username="op_prod", role_codes=[ROLE_OPERATOR], processes=[process])
    admin = factory.user(username="admin_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    product = factory.product(name="产线产品")
    db.commit()
    return stage, process, operator, admin, product


def test_create_order_and_list_my_orders(db, factory) -> None:
    _, process, operator, admin, product = _prepare_order_env(db, factory)

    order = production_order_service.create_order(
        db,
        order_code="ORD-1001",
        product_id=product.id,
        quantity=5,
        start_date=None,
        due_date=None,
        remark="",
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    assert order.status == ORDER_STATUS_PENDING
    assert order.current_process_code == process.code
    assert order.product_version == 1

    process_rows = db.execute(
        select(ProductionOrderProcess).where(ProductionOrderProcess.order_id == order.id)
    ).scalars().all()
    assert len(process_rows) == 1
    assert process_rows[0].visible_quantity == 5

    sub_orders = db.execute(
        select(ProductionSubOrder).where(ProductionSubOrder.order_process_id == process_rows[0].id)
    ).scalars().all()
    assert len(sub_orders) == 1
    assert sub_orders[0].assigned_quantity == 5

    total_admin, admin_items = production_order_service.list_my_orders(
        db,
        current_user=admin,
        keyword=None,
        page=1,
        page_size=10,
    )
    assert total_admin == 1
    assert admin_items[0]["can_first_article"] is False

    total_operator, operator_items = production_order_service.list_my_orders(
        db,
        current_user=operator,
        keyword=None,
        page=1,
        page_size=10,
    )
    assert total_operator == 1
    assert operator_items[0]["can_first_article"] is True


def test_submit_first_article_and_end_production_until_complete(db, factory) -> None:
    _, process, operator, admin, product = _prepare_order_env(db, factory)

    order = production_order_service.create_order(
        db,
        order_code="ORD-1002",
        product_id=product.id,
        quantity=5,
        start_date=None,
        due_date=None,
        remark=None,
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    process_row = db.execute(
        select(ProductionOrderProcess).where(ProductionOrderProcess.order_id == order.id)
    ).scalars().first()
    assert process_row is not None

    order, process_row, sub_order = production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        verification_code=settings.production_default_verification_code,
        remark="首件通过",
        operator=operator,
    )
    assert order.status == ORDER_STATUS_IN_PROGRESS
    assert process_row.status == PROCESS_STATUS_IN_PROGRESS
    assert sub_order.status == "in_progress"

    order, process_row, sub_order = production_execution_service.end_production(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        quantity=3,
        remark=None,
        operator=operator,
    )
    assert process_row.status == PROCESS_STATUS_PARTIAL
    assert sub_order.completed_quantity == 3

    production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        verification_code=settings.production_default_verification_code,
        remark=None,
        operator=operator,
    )
    order, process_row, sub_order = production_execution_service.end_production(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        quantity=2,
        remark="完成",
        operator=operator,
    )
    assert process_row.completed_quantity == 5
    assert order.status == ORDER_STATUS_COMPLETED


def test_update_delete_and_manual_complete_order(db, factory) -> None:
    _, process, operator, admin, product = _prepare_order_env(db, factory)

    order = production_order_service.create_order(
        db,
        order_code="ORD-1003",
        product_id=product.id,
        quantity=8,
        start_date=None,
        due_date=date.today(),
        remark="old",
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )

    updated = production_order_service.update_order(
        db,
        order=order,
        product_id=product.id,
        quantity=6,
        start_date=None,
        due_date=None,
        remark="new",
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    assert updated.quantity == 6
    assert updated.remark == "new"
    assert updated.product_version == 1

    production_order_service.delete_order(db, order=updated)
    assert production_order_service.get_order_by_code(db, "ORD-1003") is None

    order2 = production_order_service.create_order(
        db,
        order_code="ORD-1004",
        product_id=product.id,
        quantity=4,
        start_date=None,
        due_date=None,
        remark=None,
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    row = db.execute(
        select(ProductionOrderProcess).where(ProductionOrderProcess.order_id == order2.id)
    ).scalars().first()
    row.status = PROCESS_STATUS_IN_PROGRESS
    order2.status = ORDER_STATUS_IN_PROGRESS
    db.commit()

    with pytest.raises(ValueError, match="Only pending orders"):
        production_order_service.delete_order(db, order=order2)

    completed = production_order_service.complete_order_manually(db, order=order2, operator=operator)
    assert completed.status == ORDER_STATUS_COMPLETED


def test_execution_service_validation_errors(db, factory) -> None:
    _, process, operator, admin, product = _prepare_order_env(db, factory)
    order = production_order_service.create_order(
        db,
        order_code="ORD-1005",
        product_id=product.id,
        quantity=2,
        start_date=None,
        due_date=None,
        remark=None,
        process_codes=[process.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    process_row = db.execute(
        select(ProductionOrderProcess).where(ProductionOrderProcess.order_id == order.id)
    ).scalars().first()

    with pytest.raises(ValueError, match="Invalid verification code"):
        production_execution_service.submit_first_article(
            db,
            order_id=order.id,
            order_process_id=process_row.id,
            verification_code="wrong",
            remark=None,
            operator=operator,
        )

    with pytest.raises(ValueError, match="greater than 0"):
        production_execution_service.end_production(
            db,
            order_id=order.id,
            order_process_id=process_row.id,
            quantity=0,
            remark=None,
            operator=operator,
        )
