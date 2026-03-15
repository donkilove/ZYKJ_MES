from __future__ import annotations

import json

import pytest

from app.models.process import Process
from app.schemas.process import ProcessCreate, ProcessUpdate
from app.schemas.role import RoleCreate, RoleUpdate
from app.services import page_catalog_service, process_service, production_event_log_service, role_service


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


def test_role_service_create_role_type_and_status_rules(db) -> None:
    created_builtin, errors_builtin = role_service.create_role(
        db,
        RoleCreate(code="manual_builtin", name="手工内置角色", role_type="builtin"),
    )
    assert created_builtin is None
    assert errors_builtin == ["系统内置角色由系统维护，不支持手动创建"]

    created_disabled, errors_disabled = role_service.create_role(
        db,
        RoleCreate(code="r_disabled", name="Role Disabled", is_enabled=False),
    )
    assert errors_disabled == []
    assert created_disabled is not None
    assert created_disabled.role_type == "custom"
    assert created_disabled.is_builtin is False
    assert created_disabled.is_enabled is False


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


def test_page_catalog_items_excludes_legacy_visibility_page() -> None:
    items = page_catalog_service.list_page_catalog_items()
    assert items
    assert all(item["code"] != "page_visibility_config" for item in items)


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
