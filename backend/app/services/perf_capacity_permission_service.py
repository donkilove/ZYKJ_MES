from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

from sqlalchemy.orm import Session

from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.models.user import User
from app.services import authz_service


DEFAULT_PERF_CAPACITY_ROLE_MODULES: tuple[tuple[str, str], ...] = (
    (ROLE_SYSTEM_ADMIN, "user"),
    (ROLE_SYSTEM_ADMIN, "system"),
    (ROLE_SYSTEM_ADMIN, "message"),
    (ROLE_PRODUCTION_ADMIN, "production"),
    (ROLE_OPERATOR, "production"),
    (ROLE_PRODUCTION_ADMIN, "craft"),
    (ROLE_PRODUCTION_ADMIN, "product"),
    (ROLE_QUALITY_ADMIN, "quality"),
    (ROLE_MAINTENANCE_STAFF, "equipment"),
)

OPERATOR_PRODUCTION_PERMISSION_CODES = frozenset(
    {
        "module.production.access",
        "page.production.view",
        "page.production_order_query.view",
        "feature.production.order_query.execute",
        "feature.production.assist.launch",
        "feature.production.repair_orders.create_manual",
        "production.orders.detail",
        "production.my_orders.list",
        "production.my_orders.context",
        "production.execution.first_article",
        "production.execution.end_production",
        "production.assist_authorizations.create",
        "production.assist_user_options.list",
        "production.repair_orders.create_manual",
    }
)


@dataclass(frozen=True)
class PerfCapacityPermissionPlanItem:
    role_code: str
    module_code: str
    permission_codes: list[str]


@dataclass(frozen=True)
class PerfCapacityPermissionApplyResult:
    updated_count: int
    role_module_pairs: int
    items: list[dict[str, object]]


def _apply_hierarchy_rollout_if_supported(
    db: Session,
    *,
    role_code: str,
    module_code: str,
    operator: User | None,
) -> int:
    if role_code != ROLE_SYSTEM_ADMIN or module_code not in {"user", "system", "message"}:
        return 0

    try:
        payload = authz_service.get_permission_hierarchy_catalog(
            db, module_code=module_code
        )
    except ValueError:
        return 0
    page_permission_codes = sorted(
        {
            str(item.get("permission_code", "")).strip()
            for item in payload.get("pages", [])
            if isinstance(item, dict) and str(item.get("permission_code", "")).strip()
        }
    )
    feature_permission_codes = sorted(
        {
            str(item.get("permission_code", "")).strip()
            for item in payload.get("features", [])
            if isinstance(item, dict) and str(item.get("permission_code", "")).strip()
        }
    )
    if not page_permission_codes and not feature_permission_codes:
        return 0

    result = authz_service.update_permission_hierarchy_role_config(
        db,
        role_code=role_code,
        module_code=module_code,
        module_enabled=True,
        page_permission_codes=page_permission_codes,
        feature_permission_codes=feature_permission_codes,
        dry_run=False,
        operator=operator,
    )
    return int(result.get("updated_count", 0))


def build_perf_capacity_permission_rollout_plan(
    db: Session,
    *,
    role_modules: Sequence[tuple[str, str]] = DEFAULT_PERF_CAPACITY_ROLE_MODULES,
) -> list[PerfCapacityPermissionPlanItem]:
    plan: list[PerfCapacityPermissionPlanItem] = []
    for role_code, module_code in role_modules:
        catalog_permission_codes = {
            str(row.permission_code)
            for row in authz_service.list_permission_catalog_rows(
                db, module_code=module_code
            )
            if str(row.permission_code).strip()
        }
        if role_code == ROLE_OPERATOR and module_code == "production":
            permission_codes = sorted(
                catalog_permission_codes.intersection(
                    OPERATOR_PRODUCTION_PERMISSION_CODES
                )
            )
        else:
            permission_codes = sorted(
                catalog_permission_codes
            )
        if not permission_codes:
            raise ValueError(f"模块 {module_code} 的权限目录为空")
        plan.append(
            PerfCapacityPermissionPlanItem(
                role_code=role_code,
                module_code=module_code,
                permission_codes=permission_codes,
            )
        )
    return plan


def apply_perf_capacity_permission_rollout(
    db: Session,
    *,
    operator: User | None = None,
    dry_run: bool = False,
    remark: str | None = "perf phase1 permission rollout",
    role_modules: Sequence[tuple[str, str]] = DEFAULT_PERF_CAPACITY_ROLE_MODULES,
) -> PerfCapacityPermissionApplyResult:
    plan = build_perf_capacity_permission_rollout_plan(db, role_modules=role_modules)
    updated_count = 0
    items: list[dict[str, object]] = []
    for item in plan:
        result_updated_count, before_codes, after_codes = (
            authz_service.replace_role_permissions_for_module(
                db,
                role_code=item.role_code,
                module_code=item.module_code,
                granted_permission_codes=item.permission_codes,
                operator=operator,
                remark=remark,
            )
        )
        hierarchy_updated_count = _apply_hierarchy_rollout_if_supported(
            db,
            role_code=item.role_code,
            module_code=item.module_code,
            operator=operator,
        )
        updated_count += int(result_updated_count) + int(hierarchy_updated_count)
        items.append(
            {
                "role_code": item.role_code,
                "module_code": item.module_code,
                "updated_count": int(result_updated_count) + int(hierarchy_updated_count),
                "direct_updated_count": int(result_updated_count),
                "hierarchy_updated_count": int(hierarchy_updated_count),
                "before_permission_codes": before_codes,
                "after_permission_codes": after_codes,
                }
            )
    if not dry_run:
        authz_service.invalidate_permission_cache()
    return PerfCapacityPermissionApplyResult(
        updated_count=updated_count,
        role_module_pairs=len(plan),
        items=items,
    )
