from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

from sqlalchemy.orm import Session

from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
)
from app.models.user import User
from app.services import authz_service


DEFAULT_PERF_CAPACITY_ROLE_MODULES: tuple[tuple[str, str], ...] = (
    (ROLE_PRODUCTION_ADMIN, "production"),
    (ROLE_PRODUCTION_ADMIN, "craft"),
    (ROLE_PRODUCTION_ADMIN, "product"),
    (ROLE_QUALITY_ADMIN, "quality"),
    (ROLE_MAINTENANCE_STAFF, "equipment"),
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


def build_perf_capacity_permission_rollout_plan(
    db: Session,
    *,
    role_modules: Sequence[tuple[str, str]] = DEFAULT_PERF_CAPACITY_ROLE_MODULES,
) -> list[PerfCapacityPermissionPlanItem]:
    plan: list[PerfCapacityPermissionPlanItem] = []
    for role_code, module_code in role_modules:
        permission_codes = sorted(
            {
                str(row.permission_code)
                for row in authz_service.list_permission_catalog_rows(
                    db, module_code=module_code
                )
                if str(row.permission_code).strip()
            }
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
        updated_count += int(result_updated_count)
        items.append(
            {
                "role_code": item.role_code,
                "module_code": item.module_code,
                "updated_count": int(result_updated_count),
                "before_permission_codes": before_codes,
                "after_permission_codes": after_codes,
            }
        )
    return PerfCapacityPermissionApplyResult(
        updated_count=updated_count,
        role_module_pairs=len(plan),
        items=items,
    )
