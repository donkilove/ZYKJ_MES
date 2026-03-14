from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import products
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.schemas.product import (
    ProductCreate,
    ProductVersionActivateRequest,
    ProductVersionCopyRequest,
)


def _create_admin(factory, username: str):
    factory.ensure_default_roles()
    return factory.user(
        username=username,
        role_codes=[ROLE_SYSTEM_ADMIN],
        password="Admin@123",
    )


def test_copy_version_should_validate_path_version_matches_payload(db, factory) -> None:
    """回归用例：路由 version 与 payload.source_version 应保持一致。"""

    admin = _create_admin(factory, "product_issue_admin_1")
    created = products.create_product_api(
        ProductCreate(name="版本一致性产品", category="贴片", remark=""),
        db=db,
        current_user=admin,
    )

    # 先把版本 1 生效，再补出并生效版本 2，避免“存在草稿版本”短路。
    products.activate_product_version_api(
        product_id=created.data.id,
        version=1,
        payload=ProductVersionActivateRequest(confirmed=False),
        db=db,
        current_user=admin,
    )
    products.create_product_version_api(
        product_id=created.data.id,
        db=db,
        current_user=admin,
    )
    products.activate_product_version_api(
        product_id=created.data.id,
        version=2,
        payload=ProductVersionActivateRequest(confirmed=False),
        db=db,
        current_user=admin,
    )

    with pytest.raises(HTTPException) as mismatch_error:
        products.copy_product_version_api(
            product_id=created.data.id,
            version=1,
            payload=ProductVersionCopyRequest(source_version=2),
            db=db,
            current_user=admin,
        )

    assert mismatch_error.value.status_code == 400
