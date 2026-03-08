from __future__ import annotations

from sqlalchemy import select

from app.models.order_event_log import OrderEventLog
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.services.production_repair_service import (
    RepairListFilters,
    ScrapStatisticsFilters,
    complete_repair_order,
    create_repair_order,
    export_repair_orders_csv,
    export_scrap_statistics_csv,
    get_repair_order_phenomena_summary,
    list_repair_orders,
    list_scrap_statistics,
)


def _prepare_order_context(db, factory):
    operator = factory.user(username="repair_op", role_codes=["operator"])
    admin = factory.user(username="repair_admin", role_codes=["production_admin"])
    stage = factory.stage(code="91", name="维修测试工段", sort_order=1)
    process = factory.process(stage=stage, code="91-01", name="维修测试工序")
    operator.processes = [process]
    product = factory.product(name="维修测试产品")
    order = factory.order(
        product=product,
        order_code="REP-ORD-1",
        quantity=5,
        status="in_progress",
        current_process_code=process.code,
        created_by=admin,
    )
    process_row = factory.order_process(
        order=order,
        process=process,
        stage=stage,
        process_order=1,
        status="in_progress",
        visible_quantity=5,
        completed_quantity=1,
    )
    db.commit()
    return operator, admin, order, process_row


def test_create_repair_order_and_list_summary(db, factory) -> None:
    operator, _, order, process_row = _prepare_order_context(db, factory)

    repair_row = create_repair_order(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        sender=operator,
        production_quantity=3,
        defect_items=[
            {"phenomenon": "毛刺", "quantity": 1},
            {"phenomenon": "划伤", "quantity": 2},
        ],
        auto_created=True,
    )
    db.commit()

    assert repair_row.status == "in_repair"
    assert repair_row.repair_quantity == 3

    total, rows = list_repair_orders(
        db,
        page=1,
        page_size=20,
        filters=RepairListFilters(
            keyword="REP-ORD-1",
            status="in_repair",
            start_date=None,
            end_date=None,
        ),
    )
    assert total == 1
    assert rows[0].repair_order_code == repair_row.repair_order_code

    summary = get_repair_order_phenomena_summary(db, repair_order_id=repair_row.id)
    assert len(summary) == 2
    assert sum(int(item["quantity"]) for item in summary) == 3

    event_rows = db.execute(
        select(OrderEventLog).where(OrderEventLog.order_id == order.id)
    ).scalars().all()
    assert any(row.event_type == "repair_order_created_auto" for row in event_rows)


def test_complete_repair_order_generates_scrap_stats_and_exports(db, factory) -> None:
    operator, admin, order, process_row = _prepare_order_context(db, factory)
    repair_row = create_repair_order(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        sender=operator,
        production_quantity=2,
        defect_items=[{"phenomenon": "毛刺", "quantity": 2}],
        auto_created=False,
    )
    db.commit()

    completed = complete_repair_order(
        db,
        repair_order_id=repair_row.id,
        cause_items=[
            {"phenomenon": "毛刺", "reason": "刀具磨损", "quantity": 1, "is_scrap": True},
            {"phenomenon": "毛刺", "reason": "重新加工", "quantity": 1, "is_scrap": False},
        ],
        scrap_replenished=True,
        return_allocations=[{"target_order_process_id": process_row.id, "quantity": 1}],
        operator=admin,
    )
    assert completed.status == "completed"
    assert completed.scrap_quantity == 1
    assert completed.repaired_quantity == 1
    assert completed.scrap_replenished is True

    scrap_total, scrap_rows = list_scrap_statistics(
        db,
        page=1,
        page_size=20,
        filters=ScrapStatisticsFilters(
            keyword="REP-ORD-1",
            progress="pending_apply",
            start_date=None,
            end_date=None,
        ),
    )
    assert scrap_total >= 1
    assert any(row.scrap_reason == "刀具磨损" for row in scrap_rows)

    scrap_export = export_scrap_statistics_csv(
        db,
        filters=ScrapStatisticsFilters(
            keyword="REP-ORD-1",
            progress="all",
            start_date=None,
            end_date=None,
        ),
        operator=admin,
    )
    assert scrap_export["content_base64"]
    assert str(scrap_export["file_name"]).endswith(".csv")

    repair_export = export_repair_orders_csv(
        db,
        filters=RepairListFilters(
            keyword="REP-ORD-1",
            status="all",
            start_date=None,
            end_date=None,
        ),
        operator=admin,
    )
    assert repair_export["content_base64"]
    assert str(repair_export["file_name"]).endswith(".csv")

    applied_rows = db.execute(
        select(ProductionScrapStatistics).where(
            ProductionScrapStatistics.order_id == order.id
        )
    ).scalars().all()
    assert applied_rows
    assert all(row.progress == "applied" for row in applied_rows)


def test_complete_repair_order_validation_errors(db, factory) -> None:
    operator, admin, order, process_row = _prepare_order_context(db, factory)
    repair_row = create_repair_order(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        sender=operator,
        production_quantity=1,
        defect_items=[{"phenomenon": "毛刺", "quantity": 1}],
        auto_created=False,
    )
    db.commit()

    try:
        complete_repair_order(
            db,
            repair_order_id=repair_row.id,
            cause_items=[
                {"phenomenon": "毛刺", "reason": "刀具磨损", "quantity": 1, "is_scrap": False}
            ],
            scrap_replenished=False,
            return_allocations=[],
            operator=admin,
        )
    except ValueError as error:
        assert "return_allocations" in str(error)
    else:
        raise AssertionError("Expected ValueError for invalid return allocations")
