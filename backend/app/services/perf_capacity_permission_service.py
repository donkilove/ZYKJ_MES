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
    capability_codes: list[str]


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
        catalog = authz_service.get_capability_pack_catalog(db, module_code=module_code)
        template = next(
            (
                item
                for item in catalog["role_templates"]
                if str(item["role_code"]) == role_code
            ),
            None,
        )
        if template is None:
            raise ValueError(f"模块 {module_code} 缺少角色 {role_code} 的模板")
        capability_codes = [
            str(code) for code in template.get("capability_codes", []) if str(code).strip()
        ]
        if not capability_codes:
            raise ValueError(f"模块 {module_code} 的角色 {role_code} 模板为空")
        plan.append(
            PerfCapacityPermissionPlanItem(
                role_code=role_code,
                module_code=module_code,
                capability_codes=capability_codes,
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
        result = authz_service.update_capability_pack_role_config(
            db,
            role_code=item.role_code,
            module_code=item.module_code,
            module_enabled=True,
            capability_codes=item.capability_codes,
            dry_run=dry_run,
            operator=operator,
            remark=remark,
        )
        updated_count += int(result.get("updated_count", 0))
        items.append(result)
    return PerfCapacityPermissionApplyResult(
        updated_count=updated_count,
        role_module_pairs=len(plan),
        items=items,
    )
