from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.api.product.product_test_helpers import (
    activate_version,
    auth_headers,
    create_product,
    find_parameter_value,
    get_history_rows,
    get_product_row,
    get_revision_rows,
    update_version_parameter_value,
)


def test_product_detail_history_and_version_export_expose_real_change_trace(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    product = create_product(client, admin_headers, suffix="detail")
    product_id = int(product["id"])
    v1 = int(product["current_version"])

    update_version_parameter_value(
        client,
        admin_headers,
        product_id=product_id,
        version=v1,
        parameter_name="产品芯片",
        parameter_value="DETAIL-V1",
        remark="初始化详情 V1.0",
    )
    activate_response = activate_version(
        client,
        admin_headers,
        product_id=product_id,
        version=v1,
        expected_effective_version=0,
    )
    assert activate_response.status_code == 200, activate_response.text

    copy_response = client.post(
        f"/api/v1/products/{product_id}/versions/{v1}/copy",
        headers=admin_headers,
        json={"source_version": v1},
    )
    assert copy_response.status_code == 201, copy_response.text
    v2 = int(copy_response.json()["data"]["version"])

    update_version_parameter_value(
        client,
        admin_headers,
        product_id=product_id,
        version=v2,
        parameter_name="产品芯片",
        parameter_value="DETAIL-V2",
        remark="编辑详情 V1.1",
    )

    detail_response = client.get(
        f"/api/v1/products/{product_id}/detail",
        headers=admin_headers,
    )
    assert detail_response.status_code == 200, detail_response.text
    detail = detail_response.json()["data"]
    assert detail["product"]["id"] == product_id
    assert detail["product"]["name"] == product["name"]
    assert detail["detail_parameters"]["parameter_scope"] == "effective"
    assert detail["detail_parameters"]["version"] == 1
    assert detail["detail_parameter_message"] is None
    assert detail["version_total"] == 2
    assert detail["versions"][0]["version"] == 2
    assert detail["versions"][0]["version_label"] == "V1.1"
    assert detail["history_total"] >= 3
    assert detail["latest_version_changed_at"] is not None
    assert len(detail["related_info_sections"]) == 5

    history_response = client.get(
        f"/api/v1/products/{product_id}/parameter-history",
        headers=admin_headers,
        params={"page": 1, "page_size": 20},
    )
    assert history_response.status_code == 200, history_response.text
    history_payload = history_response.json()["data"]
    assert history_payload["total"] >= 3
    assert any(item["change_type"] == "copy" for item in history_payload["items"])
    assert any(item.get("version_label") == "V1.1" for item in history_payload["items"])

    version_export = client.get(
        f"/api/v1/products/{product_id}/versions/{v2}/export",
        headers=admin_headers,
    )
    assert version_export.status_code == 200, version_export.text
    export_text = version_export.content.decode("utf-8-sig")
    assert "版本号,参数名称" in export_text
    assert "V1.1" in export_text
    assert "DETAIL-V2" in export_text

    history_rows = get_history_rows(db_session, product_id)
    assert any(
        row.change_type == "copy" and row.version == 2 for row in history_rows
    )
    assert any(
        row.change_type == "edit" and "产品芯片" in row.changed_keys
        for row in history_rows
    )


def test_draft_version_hard_delete_removes_revision_and_restores_current_version(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    product = create_product(client, admin_headers, suffix="hard-delete")
    product_id = int(product["id"])
    v1 = int(product["current_version"])

    activate_response = activate_version(
        client,
        admin_headers,
        product_id=product_id,
        version=v1,
        expected_effective_version=0,
    )
    assert activate_response.status_code == 200, activate_response.text

    create_version = client.post(
        f"/api/v1/products/{product_id}/versions",
        headers=admin_headers,
        json={},
    )
    assert create_version.status_code == 201, create_version.text
    v2 = int(create_version.json()["data"]["version"])

    delete_version = client.delete(
        f"/api/v1/products/{product_id}/versions/{v2}",
        headers=admin_headers,
    )
    assert delete_version.status_code == 200, delete_version.text
    assert delete_version.json()["data"] == {"deleted": True}

    product_row = get_product_row(db_session, product_id)
    assert product_row is not None
    assert product_row.current_version == 1
    assert product_row.effective_version == 1
    assert product_row.is_deleted is False

    revision_rows = get_revision_rows(db_session, product_id)
    assert [row.version for row in revision_rows] == [1]

    history_rows = get_history_rows(db_session, product_id)
    assert any(
        row.change_type == "delete" and row.version == 2 for row in history_rows
    )


def test_version_activation_stale_write_is_rejected_and_db_state_remains_consistent(
    client: TestClient,
    db_session: Session,
    two_admin_tokens: tuple[str, str],
) -> None:
    token_a, token_b = two_admin_tokens
    token_a_headers = auth_headers(token_a)
    token_b_headers = auth_headers(token_b)

    product = create_product(
        client,
        token_a_headers,
        suffix="concurrent-activate",
    )
    product_id = int(product["id"])
    v1 = int(product["current_version"])

    update_version_parameter_value(
        client,
        token_a_headers,
        product_id=product_id,
        version=v1,
        parameter_name="产品芯片",
        parameter_value="CONCURRENCY-V1",
        remark="初始化并发生效 V1.0",
    )
    activate_v1 = activate_version(
        client,
        token_a_headers,
        product_id=product_id,
        version=v1,
        expected_effective_version=0,
    )
    assert activate_v1.status_code == 200, activate_v1.text

    create_version = client.post(
        f"/api/v1/products/{product_id}/versions",
        headers=token_a_headers,
        json={},
    )
    assert create_version.status_code == 201, create_version.text
    v2 = int(create_version.json()["data"]["version"])

    update_version_parameter_value(
        client,
        token_a_headers,
        product_id=product_id,
        version=v2,
        parameter_name="产品芯片",
        parameter_value="CONCURRENCY-V2",
        remark="并发竞态目标版本",
    )

    first_activate = activate_version(
        client,
        token_a_headers,
        product_id=product_id,
        version=v2,
        expected_effective_version=1,
    )
    assert first_activate.status_code == 200, first_activate.text

    stale_activate = activate_version(
        client,
        token_b_headers,
        product_id=product_id,
        version=v2,
        expected_effective_version=1,
    )
    assert stale_activate.status_code == 400, stale_activate.text
    stale_detail = stale_activate.json()["detail"]
    assert "抢先生效" in stale_detail or "只有草稿版本可以生效" in stale_detail

    product_row = get_product_row(db_session, product_id)
    assert product_row is not None
    assert product_row.lifecycle_status == "active"
    assert product_row.current_version == 2
    assert product_row.effective_version == 2
    assert product_row.inactive_reason is None

    revision_rows = get_revision_rows(db_session, product_id)
    assert len(revision_rows) == 2
    revision_map = {row.version: row for row in revision_rows}
    assert revision_map[1].lifecycle_status == "obsolete"
    assert revision_map[2].lifecycle_status == "effective"

    effective_parameters = client.get(
        f"/api/v1/products/{product_id}/effective-parameters",
        headers=token_a_headers,
    )
    assert effective_parameters.status_code == 200, effective_parameters.text
    effective_payload = effective_parameters.json()["data"]
    assert effective_payload["version"] == 2
    assert find_parameter_value(effective_payload, "产品芯片") == "CONCURRENCY-V2"
