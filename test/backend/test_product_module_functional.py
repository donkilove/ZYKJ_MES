from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import products
from app.core.product_parameter_template import PRODUCT_NAME_PARAMETER_KEY
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.models.product import Product
from app.schemas.product import (
    ProductCreate,
    ProductDeleteRequest,
    ProductLifecycleUpdateRequest,
    ProductParameterInputItem,
    ProductParameterUpdateRequest,
    ProductRollbackRequest,
    ProductUpdate,
    ProductVersionActivateRequest,
    ProductVersionCopyRequest,
    ProductVersionNoteUpdateRequest,
)


def _create_admin(factory, username: str):
    factory.ensure_default_roles()
    return factory.user(
        username=username,
        role_codes=[ROLE_SYSTEM_ADMIN],
        password="Admin@123",
    )


def _build_parameter_payload(
    *,
    product_name: str,
    remark: str,
    extra_name: str = "测试参数",
    extra_value: str = "value",
    confirmed: bool = False,
) -> ProductParameterUpdateRequest:
    return ProductParameterUpdateRequest(
        remark=remark,
        confirmed=confirmed,
        items=[
            ProductParameterInputItem(
                name=PRODUCT_NAME_PARAMETER_KEY,
                category="基础参数",
                type="Text",
                value=product_name,
            ),
            ProductParameterInputItem(
                name=extra_name,
                category="扩展参数",
                type="Text",
                value=extra_value,
            ),
        ],
    )


def test_product_crud_and_parameter_history_flow(db, factory) -> None:
    admin = _create_admin(factory, "product_func_admin_1")

    created = products.create_product_api(
        ProductCreate(name="功能产品A", category="贴片", remark="初始备注"),
        db=db,
        current_user=admin,
    )
    product_id = created.data.id
    assert created.data.name == "功能产品A"
    assert created.data.category == "贴片"
    assert created.data.remark == "初始备注"
    assert created.data.lifecycle_status == "active"

    listed = products.get_products(
        page=1,
        page_size=20,
        keyword="功能产品",
        category="贴片",
        lifecycle_status="active",
        has_effective_version=None,
        updated_after=None,
        updated_before=None,
        db=db,
        _=admin,
    )
    assert any(item.id == product_id for item in listed.data.items)

    detail = products.get_product_detail_api(product_id, db=db, _=admin)
    assert detail.data.id == product_id
    assert detail.data.name == "功能产品A"

    updated = products.update_product_api(
        product_id,
        ProductUpdate(name="功能产品A-更新", category="DTU", remark="已更新"),
        db=db,
        current_user=admin,
    )
    assert updated.data.name == "功能产品A-更新"
    assert updated.data.category == "DTU"
    assert updated.data.remark == "已更新"

    parameters = products.get_product_parameters(product_id, db=db, _=admin)
    assert parameters.data.total >= 1
    assert any(item.name == PRODUCT_NAME_PARAMETER_KEY for item in parameters.data.items)

    changed = products.update_parameters(
        product_id,
        _build_parameter_payload(
            product_name="功能产品A-参数版",
            remark="首次参数维护",
            extra_name="工作电压",
            extra_value="24V",
        ),
        db=db,
        current_user=admin,
    )
    assert changed.data.updated_count >= 1
    assert PRODUCT_NAME_PARAMETER_KEY in changed.data.changed_keys
    assert "工作电压" in changed.data.changed_keys

    history = products.get_parameter_history(
        product_id,
        page=1,
        page_size=20,
        db=db,
        _=admin,
    )
    assert history.data.total == 1
    assert history.data.items[0].remark == "首次参数维护"
    assert PRODUCT_NAME_PARAMETER_KEY in history.data.items[0].changed_keys

    deleted = products.delete_product_api(
        product_id,
        ProductDeleteRequest(password="Admin@123"),
        db=db,
        current_user=admin,
    )
    assert deleted.data["deleted"] is True

    with pytest.raises(HTTPException) as not_found:
        products.get_product_detail_api(product_id, db=db, _=admin)
    assert not_found.value.status_code == 404


def test_product_name_uniqueness_validation(db, factory) -> None:
    admin = _create_admin(factory, "product_func_admin_2")

    first = products.create_product_api(
        ProductCreate(name="唯一产品", category="贴片", remark=""),
        db=db,
        current_user=admin,
    )
    second = products.create_product_api(
        ProductCreate(name="唯一产品-2", category="DTU", remark=""),
        db=db,
        current_user=admin,
    )

    with pytest.raises(HTTPException) as duplicate_create:
        products.create_product_api(
            ProductCreate(name="唯一产品", category="贴片", remark="重复"),
            db=db,
            current_user=admin,
        )
    assert duplicate_create.value.status_code == 400
    assert "already exists" in str(duplicate_create.value.detail)

    with pytest.raises(HTTPException) as duplicate_update:
        products.update_product_api(
            second.data.id,
            ProductUpdate(name=first.data.name, category="DTU", remark="改名冲突"),
            db=db,
            current_user=admin,
        )
    assert duplicate_update.value.status_code == 400
    assert "already exists" in str(duplicate_update.value.detail)


def test_parameter_update_requires_confirmation_when_open_orders(db, factory) -> None:
    admin = _create_admin(factory, "product_func_admin_3")

    created = products.create_product_api(
        ProductCreate(name="确认产品A", category="贴片", remark=""),
        db=db,
        current_user=admin,
    )
    product_id = created.data.id
    product_row = db.get(Product, product_id)
    assert product_row is not None

    factory.order(product=product_row, order_code="PROD-CONFIRM-01", status="pending")
    db.commit()

    impact = products.get_product_impact_analysis(
        product_id,
        operation="update_parameters",
        target_status=None,
        target_version=None,
        db=db,
        _=admin,
    )
    assert impact.data.requires_confirmation is True
    assert impact.data.total_orders == 1

    with pytest.raises(HTTPException) as unconfirmed:
        products.update_parameters(
            product_id,
            _build_parameter_payload(
                product_name="确认产品A-改",
                remark="未确认更新",
                extra_name="参数A",
                extra_value="v1",
                confirmed=False,
            ),
            db=db,
            current_user=admin,
        )
    assert unconfirmed.value.status_code == 400
    assert "Impact confirmation required" in str(unconfirmed.value.detail)

    confirmed = products.update_parameters(
        product_id,
        _build_parameter_payload(
            product_name="确认产品A-改",
            remark="确认后更新",
            extra_name="参数A",
            extra_value="v1",
            confirmed=True,
        ),
        db=db,
        current_user=admin,
    )
    assert "参数A" in confirmed.data.changed_keys


def test_lifecycle_requires_reason_and_impact_confirmation(db, factory) -> None:
    admin = _create_admin(factory, "product_func_admin_4")

    created = products.create_product_api(
        ProductCreate(name="生命周期产品A", category="贴片", remark=""),
        db=db,
        current_user=admin,
    )
    product_id = created.data.id
    product_row = db.get(Product, product_id)
    assert product_row is not None

    with pytest.raises(HTTPException) as missing_reason:
        products.update_product_lifecycle(
            product_id,
            ProductLifecycleUpdateRequest(
                target_status="inactive",
                confirmed=True,
                inactive_reason=None,
            ),
            db=db,
            current_user=admin,
        )
    assert missing_reason.value.status_code == 400
    assert "inactive_reason is required" in str(missing_reason.value.detail)

    factory.order(product=product_row, order_code="LC-CONFIRM-01", status="pending")
    db.commit()

    impact = products.get_product_impact_analysis(
        product_id,
        operation="lifecycle",
        target_status="inactive",
        target_version=None,
        db=db,
        _=admin,
    )
    assert impact.data.requires_confirmation is True

    with pytest.raises(HTTPException) as unconfirmed:
        products.update_product_lifecycle(
            product_id,
            ProductLifecycleUpdateRequest(
                target_status="inactive",
                confirmed=False,
                inactive_reason="停用验证",
            ),
            db=db,
            current_user=admin,
        )
    assert unconfirmed.value.status_code == 400
    assert "Impact confirmation required" in str(unconfirmed.value.detail)

    inactive = products.update_product_lifecycle(
        product_id,
        ProductLifecycleUpdateRequest(
            target_status="inactive",
            confirmed=True,
            inactive_reason="停用验证",
        ),
        db=db,
        current_user=admin,
    )
    assert inactive.data.lifecycle_status == "inactive"
    assert inactive.data.inactive_reason == "停用验证"

    active = products.update_product_lifecycle(
        product_id,
        ProductLifecycleUpdateRequest(target_status="active", confirmed=False),
        db=db,
        current_user=admin,
    )
    assert active.data.lifecycle_status == "active"
    assert active.data.inactive_reason is None


def test_product_version_management_and_compare_flow(db, factory) -> None:
    admin = _create_admin(factory, "product_func_admin_5")

    created = products.create_product_api(
        ProductCreate(name="版本产品A", category="贴片", remark=""),
        db=db,
        current_user=admin,
    )
    product_id = created.data.id

    activated_v1 = products.activate_product_version_api(
        product_id,
        version=1,
        payload=ProductVersionActivateRequest(confirmed=False),
        db=db,
        current_user=admin,
    )
    assert activated_v1.data.version == 1
    assert activated_v1.data.lifecycle_status == "effective"

    copied = products.copy_product_version_api(
        product_id,
        version=1,
        payload=ProductVersionCopyRequest(source_version=1),
        db=db,
        current_user=admin,
    )
    assert copied.data.version == 2
    assert copied.data.lifecycle_status == "draft"
    assert copied.data.source_version == 1

    noted = products.update_product_version_note_api(
        product_id,
        version=2,
        body=ProductVersionNoteUpdateRequest(note="草稿备注"),
        db=db,
        current_user=admin,
    )
    assert noted.data.note == "草稿备注"

    compare = products.compare_product_version_api(
        product_id,
        from_version=1,
        to_version=2,
        db=db,
        _=admin,
    )
    assert compare.data.from_version == 1
    assert compare.data.to_version == 2

    activated_v2 = products.activate_product_version_api(
        product_id,
        version=2,
        payload=ProductVersionActivateRequest(confirmed=False),
        db=db,
        current_user=admin,
    )
    assert activated_v2.data.version == 2
    assert activated_v2.data.lifecycle_status == "effective"

    disabled_v2 = products.disable_product_version_api(
        product_id,
        version=2,
        db=db,
        current_user=admin,
    )
    assert disabled_v2.data.lifecycle_status == "disabled"

    draft_v3 = products.create_product_version_api(
        product_id,
        db=db,
        current_user=admin,
    )
    assert draft_v3.data.version == 3
    assert draft_v3.data.lifecycle_status == "draft"

    deleted_v3 = products.delete_product_version_api(
        product_id,
        version=3,
        db=db,
        current_user=admin,
    )
    assert deleted_v3.data["deleted"] is True

    versions = products.get_product_versions(product_id, db=db, _=admin)
    assert versions.data.total >= 2
    assert any(item.version == 2 and item.lifecycle_status == "disabled" for item in versions.data.items)


def test_product_rollback_requires_confirmation_with_open_orders(db, factory) -> None:
    admin = _create_admin(factory, "product_func_admin_6")

    created = products.create_product_api(
        ProductCreate(name="回滚产品A", category="贴片", remark=""),
        db=db,
        current_user=admin,
    )
    product_id = created.data.id
    product_row = db.get(Product, product_id)
    assert product_row is not None

    products.activate_product_version_api(
        product_id,
        version=1,
        payload=ProductVersionActivateRequest(confirmed=False),
        db=db,
        current_user=admin,
    )

    products.update_parameters(
        product_id,
        _build_parameter_payload(
            product_name="回滚产品A-v2",
            remark="生成版本2",
            extra_name="回滚参数",
            extra_value="v2",
            confirmed=False,
        ),
        db=db,
        current_user=admin,
    )

    factory.order(product=product_row, order_code="RB-CONFIRM-01", status="pending")
    db.commit()

    impact = products.get_product_impact_analysis(
        product_id,
        operation="rollback",
        target_status=None,
        target_version=1,
        db=db,
        _=admin,
    )
    assert impact.data.requires_confirmation is True
    assert impact.data.total_orders == 1

    with pytest.raises(HTTPException) as unconfirmed:
        products.rollback_product_api(
            product_id,
            ProductRollbackRequest(target_version=1, confirmed=False, note="未确认回滚"),
            db=db,
            current_user=admin,
        )
    assert unconfirmed.value.status_code == 400
    assert "Impact confirmation required" in str(unconfirmed.value.detail)

    rolled_back = products.rollback_product_api(
        product_id,
        ProductRollbackRequest(target_version=1, confirmed=True, note="确认回滚"),
        db=db,
        current_user=admin,
    )
    assert rolled_back.data.product.current_version == 3
    assert rolled_back.data.product.effective_version == 3
    assert PRODUCT_NAME_PARAMETER_KEY in rolled_back.data.changed_keys
