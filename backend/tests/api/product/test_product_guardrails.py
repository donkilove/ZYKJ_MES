from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.api.product.product_test_helpers import (
    ADMIN_PASSWORD,
    activate_version,
    create_order_row,
    create_product,
    get_product_row,
    get_revision_rows,
)


def test_product_name_is_globally_unique_for_create_and_update(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    first = create_product(client, admin_headers, suffix="unique-a")
    second = create_product(client, admin_headers, suffix="unique-b")
    first_id = int(first["id"])
    second_id = int(second["id"])

    duplicate_create = client.post(
        "/api/v1/products",
        headers=admin_headers,
        json={
            "name": first["name"],
            "category": "贴片",
            "remark": "重复产品名创建",
        },
    )
    assert duplicate_create.status_code == 400, duplicate_create.text
    assert duplicate_create.json()["detail"] == "Product name already exists"

    duplicate_update = client.put(
        f"/api/v1/products/{second_id}",
        headers=admin_headers,
        json={
            "name": first["name"],
            "category": "贴片",
            "remark": "重复产品名更新",
        },
    )
    assert duplicate_update.status_code == 400, duplicate_update.text
    assert duplicate_update.json()["detail"] == "Product name already exists"

    first_row = get_product_row(db_session, first_id)
    second_row = get_product_row(db_session, second_id)
    assert first_row is not None
    assert second_row is not None
    assert first_row.name == first["name"]
    assert second_row.name == second["name"]


def test_delete_product_and_delete_version_are_blocked_when_referenced(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    product = create_product(client, admin_headers, suffix="delete-guard")
    product_id = int(product["id"])
    v1 = int(product["current_version"])

    completed_order = create_order_row(
        db_session,
        product_id=product_id,
        product_version=v1,
        status="completed",
    )
    blocked_delete = client.post(
        f"/api/v1/products/{product_id}/delete",
        headers=admin_headers,
        json={"password": ADMIN_PASSWORD},
    )
    assert blocked_delete.status_code == 400, blocked_delete.text
    assert "生产工单" in blocked_delete.json()["detail"]
    assert completed_order.order_code.startswith("ORD-PRODUCT-COMPLETED-")

    product_row = get_product_row(db_session, product_id)
    assert product_row is not None
    assert product_row.is_deleted is False

    open_product = create_product(client, admin_headers, suffix="open-order-guard")
    open_product_id = int(open_product["id"])
    open_v1 = int(open_product["current_version"])

    create_order_row(
        db_session,
        product_id=open_product_id,
        product_version=open_v1,
        status="pending",
    )
    blocked_by_open_order = client.post(
        f"/api/v1/products/{open_product_id}/delete",
        headers=admin_headers,
        json={"password": ADMIN_PASSWORD},
    )
    assert blocked_by_open_order.status_code == 400, blocked_by_open_order.text
    assert "未完成的工单" in blocked_by_open_order.json()["detail"]

    activate_response = activate_version(
        client,
        admin_headers,
        product_id=open_product_id,
        version=open_v1,
        expected_effective_version=0,
    )
    assert activate_response.status_code == 200, activate_response.text

    copy_response = client.post(
        f"/api/v1/products/{open_product_id}/versions/{open_v1}/copy",
        headers=admin_headers,
        json={"source_version": open_v1},
    )
    assert copy_response.status_code == 201, copy_response.text
    draft_version = int(copy_response.json()["data"]["version"])
    draft_version_label = copy_response.json()["data"]["version_label"]

    draft_order = create_order_row(
        db_session,
        product_id=open_product_id,
        product_version=draft_version,
        status="completed",
    )

    blocked_delete_version = client.delete(
        f"/api/v1/products/{open_product_id}/versions/{draft_version}",
        headers=admin_headers,
    )
    assert blocked_delete_version.status_code == 400, blocked_delete_version.text
    detail = blocked_delete_version.json()["detail"]
    assert "生产工单" in detail
    assert draft_version_label in detail
    assert "存在 1 条生产工单" in blocked_delete.json()["detail"]
    assert draft_order.order_code in detail

    revision_rows = get_revision_rows(db_session, open_product_id)
    assert [row.version for row in revision_rows] == [1, 2]


def test_lifecycle_transition_requires_reason_and_keeps_db_state_consistent(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    product = create_product(client, admin_headers, suffix="lifecycle")
    product_id = int(product["id"])

    missing_reason = client.post(
        f"/api/v1/products/{product_id}/lifecycle",
        headers=admin_headers,
        json={
            "target_status": "inactive",
            "confirmed": False,
            "inactive_reason": None,
        },
    )
    assert missing_reason.status_code == 400, missing_reason.text
    assert "inactive_reason is required" in missing_reason.json()["detail"]

    inactive_ok = client.post(
        f"/api/v1/products/{product_id}/lifecycle",
        headers=admin_headers,
        json={
            "target_status": "inactive",
            "confirmed": False,
            "inactive_reason": "手动停用验证",
        },
    )
    assert inactive_ok.status_code == 200, inactive_ok.text
    assert inactive_ok.json()["data"]["lifecycle_status"] == "inactive"
    assert inactive_ok.json()["data"]["inactive_reason"] == "手动停用验证"

    inactive_row = get_product_row(db_session, product_id)
    assert inactive_row is not None
    assert inactive_row.lifecycle_status == "inactive"
    assert inactive_row.inactive_reason == "手动停用验证"

    reactivate_without_effective = client.post(
        f"/api/v1/products/{product_id}/lifecycle",
        headers=admin_headers,
        json={
            "target_status": "active",
            "confirmed": False,
            "inactive_reason": None,
        },
    )
    assert reactivate_without_effective.status_code == 400, reactivate_without_effective.text
    assert "产品当前无生效版本" in reactivate_without_effective.json()["detail"]

    still_inactive_row = get_product_row(db_session, product_id)
    assert still_inactive_row is not None
    assert still_inactive_row.lifecycle_status == "inactive"
    assert still_inactive_row.effective_version == 0
