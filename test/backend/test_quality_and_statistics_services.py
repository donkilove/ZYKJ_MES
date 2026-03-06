from __future__ import annotations

from datetime import date, timedelta

from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PENDING,
    RECORD_TYPE_PRODUCTION,
)
from app.core.rbac import ROLE_OPERATOR
from app.services import production_statistics_service, quality_service


def _build_quality_fixture(db, factory):
    stage = factory.stage(code="51", name="质检工段", sort_order=1)
    process = factory.process(stage=stage, code="51-01", name="质检工序")
    operator = factory.user(username="quality_op", role_codes=[ROLE_OPERATOR], processes=[process])
    product = factory.product(name="质检产品")
    order = factory.order(product=product, order_code="ORD-QA", quantity=10, status=ORDER_STATUS_IN_PROGRESS)
    process_row = factory.order_process(
        order=order,
        process=process,
        stage=stage,
        process_order=1,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=10,
        completed_quantity=4,
    )
    sub_order = factory.sub_order(
        process_row=process_row,
        operator=operator,
        assigned_quantity=10,
        completed_quantity=4,
        status="in_progress",
        is_visible=True,
    )
    factory.production_record(
        order=order,
        process_row=process_row,
        operator=operator,
        quantity=4,
        record_type=RECORD_TYPE_PRODUCTION,
        sub_order=sub_order,
    )
    today = date.today()
    factory.verification_code(verify_date=today, code="123456", created_by=operator)
    factory.first_article(
        order=order,
        process_row=process_row,
        operator=operator,
        verification_date=today,
        verification_code="123456",
        result="passed",
    )

    order2 = factory.order(product=product, order_code="ORD-QA-2", quantity=8, status=ORDER_STATUS_COMPLETED)
    process_row2 = factory.order_process(
        order=order2,
        process=process,
        stage=stage,
        process_order=1,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=8,
        completed_quantity=8,
    )
    factory.first_article(
        order=order2,
        process_row=process_row2,
        operator=operator,
        verification_date=today,
        verification_code="123456",
        result="failed",
    )
    db.commit()
    return order, process_row, operator


def test_quality_service_first_article_list_and_stats(db, factory) -> None:
    _build_quality_fixture(db, factory)

    payload = quality_service.list_first_articles(
        db,
        query_date=date.today(),
        keyword="ORD-QA",
        page=1,
        page_size=20,
    )
    assert payload["total"] >= 1
    assert payload["verification_code"] == "123456"
    assert payload["verification_code_source"] == "stored"

    overview = quality_service.get_quality_overview(
        db,
        start_date=date.today() - timedelta(days=1),
        end_date=date.today() + timedelta(days=1),
    )
    assert overview["first_article_total"] == 2
    assert overview["passed_total"] == 1
    assert overview["failed_total"] == 1

    process_rows = quality_service.get_quality_process_stats(db, start_date=None, end_date=None)
    assert len(process_rows) == 1
    assert process_rows[0]["process_code"] == "51-01"

    operator_rows = quality_service.get_quality_operator_stats(db, start_date=None, end_date=None)
    assert len(operator_rows) == 1
    assert operator_rows[0]["operator_username"] == "quality_op"


def test_production_statistics_service(db, factory) -> None:
    stage = factory.stage(code="52", name="统计工段", sort_order=1)
    process = factory.process(stage=stage, code="52-01", name="统计工序")
    operator = factory.user(username="stats_op", role_codes=[ROLE_OPERATOR], processes=[process])
    product = factory.product(name="统计产品")

    order_pending = factory.order(product=product, order_code="ORD-S1", quantity=5, status=ORDER_STATUS_PENDING)
    order_progress = factory.order(product=product, order_code="ORD-S2", quantity=7, status=ORDER_STATUS_IN_PROGRESS)
    order_done = factory.order(product=product, order_code="ORD-S3", quantity=9, status=ORDER_STATUS_COMPLETED)

    p1 = factory.order_process(
        order=order_pending,
        process=process,
        stage=stage,
        process_order=1,
        status=PROCESS_STATUS_PENDING,
        visible_quantity=5,
        completed_quantity=0,
    )
    p2 = factory.order_process(
        order=order_progress,
        process=process,
        stage=stage,
        process_order=1,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=7,
        completed_quantity=3,
    )
    p3 = factory.order_process(
        order=order_done,
        process=process,
        stage=stage,
        process_order=1,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=9,
        completed_quantity=9,
    )

    factory.production_record(
        order=order_progress,
        process_row=p2,
        operator=operator,
        quantity=3,
        record_type=RECORD_TYPE_PRODUCTION,
    )
    factory.production_record(
        order=order_done,
        process_row=p3,
        operator=operator,
        quantity=9,
        record_type=RECORD_TYPE_PRODUCTION,
    )
    db.commit()

    overview = production_statistics_service.get_overview_stats(db)
    assert overview["total_orders"] == 3
    assert overview["pending_orders"] == 1
    assert overview["in_progress_orders"] == 1
    assert overview["completed_orders"] == 1

    process_stats = production_statistics_service.get_process_stats(db)
    assert len(process_stats) == 1
    assert process_stats[0]["total_orders"] == 3

    operator_stats = production_statistics_service.get_operator_stats(db)
    assert len(operator_stats) == 1
    assert operator_stats[0]["production_records"] == 2
    assert operator_stats[0]["production_quantity"] == 12
