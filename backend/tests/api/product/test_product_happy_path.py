from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.api.product.product_test_helpers import (
    ADMIN_PASSWORD,
    activate_version,
    create_product,
    find_parameter_value,
    get_current_parameter_rows,
    get_history_rows,
    get_product_row,
    get_revision_parameter_rows,
    get_revision_rows,
    unique_suffix,
    update_version_parameter_value,
)


def test_product_crud_create_update_soft_delete_and_db_state(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    created = create_product(client, admin_headers, suffix="crud")
    product_id = int(created["id"])

    assert created["lifecycle_status"] == "active"
    assert created["current_version"] == 1
    assert created["current_version_label"] == "V1.0"
    assert created["effective_version"] == 0
    assert created["effective_version_label"] is None
    assert created["category"] == "贴片"
    assert created["remark"] == "crud 场景"

    product_row = get_product_row(db_session, product_id)
    assert product_row is not None
    assert product_row.name == created["name"]
    assert product_row.category == "贴片"
    assert product_row.remark == "crud 场景"
    assert product_row.lifecycle_status == "active"
    assert product_row.current_version == 1
    assert product_row.effective_version == 0
    assert product_row.is_deleted is False
    assert product_row.parameter_template_initialized is True

    revision_rows = get_revision_rows(db_session, product_id)
    assert len(revision_rows) == 1
    assert revision_rows[0].version == 1
    assert revision_rows[0].version_label == "V1.0"
    assert revision_rows[0].lifecycle_status == "draft"
    assert revision_rows[0].action == "create"

    current_parameter_rows = get_current_parameter_rows(db_session, product_id)
    assert len(current_parameter_rows) >= 1
    assert any(
        row.param_key == "产品名称" and row.param_value == created["name"]
        for row in current_parameter_rows
    )

    listed = client.get(
        "/api/v1/products",
        headers=admin_headers,
        params={
            "page": 1,
            "page_size": 20,
            "keyword": created["name"][4:12],
            "category": "贴片",
        },
    )
    assert listed.status_code == 200, listed.text
    listed_payload = listed.json()["data"]
    assert listed_payload["total"] >= 1
    assert any(int(item["id"]) == product_id for item in listed_payload["items"])

    update_response = client.put(
        f"/api/v1/products/{product_id}",
        headers=admin_headers,
        json={
            "name": f"已改名-{unique_suffix('product')}",
            "category": "DTU",
            "remark": "产品基础信息已更新",
        },
    )
    assert update_response.status_code == 200, update_response.text
    updated = update_response.json()["data"]
    assert updated["id"] == product_id
    assert updated["name"].startswith("已改名-")
    assert updated["category"] == "DTU"
    assert updated["remark"] == "产品基础信息已更新"

    updated_row = get_product_row(db_session, product_id)
    assert updated_row is not None
    assert updated_row.name == updated["name"]
    assert updated_row.category == "DTU"
    assert updated_row.remark == "产品基础信息已更新"
    assert updated_row.is_deleted is False

    current_parameter_rows = get_current_parameter_rows(db_session, product_id)
    assert any(
        row.param_key == "产品名称" and row.param_value == updated["name"]
        for row in current_parameter_rows
    )

    revision_parameter_rows = get_revision_parameter_rows(db_session, product_id, 1)
    assert any(
        row.param_key == "产品名称" and row.param_value == updated["name"]
        for row in revision_parameter_rows
    )

    history_rows = get_history_rows(db_session, product_id)
    assert any(
        row.change_type == "update_product"
        and set(row.changed_keys) == {"name", "category", "remark"}
        for row in history_rows
    )

    delete_response = client.post(
        f"/api/v1/products/{product_id}/delete",
        headers=admin_headers,
        json={"password": ADMIN_PASSWORD},
    )
    assert delete_response.status_code == 200, delete_response.text
    assert delete_response.json()["data"] == {"deleted": True}

    deleted_row = get_product_row(db_session, product_id)
    assert deleted_row is not None
    assert deleted_row.is_deleted is True

    detail_after_delete = client.get(
        f"/api/v1/products/{product_id}",
        headers=admin_headers,
    )
    assert detail_after_delete.status_code == 404, detail_after_delete.text

    listed_after_delete = client.get(
        "/api/v1/products",
        headers=admin_headers,
        params={"keyword": updated["name"]},
    )
    assert listed_after_delete.status_code == 200, listed_after_delete.text
    assert all(
        int(item["id"]) != product_id
        for item in listed_after_delete.json()["data"]["items"]
    )


def test_product_list_filters_pagination_and_export_share_same_contract(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    matched = create_product(
        client,
        admin_headers,
        suffix="filter-hit",
        remark="列表筛选命中",
    )
    matched_id = int(matched["id"])
    matched_v1 = int(matched["current_version"])

    activate_v1 = activate_version(
        client,
        admin_headers,
        product_id=matched_id,
        version=matched_v1,
        expected_effective_version=0,
    )
    assert activate_v1.status_code == 200, activate_v1.text

    create_version = client.post(
        f"/api/v1/products/{matched_id}/versions",
        headers=admin_headers,
        json={},
    )
    assert create_version.status_code == 201, create_version.text
    matched_v2 = int(create_version.json()["data"]["version"])

    update_version_parameter_value(
        client,
        admin_headers,
        product_id=matched_id,
        version=matched_v2,
        parameter_name="产品芯片",
        parameter_value="FILTER-CHIP",
        remark="列表筛选命中参数",
    )

    excluded = create_product(
        client,
        admin_headers,
        suffix="filter-miss",
        remark="列表筛选排除",
    )
    excluded_id = int(excluded["id"])

    list_response = client.get(
        "/api/v1/products",
        headers=admin_headers,
        params={
            "page": 1,
            "page_size": 1,
            "keyword": matched["name"],
            "current_version_keyword": "V1.1",
            "current_param_name_keyword": "产品芯片",
            "current_param_category_keyword": "基础参数",
        },
    )
    assert list_response.status_code == 200, list_response.text
    list_payload = list_response.json()["data"]
    assert list_payload["total"] == 1
    assert len(list_payload["items"]) == 1
    assert int(list_payload["items"][0]["id"]) == matched_id
    assert all(int(item["id"]) != excluded_id for item in list_payload["items"])

    second_page_response = client.get(
        "/api/v1/products",
        headers=admin_headers,
        params={
            "page": 2,
            "page_size": 1,
            "keyword": matched["name"],
            "current_version_keyword": "V1.1",
            "current_param_name_keyword": "产品芯片",
            "current_param_category_keyword": "基础参数",
        },
    )
    assert second_page_response.status_code == 200, second_page_response.text
    assert second_page_response.json()["data"]["total"] == 1
    assert second_page_response.json()["data"]["items"] == []

    export_response = client.get(
        "/api/v1/products/export/list",
        headers=admin_headers,
        params={
            "keyword": matched["name"],
            "current_version_keyword": "V1.1",
            "current_param_name_keyword": "产品芯片",
            "current_param_category_keyword": "基础参数",
        },
    )
    assert export_response.status_code == 200, export_response.text
    export_text = export_response.content.decode("utf-8-sig")
    assert matched["name"] in export_text
    assert excluded["name"] not in export_text
    assert "V1.1" in export_text

    matched_row = get_product_row(db_session, matched_id)
    excluded_row = get_product_row(db_session, excluded_id)
    assert matched_row is not None and matched_row.current_version == 2
    assert excluded_row is not None and excluded_row.current_version == 1


def test_parameter_query_and_parameter_version_filters_cover_effective_contract(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    active_product = create_product(client, admin_headers, suffix="param-active")
    active_product_id = int(active_product["id"])
    active_v1 = int(active_product["current_version"])

    update_version_parameter_value(
        client,
        admin_headers,
        product_id=active_product_id,
        version=active_v1,
        parameter_name="产品芯片",
        parameter_value="QUERY-CHIP",
        remark="参数查询命中参数",
    )
    activate_response = activate_version(
        client,
        admin_headers,
        product_id=active_product_id,
        version=active_v1,
        expected_effective_version=0,
    )
    assert activate_response.status_code == 200, activate_response.text

    inactive_product = create_product(client, admin_headers, suffix="param-inactive")
    inactive_product_id = int(inactive_product["id"])
    inactive_v1 = int(inactive_product["current_version"])
    update_version_parameter_value(
        client,
        admin_headers,
        product_id=inactive_product_id,
        version=inactive_v1,
        parameter_name="产品芯片",
        parameter_value="INACTIVE-CHIP",
        remark="参数查询排除参数",
    )
    deactivate_response = client.post(
        f"/api/v1/products/{inactive_product_id}/lifecycle",
        headers=admin_headers,
        json={
            "target_status": "inactive",
            "confirmed": False,
            "inactive_reason": "主动停用用于筛选排除",
        },
    )
    assert deactivate_response.status_code == 200, deactivate_response.text

    parameter_query = client.get(
        "/api/v1/products/parameter-query",
        headers=admin_headers,
        params={
            "keyword": "param-",
            "lifecycle_status": "active",
            "has_effective_version": True,
        },
    )
    assert parameter_query.status_code == 200, parameter_query.text
    query_items = parameter_query.json()["data"]["items"]
    assert any(int(item["id"]) == active_product_id for item in query_items)
    assert all(int(item["id"]) != inactive_product_id for item in query_items)
    matched_row = next(
        item for item in query_items if int(item["id"]) == active_product_id
    )
    assert matched_row["effective_version"] == 1
    assert matched_row["effective_version_label"] == "V1.0"

    version_query = client.get(
        "/api/v1/products/parameter-versions",
        headers=admin_headers,
        params={
            "keyword": active_product["name"],
            "param_name_keyword": "产品芯片",
            "param_category_keyword": "基础参数",
        },
    )
    assert version_query.status_code == 200, version_query.text
    version_items = version_query.json()["data"]["items"]
    target = next(
        item for item in version_items if int(item["product_id"]) == active_product_id
    )
    assert target["version"] == 1
    assert target["matched_parameter_name"] == "产品芯片"
    assert target["matched_parameter_category"] == "基础参数"
    assert target["parameter_count"] >= 1

    active_row = get_product_row(db_session, active_product_id)
    inactive_row = get_product_row(db_session, inactive_product_id)
    assert active_row is not None and active_row.effective_version == 1
    assert inactive_row is not None and inactive_row.lifecycle_status == "inactive"


def test_current_parameters_compat_endpoint_and_parameter_export_keep_contract(
    client: TestClient,
    db_session: Session,
    admin_headers: dict[str, str],
) -> None:
    product = create_product(client, admin_headers, suffix="compat")
    product_id = int(product["id"])
    current_version = int(product["current_version"])

    current_parameters_response = client.get(
        f"/api/v1/products/{product_id}/parameters",
        headers=admin_headers,
    )
    assert current_parameters_response.status_code == 200, current_parameters_response.text
    current_parameters = current_parameters_response.json()["data"]
    assert current_parameters["parameter_scope"] == "version"
    assert current_parameters["version"] == current_version
    assert current_parameters["version_label"] == "V1.0"

    updated = False
    for item in current_parameters["items"]:
        if item["name"] == "产品芯片":
            item["value"] = "COMPAT-CHIP"
            updated = True
            break
    assert updated is True

    update_response = client.put(
        f"/api/v1/products/{product_id}/parameters",
        headers=admin_headers,
        json={
            "remark": "兼容口径更新当前版本参数",
            "items": current_parameters["items"],
        },
    )
    assert update_response.status_code == 200, update_response.text
    update_payload = update_response.json()["data"]
    assert update_payload["parameter_scope"] == "version"
    assert update_payload["version"] == current_version
    assert "产品芯片" in update_payload["changed_keys"]

    current_rows = get_current_parameter_rows(db_session, product_id)
    assert any(
        row.param_key == "产品芯片" and row.param_value == "COMPAT-CHIP"
        for row in current_rows
    )

    export_response = client.get(
        "/api/v1/products/parameters/export",
        headers=admin_headers,
        params={"keyword": product["name"]},
    )
    assert export_response.status_code == 200, export_response.text
    export_text = export_response.content.decode("utf-8-sig")
    assert product["name"] in export_text
    assert "COMPAT-CHIP" in export_text


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
