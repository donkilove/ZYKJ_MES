from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import httpx


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV = {
    "POSTGRES_HOST_PORT": "5433",
    "BACKEND_WEB_HOST_PORT": "8000",
    "JWT_SECRET_KEY": "docker-local-jwt-secret-20260414",
    "BOOTSTRAP_ADMIN_PASSWORD": "Admin_Local_20260414!",
    "PRODUCTION_DEFAULT_VERIFICATION_CODE": "FA20260414",
}
DEFAULT_CHECKS = [
    "health",
    "login",
    "authz_catalog",
    "role_create",
    "user_create",
    "product_create",
    "production_order_flow",
    "first_article_flow",
    "export_flow",
]


@dataclass(frozen=True)
class SmokeContext:
    base_url: str
    admin_password: str


def _backend_runtime():
    backend_root = REPO_ROOT / "backend"
    if str(backend_root) not in sys.path:
        sys.path.insert(0, str(backend_root))
    os.environ.setdefault("DB_HOST", "127.0.0.1")
    os.environ.setdefault("DB_PORT", DEFAULT_ENV["POSTGRES_HOST_PORT"])
    os.environ.setdefault("DB_NAME", "mes_db")
    os.environ.setdefault("DB_USER", "mes_user")
    os.environ.setdefault("DB_PASSWORD", "mes_password")

    from app.db.session import SessionLocal  # noqa: PLC0415
    from app.models.first_article_record import FirstArticleRecord  # noqa: PLC0415
    from app.models.first_article_template import FirstArticleTemplate  # noqa: PLC0415
    from app.models.production_order import ProductionOrder  # noqa: PLC0415
    from app.models.production_order_process import ProductionOrderProcess  # noqa: PLC0415
    from app.models.production_sub_order import ProductionSubOrder  # noqa: PLC0415
    from app.models.user import User  # noqa: PLC0415

    return {
        "SessionLocal": SessionLocal,
        "FirstArticleRecord": FirstArticleRecord,
        "FirstArticleTemplate": FirstArticleTemplate,
        "ProductionOrder": ProductionOrder,
        "ProductionOrderProcess": ProductionOrderProcess,
        "ProductionSubOrder": ProductionSubOrder,
        "User": User,
    }


def build_env() -> dict[str, str]:
    env = os.environ.copy()
    for key, value in DEFAULT_ENV.items():
        env.setdefault(key, value)
    return env


def docker_compose(*args: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["docker", "compose", *args],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
        env=env,
    )


def ensure_compose_success(step: str, result: subprocess.CompletedProcess[str]) -> None:
    if result.returncode == 0:
        return
    raise RuntimeError(
        f"{step} failed with exit code {result.returncode}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )


def wait_for_health(base_url: str, timeout_seconds: float = 90.0) -> None:
    deadline = time.monotonic() + timeout_seconds
    last_error = ""
    while time.monotonic() < deadline:
        try:
            response = httpx.get(f"{base_url}/health", timeout=5.0)
            if response.status_code == 200:
                return
            last_error = f"status={response.status_code} body={response.text}"
        except Exception as exc:  # noqa: BLE001
            last_error = f"{type(exc).__name__}: {exc}"
        time.sleep(1.0)
    raise RuntimeError(f"backend health check timeout: {last_error}")


def smoke_login(client: httpx.Client, ctx: SmokeContext) -> str:
    response = client.post(
        f"{ctx.base_url}/api/v1/auth/login",
        data={"username": "admin", "password": ctx.admin_password},
    )
    if response.status_code != 200:
        raise RuntimeError(f"login failed: {response.status_code} {response.text}")
    return response.json()["data"]["access_token"]


def _print_step(name: str, detail: str) -> None:
    print(f"[{name}] {detail}")


def smoke_health(client: httpx.Client, ctx: SmokeContext) -> None:
    response = client.get(f"{ctx.base_url}/health")
    if response.status_code != 200:
        raise RuntimeError(f"health failed: {response.status_code} {response.text}")
    _print_step("health", str(response.status_code))


def smoke_authz_catalog(client: httpx.Client, ctx: SmokeContext, token: str) -> None:
    response = client.get(
        f"{ctx.base_url}/api/v1/authz/capability-packs/catalog",
        params={"module": "user"},
        headers={"Authorization": f"Bearer {token}"},
    )
    if response.status_code != 200:
        raise RuntimeError(f"authz_catalog failed: {response.status_code} {response.text}")
    _print_step("authz_catalog", str(response.status_code))


def smoke_role_create(
    client: httpx.Client, ctx: SmokeContext, token: str, suffix: str
) -> dict[str, object]:
    role_code = f"rl{suffix}"
    response = client.post(
        f"{ctx.base_url}/api/v1/roles",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "code": role_code,
            "name": f"R{suffix}",
            "description": "Docker smoke role create",
            "role_type": "custom",
            "is_enabled": True,
        },
    )
    if response.status_code != 201:
        raise RuntimeError(f"role_create failed: {response.status_code} {response.text}")
    _print_step("role_create", str(response.status_code))
    data = response.json()["data"]
    return {"code": role_code, "id": data["id"], "name": data["name"]}


def smoke_user_create(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    suffix: str,
    role_code: str,
) -> dict[str, object]:
    username = f"u{suffix}"
    response = client.post(
        f"{ctx.base_url}/api/v1/users",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "username": username,
            "password": "Pwd@123",
            "role_code": role_code,
            "remark": "Docker smoke user create",
            "is_active": True,
        },
    )
    if response.status_code != 201:
        raise RuntimeError(f"user_create failed: {response.status_code} {response.text}")
    _print_step("user_create", str(response.status_code))
    data = response.json()["data"]
    return {"username": username, "id": data["id"]}


def smoke_product_create(
    client: httpx.Client, ctx: SmokeContext, token: str, suffix: str
) -> dict[str, object]:
    product_name = f"DockerProduct{suffix}"
    response = client.post(
        f"{ctx.base_url}/api/v1/products",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": product_name,
            "category": "DTU",
            "remark": "Docker smoke product create",
        },
    )
    if response.status_code != 201:
        raise RuntimeError(f"product_create failed: {response.status_code} {response.text}")
    _print_step("product_create", str(response.status_code))
    data = response.json()["data"]
    return {
        "id": data["id"],
        "name": data["name"],
        "current_version": data.get("current_version", 1),
        "effective_version": data.get("effective_version", 0),
    }


def smoke_activate_product(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    product: dict[str, object],
) -> None:
    response = client.post(
        f"{ctx.base_url}/api/v1/products/{product['id']}/versions/{product['current_version']}/activate",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "confirmed": True,
            "expected_effective_version": int(product.get("effective_version", 0) or 0),
        },
    )
    if response.status_code != 200:
        raise RuntimeError(f"product_activate failed: {response.status_code} {response.text}")
    _print_step("product_activate", str(response.status_code))


def smoke_create_stage(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    suffix: str,
) -> dict[str, object]:
    stage_code = f"ST{suffix}"
    response = client.post(
        f"{ctx.base_url}/api/v1/craft/stages",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "code": stage_code,
            "name": stage_code,
            "sort_order": 0,
            "remark": "Docker smoke stage",
        },
    )
    if response.status_code != 201:
        raise RuntimeError(f"stage_create failed: {response.status_code} {response.text}")
    _print_step("stage_create", str(response.status_code))
    return response.json()["data"]


def smoke_create_process(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    stage_id: int,
    stage_code: str,
    suffix: str,
) -> dict[str, object]:
    process_code = f"{stage_code}-01"
    response = client.post(
        f"{ctx.base_url}/api/v1/craft/processes",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "code": process_code,
            "name": process_code,
            "stage_id": stage_id,
            "remark": "Docker smoke process",
        },
    )
    if response.status_code != 201:
        raise RuntimeError(f"process_create failed: {response.status_code} {response.text}")
    _print_step("process_create", str(response.status_code))
    return response.json()["data"]


def smoke_create_supplier(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    suffix: str,
) -> dict[str, object]:
    supplier_name = f"Supplier{suffix}"
    response = client.post(
        f"{ctx.base_url}/api/v1/quality/suppliers",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": supplier_name, "remark": "Docker smoke supplier", "is_enabled": True},
    )
    if response.status_code != 201:
        raise RuntimeError(f"supplier_create failed: {response.status_code} {response.text}")
    _print_step("supplier_create", str(response.status_code))
    return response.json()["data"]


def smoke_create_order(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    product_id: int,
    supplier_id: int,
    stage_id: int,
    process_id: int,
    suffix: str,
) -> dict[str, object]:
    order_code = f"PO-SMOKE-{suffix}"
    response = client.post(
        f"{ctx.base_url}/api/v1/production/orders",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "order_code": order_code,
            "product_id": product_id,
            "supplier_id": supplier_id,
            "quantity": 10,
            "process_steps": [
                {"step_order": 1, "stage_id": stage_id, "process_id": process_id}
            ],
        },
    )
    if response.status_code != 201:
        raise RuntimeError(f"order_create failed: {response.status_code} {response.text}")
    _print_step("order_create", str(response.status_code))
    return response.json()["data"]


def smoke_production_order_flow(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    state: dict[str, object],
) -> None:
    suffix = str(int(time.time()))[-5:]
    stage = smoke_create_stage(client, ctx, token, suffix)
    process = smoke_create_process(
        client,
        ctx,
        token,
        stage_id=int(stage["id"]),
        stage_code=str(stage["code"]),
        suffix=suffix,
    )
    product = smoke_product_create(client, ctx, token, suffix)
    smoke_activate_product(client, ctx, token, product)
    supplier = smoke_create_supplier(client, ctx, token, suffix)
    order = smoke_create_order(
        client,
        ctx,
        token,
        product_id=int(product["id"]),
        supplier_id=int(supplier["id"]),
        stage_id=int(stage["id"]),
        process_id=int(process["id"]),
        suffix=suffix,
    )
    state.update(
        {
            "stage": stage,
            "process": process,
            "product": product,
            "supplier": supplier,
            "order": order,
        }
    )
    _print_step("production_order_flow", str(order["id"]))


def prepare_first_article_support(state: dict[str, object]) -> dict[str, object]:
    runtime = _backend_runtime()
    SessionLocal = runtime["SessionLocal"]
    ProductionOrder = runtime["ProductionOrder"]
    ProductionOrderProcess = runtime["ProductionOrderProcess"]
    FirstArticleTemplate = runtime["FirstArticleTemplate"]
    ProductionSubOrder = runtime["ProductionSubOrder"]
    User = runtime["User"]

    order_id = int(state["order"]["id"])
    participant_user_id = int(state["user"]["id"])

    db = SessionLocal()
    try:
        order_row = db.get(ProductionOrder, order_id)
        if order_row is None:
            raise RuntimeError(f"order not found: {order_id}")
        process_row = (
            db.query(ProductionOrderProcess)
            .filter(ProductionOrderProcess.order_id == order_row.id)
            .order_by(ProductionOrderProcess.process_order.asc())
            .first()
        )
        admin = db.query(User).filter(User.username == "admin").first()
        if process_row is None or admin is None:
            raise RuntimeError("first article support data missing")

        template = FirstArticleTemplate(
            product_id=order_row.product_id,
            process_code=process_row.process_code,
            template_name=f"SmokeFA-{order_row.id}",
            check_content="Smoke check content",
            test_value="Smoke test value",
            is_enabled=True,
        )
        db.add(template)

        sub_order = (
            db.query(ProductionSubOrder)
            .filter(
                ProductionSubOrder.order_process_id == process_row.id,
                ProductionSubOrder.operator_user_id == admin.id,
            )
            .first()
        )
        if sub_order is None:
            db.add(
                ProductionSubOrder(
                    order_process_id=process_row.id,
                    operator_user_id=admin.id,
                    assigned_quantity=10,
                    completed_quantity=0,
                    status="pending",
                    is_visible=True,
                )
            )
        else:
            sub_order.assigned_quantity = 10
            sub_order.completed_quantity = 0
            sub_order.status = "pending"
            sub_order.is_visible = True

        db.commit()
        db.refresh(template)
        return {
            "order_process_id": int(process_row.id),
            "template_id": int(template.id),
            "participant_user_ids": [int(admin.id), participant_user_id],
        }
    finally:
        db.close()


def verify_first_article_record(state: dict[str, object], support: dict[str, object]) -> None:
    runtime = _backend_runtime()
    SessionLocal = runtime["SessionLocal"]
    FirstArticleRecord = runtime["FirstArticleRecord"]

    db = SessionLocal()
    try:
        row = (
            db.query(FirstArticleRecord)
            .filter(FirstArticleRecord.order_id == int(state["order"]["id"]))
            .order_by(FirstArticleRecord.id.desc())
            .first()
        )
        if row is None:
            raise RuntimeError("first article record not created")
        if int(row.template_id or 0) != int(support["template_id"]):
            raise RuntimeError("first article template mismatch")
        if row.result != "failed":
            raise RuntimeError(f"unexpected first article result: {row.result}")
    finally:
        db.close()


def smoke_first_article_flow(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    state: dict[str, object],
) -> None:
    support = prepare_first_article_support(state)
    order_id = int(state["order"]["id"])

    template_response = client.get(
        f"{ctx.base_url}/api/v1/production/orders/{order_id}/first-article/templates",
        headers={"Authorization": f"Bearer {token}"},
        params={"order_process_id": support["order_process_id"]},
    )
    if template_response.status_code != 200:
        raise RuntimeError(
            f"first_article_templates failed: {template_response.status_code} {template_response.text}"
        )

    participant_response = client.get(
        f"{ctx.base_url}/api/v1/production/orders/{order_id}/first-article/participant-users",
        headers={"Authorization": f"Bearer {token}"},
    )
    if participant_response.status_code != 200:
        raise RuntimeError(
            f"first_article_participants failed: {participant_response.status_code} {participant_response.text}"
        )

    parameter_response = client.get(
        f"{ctx.base_url}/api/v1/production/orders/{order_id}/first-article/parameters",
        headers={"Authorization": f"Bearer {token}"},
        params={"order_process_id": support["order_process_id"]},
    )
    if parameter_response.status_code != 200:
        raise RuntimeError(
            f"first_article_parameters failed: {parameter_response.status_code} {parameter_response.text}"
        )
    if int(parameter_response.json()["data"]["total"]) <= 0:
        raise RuntimeError("first article parameters empty")

    submit_response = client.post(
        f"{ctx.base_url}/api/v1/production/orders/{order_id}/first-article",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "order_process_id": support["order_process_id"],
            "template_id": support["template_id"],
            "check_content": "Smoke real check content",
            "test_value": "9.86",
            "result": "failed",
            "participant_user_ids": support["participant_user_ids"],
            "verification_code": ctx.admin_password and DEFAULT_ENV["PRODUCTION_DEFAULT_VERIFICATION_CODE"],
            "remark": "Docker smoke first article",
        },
    )
    if submit_response.status_code != 200:
        raise RuntimeError(
            f"first_article_submit failed: {submit_response.status_code} {submit_response.text}"
        )
    verify_first_article_record(state, support)
    _print_step("first_article_flow", str(submit_response.status_code))


def smoke_export_flow(
    client: httpx.Client,
    ctx: SmokeContext,
    token: str,
    state: dict[str, object],
) -> None:
    order_code = str(state["order"]["order_code"])
    order_export = client.post(
        f"{ctx.base_url}/api/v1/production/orders/export",
        headers={"Authorization": f"Bearer {token}"},
        json={"keyword": order_code},
    )
    if order_export.status_code != 200:
        raise RuntimeError(
            f"production_orders_export failed: {order_export.status_code} {order_export.text}"
        )
    if not order_export.json()["data"]["content_base64"]:
        raise RuntimeError("production_orders_export returned empty content")

    my_order_export = client.post(
        f"{ctx.base_url}/api/v1/production/my-orders/export",
        headers={"Authorization": f"Bearer {token}"},
        json={"keyword": order_code, "view_mode": "own"},
    )
    if my_order_export.status_code != 200:
        raise RuntimeError(
            f"my_orders_export failed: {my_order_export.status_code} {my_order_export.text}"
        )
    if not my_order_export.json()["data"]["content_base64"]:
        raise RuntimeError("my_orders_export returned empty content")
    _print_step("export_flow", "200")


def run_smoke(checks: list[str]) -> None:
    env = build_env()
    ctx = SmokeContext(
        base_url=f"http://127.0.0.1:{env['BACKEND_WEB_HOST_PORT']}",
        admin_password=env["BOOTSTRAP_ADMIN_PASSWORD"],
    )

    ensure_compose_success(
        "docker compose up",
        docker_compose(
            "up",
            "-d",
            "--build",
            "postgres",
            "redis",
            "backend-web",
            "backend-worker",
            env=env,
        ),
    )
    wait_for_health(ctx.base_url)

    suffix = str(int(time.time()))[-5:]
    state: dict[str, object] = {}
    with httpx.Client(timeout=20.0) as client:
        token = ""
        role_code = ""
        if "health" in checks:
            smoke_health(client, ctx)
        if "login" in checks:
            token = smoke_login(client, ctx)
            _print_step("login", "200")
        if "authz_catalog" in checks:
            smoke_authz_catalog(client, ctx, token)
        if "role_create" in checks:
            role = smoke_role_create(client, ctx, token, suffix)
            role_code = str(role["code"])
            state["role"] = role
        if "user_create" in checks:
            state["user"] = smoke_user_create(client, ctx, token, suffix, role_code)
        if "product_create" in checks:
            state["product"] = smoke_product_create(client, ctx, token, suffix)
        if "production_order_flow" in checks:
            smoke_production_order_flow(client, ctx, token, state)
        if "first_article_flow" in checks:
            smoke_first_article_flow(client, ctx, token, state)
        if "export_flow" in checks:
            smoke_export_flow(client, ctx, token, state)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Docker backend smoke runner.")
    parser.add_argument(
        "action",
        nargs="?",
        default="run",
        choices=("run", "up", "down"),
        help="docker lifecycle action",
    )
    parser.add_argument(
        "--checks",
        nargs="*",
        default=DEFAULT_CHECKS,
        help="ordered smoke checks to run",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    env = build_env()

    if args.action == "up":
        result = docker_compose(
            "up",
            "-d",
            "--build",
            "postgres",
            "redis",
            "backend-web",
            "backend-worker",
            env=env,
        )
        ensure_compose_success("docker compose up", result)
        print(result.stdout.strip())
        return 0

    if args.action == "down":
        result = docker_compose("down", env=env)
        ensure_compose_success("docker compose down", result)
        print(result.stdout.strip())
        return 0

    run_smoke(args.checks)
    print("DOCKER_BACKEND_SMOKE_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
