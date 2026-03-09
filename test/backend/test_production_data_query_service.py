from __future__ import annotations

import base64
import csv
import io
from datetime import UTC, date, datetime, timedelta

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.deps import get_current_active_user, get_db
from app.api.v1.endpoints.production import router as production_router
from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_PENDING,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
)
from app.core.authz_catalog import (
    MODULE_PERMISSION_BY_MODULE_CODE,
    PAGE_PERMISSION_BY_PAGE_CODE,
)
from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.role_permission_grant import RolePermissionGrant
from app.models.order_event_log import OrderEventLog
from app.services import production_data_query_service
from app.services.authz_service import ensure_authz_defaults


def _prepare_production_data_env(db, factory):
    factory.ensure_default_roles()
    stage_a = factory.stage(code="71", name="工段A", sort_order=1)
    stage_b = factory.stage(code="72", name="工段B", sort_order=2)
    process_a = factory.process(stage=stage_a, code="71-01", name="工序A")
    process_b = factory.process(stage=stage_b, code="72-01", name="工序B")
    operator = factory.user(
        username="operator_data",
        role_codes=[ROLE_OPERATOR],
        processes=[process_a, process_b],
    )
    quality_admin = factory.user(username="quality_data", role_codes=[ROLE_QUALITY_ADMIN])
    production_admin = factory.user(username="prod_admin_data", role_codes=[ROLE_PRODUCTION_ADMIN])
    system_admin = factory.user(username="sys_admin_data", role_codes=[ROLE_SYSTEM_ADMIN])
    product = factory.product(name="统计产品")

    order_pending = factory.order(
        product=product,
        order_code="OD-PENDING-01",
        quantity=10,
        status=ORDER_STATUS_PENDING,
    )
    order_in_progress = factory.order(
        product=product,
        order_code="OD-RUNNING-01",
        quantity=10,
        status=ORDER_STATUS_IN_PROGRESS,
    )
    order_completed = factory.order(
        product=product,
        order_code="OD-DONE-01",
        quantity=5,
        status=ORDER_STATUS_COMPLETED,
    )

    pending_step_a = factory.order_process(
        order=order_pending,
        process=process_a,
        stage=stage_a,
        process_order=1,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=10,
        completed_quantity=0,
    )
    pending_step_b = factory.order_process(
        order=order_pending,
        process=process_b,
        stage=stage_b,
        process_order=2,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=10,
        completed_quantity=0,
    )
    running_step_a = factory.order_process(
        order=order_in_progress,
        process=process_a,
        stage=stage_a,
        process_order=1,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=10,
        completed_quantity=10,
    )
    running_step_b = factory.order_process(
        order=order_in_progress,
        process=process_b,
        stage=stage_b,
        process_order=2,
        status=PROCESS_STATUS_IN_PROGRESS,
        visible_quantity=10,
        completed_quantity=3,
    )
    done_step_a = factory.order_process(
        order=order_completed,
        process=process_a,
        stage=stage_a,
        process_order=1,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=5,
        completed_quantity=5,
    )
    done_step_b = factory.order_process(
        order=order_completed,
        process=process_b,
        stage=stage_b,
        process_order=2,
        status=PROCESS_STATUS_COMPLETED,
        visible_quantity=5,
        completed_quantity=5,
    )

    now = datetime.now(UTC)
    yesterday = now - timedelta(days=1)
    two_days_ago = now - timedelta(days=2)

    rec1 = factory.production_record(
        order=order_in_progress,
        process_row=running_step_a,
        operator=operator,
        quantity=4,
    )
    rec1.created_at = now
    rec2 = factory.production_record(
        order=order_in_progress,
        process_row=running_step_b,
        operator=operator,
        quantity=3,
    )
    rec2.created_at = now + timedelta(minutes=10)
    rec3 = factory.production_record(
        order=order_pending,
        process_row=pending_step_b,
        operator=operator,
        quantity=2,
    )
    rec3.created_at = yesterday
    rec4 = factory.production_record(
        order=order_completed,
        process_row=done_step_b,
        operator=operator,
        quantity=5,
    )
    rec4.created_at = two_days_ago
    db.commit()

    return {
        "product": product,
        "operator": operator,
        "quality_admin": quality_admin,
        "production_admin": production_admin,
        "system_admin": system_admin,
    }


def _build_test_client(db, *, current_user):
    app = FastAPI()
    app.include_router(production_router, prefix="/api/v1/production")

    def override_get_db():
        yield db

    user_ref = {"value": current_user}

    def override_current_active_user():
        return user_ref["value"]

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_active_user] = override_current_active_user
    return TestClient(app), user_ref


def test_today_realtime_supports_main_and_sub_modes(db, factory) -> None:
    env = _prepare_production_data_env(db, factory)
    product = env["product"]
    operator = env["operator"]

    today_filters_main = production_data_query_service.build_today_filters(
        stat_mode="main_order",
        product_ids=[product.id],
        stage_ids=None,
        process_ids=None,
        operator_user_ids=[operator.id],
        order_status="all",
    )
    today_filters_sub = production_data_query_service.build_today_filters(
        stat_mode="sub_order",
        product_ids=[product.id],
        stage_ids=None,
        process_ids=None,
        operator_user_ids=[operator.id],
        order_status="all",
    )

    main_result = production_data_query_service.get_today_realtime_data(
        db,
        filters=today_filters_main,
    )
    sub_result = production_data_query_service.get_today_realtime_data(
        db,
        filters=today_filters_sub,
    )

    assert main_result["summary"]["total_products"] == 1
    assert main_result["summary"]["total_quantity"] == 3
    assert sub_result["summary"]["total_quantity"] == 7
    assert main_result["table_rows"][0]["product_name"] == "统计产品"
    assert "today_realtime" in main_result["query_signature"]


def test_unfinished_progress_returns_expected_progress(db, factory) -> None:
    _prepare_production_data_env(db, factory)

    result = production_data_query_service.get_unfinished_progress_data(
        db,
        product_ids=None,
        stage_ids=None,
        process_ids=None,
        operator_user_ids=None,
        order_status="all",
    )

    assert result["summary"]["total_orders"] == 2
    by_code = {row["order_code"]: row for row in result["table_rows"]}
    assert by_code["OD-PENDING-01"]["progress_percent"] == 10.0
    assert by_code["OD-RUNNING-01"]["progress_percent"] == 35.0


def test_manual_query_and_export_match_filters(db, factory) -> None:
    env = _prepare_production_data_env(db, factory)
    product = env["product"]
    operator = env["operator"]
    production_admin = env["production_admin"]

    filters = production_data_query_service.build_manual_filters(
        stat_mode="sub_order",
        start_date=date.today() - timedelta(days=1),
        end_date=date.today(),
        product_ids=[product.id],
        stage_ids=None,
        process_ids=None,
        operator_user_ids=[operator.id],
        order_status="all",
    )
    result = production_data_query_service.get_manual_production_data(
        db,
        filters=filters,
    )
    assert result["summary"]["rows"] >= 2
    assert result["summary"]["filtered_total"] == 9
    assert len(result["chart_data"]["model_output"]) == 1
    assert "manual" in result["query_signature"]

    export_result = production_data_query_service.export_manual_production_data_csv(
        db,
        filters=filters,
        operator=production_admin,
    )
    decoded = base64.b64decode(export_result["content_base64"]).decode("utf-8-sig")
    csv_rows = list(csv.reader(io.StringIO(decoded)))
    assert csv_rows[0][0] == "订单编号"
    assert any(row[1] == "统计产品" for row in csv_rows[1:])

    event_count = db.execute(
        select(OrderEventLog)
        .where(OrderEventLog.event_type == "production_data_manual_export")
    ).scalars().all()
    assert len(event_count) >= 1


def test_new_endpoints_permissions_and_validation(db, factory) -> None:
    env = _prepare_production_data_env(db, factory)
    quality_admin = env["quality_admin"]
    production_admin = env["production_admin"]
    product = env["product"]
    ensure_authz_defaults(db)

    quality_code = ROLE_QUALITY_ADMIN
    prod_module_perm = MODULE_PERMISSION_BY_MODULE_CODE["production"]
    prod_data_page_perm = PAGE_PERMISSION_BY_PAGE_CODE["production_data_query"]
    db.query(RolePermissionGrant).filter(
        RolePermissionGrant.role_code == quality_code,
        RolePermissionGrant.permission_code.in_([prod_module_perm, prod_data_page_perm]),
    ).update({"granted": True}, synchronize_session=False)
    db.query(RolePermissionGrant).filter(
        RolePermissionGrant.role_code == ROLE_PRODUCTION_ADMIN,
        RolePermissionGrant.permission_code.in_(
            [
                prod_module_perm,
                prod_data_page_perm,
                "feature.production.data_export.use",
            ]
        ),
    ).update({"granted": True}, synchronize_session=False)
    db.commit()

    client, user_ref = _build_test_client(db, current_user=quality_admin)

    response = client.get(
        "/api/v1/production/data/today-realtime",
        params={"stat_mode": "main_order", "product_ids": str(product.id)},
    )
    assert response.status_code == 200

    export_response_forbidden = client.post(
        "/api/v1/production/data/manual/export",
        json={"stat_mode": "main_order"},
    )
    assert export_response_forbidden.status_code == 200

    invalid_date_response = client.get(
        "/api/v1/production/data/manual",
        params={
            "start_date": "2026-03-02",
            "end_date": "2026-03-01",
        },
    )
    assert invalid_date_response.status_code == 400

    user_ref["value"] = production_admin
    export_response = client.post(
        "/api/v1/production/data/manual/export",
        json={
            "stat_mode": "main_order",
            "product_ids": [product.id],
            "order_status": "all",
        },
    )
    assert export_response.status_code == 200
    payload = export_response.json()["data"]
    assert payload["file_name"].endswith(".csv")
    assert payload["content_base64"]
