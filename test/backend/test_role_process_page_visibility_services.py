from __future__ import annotations

import json

import pytest
from sqlalchemy import select

from app.core.rbac import ROLE_OPERATOR, ROLE_SYSTEM_ADMIN
from app.models.page_visibility import PageVisibility
from app.models.process import Process
from app.schemas.process import ProcessCreate, ProcessUpdate
from app.schemas.role import RoleCreate, RoleUpdate
from app.services import page_visibility_service, process_service, production_event_log_service, role_service


def test_role_service_create_list_update(db) -> None:
    created, errors = role_service.create_role(db, RoleCreate(code="r1", name="Role 1"))
    assert errors == []
    assert created is not None

    total, rows = role_service.list_roles(db, page=1, page_size=20, keyword=None)
    assert total == 1
    assert rows[0].code == "r1"

    updated, errors = role_service.update_role(db, rows[0], RoleUpdate(name="Role X"))
    assert errors == []
    assert updated is not None
    assert updated.name == "Role X"


def test_role_service_get_roles_by_codes_returns_missing(db) -> None:
    role_service.create_role(db, RoleCreate(code="r2", name="Role 2"))
    roles, missing = role_service.get_roles_by_codes(db, ["r2", "r3"])
    assert {r.code for r in roles} == {"r2"}
    assert missing == ["r3"]


def test_process_service_create_update_list(db, factory) -> None:
    stage = factory.stage(code="10", sort_order=1, is_enabled=True)
    process = process_service.create_process(
        db,
        ProcessCreate(code="10-01", name="P1", stage_id=stage.id),
    )
    assert process.code == "10-01"

    updated = process_service.update_process(
        db,
        process,
        ProcessUpdate(code="10-02", name="P2", stage_id=stage.id, is_enabled=False),
    )
    assert updated.code == "10-02"
    assert updated.is_enabled is False

    total, rows = process_service.list_processes(db, page=1, page_size=20, keyword="P2")
    assert total == 1
    assert rows[0].name == "P2"


def test_process_service_default_stage_and_validation_errors(db, factory) -> None:
    with pytest.raises(ValueError, match="Stage not found"):
        process_service.create_process(db, ProcessCreate(code="99-01", name="x", stage_id=None))

    stage = factory.stage(code="11", sort_order=1, is_enabled=True)
    process = process_service.create_process(db, ProcessCreate(code="11-01", name="ok", stage_id=stage.id))

    with pytest.raises(ValueError, match="already exists"):
        process_service.create_process(db, ProcessCreate(code="11-01", name="dup", stage_id=stage.id))

    with pytest.raises(ValueError, match="must start"):
        process_service.update_process(
            db,
            process,
            ProcessUpdate(code="12-01", name="bad", stage_id=stage.id, is_enabled=True),
        )


def test_page_visibility_defaults_and_update(db) -> None:
    items = page_visibility_service.list_page_catalog_items()
    assert items

    page_visibility_service.ensure_visibility_defaults(db)
    total_rows = db.execute(select(PageVisibility)).scalars().all()
    assert len(total_rows) > 0

    updated_count, invalid_items = page_visibility_service.update_page_visibility_config(
        db,
        [
            {"role_code": ROLE_SYSTEM_ADMIN, "page_code": "product", "is_visible": True},
            {"role_code": "invalid_role", "page_code": "product", "is_visible": False},
        ],
    )
    assert updated_count == 0
    assert invalid_items

    updated_count, invalid_items = page_visibility_service.update_page_visibility_config(
        db,
        [{"role_code": ROLE_OPERATOR, "page_code": "product", "is_visible": True}],
    )
    assert updated_count == 1
    assert invalid_items == []

    sidebar, tabs = page_visibility_service.get_user_visible_pages(db, [ROLE_OPERATOR])
    assert "home" in sidebar
    assert isinstance(tabs, dict)


def test_page_visibility_config_output(db) -> None:
    page_visibility_service.ensure_visibility_defaults(db)
    config_items = page_visibility_service.get_page_visibility_config(db)
    assert config_items
    assert {"role_code", "page_code", "is_visible"}.issubset(config_items[0].keys())


def test_production_event_log_add_and_list(db, factory) -> None:
    product = factory.product(name="P")
    order = factory.order(product=product, order_code="ORD-EVENT")

    row = production_event_log_service.add_order_event_log(
        db,
        order_id=order.id,
        event_type="created",
        event_title="created",
        event_detail="detail",
        operator_user_id=None,
        payload={"a": 1},
    )
    db.commit()
    assert row.payload_json == '{"a":1}'

    logs = production_event_log_service.list_order_event_logs(db, order_id=order.id)
    assert len(logs) == 1
    assert json.loads(logs[0].payload_json or "{}") == {"a": 1}
