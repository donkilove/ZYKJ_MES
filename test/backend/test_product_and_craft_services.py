from __future__ import annotations

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
