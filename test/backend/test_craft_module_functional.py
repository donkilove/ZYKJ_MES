from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1.endpoints import craft
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.schemas.craft import (
    CraftProcessCreate,
    CraftProcessUpdate,
    ProcessStageCreate,
    ProcessStageUpdate,
    ProductProcessTemplateCreate,
    ProductProcessTemplateUpdate,
    SystemMasterTemplateUpsertRequest,
    TemplateBatchImportItem,
    TemplateBatchImportRequest,
    TemplateCopyRequest,
    TemplatePublishRequest,
    TemplateRollbackRequest,
    TemplateStepPayload,
)


def test_craft_stage_process_references_and_delete_guards(db, factory) -> None:
    admin = factory.user(username="craft_func_admin_1", role_codes=[ROLE_SYSTEM_ADMIN])

    created_stage = craft.create_stage_api(
        ProcessStageCreate(code="91", name="Stage 91", sort_order=1),
        db=db,
        _=admin,
    )
    stage_id = created_stage.data.id
    assert created_stage.message == "created"

    listed_stage = craft.get_stages(
        page=1,
        page_size=20,
        keyword="91",
        enabled=None,
        db=db,
        _=admin,
    )
    assert listed_stage.data.total == 1
    assert listed_stage.data.items[0].process_count == 0

    updated_stage = craft.update_stage_api(
        stage_id=stage_id,
        payload=ProcessStageUpdate(code="91A", name="Stage 91A", sort_order=2, is_enabled=True),
        db=db,
        _=admin,
    )
    assert updated_stage.data.code == "91A"

    created_process = craft.create_process_api(
        CraftProcessCreate(code="91A-01", name="Process 91A-01", stage_id=stage_id),
        db=db,
        _=admin,
    )
    process_id = created_process.data.id

    listed_process = craft.get_processes_api(
        page=1,
        page_size=20,
        keyword="91A",
        stage_id=stage_id,
        enabled=None,
        db=db,
        _=admin,
    )
    assert listed_process.data.total == 1

    updated_process = craft.update_process_api(
        process_id=process_id,
        payload=CraftProcessUpdate(
            code="91A-02",
            name="Process 91A-02",
            stage_id=stage_id,
            is_enabled=True,
        ),
        db=db,
        _=admin,
    )
    assert updated_process.data.code == "91A-02"

    stage_row = db.get(ProcessStage, stage_id)
    process_row = db.get(Process, process_id)
    assert stage_row is not None
    assert process_row is not None

    stage_user = factory.user(username="craft_stage_user", role_codes=[ROLE_SYSTEM_ADMIN])
    stage_user.stage_id = stage_id

    product = factory.product(name="craft-ref-product")
    created_template = craft.create_template_api(
        ProductProcessTemplateCreate(
            product_id=product.id,
            template_name="craft-ref-template",
            is_default=True,
            lifecycle_status="draft",
            steps=[
                TemplateStepPayload(step_order=1, stage_id=stage_id, process_id=process_id),
            ],
        ),
        db=db,
        current_user=admin,
    )
    template_id = created_template.data.template.id

    order = factory.order(product=product, order_code="CFT-ORD-REF", status="in_progress")
    factory.order_process(
        order=order,
        process=process_row,
        stage=stage_row,
        process_order=1,
        status="in_progress",
    )
    db.commit()

    stage_refs = craft.get_stage_references_api(stage_id=stage_id, db=db, _=admin)
    stage_ref_types = {item.ref_type for item in stage_refs.data.items}
    assert {"process", "user", "template", "order"}.issubset(stage_ref_types)

    process_refs = craft.get_process_references_api(process_id=process_id, db=db, _=admin)
    process_ref_types = {item.ref_type for item in process_refs.data.items}
    assert {"template", "order"}.issubset(process_ref_types)

    with pytest.raises(HTTPException) as delete_stage_error:
        craft.delete_stage_api(stage_id=stage_id, db=db, _=admin)
    assert delete_stage_error.value.status_code == 400

    with pytest.raises(HTTPException) as delete_process_error:
        craft.delete_process_api(process_id=process_id, db=db, _=admin)
    assert delete_process_error.value.status_code == 400

    temp_stage = craft.create_stage_api(
        ProcessStageCreate(code="91B", name="Stage 91B", sort_order=10),
        db=db,
        _=admin,
    ).data
    temp_process = craft.create_process_api(
        CraftProcessCreate(code="91B-01", name="Process 91B-01", stage_id=temp_stage.id),
        db=db,
        _=admin,
    ).data
    deleted_process = craft.delete_process_api(process_id=temp_process.id, db=db, _=admin)
    assert deleted_process.data["deleted"] is True
    deleted_stage = craft.delete_stage_api(stage_id=temp_stage.id, db=db, _=admin)
    assert deleted_stage.data["deleted"] is True

    # keep referenced data alive for guard assertions only
    assert template_id > 0


def test_craft_system_master_and_template_lifecycle_flow(db, factory) -> None:
    admin = factory.user(username="craft_func_admin_2", role_codes=[ROLE_SYSTEM_ADMIN])
    product_a = factory.product(name="craft-product-a")
    product_b = factory.product(name="craft-product-b")

    stage_a = craft.create_stage_api(
        ProcessStageCreate(code="92", name="Stage 92", sort_order=1),
        db=db,
        _=admin,
    ).data
    stage_b = craft.create_stage_api(
        ProcessStageCreate(code="93", name="Stage 93", sort_order=2),
        db=db,
        _=admin,
    ).data

    process_a = craft.create_process_api(
        CraftProcessCreate(code="92-01", name="Process 92-01", stage_id=stage_a.id),
        db=db,
        _=admin,
    ).data
    process_b = craft.create_process_api(
        CraftProcessCreate(code="93-01", name="Process 93-01", stage_id=stage_b.id),
        db=db,
        _=admin,
    ).data

    empty_master = craft.get_system_master_template_api(db=db, _=admin)
    assert empty_master.data is None

    master_created = craft.create_system_master_template_api(
        payload=SystemMasterTemplateUpsertRequest(
            steps=[TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id)]
        ),
        db=db,
        current_user=admin,
    )
    assert master_created.data.id == 1
    assert master_created.data.version == 1

    master_updated = craft.update_system_master_template_api(
        payload=SystemMasterTemplateUpsertRequest(
            steps=[
                TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id),
                TemplateStepPayload(step_order=2, stage_id=stage_b.id, process_id=process_b.id),
            ]
        ),
        db=db,
        current_user=admin,
    )
    assert master_updated.data.version == 2
    assert len(master_updated.data.steps) == 2
    master_versions = craft.list_system_master_template_versions_api(db=db, _=admin)
    assert master_versions.data.total >= 2

    created_template = craft.create_template_api(
        payload=ProductProcessTemplateCreate(
            product_id=product_a.id,
            template_name="craft-main-template",
            is_default=True,
            lifecycle_status="draft",
            steps=[
                TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id),
            ],
        ),
        db=db,
        current_user=admin,
    )
    template_id = created_template.data.template.id
    assert created_template.data.template.lifecycle_status == "draft"

    listed_templates = craft.get_templates_api(
        page=1,
        page_size=20,
        product_id=product_a.id,
        keyword=None,
        enabled=None,
        lifecycle_status=None,
        db=db,
        _=admin,
    )
    assert listed_templates.data.total == 1
    product_refs = craft.get_product_template_references_api(
        product_id=product_a.id,
        db=db,
        _=admin,
    )
    assert product_refs.data.product_id == product_a.id
    assert product_refs.data.total_templates >= 1

    detail = craft.get_template_detail_api(template_id=template_id, db=db, _=admin)
    assert len(detail.data.steps) == 1

    disabled = craft.disable_template_api(template_id=template_id, db=db, current_user=admin)
    assert disabled.data.template.is_enabled is False
    assert disabled.data.template.lifecycle_status == "draft"

    enabled = craft.enable_template_api(template_id=template_id, db=db, current_user=admin)
    assert enabled.data.template.is_enabled is True
    assert enabled.data.template.lifecycle_status == "draft"

    published_v1 = craft.publish_template_api(
        template_id=template_id,
        payload=TemplatePublishRequest(apply_order_sync=False, confirmed=False, note="publish-v1"),
        db=db,
        current_user=admin,
    )
    assert published_v1.data.detail.template.lifecycle_status == "published"
    assert published_v1.data.detail.template.published_version == 1

    updated_template = craft.update_template_api(
        template_id=template_id,
        payload=ProductProcessTemplateUpdate(
            template_name="craft-main-template-v2",
            is_default=True,
            is_enabled=True,
            steps=[
                TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id),
                TemplateStepPayload(step_order=2, stage_id=stage_b.id, process_id=process_b.id),
            ],
            sync_orders=False,
        ),
        db=db,
        current_user=admin,
    )
    assert updated_template.data.detail.template.lifecycle_status == "draft"
    assert len(updated_template.data.detail.steps) == 2

    published_v2 = craft.publish_template_api(
        template_id=template_id,
        payload=TemplatePublishRequest(apply_order_sync=False, confirmed=False, note="publish-v2"),
        db=db,
        current_user=admin,
    )
    assert published_v2.data.detail.template.published_version == 2

    versions = craft.list_template_versions_api(template_id=template_id, db=db, _=admin)
    assert versions.data.total >= 2

    compare_result = craft.compare_template_versions_api(
        template_id=template_id,
        from_version=1,
        to_version=2,
        db=db,
        _=admin,
    )
    assert compare_result.data.from_version == 1
    assert compare_result.data.to_version == 2
    assert compare_result.data.added_steps >= 1

    rolled_back = craft.rollback_template_api(
        template_id=template_id,
        payload=TemplateRollbackRequest(
            target_version=1,
            apply_order_sync=False,
            confirmed=False,
            note="rollback-to-v1",
        ),
        db=db,
        current_user=admin,
    )
    assert rolled_back.data.detail.template.lifecycle_status == "published"
    assert rolled_back.data.detail.template.published_version == 3

    archived = craft.archive_template_api(template_id=template_id, db=db, current_user=admin)
    assert archived.data.template.lifecycle_status == "archived"

    unarchived = craft.unarchive_template_api(template_id=template_id, db=db, current_user=admin)
    assert unarchived.data.template.lifecycle_status == "published"

    copied = craft.copy_template_api(
        template_id=template_id,
        body=TemplateCopyRequest(new_name="craft-main-template-copy"),
        db=db,
        current_user=admin,
    )
    copied_template_id = copied.data.template.id
    assert copied.data.template.lifecycle_status == "draft"

    exported = craft.export_templates_api(
        product_id=product_a.id,
        enabled=None,
        lifecycle_status=None,
        db=db,
        _=admin,
    )
    assert exported.data.total >= 2
    assert any(item.template_name == "craft-main-template-v2" for item in exported.data.items)

    imported = craft.import_templates_api(
        payload=TemplateBatchImportRequest(
            overwrite_existing=False,
            publish_after_import=False,
            items=[
                TemplateBatchImportItem(
                    product_id=product_b.id,
                    product_name=None,
                    template_name="craft-imported-template",
                    is_default=True,
                    is_enabled=True,
                    lifecycle_status="draft",
                    steps=[
                        TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id),
                    ],
                ),
                TemplateBatchImportItem(
                    product_id=999999,
                    product_name=None,
                    template_name="craft-import-invalid",
                    is_default=False,
                    is_enabled=True,
                    lifecycle_status="draft",
                    steps=[
                        TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id),
                    ],
                ),
            ],
        ),
        db=db,
        current_user=admin,
    )
    assert imported.data.created >= 1
    assert imported.data.skipped >= 1
    assert len(imported.data.errors) >= 1

    deleted_copy = craft.delete_template_api(template_id=copied_template_id, db=db, _=admin)
    assert deleted_copy.data["deleted"] is True


def test_craft_template_sync_impact_and_kanban_flow(db, factory) -> None:
    admin = factory.user(username="craft_func_admin_3", role_codes=[ROLE_SYSTEM_ADMIN])
    operator = factory.user(username="craft_func_operator", role_codes=[ROLE_SYSTEM_ADMIN])
    product = factory.product(name="craft-metrics-product")

    stage_a = craft.create_stage_api(
        ProcessStageCreate(code="94", name="Stage 94", sort_order=1),
        db=db,
        _=admin,
    ).data
    stage_b = craft.create_stage_api(
        ProcessStageCreate(code="95", name="Stage 95", sort_order=2),
        db=db,
        _=admin,
    ).data
    process_a = craft.create_process_api(
        CraftProcessCreate(code="94-01", name="Process 94-01", stage_id=stage_a.id),
        db=db,
        _=admin,
    ).data
    process_b = craft.create_process_api(
        CraftProcessCreate(code="95-01", name="Process 95-01", stage_id=stage_b.id),
        db=db,
        _=admin,
    ).data

    created_template = craft.create_template_api(
        payload=ProductProcessTemplateCreate(
            product_id=product.id,
            template_name="craft-sync-template",
            is_default=True,
            lifecycle_status="draft",
            steps=[
                TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id),
            ],
        ),
        db=db,
        current_user=admin,
    )
    template_id = created_template.data.template.id

    pending_order = factory.order(product=product, order_code="CFT-ORD-SYNC", quantity=12, status="pending")
    pending_order.process_template_id = template_id
    pending_order.process_template_name = created_template.data.template.template_name
    pending_order.process_template_version = created_template.data.template.version
    db.commit()

    impact = craft.get_template_impact_analysis_api(template_id=template_id, db=db, _=admin)
    assert impact.data.total_orders == 1
    assert impact.data.pending_orders == 1
    assert impact.data.syncable_orders == 1
    assert impact.data.blocked_orders == 0

    with pytest.raises(HTTPException) as unconfirmed_publish_error:
        craft.publish_template_api(
            template_id=template_id,
            payload=TemplatePublishRequest(apply_order_sync=True, confirmed=False, note="sync-publish"),
            db=db,
            current_user=admin,
        )
    assert unconfirmed_publish_error.value.status_code == 400

    published = craft.publish_template_api(
        template_id=template_id,
        payload=TemplatePublishRequest(apply_order_sync=True, confirmed=True, note="sync-publish"),
        db=db,
        current_user=admin,
    )
    assert published.data.sync_result.total == 1
    assert published.data.sync_result.synced == 1
    assert published.data.sync_result.skipped == 0

    db.expire_all()
    pending_order_row = db.get(ProductionOrder, pending_order.id)
    assert pending_order_row is not None
    pending_steps = sorted(pending_order_row.processes, key=lambda item: item.process_order)
    assert len(pending_steps) == 1
    assert pending_steps[0].process_code == process_a.code

    craft.update_template_api(
        template_id=template_id,
        payload=ProductProcessTemplateUpdate(
            template_name="craft-sync-template-v2",
            is_default=True,
            is_enabled=True,
            steps=[
                TemplateStepPayload(step_order=1, stage_id=stage_a.id, process_id=process_a.id),
                TemplateStepPayload(step_order=2, stage_id=stage_b.id, process_id=process_b.id),
            ],
            sync_orders=False,
        ),
        db=db,
        current_user=admin,
    )

    republished = craft.publish_template_api(
        template_id=template_id,
        payload=TemplatePublishRequest(apply_order_sync=True, confirmed=True, note="sync-publish-v2"),
        db=db,
        current_user=admin,
    )
    assert republished.data.sync_result.total == 1
    assert republished.data.sync_result.synced == 1

    db.expire_all()
    pending_order_row = db.get(ProductionOrder, pending_order.id)
    assert pending_order_row is not None
    pending_steps = sorted(pending_order_row.processes, key=lambda item: item.process_order)
    assert len(pending_steps) == 2
    assert pending_order_row.current_process_code == process_a.code

    with pytest.raises(HTTPException) as delete_template_error:
        craft.delete_template_api(template_id=template_id, db=db, _=admin)
    assert delete_template_error.value.status_code == 400

    stage_a_row = db.get(ProcessStage, stage_a.id)
    process_a_row = db.get(Process, process_a.id)
    assert stage_a_row is not None
    assert process_a_row is not None

    completed_order = factory.order(product=product, order_code="CFT-ORD-METRIC", quantity=20, status="completed")
    completed_process = factory.order_process(
        order=completed_order,
        process=process_a_row,
        stage=stage_a_row,
        process_order=1,
        status="completed",
    )
    first_article = factory.production_record(
        order=completed_order,
        process_row=completed_process,
        operator=operator,
        quantity=0,
        record_type="first_article",
    )
    prod_a = factory.production_record(
        order=completed_order,
        process_row=completed_process,
        operator=operator,
        quantity=30,
        record_type="production",
    )
    prod_b = factory.production_record(
        order=completed_order,
        process_row=completed_process,
        operator=operator,
        quantity=20,
        record_type="production",
    )
    first_article.created_at = datetime.now(UTC) - timedelta(minutes=40)
    prod_a.created_at = datetime.now(UTC) - timedelta(minutes=30)
    prod_b.created_at = datetime.now(UTC) - timedelta(minutes=10)
    db.commit()

    kanban = craft.get_craft_kanban_process_metrics_api(
        product_id=product.id,
        limit=5,
        stage_id=stage_a.id,
        process_id=process_a.id,
        start_date=None,
        end_date=None,
        db=db,
        _=admin,
    )
    assert kanban.data.product_id == product.id
    assert len(kanban.data.items) >= 1
    first_item = kanban.data.items[0]
    assert first_item.process_id == process_a.id
    assert len(first_item.samples) >= 1
    assert first_item.samples[-1].production_qty == 50

    completed_rows = db.execute(
        select(ProductionOrderProcess).where(ProductionOrderProcess.order_id == completed_order.id)
    ).scalars().all()
    assert len(completed_rows) == 1
