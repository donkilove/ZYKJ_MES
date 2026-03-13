from __future__ import annotations

from datetime import date, timedelta
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import auth, craft, equipment, processes, production, products, quality, roles, ui, users
from app.core.config import settings
from app.core.production_constants import ORDER_STATUS_IN_PROGRESS
from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.core.security import get_password_hash
from app.models.process import Process
from app.models.role import Role
from app.models.user import User
from app.schemas.auth import ApproveRegistrationRequest, RegisterRequest, RejectRegistrationRequest
from app.schemas.craft import (
    CraftProcessCreate,
    ProcessStageCreate,
    ProductProcessTemplateCreate,
    ProductProcessTemplateUpdate,
    SystemMasterTemplateUpsertRequest,
    TemplateStepPayload,
)
from app.schemas.equipment import (
    EquipmentLedgerUpsertRequest,
    MaintenanceItemUpsertRequest,
    MaintenancePlanUpsertRequest,
    MaintenancePlanToggleRequest,
    MaintenanceWorkOrderCompleteRequest,
    ToggleEnabledRequest,
)
from app.schemas.process import ProcessCreate, ProcessUpdate
from app.schemas.product import ProductCreate, ProductDeleteRequest, ProductParameterInputItem, ProductParameterUpdateRequest
from app.schemas.production import (
    AssistAuthorizationCreateRequest,
    AssistAuthorizationReviewRequest,
    EndProductionRequest,
    FirstArticleRequest,
    OrderCreate,
    OrderPipelineModeUpdateRequest,
    OrderUpdate,
    ProductionDefectItem,
    RepairCauseItem,
    RepairOrderCompleteRequest,
    RepairOrderCreateRequest,
    RepairOrdersExportRequest,
    RepairReturnAllocationItem,
    ScrapStatisticsExportRequest,
)
from app.schemas.user import UserCreate, UserUpdate


def _auth_user(factory, username: str, role_code: str = ROLE_SYSTEM_ADMIN, password: str = "Passw0rd!") -> User:
    user = factory.user(username=username, role_codes=[role_code], password=password)
    return user


def test_auth_endpoints_login_register_and_me(db, factory) -> None:
    factory.ensure_default_roles()
    user = _auth_user(factory, "auth_admin", ROLE_SYSTEM_ADMIN, "Passw0rd!")
    db.commit()

    login_result = auth.login(SimpleNamespace(username="auth_admin", password="Passw0rd!"), request=None, db=db)
    assert login_result.data.access_token

    with pytest.raises(HTTPException):
        auth.login(SimpleNamespace(username="auth_admin", password="bad"), request=None, db=db)

    register_resp = auth.register(RegisterRequest(account="new_account", password="Passw0rd!"), db)
    assert register_resp.data.status == "pending_approval"

    accounts = auth.list_accounts(db)
    assert "auth_admin" in accounts.data.accounts

    me = auth.get_current_login_user(user)
    assert me.data.username == "auth_admin"


def test_auth_endpoints_admin_actions(db, factory) -> None:
    factory.ensure_default_roles()
    stage = factory.stage(code="71")
    process = factory.process(stage=stage, code="71-01")

    req = auth.register(RegisterRequest(account="pending_x", password="Passw0rd!"), db)
    request_id = req.data.account
    assert request_id == "pending_x"

    list_resp = auth.get_registration_requests(page=1, page_size=20, keyword=None, status_filter=None, db=db, _=factory.user(role_codes=[ROLE_SYSTEM_ADMIN]))
    assert list_resp.data.total >= 1

    db_req = auth.get_registration_requests(page=1, page_size=20, keyword="pending_x", status_filter=None, db=db, _=factory.user(role_codes=[ROLE_SYSTEM_ADMIN]))
    target = db_req.data.items[0]

    approved = auth.approve_registration(
        target.id,
        ApproveRegistrationRequest(account="pending_x", role_codes=[ROLE_OPERATOR], process_codes=[process.code], stage_id=stage.id),
        request=None,
        db=db,
        current_user=factory.user(role_codes=[ROLE_SYSTEM_ADMIN]),
    )
    assert approved.data.approved is True

    req2 = auth.register(RegisterRequest(account="pending_y", password="Passw0rd!"), db)
    db_req2 = auth.get_registration_requests(page=1, page_size=20, keyword="pending_y", status_filter=None, db=db, _=factory.user(role_codes=[ROLE_SYSTEM_ADMIN]))
    target2 = db_req2.data.items[0]
    rejected = auth.reject_registration(target2.id, RejectRegistrationRequest(), request=None, db=db, current_user=factory.user(role_codes=[ROLE_SYSTEM_ADMIN]))
    assert rejected.data.approved is False


def test_roles_processes_users_ui_endpoints(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="ep_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = factory.stage(code="72", name="阶段")
    db.commit()

    roles_resp = roles.get_roles(page=1, page_size=50, keyword=None, db=db, _=admin)
    assert roles_resp.data.total >= 1

    role_id = roles_resp.data.items[0].id
    role_detail = roles.get_role_detail(role_id, db=db, _=admin)
    assert role_detail.data.id == role_id

    proc_created = processes.create_process_api(
        ProcessCreate(code=f"{stage.code}-01", name="P-EP", stage_id=stage.id),
        db,
        _=admin,
    )
    assert proc_created.data.code == f"{stage.code}-01"

    proc_list = processes.get_processes(page=1, page_size=20, keyword=None, db=db, _=admin)
    assert proc_list.data.total >= 1

    proc_updated = processes.update_process_api(
        proc_created.data.id,
        ProcessUpdate(code=f"{stage.code}-02", name="P-EP2", stage_id=stage.id, is_enabled=True),
        db,
        _=admin,
    )
    assert proc_updated.data.code == f"{stage.code}-02"

    user_created = users.create_user_api(
        UserCreate(
            username="ep_user",
            full_name="EP User",
            password="EpUser@999",
            role_codes=[ROLE_QUALITY_ADMIN],
            process_codes=[],
        ),
        request=None,
        db=db,
        current_user=admin,
    )
    assert user_created.data.username == "ep_user"

    user_list = users.get_users(page=1, page_size=20, keyword=None, role_code=None, stage_id=None, is_active=None, include_deleted=False, db=db, _=admin)
    assert user_list.data.total >= 1

    user_detail = users.get_user_detail(user_created.data.id, db=db, _=admin)
    assert user_detail.data.id == user_created.data.id

    user_updated = users.update_user_api(
        user_created.data.id,
        UserUpdate(full_name="EP User Updated"),
        request=None,
        db=db,
        current_user=admin,
    )
    assert user_updated.data.full_name == "EP User Updated"

    catalog = ui.get_page_catalog(current_user=admin)
    assert len(catalog.data.items) > 0


def test_products_and_craft_endpoints(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="craft_admin", role_codes=[ROLE_SYSTEM_ADMIN])

    product_resp = products.create_product_api(ProductCreate(name="接口产品A"), db, current_user=admin)
    product_id = product_resp.data.id
    assert product_resp.data.lifecycle_status == "active"

    assert product_resp.data.effective_version >= 1

    kanban_empty = craft.get_craft_kanban_process_metrics_api(
        product_id=product_id,
        limit=5,
        db=db,
        _=admin,
    )
    assert kanban_empty.data.product_id == product_id
    assert kanban_empty.data.items == []

    products_list = products.get_products(page=1, page_size=20, keyword=None, category=None, db=db, _=admin)
    assert products_list.data.total >= 1

    param_resp = products.get_product_parameters(product_id, db, _=admin)
    assert param_resp.data.total >= 1

    updated_params = products.update_parameters(
        product_id,
        ProductParameterUpdateRequest(
            remark="接口更新",
            items=[
                ProductParameterInputItem(name=param_resp.data.items[0].name, category="基础参数", type="Text", value="接口产品A2"),
                ProductParameterInputItem(name="新增参数", category="扩展", type="Text", value="v"),
            ],
        ),
        db,
        current_user=admin,
    )
    assert updated_params.data.updated_count >= 1

    history = products.get_parameter_history(product_id, page=1, page_size=20, db=db, _=admin)
    assert history.data.total >= 1

    versions_resp = products.get_product_versions(product_id, db=db, _=admin)
    assert versions_resp.data.total >= 2

    compare_resp = products.compare_product_version_api(
        product_id,
        from_version=1,
        to_version=2,
        db=db,
        _=admin,
    )
    assert compare_resp.data.changed_items >= 1

    impact_resp = products.get_product_impact_analysis(
        product_id,
        operation="rollback",
        target_status=None,
        target_version=1,
        db=db,
        _=admin,
    )
    assert impact_resp.data.operation == "rollback"

    rollback_resp = products.rollback_product_api(
        product_id,
        products.ProductRollbackRequest(target_version=1, confirmed=False, note="回滚"),
        db=db,
        current_user=admin,
    )
    assert rollback_resp.data.product.current_version >= 3

    # craft stage/process/template flow
    stage_resp = craft.create_stage_api(ProcessStageCreate(code="73", name="工段73", sort_order=1), db, _=admin)
    process_resp = craft.create_process_api(
        CraftProcessCreate(code="73-01", name="工序73", stage_id=stage_resp.data.id),
        db,
        _=admin,
    )

    master_created = craft.create_system_master_template_api(
        SystemMasterTemplateUpsertRequest(
            steps=[TemplateStepPayload(step_order=1, stage_id=stage_resp.data.id, process_id=process_resp.data.id)]
        ),
        db,
        current_user=admin,
    )
    assert master_created.data.id == 1

    master_get = craft.get_system_master_template_api(db=db, _=admin)
    assert master_get.data is not None

    master_updated = craft.update_system_master_template_api(
        SystemMasterTemplateUpsertRequest(
            steps=[TemplateStepPayload(step_order=1, stage_id=stage_resp.data.id, process_id=process_resp.data.id)]
        ),
        db,
        current_user=admin,
    )
    assert master_updated.data.version >= 2

    tpl_created = craft.create_template_api(
        ProductProcessTemplateCreate(
            product_id=product_id,
            template_name="接口模板",
            is_default=True,
            steps=[TemplateStepPayload(step_order=1, stage_id=stage_resp.data.id, process_id=process_resp.data.id)],
        ),
        db,
        current_user=admin,
    )
    tpl_id = tpl_created.data.template.id

    tpl_detail = craft.get_template_detail_api(tpl_id, db=db, _=admin)
    assert tpl_detail.data.template.id == tpl_id

    tpl_updated = craft.update_template_api(
        tpl_id,
        ProductProcessTemplateUpdate(
            template_name="接口模板2",
            is_default=True,
            is_enabled=True,
            steps=[TemplateStepPayload(step_order=1, stage_id=stage_resp.data.id, process_id=process_resp.data.id)],
            sync_orders=False,
        ),
        db,
        current_user=admin,
    )
    assert tpl_updated.data.detail.template.template_name == "接口模板2"


def test_production_quality_and_equipment_endpoints(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="prod_admin_ep", role_codes=[ROLE_SYSTEM_ADMIN])
    qa_admin = factory.user(username="qa_admin_ep", role_codes=[ROLE_QUALITY_ADMIN])

    stage = craft.create_stage_api(ProcessStageCreate(code="74", name="工段74", sort_order=1), db, _=admin)
    process = craft.create_process_api(
        CraftProcessCreate(code="74-01", name="工序74", stage_id=stage.data.id),
        db,
        _=admin,
    )
    stage_2 = craft.create_stage_api(ProcessStageCreate(code="75", name="工段75", sort_order=2), db, _=admin)
    process_2 = craft.create_process_api(
        CraftProcessCreate(code="75-01", name="工序75", stage_id=stage_2.data.id),
        db,
        _=admin,
    )
    operator = factory.user(username="prod_operator_ep", role_codes=[ROLE_OPERATOR], processes=[])
    unrelated_operator = factory.user(username="prod_operator_unrelated", role_codes=[ROLE_OPERATOR], processes=[])
    # operator uses process assignment by direct model relationship
    db_process = db.get(Process, process.data.id)
    db_process_2 = db.get(Process, process_2.data.id)
    assert db_process is not None
    assert db_process_2 is not None
    operator.processes = [db_process, db_process_2]
    db.commit()

    product_resp = products.create_product_api(ProductCreate(name="生产接口产品"), db, current_user=admin)
    order_resp = production.create_order_api(
        OrderCreate(
            order_code="EP-ORD-1",
            product_id=product_resp.data.id,
            quantity=5,
            process_codes=[process.data.code, process_2.data.code],
            template_id=None,
            process_steps=None,
            save_as_template=False,
            new_template_name=None,
            new_template_set_default=False,
        ),
        db,
        current_user=admin,
    )
    order_id = order_resp.data.id
    assert order_resp.data.product_version is not None

    order_list = production.get_orders(page=1, page_size=20, keyword=None, status_text=None, db=db, _=admin)
    assert order_list.data.total >= 1

    detail = production.get_order_detail_api(order_id, db=db, current_user=admin)
    assert detail.data.order.id == order_id
    process_id = detail.data.processes[0].id
    with pytest.raises(HTTPException) as detail_permission_error:
        production.get_order_detail_api(order_id, db=db, current_user=unrelated_operator)
    assert detail_permission_error.value.status_code == 403

    pipeline_mode = production.get_order_pipeline_mode_api(order_id, db=db, current_user=admin)
    assert pipeline_mode.data.enabled is False
    assert pipeline_mode.data.available_process_codes == [process.data.code, process_2.data.code]

    pipeline_mode_by_operator = production.get_order_pipeline_mode_api(order_id, db=db, current_user=operator)
    assert pipeline_mode_by_operator.data.order_id == order_id

    with pytest.raises(HTTPException) as no_permission_error:
        production.update_order_pipeline_mode_api(
            order_id,
            OrderPipelineModeUpdateRequest(enabled=True, process_codes=[process.data.code, process_2.data.code]),
            db=db,
            current_user=operator,
        )
    assert no_permission_error.value.status_code == 403

    with pytest.raises(HTTPException) as invalid_pipeline_error:
        production.update_order_pipeline_mode_api(
            order_id,
            OrderPipelineModeUpdateRequest(enabled=True, process_codes=[process.data.code]),
            db=db,
            current_user=admin,
        )
    assert invalid_pipeline_error.value.status_code == 400

    pipeline_updated = production.update_order_pipeline_mode_api(
        order_id,
        OrderPipelineModeUpdateRequest(enabled=True, process_codes=[process.data.code, process_2.data.code]),
        db=db,
        current_user=admin,
    )
    assert pipeline_updated.data.enabled is True

    my_orders = production.get_my_orders_api(keyword=None, page=1, page_size=20, db=db, current_user=operator)
    assert my_orders.data.total >= 1
    assert isinstance(my_orders.data.items[0].pipeline_mode_enabled, bool)
    assert isinstance(my_orders.data.items[0].pipeline_start_allowed, bool)
    assert isinstance(my_orders.data.items[0].pipeline_end_allowed, bool)

    first = production.submit_first_article_api(
        order_id,
        FirstArticleRequest(order_process_id=process_id, verification_code=settings.production_default_verification_code, remark=None),
        db,
        current_user=operator,
    )
    assert first.data.status == ORDER_STATUS_IN_PROGRESS

    end = production.end_production_api(
        order_id,
        EndProductionRequest(order_process_id=process_id, quantity=5, remark="done"),
        db,
        current_user=operator,
    )
    assert end.data.status in {"in_progress", "completed"}

    order_resp_2 = production.create_order_api(
        OrderCreate(
            order_code="EP-ORD-2",
            product_id=product_resp.data.id,
            quantity=2,
            process_codes=[process.data.code],
            template_id=None,
            process_steps=None,
            save_as_template=False,
            new_template_name=None,
            new_template_set_default=False,
        ),
        db,
        current_user=admin,
    )
    order_id_2 = order_resp_2.data.id
    detail_2 = production.get_order_detail_api(order_id_2, db=db, current_user=admin)
    process_id_2 = detail_2.data.processes[0].id

    with pytest.raises(HTTPException) as proxy_error:
        production.get_my_orders_api(
            keyword=None,
            page=1,
            page_size=20,
            view_mode="proxy",
            proxy_operator_user_id=None,
            db=db,
            current_user=admin,
        )
    assert proxy_error.value.status_code == 400

    assist_created = production.create_assist_authorization_api(
        order_id_2,
        AssistAuthorizationCreateRequest(
            order_process_id=process_id_2,
            target_operator_user_id=operator.id,
            helper_user_id=admin.id,
            reason="代班测试",
        ),
        db=db,
        current_user=operator,
    )
    assert assist_created.data.status == "approved"

    with pytest.raises(HTTPException) as duplicate_error:
        production.create_assist_authorization_api(
            order_id_2,
            AssistAuthorizationCreateRequest(
                order_process_id=process_id_2,
                target_operator_user_id=operator.id,
                helper_user_id=admin.id,
                reason="重复申请",
            ),
            db=db,
            current_user=operator,
        )
    assert duplicate_error.value.status_code == 409

    assist_list = production.get_assist_authorizations_api(
        page=1,
        page_size=20,
        status_text="approved",
        db=db,
        current_user=admin,
    )
    assert assist_list.data.total >= 1

    assist_user_options = production.get_assist_user_options_api(
        page=1,
        page_size=20,
        keyword=None,
        role_code=None,
        db=db,
        _=admin,
    )
    assert assist_user_options.data.total >= 2
    assert any(item.id == operator.id for item in assist_user_options.data.items)

    assist_operator_options = production.get_assist_user_options_api(
        page=1,
        page_size=20,
        keyword=None,
        role_code=ROLE_OPERATOR,
        db=db,
        _=admin,
    )
    assert assist_operator_options.data.total >= 1
    assert all(ROLE_OPERATOR in item.role_codes for item in assist_operator_options.data.items)

    assist_user_options_for_quality = production.get_assist_user_options_api(
        page=1,
        page_size=20,
        keyword=None,
        role_code=ROLE_OPERATOR,
        db=db,
        _=qa_admin,
    )
    assert assist_user_options_for_quality.data.total >= 1
    assert all(ROLE_OPERATOR in item.role_codes for item in assist_user_options_for_quality.data.items)

    with pytest.raises(HTTPException) as invalid_role_error:
        production.get_assist_user_options_api(
            page=1,
            page_size=20,
            keyword=None,
            role_code="invalid_role",
            db=db,
            _=admin,
        )
    assert invalid_role_error.value.status_code == 400

    with pytest.raises(HTTPException) as review_disabled_error:
        production.review_assist_authorization_api(
            authorization_id=assist_created.data.id,
            payload=AssistAuthorizationReviewRequest(approve=True, review_remark="ok"),
            db=db,
            current_user=admin,
        )
    assert review_disabled_error.value.status_code == 409

    assist_my_orders = production.get_my_orders_api(
        keyword=None,
        page=1,
        page_size=20,
        view_mode="assist",
        proxy_operator_user_id=None,
        db=db,
        current_user=admin,
    )
    assert assist_my_orders.data.total >= 1
    assist_item = assist_my_orders.data.items[0]
    assert assist_item.assist_authorization_id == assist_created.data.id

    assist_context = production.get_my_order_context_api(
        order_id_2,
        view_mode="assist",
        order_process_id=process_id_2,
        proxy_operator_user_id=None,
        db=db,
        current_user=admin,
    )
    assert assist_context.data.found is True
    assert assist_context.data.item is not None
    assert assist_context.data.item.assist_authorization_id == assist_created.data.id

    assist_first = production.submit_first_article_api(
        order_id_2,
        FirstArticleRequest(
            order_process_id=process_id_2,
            verification_code=settings.production_default_verification_code,
            remark="assist",
            effective_operator_user_id=operator.id,
            assist_authorization_id=assist_created.data.id,
        ),
        db,
        current_user=admin,
    )
    assert assist_first.data.status in {"in_progress", "pending"}

    assist_end = production.end_production_api(
        order_id_2,
        EndProductionRequest(
            order_process_id=process_id_2,
            quantity=2,
            remark="assist-done",
            effective_operator_user_id=operator.id,
            assist_authorization_id=assist_created.data.id,
        ),
        db,
        current_user=admin,
    )
    assert assist_end.data.status in {"in_progress", "completed"}

    consumed_context = production.get_my_order_context_api(
        order_id_2,
        view_mode="assist",
        order_process_id=process_id_2,
        proxy_operator_user_id=None,
        db=db,
        current_user=admin,
    )
    assert consumed_context.data.found is False
    assert consumed_context.data.item is None

    with pytest.raises(HTTPException) as consumed_error:
        production.end_production_api(
            order_id_2,
            EndProductionRequest(
                order_process_id=process_id_2,
                quantity=1,
                remark="retry",
                effective_operator_user_id=operator.id,
                assist_authorization_id=assist_created.data.id,
            ),
            db,
            current_user=admin,
        )
    assert consumed_error.value.status_code in {400, 404}

    order_resp_3 = production.create_order_api(
        OrderCreate(
            order_code="EP-ORD-3",
            product_id=product_resp.data.id,
            quantity=2,
            process_codes=[process.data.code],
            template_id=None,
            process_steps=None,
            save_as_template=False,
            new_template_name=None,
            new_template_set_default=False,
        ),
        db,
        current_user=admin,
    )
    order_id_3 = order_resp_3.data.id
    detail_3 = production.get_order_detail_api(order_id_3, db=db, current_user=admin)
    process_id_3 = detail_3.data.processes[0].id

    production.submit_first_article_api(
        order_id_3,
        FirstArticleRequest(
            order_process_id=process_id_3,
            verification_code=settings.production_default_verification_code,
            remark=None,
        ),
        db,
        current_user=operator,
    )
    production.end_production_api(
        order_id_3,
        EndProductionRequest(
            order_process_id=process_id_3,
            quantity=1,
            remark="auto-repair",
            defect_items=[ProductionDefectItem(phenomenon="毛刺", quantity=1)],
        ),
        db,
        current_user=operator,
    )

    repair_orders = production.get_repair_orders_api(
        page=1,
        page_size=20,
        keyword="EP-ORD-3",
        status_text="in_repair",
        start_date=None,
        end_date=None,
        db=db,
        _=qa_admin,
    )
    assert repair_orders.data.total >= 1
    auto_repair = repair_orders.data.items[0]

    manual_repair = production.create_manual_repair_order_api(
        order_id_3,
        RepairOrderCreateRequest(
            order_process_id=process_id_3,
            production_quantity=2,
            defect_items=[ProductionDefectItem(phenomenon="划伤", quantity=1)],
        ),
        db=db,
        current_user=operator,
    )
    assert manual_repair.data.status == "in_repair"

    phenomena_summary = production.get_repair_order_phenomena_summary_api(
        repair_order_id=auto_repair.id,
        db=db,
        _=qa_admin,
    )
    assert phenomena_summary.data.items

    completed_repair = production.complete_repair_order_api(
        repair_order_id=auto_repair.id,
        payload=RepairOrderCompleteRequest(
            cause_items=[
                RepairCauseItem(
                    phenomenon="毛刺",
                    reason="刀具磨损",
                    quantity=1,
                    is_scrap=True,
                )
            ],
            scrap_replenished=True,
            return_allocations=[],
        ),
        db=db,
        current_user=admin,
    )
    assert completed_repair.data.status == "completed"
    assert completed_repair.data.scrap_quantity == 1

    scrap_stats = production.get_scrap_statistics_api(
        page=1,
        page_size=20,
        keyword="EP-ORD-3",
        progress="all",
        start_date=None,
        end_date=None,
        db=db,
        _=qa_admin,
    )
    assert scrap_stats.data.total >= 1

    scrap_export = production.export_scrap_statistics_api(
        ScrapStatisticsExportRequest(
            keyword="EP-ORD-3",
            progress="all",
            start_date=None,
            end_date=None,
        ),
        db=db,
        current_user=admin,
    )
    assert scrap_export.data.content_base64
    assert scrap_export.data.file_name.endswith(".csv")

    repair_export = production.export_repair_orders_api(
        RepairOrdersExportRequest(
            keyword="EP-ORD-3",
            status="all",
            start_date=None,
            end_date=None,
        ),
        db=db,
        current_user=admin,
    )
    assert repair_export.data.content_base64
    assert repair_export.data.file_name.endswith(".csv")

    overview = production.get_overview_stats_api(db=db, _=qa_admin)
    assert overview.data.total_orders >= 1

    pstats = production.get_process_stats_api(db=db, _=qa_admin)
    assert len(pstats.data.items) >= 1

    ostats = production.get_operator_stats_api(db=db, _=qa_admin)
    assert len(ostats.data.items) >= 1

    q_list = quality.get_first_articles_api(query_date=date.today(), keyword=None, page=1, page_size=20, db=db, _=qa_admin)
    assert q_list.data.total >= 1

    q_overview = quality.get_quality_overview_api(start_date=None, end_date=None, db=db, _=qa_admin)
    assert q_overview.data.first_article_total >= 1

    q_process = quality.get_quality_process_stats_api(start_date=None, end_date=None, db=db, _=qa_admin)
    assert len(q_process.data.items) >= 1

    q_operator = quality.get_quality_operator_stats_api(start_date=None, end_date=None, db=db, _=qa_admin)
    assert len(q_operator.data.items) >= 1

    # equipment flow
    eq_resp = equipment.create_equipment_ledger(
        EquipmentLedgerUpsertRequest(code="EQ-EP-1", name="设备EP", model="M", location="L", owner_name="O"),
        db,
        _=admin,
    )
    item_resp = equipment.create_maintenance_item_api(
        MaintenanceItemUpsertRequest(name="保养EP", default_cycle_days=7),
        db,
        _=admin,
    )
    plan_resp = equipment.create_maintenance_plan_api(
        MaintenancePlanUpsertRequest(
            equipment_id=eq_resp.data.id,
            item_id=item_resp.data.id,
            cycle_days=None,
            execution_process_code=stage.data.code,
            estimated_duration_minutes=30,
            start_date=date.today() - timedelta(days=7),
            next_due_date=date.today(),
            default_executor_user_id=None,
        ),
        db,
        _=admin,
    )
    plan_id = plan_resp.data.id

    gen_resp = equipment.generate_plan_work_order_api(plan_id, db, _=admin)
    assert gen_resp.data.work_order_id > 0

    work_list = equipment.get_maintenance_executions(page=1, page_size=20, status_filter=None, keyword=None, mine=False, db=db, current_user=admin)
    assert work_list.data.total >= 1
    work_id = work_list.data.items[0].id

    started = equipment.start_maintenance_execution(work_id, db=db, current_user=admin)
    assert started.data.status == "in_progress"

    completed = equipment.complete_maintenance_execution(
        work_id,
        SimpleNamespace(result_summary="瀹屾垚", result_remark="ok", attachment_link=None),
        db,
        current_user=admin,
    )
    assert completed.data.status == "done"

    records = equipment.get_maintenance_records(
        page=1,
        page_size=20,
        keyword=None,
        executor_id=None,
        start_date=date.today() - timedelta(days=1),
        end_date=date.today() + timedelta(days=1),
        db=db,
        current_user=admin,
    )
    assert records.data.total >= 1
