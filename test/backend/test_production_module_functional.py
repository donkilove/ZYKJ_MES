from __future__ import annotations

import base64
from datetime import UTC, date, datetime, timedelta

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1.endpoints import production as production_api
from app.core.config import settings
from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
)
from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.models.order_event_log import OrderEventLog
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.schemas.production import (
    AssistAuthorizationCreateRequest,
    AssistAuthorizationReviewRequest,
    EndProductionRequest,
    FirstArticleRequest,
    OrderCreate,
    OrderPipelineModeUpdateRequest,
    OrdersExportRequest,
    OrderUpdate,
    ProductionDataManualExportRequest,
    ProductionDefectItem,
    RepairCauseItem,
    RepairOrderCompleteRequest,
    RepairOrderCreateRequest,
    RepairOrdersExportRequest,
    RepairReturnAllocationItem,
    ScrapStatisticsExportRequest,
)


def _prepare_production_env(db, factory) -> dict[str, object]:
    factory.ensure_default_roles()
    stage_cut = factory.stage(code="61", name="切割工段", sort_order=1)
    stage_assembly = factory.stage(code="62", name="装配工段", sort_order=2)
    process_cut = factory.process(stage=stage_cut, code="61-01", name="切割")
    process_assembly = factory.process(stage=stage_assembly, code="62-01", name="装配")

    operator = factory.user(
        username="prod_func_operator",
        role_codes=[ROLE_OPERATOR],
        processes=[process_cut, process_assembly],
    )
    helper = factory.user(
        username="prod_func_helper",
        role_codes=[ROLE_PRODUCTION_ADMIN],
    )
    quality_admin = factory.user(
        username="prod_func_quality",
        role_codes=[ROLE_QUALITY_ADMIN],
    )
    system_admin = factory.user(
        username="prod_func_admin",
        role_codes=[ROLE_SYSTEM_ADMIN],
    )
    product = factory.product(name="生产模块功能测试产品")
    db.commit()
    return {
        "stage_cut": stage_cut,
        "stage_assembly": stage_assembly,
        "process_cut": process_cut,
        "process_assembly": process_assembly,
        "operator": operator,
        "helper": helper,
        "quality_admin": quality_admin,
        "system_admin": system_admin,
        "product": product,
    }


def _create_order(
    db,
    *,
    current_user,
    order_code: str,
    product_id: int,
    quantity: int,
    process_codes: list[str],
):
    response = production_api.create_order_api(
        payload=OrderCreate(
            order_code=order_code,
            product_id=product_id,
            quantity=quantity,
            process_codes=process_codes,
        ),
        db=db,
        current_user=current_user,
    )
    return response.data


def test_production_order_management_pipeline_and_export_endpoints(db, factory) -> None:
    env = _prepare_production_env(db, factory)
    admin = env["system_admin"]
    product = env["product"]
    process_cut = env["process_cut"]
    process_assembly = env["process_assembly"]

    created = _create_order(
        db,
        current_user=admin,
        order_code="PF-ORD-001",
        product_id=product.id,
        quantity=12,
        process_codes=[process_cut.code, process_assembly.code],
    )
    order_id = created.id
    assert created.order_code == "PF-ORD-001"
    assert created.status == ORDER_STATUS_PENDING
    assert created.pipeline_enabled is False

    listed = production_api.get_orders(
        page=1,
        page_size=20,
        keyword="PF-ORD",
        status_text=None,
        product_name=None,
        pipeline_enabled=None,
        start_date_from=None,
        start_date_to=None,
        due_date_from=None,
        due_date_to=None,
        db=db,
        _=admin,
    )
    assert listed.data.total == 1
    assert listed.data.items[0].order_code == "PF-ORD-001"

    detail = production_api.get_order_detail_api(
        order_id=order_id,
        db=db,
        current_user=admin,
    )
    assert detail.data.order.id == order_id
    assert len(detail.data.processes) == 2

    pipeline_before = production_api.get_order_pipeline_mode_api(
        order_id=order_id,
        db=db,
        current_user=admin,
    )
    assert pipeline_before.data.enabled is False

    pipeline_updated = production_api.update_order_pipeline_mode_api(
        order_id=order_id,
        payload=OrderPipelineModeUpdateRequest(
            enabled=True,
            process_codes=[process_cut.code, process_assembly.code],
        ),
        db=db,
        current_user=admin,
    )
    assert pipeline_updated.data.enabled is True
    assert pipeline_updated.data.process_codes == [process_cut.code, process_assembly.code]

    instances = production_api.get_pipeline_instances_api(
        order_id=order_id,
        order_process_id=None,
        sub_order_id=None,
        is_active=None,
        page=1,
        page_size=500,
        db=db,
        _=admin,
    )
    assert instances.data.total >= 2
    assert all(item.order_id == order_id for item in instances.data.items)

    updated = production_api.update_order_api(
        order_id=order_id,
        payload=OrderUpdate(
            product_id=product.id,
            quantity=15,
            process_codes=[process_cut.code, process_assembly.code],
            remark="更新后的订单",
        ),
        db=db,
        current_user=admin,
    )
    assert updated.data.quantity == 15
    assert updated.data.pipeline_enabled is False
    assert updated.data.remark == "更新后的订单"

    exported = production_api.export_orders_api(
        payload=OrdersExportRequest(keyword="PF-ORD"),
        db=db,
        current_user=admin,
    )
    assert exported.data.file_name.endswith(".csv")
    assert exported.data.exported_count >= 1
    assert base64.b64decode(exported.data.content_base64)

    completed = production_api.complete_order_api(
        order_id=order_id,
        db=db,
        current_user=admin,
    )
    assert completed.data.order_id == order_id
    assert completed.data.status == ORDER_STATUS_COMPLETED

    removable = _create_order(
        db,
        current_user=admin,
        order_code="PF-ORD-DELETE",
        product_id=product.id,
        quantity=4,
        process_codes=[process_cut.code],
    )
    deleted = production_api.delete_order_api(
        order_id=removable.id,
        db=db,
        current_user=admin,
    )
    assert deleted.data["deleted"] is True


def test_production_execution_assist_and_context_endpoints(db, factory) -> None:
    env = _prepare_production_env(db, factory)
    admin = env["system_admin"]
    helper = env["helper"]
    operator = env["operator"]
    product = env["product"]
    process_cut = env["process_cut"]

    created = _create_order(
        db,
        current_user=admin,
        order_code="PF-ASSIST-001",
        product_id=product.id,
        quantity=3,
        process_codes=[process_cut.code],
    )
    order_id = created.id

    process_row = db.execute(
        select(ProductionOrderProcess)
        .where(ProductionOrderProcess.order_id == order_id)
        .order_by(ProductionOrderProcess.process_order.asc())
    ).scalars().first()
    assert process_row is not None

    my_orders_before = production_api.get_my_orders_api(
        keyword=None,
        page=1,
        page_size=30,
        view_mode="own",
        proxy_operator_user_id=None,
        db=db,
        current_user=operator,
    )
    assert my_orders_before.data.total == 1
    assert my_orders_before.data.items[0].can_first_article is True

    context_before = production_api.get_my_order_context_api(
        order_id=order_id,
        view_mode="own",
        order_process_id=None,
        proxy_operator_user_id=None,
        db=db,
        current_user=operator,
    )
    assert context_before.data.found is True
    assert context_before.data.item is not None
    assert context_before.data.item.current_process_id == process_row.id

    assist_created = production_api.create_assist_authorization_api(
        order_id=order_id,
        payload=AssistAuthorizationCreateRequest(
            order_process_id=process_row.id,
            target_operator_user_id=operator.id,
            helper_user_id=helper.id,
            reason="功能测试代班",
        ),
        db=db,
        current_user=operator,
    )
    assist_id = assist_created.data.id
    assert assist_created.data.status == "pending"

    assist_reviewed = production_api.review_assist_authorization_api(
        authorization_id=assist_id,
        payload=AssistAuthorizationReviewRequest(
            approve=True,
            review_remark="同意代班",
        ),
        db=db,
        current_user=admin,
    )
    assert assist_reviewed.data.status == "approved"

    assist_list = production_api.get_assist_authorizations_api(
        page=1,
        page_size=20,
        status_text="approved",
        db=db,
        current_user=helper,
    )
    assert assist_list.data.total == 1
    assert assist_list.data.items[0].id == assist_id

    assist_context = production_api.get_my_order_context_api(
        order_id=order_id,
        view_mode="assist",
        db=db,
        current_user=helper,
    )
    assert assist_context.data.found is True
    assert assist_context.data.item is not None
    assert assist_context.data.item.assist_authorization_id == assist_id

    first_article = production_api.submit_first_article_api(
        order_id=order_id,
        payload=FirstArticleRequest(
            order_process_id=process_row.id,
            verification_code=settings.production_default_verification_code,
            effective_operator_user_id=operator.id,
            assist_authorization_id=assist_id,
        ),
        db=db,
        current_user=helper,
    )
    assert first_article.data.status == ORDER_STATUS_IN_PROGRESS

    end_production = production_api.end_production_api(
        order_id=order_id,
        payload=EndProductionRequest(
            order_process_id=process_row.id,
            quantity=3,
            effective_operator_user_id=operator.id,
            assist_authorization_id=assist_id,
            defect_items=[],
        ),
        db=db,
        current_user=helper,
    )
    assert end_production.data.status == ORDER_STATUS_COMPLETED

    assist_after = production_api.get_my_orders_api(
        keyword=None,
        page=1,
        page_size=30,
        view_mode="assist",
        proxy_operator_user_id=None,
        db=db,
        current_user=helper,
    )
    assert assist_after.data.total == 0

    user_options = production_api.get_assist_user_options_api(
        page=1,
        page_size=50,
        keyword="prod_func_operator",
        role_code="operator",
        db=db,
        _=admin,
    )
    assert user_options.data.total >= 1
    assert any(item.id == operator.id for item in user_options.data.items)


def test_production_statistics_and_data_query_endpoints(db, factory) -> None:
    env = _prepare_production_env(db, factory)
    admin = env["system_admin"]
    operator = env["operator"]
    product = env["product"]
    stage_cut = env["stage_cut"]
    stage_assembly = env["stage_assembly"]
    process_cut = env["process_cut"]
    process_assembly = env["process_assembly"]

    order_pending = factory.order(
        product=product,
        order_code="PF-DATA-PENDING",
        quantity=10,
        status=ORDER_STATUS_PENDING,
    )
    order_running = factory.order(
        product=product,
        order_code="PF-DATA-RUNNING",
        quantity=10,
        status=ORDER_STATUS_IN_PROGRESS,
    )
    order_done = factory.order(
        product=product,
        order_code="PF-DATA-DONE",
        quantity=5,
        status=ORDER_STATUS_COMPLETED,
    )

    pending_cut = factory.order_process(
        order=order_pending,
        process=process_cut,
        stage=stage_cut,
        process_order=1,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=10,
        completed_quantity=0,
    )
    pending_assembly = factory.order_process(
        order=order_pending,
        process=process_assembly,
        stage=stage_assembly,
        process_order=2,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=10,
        completed_quantity=0,
    )
    running_cut = factory.order_process(
        order=order_running,
        process=process_cut,
        stage=stage_cut,
        process_order=1,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=10,
        completed_quantity=10,
    )
    running_assembly = factory.order_process(
        order=order_running,
        process=process_assembly,
        stage=stage_assembly,
        process_order=2,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=10,
        completed_quantity=3,
    )
    done_cut = factory.order_process(
        order=order_done,
        process=process_cut,
        stage=stage_cut,
        process_order=1,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=5,
        completed_quantity=5,
    )
    done_assembly = factory.order_process(
        order=order_done,
        process=process_assembly,
        stage=stage_assembly,
        process_order=2,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=5,
        completed_quantity=5,
    )

    now = datetime.now(UTC)
    rec1 = factory.production_record(
        order=order_running,
        process_row=running_cut,
        operator=operator,
        quantity=4,
    )
    rec1.created_at = now
    rec2 = factory.production_record(
        order=order_running,
        process_row=running_assembly,
        operator=operator,
        quantity=3,
    )
    rec2.created_at = now + timedelta(minutes=10)
    rec3 = factory.production_record(
        order=order_pending,
        process_row=pending_assembly,
        operator=operator,
        quantity=2,
    )
    rec3.created_at = now - timedelta(days=1)
    rec4 = factory.production_record(
        order=order_done,
        process_row=done_assembly,
        operator=operator,
        quantity=5,
    )
    rec4.created_at = now - timedelta(days=2)
    db.commit()

    overview = production_api.get_overview_stats_api(db=db, _=admin)
    assert overview.data.total_orders == 3
    assert overview.data.pending_orders == 1
    assert overview.data.in_progress_orders == 1
    assert overview.data.completed_orders == 1

    process_stats = production_api.get_process_stats_api(db=db, _=admin)
    assert any(item.process_code == process_cut.code for item in process_stats.data.items)
    assert any(item.process_code == process_assembly.code for item in process_stats.data.items)

    operator_stats = production_api.get_operator_stats_api(db=db, _=admin)
    assert any(item.operator_user_id == operator.id for item in operator_stats.data.items)

    today_main = production_api.get_today_realtime_data_api(
        stat_mode="main_order",
        product_ids=str(product.id),
        stage_ids=None,
        process_ids=None,
        operator_user_ids=str(operator.id),
        order_status="all",
        db=db,
        _=admin,
    )
    today_sub = production_api.get_today_realtime_data_api(
        stat_mode="sub_order",
        product_ids=str(product.id),
        stage_ids=None,
        process_ids=None,
        operator_user_ids=str(operator.id),
        order_status="all",
        db=db,
        _=admin,
    )
    assert today_main.data.summary.total_quantity == 3
    assert today_sub.data.summary.total_quantity == 7

    unfinished = production_api.get_unfinished_progress_data_api(
        product_ids=str(product.id),
        stage_ids=None,
        process_ids=None,
        operator_user_ids=None,
        order_status="all",
        db=db,
        _=admin,
    )
    by_code = {item.order_code: item for item in unfinished.data.table_rows}
    assert unfinished.data.summary.total_orders == 2
    assert by_code["PF-DATA-PENDING"].progress_percent == 10.0
    assert by_code["PF-DATA-RUNNING"].progress_percent == 35.0

    manual = production_api.get_manual_production_data_api(
        stat_mode="sub_order",
        start_date=date.today() - timedelta(days=1),
        end_date=date.today(),
        product_ids=str(product.id),
        stage_ids=None,
        process_ids=None,
        operator_user_ids=str(operator.id),
        order_status="all",
        db=db,
        _=admin,
    )
    assert manual.data.summary.filtered_total == 9
    assert manual.data.summary.rows >= 2

    manual_export = production_api.export_manual_production_data_api(
        payload=ProductionDataManualExportRequest(
            stat_mode="sub_order",
            start_date=date.today() - timedelta(days=1),
            end_date=date.today(),
            product_ids=[product.id],
            operator_user_ids=[operator.id],
            order_status="all",
        ),
        db=db,
        current_user=admin,
    )
    assert manual_export.data.file_name.endswith(".csv")
    assert base64.b64decode(manual_export.data.content_base64)

    export_events = db.execute(
        select(OrderEventLog).where(OrderEventLog.event_type == "production_data_manual_export")
    ).scalars().all()
    assert len(export_events) >= 1


def test_production_repair_and_scrap_endpoints(db, factory) -> None:
    env = _prepare_production_env(db, factory)
    admin = env["system_admin"]
    operator = env["operator"]
    product = env["product"]
    process_cut = env["process_cut"]

    created = _create_order(
        db,
        current_user=admin,
        order_code="PF-REPAIR-001",
        product_id=product.id,
        quantity=6,
        process_codes=[process_cut.code],
    )
    order_id = created.id
    process_row = db.execute(
        select(ProductionOrderProcess)
        .where(ProductionOrderProcess.order_id == order_id)
        .order_by(ProductionOrderProcess.process_order.asc())
    ).scalars().first()
    assert process_row is not None

    repair_created = production_api.create_manual_repair_order_api(
        order_id=order_id,
        payload=RepairOrderCreateRequest(
            order_process_id=process_row.id,
            production_quantity=3,
            defect_items=[
                ProductionDefectItem(phenomenon="毛刺", quantity=1),
                ProductionDefectItem(phenomenon="划伤", quantity=2),
            ],
        ),
        db=db,
        current_user=operator,
    )
    repair_id = repair_created.data.id
    assert repair_created.data.status == "in_repair"

    repair_list = production_api.get_repair_orders_api(
        page=1,
        page_size=20,
        keyword="PF-REPAIR-001",
        status_text="in_repair",
        start_date=None,
        end_date=None,
        db=db,
        _=admin,
    )
    assert repair_list.data.total == 1
    assert repair_list.data.items[0].id == repair_id

    repair_detail = production_api.get_repair_order_detail_api(
        repair_order_id=repair_id,
        db=db,
        _=admin,
    )
    assert repair_detail.data.repair_order_code == repair_created.data.repair_order_code
    assert len(repair_detail.data.defect_rows) == 2

    phenomena_summary = production_api.get_repair_order_phenomena_summary_api(
        repair_order_id=repair_id,
        db=db,
        _=admin,
    )
    assert len(phenomena_summary.data.items) == 2
    assert sum(item.quantity for item in phenomena_summary.data.items) == 3

    repair_completed = production_api.complete_repair_order_api(
        repair_order_id=repair_id,
        payload=RepairOrderCompleteRequest(
            cause_items=[
                RepairCauseItem(
                    phenomenon="毛刺",
                    reason="刀具磨损",
                    quantity=1,
                    is_scrap=True,
                ),
                RepairCauseItem(
                    phenomenon="划伤",
                    reason="二次加工",
                    quantity=2,
                    is_scrap=False,
                ),
            ],
            scrap_replenished=True,
            return_allocations=[
                RepairReturnAllocationItem(
                    target_order_process_id=process_row.id,
                    quantity=2,
                )
            ],
        ),
        db=db,
        current_user=admin,
    )
    assert repair_completed.data.status == "completed"
    assert repair_completed.data.scrap_quantity == 1
    assert repair_completed.data.repaired_quantity == 2

    scrap_list = production_api.get_scrap_statistics_api(
        page=1,
        page_size=20,
        keyword="PF-REPAIR-001",
        progress="pending_apply",
        start_date=None,
        end_date=None,
        db=db,
        _=admin,
    )
    assert scrap_list.data.total >= 1
    scrap_id = scrap_list.data.items[0].id

    scrap_detail = production_api.get_scrap_statistics_detail_api(
        scrap_id=scrap_id,
        db=db,
        _=admin,
    )
    assert scrap_detail.data.scrap_reason == "刀具磨损"

    scrap_export = production_api.export_scrap_statistics_api(
        payload=ScrapStatisticsExportRequest(
            keyword="PF-REPAIR-001",
            progress="all",
        ),
        db=db,
        current_user=admin,
    )
    assert scrap_export.data.file_name.endswith(".csv")
    assert scrap_export.data.exported_count >= 1
    assert base64.b64decode(scrap_export.data.content_base64)

    repair_export = production_api.export_repair_orders_api(
        payload=RepairOrdersExportRequest(
            keyword="PF-REPAIR-001",
            status="all",
        ),
        db=db,
        current_user=admin,
    )
    assert repair_export.data.file_name.endswith(".csv")
    assert repair_export.data.exported_count >= 1
    assert base64.b64decode(repair_export.data.content_base64)

    scrap_rows = db.execute(
        select(ProductionScrapStatistics).where(ProductionScrapStatistics.order_id == order_id)
    ).scalars().all()
    assert scrap_rows
    assert all(row.progress == "applied" for row in scrap_rows)


def test_production_endpoints_validation_errors(db, factory) -> None:
    env = _prepare_production_env(db, factory)
    admin = env["system_admin"]

    with pytest.raises(HTTPException) as invalid_order_status:
        production_api.get_orders(
            page=1,
            page_size=20,
            keyword=None,
            status_text="bad_status",
            product_name=None,
            pipeline_enabled=None,
            start_date_from=None,
            start_date_to=None,
            due_date_from=None,
            due_date_to=None,
            db=db,
            _=admin,
        )
    assert invalid_order_status.value.status_code == 400

    with pytest.raises(HTTPException) as invalid_id_list:
        production_api.get_today_realtime_data_api(
            stat_mode="main_order",
            product_ids="1,a",
            stage_ids=None,
            process_ids=None,
            operator_user_ids=None,
            order_status="all",
            db=db,
            _=admin,
        )
    assert invalid_id_list.value.status_code == 400

    with pytest.raises(HTTPException) as invalid_role_code:
        production_api.get_assist_user_options_api(
            page=1,
            page_size=20,
            keyword=None,
            role_code="invalid_role",
            db=db,
            _=admin,
        )
    assert invalid_role_code.value.status_code == 400

    with pytest.raises(HTTPException) as repair_not_found:
        production_api.get_repair_order_detail_api(
            repair_order_id=99999,
            db=db,
            _=admin,
        )
    assert repair_not_found.value.status_code == 404

    with pytest.raises(HTTPException) as scrap_not_found:
        production_api.get_scrap_statistics_detail_api(
            scrap_id=99999,
            db=db,
            _=admin,
        )
    assert scrap_not_found.value.status_code == 404
