from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.core.product_parameter_template import PRODUCT_NAME_PARAMETER_KEY
from app.models.product_parameter_history import ProductParameterHistory
from app.models.product_process_template import ProductProcessTemplate
from app.schemas.craft import ProductProcessTemplateUpdate
from app.services import craft_service, product_service


def test_craft_stage_and_process_crud(db, factory) -> None:
    stage = craft_service.create_stage(db, code="31", name="切割", sort_order=1)
    assert stage.code == "31"

    updated_stage = craft_service.update_stage(
        db,
        row=stage,
        name="切割2",
        sort_order=2,
        is_enabled=True,
        code="31A",
    )
    assert updated_stage.code == "31A"

    process = craft_service.create_process(db, code="31A-01", name="切割工序", stage_id=updated_stage.id)
    assert process.stage_id == updated_stage.id

    updated_process = craft_service.update_process(
        db,
        row=process,
        name="切割工序2",
        stage_id=updated_stage.id,
        is_enabled=False,
        code="31A-02",
    )
    assert updated_process.code == "31A-02"
    assert updated_process.is_enabled is False

    # delete process then stage
    craft_service.delete_process(db, row=updated_process)
    craft_service.delete_stage(db, row=updated_stage)


def test_craft_delete_stage_or_process_when_referenced(db, factory) -> None:
    operator = factory.user(username="op_craft", role_codes=[ROLE_SYSTEM_ADMIN])
    product = factory.product(name="P-craft")

    stage = craft_service.create_stage(db, code="32", name="装配", sort_order=1)
    process = craft_service.create_process(db, code="32-01", name="装配工序", stage_id=stage.id)

    template = craft_service.create_template(
        db,
        product_id=product.id,
        template_name="T1",
        is_default=True,
        steps=[{"step_order": 1, "stage_id": stage.id, "process_id": process.id}],
        operator=operator,
    )
    assert template.id > 0

    try:
        craft_service.delete_stage(db, row=stage)
        assert False, "expected ValueError"
    except ValueError as exc:
        assert "referenced" in str(exc)

    try:
        craft_service.delete_process(db, row=process)
        assert False, "expected ValueError"
    except ValueError as exc:
        assert "referenced" in str(exc)


def test_system_master_template_create_update_resolve(db, factory) -> None:
    operator = factory.user(username="admin_craft", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = craft_service.create_stage(db, code="33", name="测试", sort_order=1)
    process = craft_service.create_process(db, code="33-01", name="测试工序", stage_id=stage.id)

    created = craft_service.create_system_master_template(
        db,
        steps=[{"step_order": 1, "stage_id": stage.id, "process_id": process.id}],
        operator=operator,
    )
    assert created.version == 1
    assert len(created.steps) == 1

    resolved = craft_service.resolve_system_master_template(db)
    assert resolved.template is not None
    assert resolved.skip_reason is None

    updated = craft_service.update_system_master_template(
        db,
        steps=[{"step_order": 1, "stage_id": stage.id, "process_id": process.id}],
        operator=operator,
    )
    assert updated.version == 2


def test_system_master_template_resolve_skip_cases(db, factory) -> None:
    result = craft_service.resolve_system_master_template(db)
    assert result.template is None
    assert "No system master template" in (result.skip_reason or "")

    operator = factory.user(username="admin_skip", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = craft_service.create_stage(db, code="34", name="焊接", sort_order=1)
    process = craft_service.create_process(db, code="34-01", name="焊接工序", stage_id=stage.id)

    row = craft_service.create_system_master_template(
        db,
        steps=[{"step_order": 1, "stage_id": stage.id, "process_id": process.id}],
        operator=operator,
    )
    assert row.id == 1

    # Invalidate by disabling process
    craft_service.update_process(
        db,
        row=process,
        name=process.name,
        stage_id=stage.id,
        is_enabled=False,
        code=process.code,
    )
    skipped = craft_service.resolve_system_master_template(db)
    assert skipped.template is None
    assert "invalid" in (skipped.skip_reason or "")


def test_template_create_update_and_stage_helpers(db, factory) -> None:
    operator = factory.user(username="admin_tpl", role_codes=[ROLE_PRODUCTION_ADMIN])
    product = factory.product(name="P-template")
    stage = craft_service.create_stage(db, code="35", name="打标", sort_order=5)
    process = craft_service.create_process(db, code="35-01", name="打标工序", stage_id=stage.id)

    tpl = craft_service.create_template(
        db,
        product_id=product.id,
        template_name="模板A",
        is_default=False,
        steps=[{"step_order": 1, "stage_id": stage.id, "process_id": process.id}],
        operator=operator,
    )
    assert tpl.is_default is True

    updated, sync_result = craft_service.update_template(
        db,
        template=tpl,
        template_name="模板B",
        is_default=True,
        is_enabled=True,
        steps=[{"step_order": 1, "stage_id": stage.id, "process_id": process.id}],
        sync_orders=False,
        operator=operator,
    )
    assert updated.template_name == "模板B"
    assert sync_result.total == 0

    assert craft_service.is_valid_stage_code(db, "35") is True
    assert craft_service.is_valid_stage_code(db, "  ") is False
    enabled_stages = craft_service.list_enabled_stage_options(db)
    assert any(item.code == "35" for item in enabled_stages)
    stage_codes = craft_service.resolve_user_stage_codes(db, process_codes=[process.code, "missing"])
    assert stage_codes == {"35"}


def test_product_create_auto_clone_master_template(db, factory) -> None:
    operator = factory.user(username="prod_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = craft_service.create_stage(db, code="36", name="组装", sort_order=1)
    process = craft_service.create_process(db, code="36-01", name="组装工序", stage_id=stage.id)
    craft_service.create_system_master_template(
        db,
        steps=[{"step_order": 1, "stage_id": stage.id, "process_id": process.id}],
        operator=operator,
    )

    product = product_service.create_product(db, "产品A", operator=operator)
    assert product.name == "产品A"

    templates = db.query(ProductProcessTemplate).filter_by(product_id=product.id).all()
    assert len(templates) == 1
    assert templates[0].is_default is True
    assert templates[0].is_enabled is True
    assert len(templates[0].steps) == 1


def test_craft_kanban_metrics_returns_latest_five_samples(db, factory) -> None:
    operator = factory.user(username="kanban_operator", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = craft_service.create_stage(db, code="37", name="工段37", sort_order=1)
    process = craft_service.create_process(db, code="37-01", name="工序37", stage_id=stage.id)
    product = factory.product(name="看板产品A")

    base = datetime(2026, 3, 1, 8, 0, tzinfo=UTC)
    for index in range(6):
        order = factory.order(
            product=product,
            order_code=f"KB-{index + 1}",
            status="completed",
        )
        process_row = factory.order_process(
            order=order,
            process=process,
            stage=stage,
            process_order=1,
            status="completed",
        )
        first_article = factory.production_record(
            order=order,
            process_row=process_row,
            operator=operator,
            quantity=0,
            record_type="first_article",
        )
        production_a = factory.production_record(
            order=order,
            process_row=process_row,
            operator=operator,
            quantity=30 + index,
            record_type="production",
        )
        production_b = factory.production_record(
            order=order,
            process_row=process_row,
            operator=operator,
            quantity=10 + index,
            record_type="production",
        )
        first_article.created_at = base + timedelta(days=index)
        production_a.created_at = base + timedelta(days=index, minutes=10)
        production_b.created_at = base + timedelta(days=index, minutes=30)

    invalid_order = factory.order(product=product, order_code="KB-INVALID", status="completed")
    invalid_row = factory.order_process(
        order=invalid_order,
        process=process,
        stage=stage,
        process_order=1,
        status="completed",
    )
    invalid_record = factory.production_record(
        order=invalid_order,
        process_row=invalid_row,
        operator=operator,
        quantity=0,
        record_type="production",
    )
    invalid_record.created_at = base + timedelta(days=20)
    db.commit()

    result = craft_service.get_craft_kanban_process_metrics(
        db,
        product_id=product.id,
        limit=5,
    )
    assert result.product.id == product.id
    assert len(result.items) == 1

    samples = result.items[0].samples
    assert len(samples) == 5
    assert [item.order_code for item in samples] == ["KB-2", "KB-3", "KB-4", "KB-5", "KB-6"]
    assert all(item.work_minutes == 30 for item in samples)
    assert samples[-1].production_qty == 50
    assert samples[-1].capacity_per_hour == 100.0


def test_craft_kanban_metrics_uses_production_fallback_start_time(db, factory) -> None:
    operator = factory.user(username="kanban_operator_b", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = craft_service.create_stage(db, code="38", name="工段38", sort_order=1)
    process = craft_service.create_process(db, code="38-01", name="工序38", stage_id=stage.id)
    product = factory.product(name="看板产品B")

    base = datetime(2026, 3, 2, 8, 0, tzinfo=UTC)
    order = factory.order(product=product, order_code="KB-FALLBACK", status="completed")
    process_row = factory.order_process(
        order=order,
        process=process,
        stage=stage,
        process_order=1,
        status="completed",
    )
    first_production = factory.production_record(
        order=order,
        process_row=process_row,
        operator=operator,
        quantity=30,
        record_type="production",
    )
    last_production = factory.production_record(
        order=order,
        process_row=process_row,
        operator=operator,
        quantity=30,
        record_type="production",
    )
    first_production.created_at = base + timedelta(minutes=5)
    last_production.created_at = base + timedelta(minutes=65)

    invalid_order = factory.order(product=product, order_code="KB-BAD-INTERVAL", status="completed")
    invalid_row = factory.order_process(
        order=invalid_order,
        process=process,
        stage=stage,
        process_order=1,
        status="completed",
    )
    bad_first = factory.production_record(
        order=invalid_order,
        process_row=invalid_row,
        operator=operator,
        quantity=0,
        record_type="first_article",
    )
    bad_prod = factory.production_record(
        order=invalid_order,
        process_row=invalid_row,
        operator=operator,
        quantity=20,
        record_type="production",
    )
    bad_first.created_at = base + timedelta(minutes=70)
    bad_prod.created_at = base + timedelta(minutes=40)
    db.commit()

    result = craft_service.get_craft_kanban_process_metrics(
        db,
        product_id=product.id,
        limit=5,
    )
    assert len(result.items) == 1
    samples = result.items[0].samples
    assert len(samples) == 1
    assert samples[0].order_code == "KB-FALLBACK"
    assert samples[0].start_at == first_production.created_at.replace(tzinfo=None)
    assert samples[0].work_minutes == 60
    assert samples[0].capacity_per_hour == 60.0


def test_product_parameters_update_and_history(db, factory) -> None:
    operator = factory.user(username="product_operator", role_codes=[ROLE_SYSTEM_ADMIN])
    product = product_service.create_product(db, "产品B", operator=operator)

    changed_keys = product_service.update_product_parameters(
        db,
        product=product,
        items=[
            (PRODUCT_NAME_PARAMETER_KEY, "基础参数", "Text", "产品B-新"),
            ("参数1", "分类1", "Text", "v1"),
        ],
        remark="更新参数",
        operator=operator,
    )
    assert PRODUCT_NAME_PARAMETER_KEY in changed_keys
    assert "参数1" in changed_keys

    total, histories = product_service.list_parameter_history(db, product_id=product.id, page=1, page_size=10)
    assert total == 1
    assert len(histories) == 1
    assert histories[0].remark == "更新参数"

    latest = product_service.get_latest_history_map_by_product_ids(db, [product.id])
    assert product.id in latest
    assert isinstance(latest[product.id], ProductParameterHistory)


def test_product_parameter_template_init_and_summary(db, factory) -> None:
    product = factory.product(name="NeedInit")
    changed = product_service.ensure_product_parameter_template_initialized(db, product)
    assert changed is True

    changed_again = product_service.ensure_product_parameter_template_initialized(db, product)
    assert isinstance(changed_again, bool)

    assert product_service.summarize_changed_keys([]) is None
    assert product_service.summarize_changed_keys(["a", "b"]) == "a, b"
    assert product_service.summarize_changed_keys(["a", "b", "c", "d"], max_count=2) == "a, b (+2)"


def test_product_update_parameters_rejects_invalid_input(db, factory) -> None:
    operator = factory.user(username="operator_invalid", role_codes=[ROLE_SYSTEM_ADMIN])
    product = product_service.create_product(db, "产品C", operator=operator)

    try:
        product_service.update_product_parameters(
            db,
            product=product,
            items=[("X", "C", "Text", "v")],
            remark="ok",
            operator=operator,
        )
        assert False, "expected ValueError"
    except ValueError as exc:
        assert "cannot be deleted" in str(exc)


def test_product_lifecycle_and_version_compare_and_rollback(db, factory) -> None:
    operator = factory.user(username="product_lifecycle_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    product = product_service.create_product(db, "产品生命周期A", operator=operator)
    assert product.lifecycle_status == "active"
    assert product.current_version == 1
    assert product.effective_version == 0  # new products start with draft, no effective version yet

    changed_keys = product_service.update_product_parameters(
        db,
        product=product,
        items=[
            (PRODUCT_NAME_PARAMETER_KEY, "基础参数", "Text", "产品生命周期A-改1"),
            ("参数X", "分类X", "Text", "v1"),
        ],
        remark="版本二",
        operator=operator,
    )
    assert "参数X" in changed_keys
    assert product.current_version == 2

    product_service.update_product_parameters(
        db,
        product=product,
        items=[
            (PRODUCT_NAME_PARAMETER_KEY, "基础参数", "Text", "产品生命周期A-改2"),
            ("参数X", "分类X", "Text", "v2"),
        ],
        remark="版本三",
        operator=operator,
    )
    assert product.current_version == 3

    versions = product_service.list_product_versions(db, product_id=product.id)
    assert [item.version for item in versions[:3]] == [3, 2, 1]
    assert versions[0].lifecycle_status == "effective"
    assert versions[1].lifecycle_status == "obsolete"
    # version 1 was created as draft; after parameter updates it remains draft (not promoted to effective)
    assert versions[2].lifecycle_status in {"draft", "obsolete"}

    compare_result = product_service.compare_product_versions(
        db,
        product=product,
        from_version=1,
        to_version=3,
    )
    assert compare_result.changed_items >= 1

    rollback_changed_keys = product_service.rollback_product_to_version(
        db,
        product=product,
        target_version=1,
        confirmed=False,
        note="回滚到v1",
        operator=operator,
    )
    assert PRODUCT_NAME_PARAMETER_KEY in rollback_changed_keys
    assert product.current_version == 4
    assert product.effective_version == 4


def test_product_impact_confirmation_required_for_inactive_and_update(db, factory) -> None:
    operator = factory.user(username="product_impact_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    product = product_service.create_product(db, "产品影响A", operator=operator)
    factory.order(product=product, order_code="IMPACT-ORD-1", status="pending")
    db.commit()

    impact = product_service.analyze_product_impact(
        db,
        product=product,
        operation="lifecycle",
        target_status="inactive",
    )
    assert impact.requires_confirmation is True
    assert impact.total_orders == 1

    try:
        product_service.change_product_lifecycle(
            db,
            product=product,
            target_status="inactive",
            confirmed=False,
            note=None,
            inactive_reason="停产",
            operator=operator,
        )
        assert False, "expected ValueError"
    except ValueError as exc:
        assert "Impact confirmation required" in str(exc)

    product = product_service.change_product_lifecycle(
        db,
        product=product,
        target_status="inactive",
        confirmed=True,
        note=None,
        inactive_reason="停产",
        operator=operator,
    )
    assert product.lifecycle_status == "inactive"

    product = product_service.change_product_lifecycle(
        db,
        product=product,
        target_status="active",
        confirmed=False,
        note=None,
        inactive_reason=None,
        operator=operator,
    )
    assert product.lifecycle_status == "active"

    try:
        product_service.update_product_parameters(
            db,
            product=product,
            items=[
                (PRODUCT_NAME_PARAMETER_KEY, "基础参数", "Text", "产品影响A-改"),
                ("参数Y", "分类Y", "Text", "v1"),
            ],
            remark="启用状态改参",
            operator=operator,
            confirmed=False,
        )
        assert False, "expected ValueError"
    except ValueError as exc:
        assert "Impact confirmation required" in str(exc)

    changed_keys = product_service.update_product_parameters(
        db,
        product=product,
        items=[
            (PRODUCT_NAME_PARAMETER_KEY, "基础参数", "Text", "产品影响A-改"),
            ("参数Y", "分类Y", "Text", "v1"),
        ],
        remark="启用状态改参",
        operator=operator,
        confirmed=True,
    )
    assert "参数Y" in changed_keys
