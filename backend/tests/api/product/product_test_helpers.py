from __future__ import annotations

import time

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.product import Product
from app.models.product_parameter import ProductParameter
from app.models.product_parameter_history import ProductParameterHistory
from app.models.product_revision import ProductRevision
from app.models.product_revision_parameter import ProductRevisionParameter
from app.models.production_order import ProductionOrder


ADMIN_PASSWORD = "Admin@123456"


def unique_suffix(label: str) -> str:
    return f"{label}{int(time.time() * 1000)}"


def auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def create_product(
    client: TestClient,
    admin_headers: dict[str, str],
    *,
    suffix: str,
    category: str = "贴片",
    remark: str | None = None,
) -> dict:
    payload = {
        "name": f"产品模块集成测试-{unique_suffix(suffix)}",
        "category": category,
        "remark": remark or f"{suffix} 场景",
    }
    response = client.post("/api/v1/products", headers=admin_headers, json=payload)
    assert response.status_code == 201, response.text
    return response.json()["data"]


def get_product_row(db_session: Session, product_id: int) -> Product | None:
    db_session.expire_all()
    return db_session.execute(
        select(Product).where(Product.id == product_id)
    ).scalars().first()


def get_revision_rows(db_session: Session, product_id: int) -> list[ProductRevision]:
    db_session.expire_all()
    return db_session.execute(
        select(ProductRevision)
        .where(ProductRevision.product_id == product_id)
        .order_by(ProductRevision.version.asc(), ProductRevision.id.asc())
    ).scalars().all()


def get_current_parameter_rows(
    db_session: Session,
    product_id: int,
) -> list[ProductParameter]:
    db_session.expire_all()
    return db_session.execute(
        select(ProductParameter)
        .where(ProductParameter.product_id == product_id)
        .order_by(ProductParameter.sort_order.asc(), ProductParameter.id.asc())
    ).scalars().all()


def get_revision_parameter_rows(
    db_session: Session,
    product_id: int,
    version: int,
) -> list[ProductRevisionParameter]:
    db_session.expire_all()
    return db_session.execute(
        select(ProductRevisionParameter)
        .where(
            ProductRevisionParameter.product_id == product_id,
            ProductRevisionParameter.version == version,
        )
        .order_by(
            ProductRevisionParameter.sort_order.asc(),
            ProductRevisionParameter.id.asc(),
        )
    ).scalars().all()


def get_history_rows(
    db_session: Session,
    product_id: int,
) -> list[ProductParameterHistory]:
    db_session.expire_all()
    return db_session.execute(
        select(ProductParameterHistory)
        .where(ProductParameterHistory.product_id == product_id)
        .order_by(
            ProductParameterHistory.created_at.desc(),
            ProductParameterHistory.id.desc(),
        )
    ).scalars().all()


def create_order_row(
    db_session: Session,
    *,
    product_id: int,
    product_version: int,
    status: str,
) -> ProductionOrder:
    order = ProductionOrder(
        order_code=f"ORD-PRODUCT-{status.upper()}-{unique_suffix('R')}",
        product_id=product_id,
        product_version=product_version,
        quantity=1,
        status=status,
    )
    db_session.add(order)
    db_session.commit()
    db_session.refresh(order)
    return order


def load_version_parameters(
    client: TestClient,
    headers: dict[str, str],
    *,
    product_id: int,
    version: int,
) -> dict:
    response = client.get(
        f"/api/v1/products/{product_id}/versions/{version}/parameters",
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()["data"]


def update_version_parameter_value(
    client: TestClient,
    headers: dict[str, str],
    *,
    product_id: int,
    version: int,
    parameter_name: str,
    parameter_value: str,
    remark: str,
) -> dict:
    payload = load_version_parameters(
        client,
        headers,
        product_id=product_id,
        version=version,
    )
    updated = False
    for item in payload["items"]:
        if item["name"] == parameter_name:
            item["value"] = parameter_value
            updated = True
            break
    assert updated, f"未找到参数 {parameter_name}"

    response = client.put(
        f"/api/v1/products/{product_id}/versions/{version}/parameters",
        headers=headers,
        json={
            "remark": remark,
            "items": payload["items"],
        },
    )
    assert response.status_code == 200, response.text
    return response.json()["data"]


def activate_version(
    client: TestClient,
    headers: dict[str, str],
    *,
    product_id: int,
    version: int,
    expected_effective_version: int,
    confirmed: bool = True,
):
    return client.post(
        f"/api/v1/products/{product_id}/versions/{version}/activate",
        headers=headers,
        json={
            "confirmed": confirmed,
            "expected_effective_version": expected_effective_version,
        },
    )


def find_parameter_value(payload: dict, parameter_name: str) -> str:
    return next(
        item["value"] for item in payload["items"] if item["name"] == parameter_name
    )
