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
from app.core.rbac import ROLE_OPERATOR, ROLE_QUALITY_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_sub_order import ProductionSubOrder
from app.services import assist_authorization_service, production_execution_service, production_order_service


def _prepare_order_env(db, factory):
    factory.ensure_default_roles()
    stage = factory.stage(code="41", name="测试工段", sort_order=1)
    process = factory.process(stage=stage, code="41-01", name="测试工序")
    operator = factory.user(username="op_prod", role_codes=[ROLE_OPERATOR], processes=[process])
    admin = factory.user(username="admin_prod", role_codes=[ROLE_SYSTEM_ADMIN])
    product = factory.product(name="产线产品")
    db.commit()
    return stage, process, operator, admin, product


def _prepare_two_process_order_env(db, factory):
    factory.ensure_default_roles()
    stage_a = factory.stage(code="51", name="工段A", sort_order=1)
    stage_b = factory.stage(code="52", name="工段B", sort_order=2)
    process_a = factory.process(stage=stage_a, code="51-01", name="工序A")
    process_b = factory.process(stage=stage_b, code="52-01", name="工序B")
    operator = factory.user(
        username="op_pipeline",
        role_codes=[ROLE_OPERATOR],
        processes=[process_a, process_b],
    )
    admin = factory.user(username="admin_pipeline", role_codes=[ROLE_SYSTEM_ADMIN])
    product = factory.product(name="并行测试产品")
    db.commit()
    return stage_a, stage_b, process_a, process_b, operator, admin, product


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


def test_assist_authorization_and_view_modes(db, factory) -> None:
    _, process, operator, admin, product = _prepare_order_env(db, factory)

    order = production_order_service.create_order(
        db,
        order_code="ORD-2001",
        product_id=product.id,
        quantity=3,
        start_date=None,
        due_date=None,
        remark="assist",
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

    total_proxy, proxy_items = production_order_service.list_my_orders(
        db,
        current_user=admin,
        keyword=None,
        page=1,
        page_size=10,
        view_mode="proxy",
        proxy_operator_user_id=operator.id,
    )
    assert total_proxy == 1
    assert proxy_items[0]["can_first_article"] is False
    assert proxy_items[0]["can_end_production"] is False

    auth_row = assist_authorization_service.create_assist_authorization(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        target_operator_user_id=operator.id,
        helper_user_id=admin.id,
        reason="代班服务测试",
        requester=operator,
    )
    assert auth_row.status == "pending"

    reviewed = assist_authorization_service.review_assist_authorization(
        db,
        authorization_id=auth_row.id,
        approve=True,
        reviewer=admin,
        review_remark="ok",
    )
    assert reviewed.status == "approved"

    total_assist, assist_items = production_order_service.list_my_orders(
        db,
        current_user=admin,
        keyword=None,
        page=1,
        page_size=10,
        view_mode="assist",
    )
    assert total_assist == 1
    assert assist_items[0]["assist_authorization_id"] == auth_row.id
    assert assist_items[0]["work_view"] == "assist"
    assert assist_items[0]["can_first_article"] is True

    order, process_row, _ = production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        verification_code=settings.production_default_verification_code,
        remark="assist-first",
        operator=admin,
        effective_operator_user_id=operator.id,
        assist_authorization_id=auth_row.id,
    )
    assert order.status == ORDER_STATUS_IN_PROGRESS
    assert process_row.status == PROCESS_STATUS_IN_PROGRESS

    with pytest.raises(ValueError, match="does not allow first-article operation"):
        production_execution_service.submit_first_article(
            db,
            order_id=order.id,
            order_process_id=process_row.id,
            verification_code=settings.production_default_verification_code,
            remark=None,
            operator=admin,
            effective_operator_user_id=operator.id,
            assist_authorization_id=auth_row.id,
        )

    order, process_row, _ = production_execution_service.end_production(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        quantity=3,
        remark="assist-end",
        operator=admin,
        effective_operator_user_id=operator.id,
        assist_authorization_id=auth_row.id,
    )
    assert process_row.completed_quantity == 3
    assert order.status == ORDER_STATUS_COMPLETED

    with pytest.raises(ValueError, match="Order already completed"):
        production_execution_service.end_production(
            db,
            order_id=order.id,
            order_process_id=process_row.id,
            quantity=1,
            remark="retry",
            operator=admin,
            effective_operator_user_id=operator.id,
            assist_authorization_id=auth_row.id,
        )


def test_pipeline_mode_start_gate_and_release_rule(db, factory) -> None:
    _, _, process_a, process_b, operator, admin, product = _prepare_two_process_order_env(db, factory)
    order = production_order_service.create_order(
        db,
        order_code="ORD-PIPE-01",
        product_id=product.id,
        quantity=5,
        start_date=None,
        due_date=None,
        remark="pipeline",
        process_codes=[process_a.code, process_b.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    process_rows = db.execute(
        select(ProductionOrderProcess)
        .where(ProductionOrderProcess.order_id == order.id)
        .order_by(ProductionOrderProcess.process_order.asc())
    ).scalars().all()
    assert len(process_rows) == 2
    first_row = process_rows[0]
    second_row = process_rows[1]

    # Force visibility to verify strict start gate (serial mode should still block second process).
    second_row.visible_quantity = 1
    production_order_service.ensure_sub_orders_visible_quantity(
        db,
        process_row=second_row,
        target_visible_quantity=1,
    )
    db.commit()

    with pytest.raises(ValueError, match="pipeline start gate"):
        production_execution_service.submit_first_article(
            db,
            order_id=order.id,
            order_process_id=second_row.id,
            verification_code=settings.production_default_verification_code,
            remark=None,
            operator=operator,
        )

    mode_payload = production_order_service.update_order_pipeline_mode(
        db,
        order_id=order.id,
        enabled=True,
        process_codes=[process_a.code, process_b.code],
        operator=admin,
    )
    assert mode_payload["enabled"] is True
    assert mode_payload["process_codes"] == [process_a.code, process_b.code]

    production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=first_row.id,
        verification_code=settings.production_default_verification_code,
        remark=None,
        operator=operator,
    )
    production_execution_service.end_production(
        db,
        order_id=order.id,
        order_process_id=first_row.id,
        quantity=1,
        remark="upstream",
        operator=operator,
    )

    # Parallel edge allows second process first article once upstream has output.
    order, second_row, _ = production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=second_row.id,
        verification_code=settings.production_default_verification_code,
        remark="pipeline-start",
        operator=operator,
    )
    assert order.status == ORDER_STATUS_IN_PROGRESS
    assert second_row.status == PROCESS_STATUS_IN_PROGRESS

    # Serial mode should not release downstream visibility on partial completion.
    order_2 = production_order_service.create_order(
        db,
        order_code="ORD-PIPE-02",
        product_id=product.id,
        quantity=5,
        start_date=None,
        due_date=None,
        remark="pipeline-release",
        process_codes=[process_a.code, process_b.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    process_rows_2 = db.execute(
        select(ProductionOrderProcess)
        .where(ProductionOrderProcess.order_id == order_2.id)
        .order_by(ProductionOrderProcess.process_order.asc())
    ).scalars().all()
    first_row_2 = process_rows_2[0]
    second_row_2 = process_rows_2[1]

    production_execution_service.submit_first_article(
        db,
        order_id=order_2.id,
        order_process_id=first_row_2.id,
        verification_code=settings.production_default_verification_code,
        remark=None,
        operator=operator,
    )
    production_execution_service.end_production(
        db,
        order_id=order_2.id,
        order_process_id=first_row_2.id,
        quantity=1,
        remark="serial",
        operator=operator,
    )
    second_row_2 = db.execute(
        select(ProductionOrderProcess).where(ProductionOrderProcess.id == second_row_2.id)
    ).scalars().first()
    assert second_row_2 is not None
    assert second_row_2.visible_quantity == 0

    production_order_service.update_order_pipeline_mode(
        db,
        order_id=order_2.id,
        enabled=True,
        process_codes=[process_a.code, process_b.code],
        operator=admin,
    )
    production_execution_service.submit_first_article(
        db,
        order_id=order_2.id,
        order_process_id=first_row_2.id,
        verification_code=settings.production_default_verification_code,
        remark=None,
        operator=operator,
    )
    production_execution_service.end_production(
        db,
        order_id=order_2.id,
        order_process_id=first_row_2.id,
        quantity=1,
        remark="parallel",
        operator=operator,
    )
    second_row_2 = db.execute(
        select(ProductionOrderProcess).where(ProductionOrderProcess.id == second_row_2.id)
    ).scalars().first()
    assert second_row_2 is not None
    assert second_row_2.visible_quantity == 2


def test_update_pipeline_mode_validation_and_my_orders_flags(db, factory) -> None:
    _, _, process_a, process_b, operator, admin, product = _prepare_two_process_order_env(db, factory)
    order = production_order_service.create_order(
        db,
        order_code="ORD-PIPE-03",
        product_id=product.id,
        quantity=4,
        start_date=None,
        due_date=None,
        remark=None,
        process_codes=[process_a.code, process_b.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    with pytest.raises(ValueError, match="At least two valid process codes"):
        production_order_service.update_order_pipeline_mode(
            db,
            order_id=order.id,
            enabled=True,
            process_codes=[process_a.code],
            operator=admin,
        )

    production_order_service.update_order_pipeline_mode(
        db,
        order_id=order.id,
        enabled=True,
        process_codes=[process_a.code, process_b.code],
        operator=admin,
    )
    total, items = production_order_service.list_my_orders(
        db,
        current_user=operator,
        keyword=None,
        page=1,
        page_size=20,
        view_mode="own",
    )
    assert total >= 1
    first_item = items[0]
    assert first_item["pipeline_mode_enabled"] is True
    assert "pipeline_start_allowed" in first_item
    assert "pipeline_end_allowed" in first_item


def test_order_detail_access_and_my_order_context(db, factory) -> None:
    _, process, operator, admin, product = _prepare_order_env(db, factory)
    quality_admin = factory.user(username="quality_reader", role_codes=[ROLE_QUALITY_ADMIN])
    unrelated_operator = factory.user(
        username="unrelated_operator",
        role_codes=[ROLE_OPERATOR],
        processes=[],
    )
    db.commit()

    order = production_order_service.create_order(
        db,
        order_code="ORD-CTX-01",
        product_id=product.id,
        quantity=6,
        start_date=None,
        due_date=None,
        remark="ctx",
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

    assert production_order_service.can_user_access_order_detail(
        db,
        order_id=order.id,
        current_user=admin,
    )
    assert not production_order_service.can_user_access_order_detail(
        db,
        order_id=order.id,
        current_user=quality_admin,
    )
    assert production_order_service.can_user_access_order_detail(
        db,
        order_id=order.id,
        current_user=operator,
    )
    assert not production_order_service.can_user_access_order_detail(
        db,
        order_id=order.id,
        current_user=unrelated_operator,
    )

    context_own = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        current_user=operator,
        view_mode="own",
    )
    assert context_own is not None
    assert context_own["work_view"] == "own"

    context_unrelated = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        current_user=unrelated_operator,
        view_mode="own",
    )
    assert context_unrelated is None

    auth_row = assist_authorization_service.create_assist_authorization(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        target_operator_user_id=operator.id,
        helper_user_id=admin.id,
        reason="代班上下文",
        requester=operator,
    )
    assert auth_row.status == "pending"

    context_assist_pending = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        current_user=admin,
        view_mode="assist",
    )
    assert context_assist_pending is None

    reviewed = assist_authorization_service.review_assist_authorization(
        db,
        authorization_id=auth_row.id,
        approve=True,
        reviewer=admin,
        review_remark="同意",
    )
    assert reviewed.status == "approved"

    context_assist = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        current_user=admin,
        view_mode="assist",
    )
    assert context_assist is not None
    assert context_assist["assist_authorization_id"] == auth_row.id

    _, _, _ = production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        verification_code=settings.production_default_verification_code,
        remark="ctx-first",
        operator=admin,
        effective_operator_user_id=operator.id,
        assist_authorization_id=auth_row.id,
    )
    _, _, _ = production_execution_service.end_production(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        quantity=6,
        remark="ctx-end",
        operator=admin,
        effective_operator_user_id=operator.id,
        assist_authorization_id=auth_row.id,
    )

    context_assist_after = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        current_user=admin,
        view_mode="assist",
    )
    assert context_assist_after is None
    assert production_order_service.can_user_access_order_detail(
        db,
        order_id=order.id,
        current_user=admin,
    )


def test_get_my_order_context_can_lock_to_specific_process(db, factory) -> None:
    _, _, process_a, process_b, operator, admin, product = _prepare_two_process_order_env(db, factory)

    order = production_order_service.create_order(
        db,
        order_code="ORD-CTX-PROCESS",
        product_id=product.id,
        quantity=8,
        start_date=None,
        due_date=None,
        remark="ctx-process",
        process_codes=[process_a.code, process_b.code],
        template_id=None,
        process_steps=None,
        save_as_template=False,
        new_template_name=None,
        new_template_set_default=False,
        operator=admin,
    )
    process_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == order.id)
            .order_by(ProductionOrderProcess.process_order.asc())
        )
        .scalars()
        .all()
    )
    assert len(process_rows) == 2
    first_process = process_rows[0]
    second_process = process_rows[1]

    production_order_service.update_order_pipeline_mode(
        db,
        order_id=order.id,
        enabled=True,
        process_codes=[first_process.process_code, second_process.process_code],
        operator=admin,
    )
    production_execution_service.submit_first_article(
        db,
        order_id=order.id,
        order_process_id=first_process.id,
        verification_code=settings.production_default_verification_code,
        remark="first-start",
        operator=operator,
    )
    production_execution_service.end_production(
        db,
        order_id=order.id,
        order_process_id=first_process.id,
        quantity=3,
        remark="first-partial",
        operator=operator,
    )

    # Without explicit process context, the API may return any visible process row for this order.
    context_any = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        current_user=operator,
        view_mode="own",
    )
    assert context_any is not None

    context_first = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        order_process_id=first_process.id,
        current_user=operator,
        view_mode="own",
    )
    assert context_first is not None
    assert context_first["current_process_id"] == first_process.id

    context_second = production_order_service.get_my_order_context(
        db,
        order_id=order.id,
        order_process_id=second_process.id,
        current_user=operator,
        view_mode="own",
    )
    assert context_second is not None
    assert context_second["current_process_id"] == second_process.id
