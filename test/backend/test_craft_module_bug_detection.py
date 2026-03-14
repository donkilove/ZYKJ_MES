from __future__ import annotations

import pytest
from sqlalchemy import func, select

from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.models.product_process_template import ProductProcessTemplate
from app.services import craft_service


def test_import_templates_partial_failure_should_not_rollback_previous_success(db, factory) -> None:
    operator = factory.user(username="craft_bug_operator_1", role_codes=[ROLE_SYSTEM_ADMIN])
    product = factory.product(name="craft-bug-import-product")
    stage = craft_service.create_stage(db, code="96", name="Stage 96", sort_order=1)
    process = craft_service.create_process(db, code="96-01", name="Process 96-01", stage_id=stage.id)

    rows, created, updated, skipped, errors = craft_service.import_templates(
        db,
        items=[
            {
                "product_id": product.id,
                "template_name": "import-ok",
                "is_default": True,
                "is_enabled": True,
                "lifecycle_status": "draft",
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage.id,
                        "process_id": process.id,
                    }
                ],
            },
            {
                "product_id": product.id,
                "template_name": "import-bad",
                "is_default": False,
                "is_enabled": True,
                "lifecycle_status": "draft",
                "steps": [
                    {
                        "step_order": 1,
                        "stage_id": stage.id,
                        "process_id": 999999,
                    }
                ],
            },
        ],
        overwrite_existing=False,
        publish_after_import=False,
        operator=operator,
    )

    assert created == 1
    assert updated == 0
    assert skipped == 1
    assert len(errors) == 1
    assert len(rows) == 1

    persisted_count = db.execute(
        select(func.count())
        .select_from(ProductProcessTemplate)
        .where(
            ProductProcessTemplate.product_id == product.id,
            ProductProcessTemplate.template_name == "import-ok",
        )
    ).scalar_one()
    assert int(persisted_count) == 1


def test_delete_process_referenced_by_system_master_should_return_business_error(db, factory) -> None:
    operator = factory.user(username="craft_bug_operator_2", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = craft_service.create_stage(db, code="97", name="Stage 97", sort_order=1)
    process = craft_service.create_process(db, code="97-01", name="Process 97-01", stage_id=stage.id)

    craft_service.create_system_master_template(
        db,
        steps=[
            {
                "step_order": 1,
                "stage_id": stage.id,
                "process_id": process.id,
            }
        ],
        operator=operator,
    )

    with pytest.raises(ValueError, match="referenced"):
        craft_service.delete_process(db, row=process)


def test_delete_stage_referenced_by_system_master_should_return_business_error(db, factory) -> None:
    operator = factory.user(username="craft_bug_operator_3", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = craft_service.create_stage(db, code="98", name="Stage 98", sort_order=1)
    process = craft_service.create_process(db, code="98-01", name="Process 98-01", stage_id=stage.id)

    craft_service.create_system_master_template(
        db,
        steps=[
            {
                "step_order": 1,
                "stage_id": stage.id,
                "process_id": process.id,
            }
        ],
        operator=operator,
    )

    with pytest.raises(ValueError, match="referenced"):
        craft_service.delete_stage(db, row=stage)
