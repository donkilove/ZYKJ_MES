from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.core.security import get_password_hash
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.role import Role
from app.models.user import User
from app.services.role_service import get_roles_by_codes
from app.services.user_service import get_user_by_username


@dataclass(frozen=True)
class PerfUserPoolSpec:
    pool_name: str
    role_code: str
    username_prefix: str
    count: int
    requires_stage: bool = False


@dataclass(frozen=True)
class PerfUserAccountSpec:
    pool_name: str
    role_code: str
    username: str
    requires_stage: bool = False


@dataclass(frozen=True)
class PerfUserSeedResult:
    created_count: int
    updated_count: int
    usernames: list[str]


DEFAULT_PERF_USER_POOL_SPECS: tuple[PerfUserPoolSpec, ...] = (
    PerfUserPoolSpec(
        pool_name="pool-admin",
        role_code=ROLE_SYSTEM_ADMIN,
        username_prefix="ltadm",
        count=2,
    ),
    PerfUserPoolSpec(
        pool_name="pool-user-admin",
        role_code=ROLE_SYSTEM_ADMIN,
        username_prefix="ltusr",
        count=2,
    ),
    PerfUserPoolSpec(
        pool_name="pool-production",
        role_code=ROLE_PRODUCTION_ADMIN,
        username_prefix="ltprd",
        count=4,
    ),
    PerfUserPoolSpec(
        pool_name="pool-quality",
        role_code=ROLE_QUALITY_ADMIN,
        username_prefix="ltqua",
        count=4,
    ),
    PerfUserPoolSpec(
        pool_name="pool-equipment",
        role_code=ROLE_MAINTENANCE_STAFF,
        username_prefix="ltmnt",
        count=4,
    ),
    PerfUserPoolSpec(
        pool_name="pool-operator",
        role_code=ROLE_OPERATOR,
        username_prefix="ltopr",
        count=4,
        requires_stage=True,
    ),
)


def _now_utc() -> datetime:
    return datetime.now(UTC)


def build_perf_user_account_specs(
    pool_specs: Sequence[PerfUserPoolSpec],
) -> list[PerfUserAccountSpec]:
    accounts: list[PerfUserAccountSpec] = []
    seen_usernames: set[str] = set()
    seen_pool_names: set[str] = set()

    for pool_spec in pool_specs:
        if not pool_spec.pool_name.strip():
            raise ValueError("压测池名称不能为空")
        if pool_spec.pool_name in seen_pool_names:
            raise ValueError(f"存在重复的压测池名称：{pool_spec.pool_name}")
        seen_pool_names.add(pool_spec.pool_name)
        if not pool_spec.username_prefix.strip():
            raise ValueError(f"压测池 {pool_spec.pool_name} 的用户名短前缀不能为空")
        if pool_spec.count < 1:
            raise ValueError(f"压测池 {pool_spec.pool_name} 的数量必须大于 0")

        for index in range(1, pool_spec.count + 1):
            username = f"{pool_spec.username_prefix}{index}"
            if len(username) > 10:
                raise ValueError(
                    f"压测用户名长度不能超过 10：{pool_spec.pool_name} -> {username}"
                )
            if username in seen_usernames:
                raise ValueError(f"存在重复的压测用户名：{username}")
            seen_usernames.add(username)
            accounts.append(
                PerfUserAccountSpec(
                    pool_name=pool_spec.pool_name,
                    role_code=pool_spec.role_code,
                    username=username,
                    requires_stage=pool_spec.requires_stage,
                )
            )

    return accounts


def _load_roles_by_code(
    db: Session,
    role_codes: Sequence[str],
) -> dict[str, Role]:
    roles, missing_role_codes = get_roles_by_codes(db, list(role_codes))
    if missing_role_codes:
        raise ValueError(
            "压测账号初始化缺少内置角色："
            + ", ".join(sorted(missing_role_codes))
        )
    return {role.code: role for role in roles}


def _load_operator_stage_and_processes(
    db: Session,
) -> tuple[ProcessStage, list[Process]]:
    stage = (
        db.execute(
            select(ProcessStage)
            .where(ProcessStage.is_enabled.is_(True))
            .order_by(ProcessStage.sort_order.asc(), ProcessStage.id.asc())
        )
        .scalars()
        .first()
    )
    if stage is None:
        raise ValueError("operator 压测池至少需要一个已启用的工序阶段")
    processes = (
        db.execute(
            select(Process)
            .where(
                Process.stage_id == stage.id,
                Process.is_enabled.is_(True),
            )
            .order_by(Process.id.asc())
        )
        .scalars()
        .all()
    )
    return stage, list(processes)


def seed_perf_capacity_users(
    db: Session,
    *,
    password: str,
    pool_specs: Sequence[PerfUserPoolSpec] = DEFAULT_PERF_USER_POOL_SPECS,
) -> PerfUserSeedResult:
    accounts = build_perf_user_account_specs(pool_specs)
    role_codes = sorted({account.role_code for account in accounts})
    roles_by_code = _load_roles_by_code(db, role_codes)

    operator_stage: ProcessStage | None = None
    operator_processes: list[Process] = []
    if any(account.requires_stage for account in accounts):
        operator_stage, operator_processes = _load_operator_stage_and_processes(db)

    created_count = 0
    updated_count = 0
    password_hash = get_password_hash(password)

    for account in accounts:
        role = roles_by_code[account.role_code]
        stage_id = operator_stage.id if account.requires_stage and operator_stage else None
        processes = operator_processes if account.requires_stage else []
        existing = get_user_by_username(db, account.username, include_deleted=True)

        if existing is None:
            user = User(
                username=account.username,
                full_name=account.username,
                remark=f"perf:{account.pool_name}",
                password_hash=password_hash,
                is_active=True,
                is_superuser=False,
                is_deleted=False,
                must_change_password=False,
                password_changed_at=_now_utc(),
                stage_id=stage_id,
            )
            user.roles = [role]
            user.processes = processes
            db.add(user)
            created_count += 1
            continue

        existing.full_name = account.username
        existing.remark = f"perf:{account.pool_name}"
        existing.password_hash = password_hash
        existing.is_active = True
        existing.is_superuser = False
        existing.is_deleted = False
        existing.deleted_at = None
        existing.must_change_password = False
        existing.password_changed_at = _now_utc()
        existing.roles = [role]
        existing.stage_id = stage_id
        existing.processes = processes
        updated_count += 1

    db.commit()
    return PerfUserSeedResult(
        created_count=created_count,
        updated_count=updated_count,
        usernames=[account.username for account in accounts],
    )
