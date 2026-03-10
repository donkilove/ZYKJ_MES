from __future__ import annotations

from collections import defaultdict

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.authz_catalog import (
    AUTHZ_RESOURCE_ACTION,
    AUTHZ_RESOURCE_FEATURE,
    AUTHZ_RESOURCE_MODULE,
    AUTHZ_RESOURCE_PAGE,
    MODULE_PERMISSION_BY_MODULE_CODE,
    PAGE_DEFINITIONS,
    PAGE_PERMISSION_BY_PAGE_CODE,
    PERMISSION_BY_CODE,
    PERMISSION_CATALOG,
    PermissionCatalogItem,
    default_permission_granted,
)
from app.core.authz_hierarchy_catalog import (
    FEATURE_BY_PERMISSION_CODE,
    FEATURE_DEFINITIONS,
    MODULE_DEFINITIONS,
    MODULE_NAME_BY_CODE,
    module_permission_code,
)
from app.core.rbac import (
    ROLE_DEFINITIONS,
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.models.authz_change_log import AuthzChangeLog, AuthzChangeLogItem
from app.models.permission_catalog import PermissionCatalog
from app.models.authz_module_revision import AuthzModuleRevision
from app.models.role import Role
from app.models.role_permission_grant import RolePermissionGrant
from app.models.user import User


ROLE_SORT_ORDER = {str(item["code"]): index for index, item in enumerate(ROLE_DEFINITIONS)}


class AuthzRevisionConflictError(ValueError):
    pass

MODULE_NAME_FALLBACK_ZH_BY_CODE = {
    "system": "系统管理",
    "user": "用户管理",
    "product": "产品管理",
    "equipment": "设备管理",
    "craft": "工艺管理",
    "quality": "质量管理",
    "production": "生产管理",
}

PAGE_NAME_FALLBACK_ZH_BY_CODE = {
    "user": "用户模块",
    "user_management": "用户管理",
    "registration_approval": "注册审批",
    "function_permission_config": "功能权限配置",
    "product": "产品模块",
    "product_management": "产品管理",
    "product_parameter_management": "产品参数管理",
    "product_parameter_query": "产品参数查询",
    "equipment": "设备模块",
    "equipment_ledger": "设备台账",
    "maintenance_item": "保养项目",
    "maintenance_plan": "保养计划",
    "maintenance_execution": "保养执行",
    "maintenance_record": "保养记录",
    "production": "生产模块",
    "production_order_management": "订单管理",
    "production_order_query": "订单查询",
    "production_assist_approval": "代班记录",
    "production_data_query": "生产数据",
    "production_scrap_statistics": "报废统计",
    "production_repair_orders": "维修订单",
    "quality": "质量模块",
    "first_article_management": "每日首件",
    "quality_data_query": "质量数据",
    "craft": "工艺模块",
    "process_management": "工段工序管理",
    "production_process_config": "生产工序配置",
    "craft_kanban": "工艺看板",
}

CAPABILITY_NAME_FALLBACK_ZH_BY_CODE = {
    "feature.system.permission_catalog.view": "查看权限目录",
    "feature.system.role_permissions.manage": "管理功能权限配置",
    "feature.user.user_management.view": "查看用户与角色信息",
    "feature.user.user_management.manage": "维护用户信息",
    "feature.user.registration_approval.review": "处理注册审批",
    "feature.product.catalog.read": "查看产品目录",
    "feature.product.product_management.manage": "维护产品主数据",
    "feature.product.version_analysis.view": "查看产品版本与影响分析",
    "feature.product.parameters.view": "查看产品参数",
    "feature.product.parameters.edit": "编辑产品参数",
    "feature.equipment.ledger.manage": "维护设备台账",
    "feature.equipment.items.manage": "维护保养项目",
    "feature.equipment.plans.manage": "维护保养计划",
    "feature.equipment.executions.operate": "执行保养任务",
    "feature.equipment.records.view": "查看保养记录",
    "feature.craft.process_basics.view": "查看工段工序",
    "feature.craft.process_basics.manage": "维护工段工序",
    "feature.craft.process_templates.view": "查看工艺模板与系统母版",
    "feature.craft.process_templates.manage": "维护工艺模板与系统母版",
    "feature.craft.kanban.view": "查看工艺看板",
    "feature.quality.first_articles.view": "查看每日首件",
    "feature.quality.stats.view": "查看质量统计",
    "feature.production.order_management.manage": "维护生产订单",
    "feature.production.pipeline_mode.manage": "维护并行生产模式",
    "feature.production.order_query.execute": "执行首件与报工",
    "feature.production.order_query.proxy": "代理视角查看工单",
    "feature.production.assist.launch": "发起代班",
    "feature.production.assist.records.view": "查看代班记录",
    "feature.production.data_query.view": "查看生产数据三视图",
    "feature.production.data_export.use": "导出生产手动筛选数据",
    "feature.production.scrap_statistics.view": "查看报废统计",
    "feature.production.scrap_export.use": "导出报废统计",
    "feature.production.repair_orders.manage": "处理维修订单",
    "feature.production.repair_orders.export": "导出维修订单",
    "feature.production.repair_orders.create_manual": "手工送修建单",
}

CAPABILITY_GROUP_META_BY_CODE = {
    "feature.system.permission_catalog.view": ("system.catalog", "权限目录", "查看权限目录与个人权限集合"),
    "feature.system.role_permissions.manage": (
        "system.permission_config",
        "功能权限配置",
        "维护角色的功能权限与配置",
    ),
    "feature.user.user_management.view": ("user.accounts", "用户管理", "查看用户、角色和工序关联"),
    "feature.user.user_management.manage": ("user.accounts", "用户管理", "创建、编辑、删除用户"),
    "feature.user.registration_approval.review": ("user.registration", "注册审批", "处理注册申请"),
    "feature.product.catalog.read": ("product.catalog", "产品目录", "查看产品列表"),
    "feature.product.product_management.manage": ("product.catalog", "产品目录", "维护产品主数据"),
    "feature.product.version_analysis.view": ("product.version", "版本分析", "查看版本与影响分析"),
    "feature.product.parameters.view": ("product.parameters", "产品参数", "查看产品参数与历史"),
    "feature.product.parameters.edit": ("product.parameters", "产品参数", "编辑产品参数"),
    "feature.equipment.ledger.manage": ("equipment.ledger", "设备台账", "维护设备台账信息"),
    "feature.equipment.items.manage": ("equipment.maintenance", "保养配置", "维护保养项目"),
    "feature.equipment.plans.manage": ("equipment.maintenance", "保养配置", "维护保养计划"),
    "feature.equipment.executions.operate": ("equipment.execution", "保养执行", "开始与完成保养任务"),
    "feature.equipment.records.view": ("equipment.execution", "保养执行", "查看保养记录"),
    "feature.craft.process_basics.view": ("craft.process", "工段工序", "查看工段与工序"),
    "feature.craft.process_basics.manage": ("craft.process", "工段工序", "维护工段与工序"),
    "feature.craft.process_templates.view": ("craft.template", "工艺模板", "查看工艺模板与系统母版"),
    "feature.craft.process_templates.manage": ("craft.template", "工艺模板", "维护工艺模板与系统母版"),
    "feature.craft.kanban.view": ("craft.kanban", "工艺看板", "查看工艺看板"),
    "feature.quality.first_articles.view": ("quality.first_article", "每日首件", "查看每日首件记录"),
    "feature.quality.stats.view": ("quality.stats", "质量统计", "查看质量统计数据"),
    "feature.production.order_management.manage": ("production.orders", "订单管理", "创建、编辑、删除、结束订单"),
    "feature.production.pipeline_mode.manage": ("production.orders", "订单管理", "设置并行生产模式"),
    "feature.production.order_query.execute": ("production.execution", "生产执行", "执行首件与报工"),
    "feature.production.order_query.proxy": ("production.execution", "生产执行", "代理/代班视角查询"),
    "feature.production.assist.launch": ("production.assist", "代班", "发起代班授权"),
    "feature.production.assist.records.view": ("production.assist", "代班", "查看代班记录"),
    "feature.production.data_query.view": ("production.data", "生产数据", "查看今日实时、未完工、手动筛选"),
    "feature.production.data_export.use": ("production.data", "生产数据", "导出手动筛选数据"),
    "feature.production.scrap_statistics.view": ("production.repair_scrap", "维修与报废", "查看报废统计"),
    "feature.production.scrap_export.use": ("production.repair_scrap", "维修与报废", "导出报废统计"),
    "feature.production.repair_orders.manage": ("production.repair_scrap", "维修与报废", "处理维修单闭环"),
    "feature.production.repair_orders.export": ("production.repair_scrap", "维修与报废", "导出维修订单"),
    "feature.production.repair_orders.create_manual": ("production.repair_scrap", "维修与报废", "手工送修建单"),
}


def _ensure_role_rows(db: Session) -> None:
    existing_codes = {
        code
        for code in db.execute(select(Role.code)).scalars().all()
    }
    created = False
    for permission_item in PERMISSION_CATALOG:
        _ = permission_item
    from app.core.rbac import ROLE_DEFINITIONS  # delayed import avoids accidental startup cycle

    for item in ROLE_DEFINITIONS:
        role_code = str(item["code"])
        if role_code in existing_codes:
            continue
        db.add(
            Role(
                code=role_code,
                name=str(item["name"]),
            )
        )
        created = True
    if created:
        db.flush()


def ensure_permission_catalog_defaults(db: Session) -> bool:
    existing_rows = db.execute(select(PermissionCatalog)).scalars().all()
    row_by_code = {row.permission_code: row for row in existing_rows}
    changed = False

    for item in PERMISSION_CATALOG:
        row = row_by_code.get(item.permission_code)
        if row is None:
            db.add(
                PermissionCatalog(
                    permission_code=item.permission_code,
                    permission_name=item.permission_name,
                    module_code=item.module_code,
                    resource_type=item.resource_type,
                    parent_permission_code=item.parent_permission_code,
                    is_enabled=item.is_enabled,
                )
            )
            changed = True
            continue
        if row.permission_name != item.permission_name:
            row.permission_name = item.permission_name
            changed = True
        if row.module_code != item.module_code:
            row.module_code = item.module_code
            changed = True
        if row.resource_type != item.resource_type:
            row.resource_type = item.resource_type
            changed = True
        if row.parent_permission_code != item.parent_permission_code:
            row.parent_permission_code = item.parent_permission_code
            changed = True
        if row.is_enabled != item.is_enabled:
            row.is_enabled = item.is_enabled
            changed = True

    if changed:
        db.flush()
    return changed


def ensure_role_permission_defaults(db: Session) -> bool:
    _ensure_role_rows(db)
    role_codes = [code for code in db.execute(select(Role.code)).scalars().all()]
    permission_codes = [item.permission_code for item in PERMISSION_CATALOG]

    existing_rows = db.execute(select(RolePermissionGrant)).scalars().all()
    existing_keys = {(row.role_code, row.permission_code) for row in existing_rows}

    changed = False
    for role_code in role_codes:
        for permission_code in permission_codes:
            key = (role_code, permission_code)
            if key in existing_keys:
                continue
            db.add(
                RolePermissionGrant(
                    role_code=role_code,
                    permission_code=permission_code,
                    granted=default_permission_granted(role_code, permission_code),
                )
            )
            changed = True

    if changed:
        db.flush()
    return changed


def ensure_authz_module_revision_defaults(db: Session) -> bool:
    existing_rows = db.execute(select(AuthzModuleRevision)).scalars().all()
    row_by_module_code = {row.module_code: row for row in existing_rows}
    changed = False

    for item in MODULE_DEFINITIONS:
        module_code = str(item.module_code).strip()
        if not module_code or module_code in row_by_module_code:
            continue
        db.add(AuthzModuleRevision(module_code=module_code, revision=0))
        changed = True

    if changed:
        db.flush()
    return changed


def ensure_authz_defaults(db: Session) -> None:
    catalog_changed = ensure_permission_catalog_defaults(db)
    grants_changed = ensure_role_permission_defaults(db)
    revision_changed = ensure_authz_module_revision_defaults(db)
    if catalog_changed or grants_changed or revision_changed:
        db.commit()


def get_authz_module_revision(db: Session, *, module_code: str) -> int:
    ensure_authz_defaults(db)
    normalized_module = _normalize_module_code(module_code)
    row = db.execute(
        select(AuthzModuleRevision).where(AuthzModuleRevision.module_code == normalized_module)
    ).scalars().first()
    if row is None:
        row = AuthzModuleRevision(module_code=normalized_module, revision=0)
        db.add(row)
        db.flush()
    return int(row.revision)


def get_authz_module_revision_map(db: Session) -> dict[str, int]:
    ensure_authz_defaults(db)
    rows = db.execute(select(AuthzModuleRevision)).scalars().all()
    revision_by_module = {str(row.module_code): int(row.revision) for row in rows}
    for item in MODULE_DEFINITIONS:
        revision_by_module.setdefault(str(item.module_code), 0)
    return revision_by_module


def _bump_authz_module_revision(
    db: Session,
    *,
    module_code: str,
    operator: User | None,
) -> int:
    normalized_module = _normalize_module_code(module_code)
    row = db.execute(
        select(AuthzModuleRevision).where(AuthzModuleRevision.module_code == normalized_module)
    ).scalars().first()
    if row is None:
        row = AuthzModuleRevision(module_code=normalized_module, revision=0)
        db.add(row)
        db.flush()
    row.revision = int(row.revision) + 1
    row.updated_by_user_id = operator.id if operator is not None else None
    db.flush()
    return int(row.revision)


def _serialize_capability_pack_role_result(item: dict[str, object]) -> dict[str, object]:
    return {
        "role_code": str(item["role_code"]),
        "role_name": str(item["role_name"]),
        "readonly": bool(item["readonly"]),
        "ignored_input": bool(item["ignored_input"]),
        "module_code": str(item["module_code"]),
        "before_capability_codes": [str(code) for code in item["before_capability_codes"]],
        "after_capability_codes": [str(code) for code in item["after_capability_codes"]],
        "added_capability_codes": [str(code) for code in item["added_capability_codes"]],
        "removed_capability_codes": [str(code) for code in item["removed_capability_codes"]],
        "auto_linked_dependencies": [str(code) for code in item["auto_linked_dependencies"]],
        "effective_capability_codes": [
            str(code) for code in item["effective_capability_codes"]
        ],
        "effective_page_permission_codes": [
            str(code) for code in item["effective_page_permission_codes"]
        ],
        "updated_count": int(item["updated_count"]),
    }


def _snapshot_capability_pack_module_state(
    db: Session,
    *,
    module_code: str,
) -> list[dict[str, object]]:
    role_rows = db.execute(select(Role)).scalars().all()
    ordered_roles = sorted(role_rows, key=_role_sort_key)
    snapshot: list[dict[str, object]] = []
    for role_row in ordered_roles:
        config = get_capability_pack_role_config(
            db,
            role_code=role_row.code,
            module_code=module_code,
        )
        snapshot.append(
            {
                "role_code": str(config["role_code"]),
                "module_enabled": bool(config["module_enabled"]),
                "capability_codes": [
                    str(code) for code in config["granted_capability_codes"]
                ],
            }
        )
    return snapshot


def _normalize_capability_pack_snapshot(
    snapshot: list[dict[str, object]],
) -> list[dict[str, object]]:
    normalized: list[dict[str, object]] = []
    for item in snapshot:
        role_code = str(item.get("role_code", "")).strip()
        if not role_code:
            continue
        raw_capability_codes = item.get("capability_codes")
        capability_codes = (
            sorted(
                {
                    str(code).strip()
                    for code in raw_capability_codes
                    if str(code).strip()
                }
            )
            if isinstance(raw_capability_codes, list)
            else []
        )
        normalized.append(
            {
                "role_code": role_code,
                "module_enabled": bool(item.get("module_enabled", False))
                or bool(capability_codes),
                "capability_codes": capability_codes,
            }
        )
    normalized.sort(
        key=lambda item: (
            ROLE_SORT_ORDER.get(str(item["role_code"]), 9999),
            str(item["role_code"]),
        )
    )
    return normalized


def _capability_pack_snapshot_matches_current(
    db: Session,
    *,
    module_code: str,
    snapshot: list[dict[str, object]],
) -> bool:
    current_snapshot = _snapshot_capability_pack_module_state(db, module_code=module_code)
    return _normalize_capability_pack_snapshot(current_snapshot) == _normalize_capability_pack_snapshot(
        snapshot
    )


def _get_capability_pack_change_log(
    db: Session,
    *,
    module_code: str,
    change_log_id: int,
) -> AuthzChangeLog:
    normalized_module = _normalize_module_code(module_code)
    row = db.execute(
        select(AuthzChangeLog).where(
            AuthzChangeLog.id == change_log_id,
            AuthzChangeLog.module_code == normalized_module,
        )
    ).scalars().first()
    if row is None:
        raise ValueError(f"Change log not found: {change_log_id}")
    return row


def _serialize_capability_pack_change_log_role_item(
    *,
    module_code: str,
    item: AuthzChangeLogItem,
) -> dict[str, object]:
    return {
        "role_code": item.role_code,
        "role_name": item.role_name,
        "readonly": bool(item.readonly),
        "ignored_input": False,
        "module_code": module_code,
        "before_capability_codes": list(item.before_capability_codes),
        "after_capability_codes": list(item.after_capability_codes),
        "added_capability_codes": list(item.added_capability_codes),
        "removed_capability_codes": list(item.removed_capability_codes),
        "auto_linked_dependencies": list(item.auto_linked_dependencies),
        "effective_capability_codes": list(item.effective_capability_codes),
        "effective_page_permission_codes": list(item.effective_page_permission_codes),
        "updated_count": int(item.updated_count),
    }


def _record_capability_pack_change_log(
    db: Session,
    *,
    module_code: str,
    revision: int,
    operator: User | None,
    remark: str | None,
    change_type: str,
    rollback_of_change_log_id: int | None,
    role_results: list[dict[str, object]],
) -> AuthzChangeLog:
    snapshot = _snapshot_capability_pack_module_state(db, module_code=module_code)
    log_row = AuthzChangeLog(
        module_code=module_code,
        revision=revision,
        change_type=change_type,
        remark=remark,
        operator_user_id=operator.id if operator is not None else None,
        operator_username=operator.username if operator is not None else None,
        rollback_of_change_log_id=rollback_of_change_log_id,
        snapshot_json=snapshot,
    )
    db.add(log_row)
    db.flush()
    for item in role_results:
        serialized = _serialize_capability_pack_role_result(item)
        db.add(
            AuthzChangeLogItem(
                change_log_id=log_row.id,
                role_code=str(serialized["role_code"]),
                role_name=str(serialized["role_name"]),
                readonly=bool(serialized["readonly"]),
                before_capability_codes=list(serialized["before_capability_codes"]),
                after_capability_codes=list(serialized["after_capability_codes"]),
                added_capability_codes=list(serialized["added_capability_codes"]),
                removed_capability_codes=list(serialized["removed_capability_codes"]),
                auto_linked_dependencies=list(serialized["auto_linked_dependencies"]),
                effective_capability_codes=list(serialized["effective_capability_codes"]),
                effective_page_permission_codes=list(
                    serialized["effective_page_permission_codes"]
                ),
                updated_count=int(serialized["updated_count"]),
            )
        )
    db.flush()
    return log_row


def list_permission_catalog_rows(
    db: Session,
    *,
    module_code: str | None = None,
) -> list[PermissionCatalog]:
    ensure_authz_defaults(db)
    stmt = select(PermissionCatalog).where(PermissionCatalog.is_enabled.is_(True))
    if module_code and module_code.strip():
        stmt = stmt.where(PermissionCatalog.module_code == module_code.strip())
    stmt = stmt.order_by(
        PermissionCatalog.module_code.asc(),
        PermissionCatalog.resource_type.asc(),
        PermissionCatalog.permission_code.asc(),
    )
    return db.execute(stmt).scalars().all()


def list_permission_modules(db: Session) -> list[str]:
    rows = list_permission_catalog_rows(db)
    return sorted({row.module_code for row in rows if row.module_code})


def _normalize_module_code(module_code: str) -> str:
    normalized = module_code.strip()
    if not normalized:
        raise ValueError("module_code is required")
    return normalized


def _role_sort_key(role: Role) -> tuple[int, str]:
    return ROLE_SORT_ORDER.get(role.code, 9999), role.code


def _normalize_requested_permission_codes(
    *,
    granted_permission_codes: list[str],
    valid_codes: set[str],
) -> set[str]:
    target_codes = {code.strip() for code in granted_permission_codes if code and code.strip()}
    invalid_codes = sorted(target_codes.difference(valid_codes))
    if invalid_codes:
        raise ValueError(f"invalid permission codes: {', '.join(invalid_codes)}")
    return target_codes


def _normalize_permission_codes_with_dependencies(
    *,
    requested_codes: set[str],
    parent_by_code: dict[str, str | None],
    module_permission_by_code: dict[str, str] | None = None,
) -> tuple[set[str], list[str], list[str]]:
    normalized = set(requested_codes)
    auto_granted: set[str] = set()

    changed = True
    while changed:
        changed = False
        for permission_code in list(normalized):
            parent_code = parent_by_code.get(permission_code)
            if parent_code and parent_code not in normalized:
                normalized.add(parent_code)
                auto_granted.add(parent_code)
                changed = True
            if module_permission_by_code is not None:
                module_permission = module_permission_by_code.get(permission_code)
                if module_permission and module_permission not in normalized:
                    normalized.add(module_permission)
                    auto_granted.add(module_permission)
                    changed = True

    return normalized, sorted(auto_granted), []


def _catalog_rows_by_code(
    db: Session,
    *,
    module_code: str | None = None,
) -> dict[str, PermissionCatalog]:
    rows = list_permission_catalog_rows(db, module_code=module_code)
    return {row.permission_code: row for row in rows}


def _load_granted_permission_codes_for_roles(
    db: Session,
    *,
    role_codes: list[str],
    module_code: str | None = None,
) -> set[str]:
    normalized_roles = sorted({code for code in role_codes if code})
    if not normalized_roles:
        return set()

    stmt = (
        select(RolePermissionGrant.permission_code)
        .join(
            PermissionCatalog,
            PermissionCatalog.permission_code == RolePermissionGrant.permission_code,
        )
        .where(
            RolePermissionGrant.role_code.in_(normalized_roles),
            RolePermissionGrant.granted.is_(True),
            PermissionCatalog.is_enabled.is_(True),
        )
    )
    if module_code and module_code.strip():
        stmt = stmt.where(PermissionCatalog.module_code == module_code.strip())
    rows = db.execute(stmt).scalars().all()
    return {str(code) for code in rows}


def _effective_permission_codes_from_granted(
    *,
    granted_codes: set[str],
    row_by_code: dict[str, PermissionCatalog],
) -> set[str]:
    if not granted_codes:
        return set()

    effective: set[str] = set()
    enabled_modules: set[str] = set()

    for code in granted_codes:
        row = row_by_code.get(code)
        if row is None or row.resource_type != AUTHZ_RESOURCE_MODULE:
            continue
        enabled_modules.add(code)
    effective.update(enabled_modules)

    enabled_pages: set[str] = set()
    for code in granted_codes:
        row = row_by_code.get(code)
        if row is None or row.resource_type != AUTHZ_RESOURCE_PAGE:
            continue
        module_code_value = str(row.module_code).strip()
        module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
            module_code_value,
            module_permission_code(module_code_value),
        )
        if module_permission in enabled_modules:
            enabled_pages.add(code)
    effective.update(enabled_pages)

    enabled_features: set[str] = set()
    remaining_feature_codes = {
        code
        for code in granted_codes
        if (row := row_by_code.get(code)) is not None
        and row.resource_type == AUTHZ_RESOURCE_FEATURE
    }
    changed = True
    while changed:
        changed = False
        for code in list(remaining_feature_codes):
            row = row_by_code.get(code)
            if row is None:
                remaining_feature_codes.discard(code)
                continue
            module_code_value = str(row.module_code).strip()
            module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
                module_code_value,
                module_permission_code(module_code_value),
            )
            if module_permission not in enabled_modules:
                continue
            feature_definition = FEATURE_BY_PERMISSION_CODE.get(code)
            feature_page_code = (
                PAGE_PERMISSION_BY_PAGE_CODE.get(feature_definition.page_code)
                if feature_definition is not None
                else row.parent_permission_code
            )
            if feature_page_code and feature_page_code not in enabled_pages:
                continue
            dependency_codes = (
                set(feature_definition.dependency_permission_codes)
                if feature_definition is not None
                else set()
            )
            if dependency_codes and not dependency_codes.issubset(enabled_features):
                continue
            enabled_features.add(code)
            remaining_feature_codes.discard(code)
            changed = True
    effective.update(enabled_features)

    linked_action_codes: set[str] = set()
    for code in enabled_features:
        feature_definition = FEATURE_BY_PERMISSION_CODE.get(code)
        if feature_definition is None:
            continue
        linked_action_codes.update(feature_definition.action_permission_codes)

    enabled_actions: set[str] = set()
    for code in granted_codes.union(linked_action_codes):
        row = row_by_code.get(code)
        if row is None or row.resource_type != AUTHZ_RESOURCE_ACTION:
            continue
        module_code_value = str(row.module_code).strip()
        module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
            module_code_value,
            module_permission_code(module_code_value),
        )
        if module_permission not in enabled_modules:
            continue
        parent_page_code = row.parent_permission_code
        if (
            parent_page_code
            and parent_page_code.startswith("page.")
            and parent_page_code not in enabled_pages
        ):
            continue
        enabled_actions.add(code)
    effective.update(enabled_actions)
    return effective


def _effective_permission_codes_for_role_codes(
    db: Session,
    *,
    role_codes: list[str],
    module_code: str | None = None,
) -> set[str]:
    normalized_roles = sorted({code for code in role_codes if code})
    if not normalized_roles:
        return set()
    row_by_code = _catalog_rows_by_code(db)
    if ROLE_SYSTEM_ADMIN in normalized_roles:
        if module_code and module_code.strip():
            normalized_module = module_code.strip()
            return {
                code
                for code, row in row_by_code.items()
                if str(row.module_code).strip() == normalized_module
            }
        return {code for code in row_by_code}
    granted_codes = _load_granted_permission_codes_for_roles(
        db,
        role_codes=normalized_roles,
    )
    effective_codes = _effective_permission_codes_from_granted(
        granted_codes=granted_codes,
        row_by_code=row_by_code,
    )
    if module_code and module_code.strip():
        normalized_module = module_code.strip()
        return {
            code
            for code in effective_codes
            if (row := row_by_code.get(code)) is not None
            and str(row.module_code).strip() == normalized_module
        }
    return effective_codes


def _list_catalog_rows_by_module(db: Session, *, module_code: str) -> list[PermissionCatalog]:
    rows = list_permission_catalog_rows(db, module_code=module_code)
    if not rows:
        raise ValueError(f"module_code is invalid: {module_code}")
    return rows


def _user_role_codes(user: User) -> list[str]:
    return sorted({role.code for role in user.roles})


def get_user_permission_codes(
    db: Session,
    *,
    user: User,
    module_code: str | None = None,
) -> set[str]:
    ensure_authz_defaults(db)
    role_codes = _user_role_codes(user)
    return _effective_permission_codes_for_role_codes(
        db,
        role_codes=role_codes,
        module_code=module_code,
    )


def get_permission_codes_for_role_codes(
    db: Session,
    *,
    role_codes: list[str],
    module_code: str | None = None,
) -> set[str]:
    ensure_authz_defaults(db)
    return _effective_permission_codes_for_role_codes(
        db,
        role_codes=role_codes,
        module_code=module_code,
    )


def has_permission(
    db: Session,
    *,
    user: User,
    permission_code: str,
) -> bool:
    role_codes = _user_role_codes(user)
    if ROLE_SYSTEM_ADMIN in role_codes:
        return True
    if not role_codes:
        return False
    ensure_authz_defaults(db)
    effective_codes = _effective_permission_codes_for_role_codes(
        db,
        role_codes=role_codes,
    )
    return permission_code in effective_codes


def get_role_permission_items(
    db: Session,
    *,
    role_code: str,
    module_code: str | None = None,
) -> tuple[str, list[dict[str, object]]]:
    ensure_authz_defaults(db)
    role_row = db.execute(select(Role).where(Role.code == role_code)).scalars().first()
    if role_row is None:
        raise ValueError(f"Role not found: {role_code}")

    catalog_rows = list_permission_catalog_rows(db, module_code=module_code)
    catalog_codes = [row.permission_code for row in catalog_rows]
    parent_by_code = {
        row.permission_code: (
            row.parent_permission_code if row.parent_permission_code in catalog_codes else None
        )
        for row in catalog_rows
    }
    module_permission_by_code = {
        row.permission_code: MODULE_PERMISSION_BY_MODULE_CODE.get(
            str(row.module_code).strip(),
            module_permission_code(str(row.module_code).strip()),
        )
        for row in catalog_rows
    }

    if role_code == ROLE_SYSTEM_ADMIN:
        granted_codes = set(catalog_codes)
    else:
        grant_rows = db.execute(
            select(RolePermissionGrant).where(
                RolePermissionGrant.role_code == role_code,
                RolePermissionGrant.permission_code.in_(catalog_codes),
            )
        ).scalars().all()
        granted_codes = {row.permission_code for row in grant_rows if row.granted}
        granted_codes, _, _ = _normalize_permission_codes_with_dependencies(
            requested_codes=granted_codes,
            parent_by_code=parent_by_code,
            module_permission_by_code=module_permission_by_code,
        )

    items: list[dict[str, object]] = []
    for row in catalog_rows:
        items.append(
            {
                "role_code": role_code,
                "role_name": role_row.name,
                "permission_code": row.permission_code,
                "permission_name": row.permission_name,
                "module_code": row.module_code,
                "resource_type": row.resource_type,
                "parent_permission_code": row.parent_permission_code,
                "granted": row.permission_code in granted_codes,
                "is_enabled": bool(row.is_enabled),
            }
        )
    return role_row.name, items


def get_role_permission_matrix(
    db: Session,
    *,
    module_code: str,
) -> dict[str, object]:
    normalized_module = _normalize_module_code(module_code)
    ensure_authz_defaults(db)
    catalog_rows = _list_catalog_rows_by_module(db, module_code=normalized_module)
    module_codes = list_permission_modules(db)
    valid_codes = [row.permission_code for row in catalog_rows]

    role_rows = db.execute(select(Role)).scalars().all()
    role_rows.sort(key=_role_sort_key)
    role_codes = [row.code for row in role_rows]

    grants_by_role: dict[str, set[str]] = defaultdict(set)
    if role_codes and valid_codes:
        grant_rows = db.execute(
            select(RolePermissionGrant).where(
                RolePermissionGrant.role_code.in_(role_codes),
                RolePermissionGrant.permission_code.in_(valid_codes),
                RolePermissionGrant.granted.is_(True),
            )
        ).scalars().all()
        for row in grant_rows:
            grants_by_role[row.role_code].add(row.permission_code)

    role_items: list[dict[str, object]] = []
    for role_row in role_rows:
        readonly = role_row.code == ROLE_SYSTEM_ADMIN
        granted_codes = sorted(valid_codes if readonly else grants_by_role.get(role_row.code, set()))
        role_items.append(
            {
                "role_code": role_row.code,
                "role_name": role_row.name,
                "readonly": readonly,
                "is_system_admin": readonly,
                "granted_permission_codes": granted_codes,
            }
        )

    return {
        "module_code": normalized_module,
        "module_codes": module_codes,
        "permissions": [
            {
                "permission_code": row.permission_code,
                "permission_name": row.permission_name,
                "module_code": row.module_code,
                "resource_type": row.resource_type,
                "parent_permission_code": row.parent_permission_code,
                "is_enabled": bool(row.is_enabled),
            }
            for row in catalog_rows
        ],
        "role_items": role_items,
    }


def update_role_permission_matrix(
    db: Session,
    *,
    module_code: str,
    role_items: list[dict[str, object]],
    dry_run: bool = False,
    operator: User | None,
    remark: str | None = None,
) -> dict[str, object]:
    _ = operator
    _ = remark
    normalized_module = _normalize_module_code(module_code)

    ensure_authz_defaults(db)
    catalog_rows = _list_catalog_rows_by_module(db, module_code=normalized_module)
    valid_codes = {row.permission_code for row in catalog_rows}
    parent_by_code = {
        row.permission_code: (
            row.parent_permission_code if row.parent_permission_code in valid_codes else None
        )
        for row in catalog_rows
    }
    module_permission_by_code = {
        row.permission_code: MODULE_PERMISSION_BY_MODULE_CODE.get(
            str(row.module_code).strip(),
            module_permission_code(str(row.module_code).strip()),
        )
        for row in catalog_rows
    }

    role_rows = db.execute(select(Role)).scalars().all()
    role_map = {row.code: row for row in role_rows}
    role_input_map: dict[str, set[str]] = {}
    for item in role_items:
        role_code = str(item.get("role_code", "")).strip()
        if not role_code:
            raise ValueError("role_code is required")
        if role_code in role_input_map:
            raise ValueError(f"duplicate role_code: {role_code}")
        if role_code not in role_map:
            raise ValueError(f"Role not found: {role_code}")
        raw_codes = item.get("granted_permission_codes")
        if raw_codes is None:
            requested_codes: list[str] = []
        elif isinstance(raw_codes, list):
            requested_codes = [str(code) for code in raw_codes]
        else:
            raise ValueError(f"invalid granted_permission_codes for role: {role_code}")
        role_input_map[role_code] = _normalize_requested_permission_codes(
            granted_permission_codes=requested_codes,
            valid_codes=valid_codes,
        )

    if not role_input_map:
        if dry_run:
            db.rollback()
        else:
            db.rollback()
        return {
            "module_code": normalized_module,
            "dry_run": dry_run,
            "role_results": [],
        }

    selected_role_codes = sorted(role_input_map.keys())
    grant_rows = db.execute(
        select(RolePermissionGrant).where(
            RolePermissionGrant.role_code.in_(selected_role_codes),
            RolePermissionGrant.permission_code.in_(valid_codes),
        )
    ).scalars().all()
    row_by_key = {(row.role_code, row.permission_code): row for row in grant_rows}
    granted_before_by_role: dict[str, set[str]] = defaultdict(set)
    for row in grant_rows:
        if row.granted:
            granted_before_by_role[row.role_code].add(row.permission_code)

    role_results: list[dict[str, object]] = []
    total_updated_count = 0
    ordered_role_codes = sorted(selected_role_codes, key=lambda code: _role_sort_key(role_map[code]))
    valid_codes_sorted = sorted(valid_codes)

    for role_code in ordered_role_codes:
        role_row = role_map[role_code]
        is_system_admin = role_code == ROLE_SYSTEM_ADMIN
        before_codes = set(valid_codes if is_system_admin else granted_before_by_role.get(role_code, set()))
        requested_codes = role_input_map[role_code]
        if is_system_admin:
            after_codes = set(valid_codes)
            auto_granted: list[str] = []
            auto_revoked: list[str] = []
            ignored_input = True
        else:
            after_codes, auto_granted, auto_revoked = _normalize_permission_codes_with_dependencies(
                requested_codes=requested_codes,
                parent_by_code=parent_by_code,
                module_permission_by_code=module_permission_by_code,
            )
            ignored_input = False

        added_codes = sorted(after_codes.difference(before_codes))
        removed_codes = sorted(before_codes.difference(after_codes))
        updated_count = 0

        if not dry_run and not is_system_admin:
            for permission_code in valid_codes_sorted:
                should_grant = permission_code in after_codes
                row = row_by_key.get((role_code, permission_code))
                if row is None:
                    if should_grant:
                        db.add(
                            RolePermissionGrant(
                                role_code=role_code,
                                permission_code=permission_code,
                                granted=True,
                            )
                        )
                        updated_count += 1
                    continue
                if bool(row.granted) != should_grant:
                    row.granted = should_grant
                    updated_count += 1
        else:
            updated_count = len(added_codes) + len(removed_codes)

        total_updated_count += updated_count
        role_results.append(
            {
                "role_code": role_code,
                "role_name": role_row.name,
                "readonly": is_system_admin,
                "is_system_admin": is_system_admin,
                "ignored_input": ignored_input,
                "before_permission_codes": sorted(before_codes),
                "after_permission_codes": sorted(after_codes),
                "added_permission_codes": added_codes,
                "removed_permission_codes": removed_codes,
                "auto_granted_permission_codes": auto_granted,
                "auto_revoked_permission_codes": auto_revoked,
                "updated_count": updated_count,
            }
        )

    if dry_run:
        db.rollback()
    elif total_updated_count > 0:
        _bump_authz_module_revision(
            db,
            module_code=normalized_module,
            operator=operator,
        )
        db.commit()
    else:
        db.rollback()

    return {
        "module_code": normalized_module,
        "dry_run": dry_run,
        "role_results": role_results,
    }


def replace_role_permissions_for_module(
    db: Session,
    *,
    role_code: str,
    module_code: str,
    granted_permission_codes: list[str],
    operator: User | None,
    remark: str | None = None,
) -> tuple[int, list[str], list[str]]:
    result = update_role_permission_matrix(
        db,
        module_code=module_code,
        role_items=[
            {
                "role_code": role_code,
                "granted_permission_codes": granted_permission_codes,
            }
        ],
        dry_run=False,
        operator=operator,
        remark=remark,
    )
    role_results = result.get("role_results", [])
    if not role_results:
        return 0, [], []
    role_result = role_results[0]
    updated_count = int(role_result.get("updated_count", 0))
    before_codes = [str(code) for code in role_result.get("before_permission_codes", [])]
    after_codes = [str(code) for code in role_result.get("after_permission_codes", [])]
    return updated_count, before_codes, after_codes


def _module_permission_catalog_rows(db: Session) -> list[PermissionCatalog]:
    rows = list_permission_catalog_rows(db)
    return [row for row in rows if row.resource_type == AUTHZ_RESOURCE_MODULE]


def _module_display_name(module_code: str) -> str:
    from_catalog = MODULE_NAME_BY_CODE.get(module_code)
    if from_catalog and from_catalog.strip():
        fallback = MODULE_NAME_FALLBACK_ZH_BY_CODE.get(module_code)
        if fallback:
            return fallback
        return from_catalog
    return MODULE_NAME_FALLBACK_ZH_BY_CODE.get(module_code, module_code)


def _page_name_by_code() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for page_code, page_name, _, _ in PAGE_DEFINITIONS:
        fallback = PAGE_NAME_FALLBACK_ZH_BY_CODE.get(page_code)
        if fallback:
            mapping[page_code] = fallback
            continue
        mapping[page_code] = page_name
    return mapping


def _capability_name(*, capability_code: str, raw_name: str) -> str:
    fallback = CAPABILITY_NAME_FALLBACK_ZH_BY_CODE.get(capability_code)
    if fallback:
        return fallback
    if raw_name.strip():
        return raw_name
    return capability_code


def _capability_group_meta(
    *,
    capability_code: str,
    module_code: str,
    page_code: str,
) -> tuple[str, str, str]:
    explicit = CAPABILITY_GROUP_META_BY_CODE.get(capability_code)
    if explicit is not None:
        return explicit
    page_name = _page_name_by_code().get(page_code, page_code)
    return (f"{module_code}.{page_code}", page_name, f"{page_name}相关能力")


def _capability_items_for_module(module_code: str) -> list[dict[str, object]]:
    page_name_map = _page_name_by_code()
    items: list[dict[str, object]] = []
    for feature in FEATURE_DEFINITIONS:
        if feature.module_code != module_code:
            continue
        group_code, group_name, description = _capability_group_meta(
            capability_code=feature.permission_code,
            module_code=module_code,
            page_code=feature.page_code,
        )
        items.append(
            {
                "capability_code": feature.permission_code,
                "capability_name": _capability_name(
                    capability_code=feature.permission_code,
                    raw_name=feature.permission_name,
                ),
                "group_code": group_code,
                "group_name": group_name,
                "page_code": feature.page_code,
                "page_name": page_name_map.get(feature.page_code, feature.page_code),
                "description": description,
                "dependency_capability_codes": list(feature.dependency_permission_codes),
                "linked_action_permission_codes": list(feature.action_permission_codes),
            }
        )
    items.sort(key=lambda item: str(item["capability_code"]))
    return items


def _capability_permission_codes_for_module(module_code: str) -> set[str]:
    return {
        feature.permission_code
        for feature in FEATURE_DEFINITIONS
        if feature.module_code == module_code
    }


def _dependency_capability_codes_for_module(module_code: str) -> set[str]:
    module_capability_codes = _capability_permission_codes_for_module(module_code)
    dependency_map = _dependency_codes_by_permission_code()
    discovered: set[str] = set()
    pending = list(module_capability_codes)
    while pending:
        code = pending.pop()
        for dependency_code in dependency_map.get(code, set()):
            if dependency_code in discovered:
                continue
            discovered.add(dependency_code)
            pending.append(dependency_code)
    return discovered.difference(module_capability_codes)


def _normalize_capability_codes_with_dependencies(
    *,
    requested_codes: set[str],
) -> tuple[set[str], list[str]]:
    dependency_map = _dependency_codes_by_permission_code()
    all_feature_codes = {item.permission_code for item in FEATURE_DEFINITIONS}
    normalized = {code for code in requested_codes if code in all_feature_codes}
    auto_linked: set[str] = set()

    changed = True
    while changed:
        changed = False
        for code in list(normalized):
            for dependency_code in dependency_map.get(code, set()):
                if dependency_code not in all_feature_codes:
                    continue
                if dependency_code in normalized:
                    continue
                normalized.add(dependency_code)
                auto_linked.add(dependency_code)
                changed = True
    return normalized, sorted(auto_linked)


def _role_template_capability_codes(
    *,
    module_code: str,
    role_code: str,
    capability_codes: set[str],
) -> list[str]:
    if role_code == ROLE_SYSTEM_ADMIN:
        return sorted(capability_codes)

    if role_code == ROLE_PRODUCTION_ADMIN:
        return sorted(capability_codes)

    if role_code == ROLE_QUALITY_ADMIN:
        if module_code == "quality":
            return sorted(capability_codes)
        if module_code == "production":
            preferred = {
                "feature.production.data_query.view",
                "feature.production.scrap_statistics.view",
                "feature.production.repair_orders.manage",
                "feature.production.assist.records.view",
            }
            return sorted(capability_codes.intersection(preferred))
        preferred = {
            code for code in capability_codes if code.endswith(".view") or code.endswith(".read")
        }
        return sorted(preferred)

    if role_code == ROLE_OPERATOR:
        preferred_by_module = {
            "production": {
                "feature.production.order_query.execute",
                "feature.production.assist.launch",
                "feature.production.repair_orders.create_manual",
            },
            "equipment": {"feature.equipment.executions.operate"},
            "quality": {"feature.quality.first_articles.view"},
        }
        return sorted(capability_codes.intersection(preferred_by_module.get(module_code, set())))

    return []


def _role_template_description(role_code: str) -> str:
    if role_code == ROLE_SYSTEM_ADMIN:
        return "系统管理员固定全权限，仅展示模板结果。"
    if role_code == ROLE_PRODUCTION_ADMIN:
        return "推荐授予当前模块全部能力。"
    if role_code == ROLE_QUALITY_ADMIN:
        return "推荐授予质量相关与统计分析能力。"
    if role_code == ROLE_OPERATOR:
        return "推荐授予执行链路相关能力。"
    return "推荐模板"


def _capability_role_template_items(module_code: str) -> list[dict[str, object]]:
    role_items: list[dict[str, object]] = []
    capability_codes = _capability_permission_codes_for_module(module_code)
    for role in ROLE_DEFINITIONS:
        role_code = str(role["code"])
        role_items.append(
            {
                "role_code": role_code,
                "role_name": str(role["name"]),
                "capability_codes": _role_template_capability_codes(
                    module_code=module_code,
                    role_code=role_code,
                    capability_codes=capability_codes,
                ),
                "description": _role_template_description(role_code),
            }
        )
    return role_items


def _page_items_for_module(module_code: str) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    for page_code, page_name, page_module_code, parent_code in PAGE_DEFINITIONS:
        if page_module_code != module_code:
            continue
        permission_code = PAGE_PERMISSION_BY_PAGE_CODE.get(page_code)
        if permission_code is None:
            continue
        items.append(
            {
                "page_code": page_code,
                "page_name": page_name,
                "permission_code": permission_code,
                "parent_page_code": parent_code,
            }
        )
    return items


def _feature_items_for_module(module_code: str) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    for feature in FEATURE_DEFINITIONS:
        if feature.module_code != module_code:
            continue
        items.append(
            {
                "feature_code": feature.permission_code.split(".", 2)[-1],
                "feature_name": feature.permission_name,
                "permission_code": feature.permission_code,
                "page_permission_code": PAGE_PERMISSION_BY_PAGE_CODE.get(feature.page_code),
                "linked_action_permission_codes": list(feature.action_permission_codes),
                "dependency_permission_codes": list(feature.dependency_permission_codes),
            }
        )
    items.sort(key=lambda item: str(item["permission_code"]))
    return items


def _hierarchy_permission_codes_for_module(module_code: str) -> dict[str, set[str] | str]:
    module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
        module_code,
        module_permission_code(module_code),
    )
    page_permission_codes = {
        PAGE_PERMISSION_BY_PAGE_CODE[page_code]
        for page_code, _, page_module_code, _ in PAGE_DEFINITIONS
        if page_module_code == module_code and page_code in PAGE_PERMISSION_BY_PAGE_CODE
    }
    feature_permission_codes = {
        feature.permission_code
        for feature in FEATURE_DEFINITIONS
        if feature.module_code == module_code
    }
    return {
        "module_permission_code": module_permission,
        "page_permission_codes": page_permission_codes,
        "feature_permission_codes": feature_permission_codes,
    }


def _all_hierarchy_permission_codes() -> set[str]:
    module_codes = {module_permission_code(item.module_code) for item in MODULE_DEFINITIONS}
    page_codes = {permission_code for permission_code in PAGE_PERMISSION_BY_PAGE_CODE.values()}
    feature_codes = {item.permission_code for item in FEATURE_DEFINITIONS}
    return module_codes.union(page_codes).union(feature_codes)


def _dependency_codes_by_permission_code() -> dict[str, set[str]]:
    dependency_map: dict[str, set[str]] = {}
    for feature in FEATURE_DEFINITIONS:
        dependency_map[feature.permission_code] = set(feature.dependency_permission_codes)
    return dependency_map


def _normalize_hierarchy_permission_codes(
    *,
    requested_codes: set[str],
    valid_codes: set[str],
) -> tuple[set[str], list[str]]:
    dependency_map = _dependency_codes_by_permission_code()
    normalized = {code for code in requested_codes if code in valid_codes}
    auto_linked: set[str] = set()

    changed = True
    while changed:
        changed = False
        for code in list(normalized):
            for dependency_code in dependency_map.get(code, set()):
                if dependency_code not in valid_codes:
                    continue
                if dependency_code in normalized:
                    continue
                normalized.add(dependency_code)
                auto_linked.add(dependency_code)
                changed = True
    return normalized, sorted(auto_linked)


def _role_granted_codes_for_hierarchy(
    db: Session,
    *,
    role_code: str,
    valid_codes: set[str],
) -> set[str]:
    if role_code == ROLE_SYSTEM_ADMIN:
        return set(valid_codes)
    if not valid_codes:
        return set()
    rows = db.execute(
        select(RolePermissionGrant.permission_code).where(
            RolePermissionGrant.role_code == role_code,
            RolePermissionGrant.permission_code.in_(sorted(valid_codes)),
            RolePermissionGrant.granted.is_(True),
        )
    ).scalars().all()
    return {str(code) for code in rows}


def _calculate_role_hierarchy_update(
    db: Session,
    *,
    role_code: str,
    module_code: str,
    module_enabled: bool,
    page_permission_codes: list[str],
    feature_permission_codes: list[str],
) -> dict[str, object]:
    normalized_module = _normalize_module_code(module_code)
    hierarchy_codes = _hierarchy_permission_codes_for_module(normalized_module)
    module_permission = str(hierarchy_codes["module_permission_code"])
    module_pages = set(hierarchy_codes["page_permission_codes"])
    module_features = set(hierarchy_codes["feature_permission_codes"])

    all_hierarchy_codes = _all_hierarchy_permission_codes()
    requested_page_codes = {code.strip() for code in page_permission_codes if code.strip()}
    requested_feature_codes = {code.strip() for code in feature_permission_codes if code.strip()}
    invalid_page_codes = sorted(requested_page_codes.difference(module_pages))
    invalid_feature_codes = sorted(requested_feature_codes.difference(module_features))
    if invalid_page_codes:
        raise ValueError(f"invalid page permission codes: {', '.join(invalid_page_codes)}")
    if invalid_feature_codes:
        raise ValueError(
            f"invalid feature permission codes: {', '.join(invalid_feature_codes)}"
        )

    requested_codes = requested_page_codes.union(requested_feature_codes)
    if module_enabled:
        requested_codes.add(module_permission)

    requested_codes, auto_linked_dependencies = _normalize_hierarchy_permission_codes(
        requested_codes=requested_codes,
        valid_codes=all_hierarchy_codes,
    )

    before_granted_codes = _role_granted_codes_for_hierarchy(
        db,
        role_code=role_code,
        valid_codes=all_hierarchy_codes,
    )
    after_granted_codes = set(before_granted_codes)
    selected_module_codes = module_pages.union(module_features).union({module_permission})
    after_granted_codes.difference_update(selected_module_codes)
    after_granted_codes.update(requested_codes)

    row_by_code = _catalog_rows_by_code(db)
    before_effective_codes = _effective_permission_codes_from_granted(
        granted_codes=before_granted_codes,
        row_by_code=row_by_code,
    )
    after_effective_codes = _effective_permission_codes_from_granted(
        granted_codes=after_granted_codes,
        row_by_code=row_by_code,
    )

    before_selected_codes = sorted(before_granted_codes.intersection(selected_module_codes))
    after_selected_codes = sorted(after_granted_codes.intersection(selected_module_codes))
    return {
        "role_code": role_code,
        "module_code": normalized_module,
        "module_permission_code": module_permission,
        "before_granted_codes": before_granted_codes,
        "after_granted_codes": after_granted_codes,
        "before_selected_codes": before_selected_codes,
        "after_selected_codes": after_selected_codes,
        "added_permission_codes": sorted(after_granted_codes.difference(before_granted_codes)),
        "removed_permission_codes": sorted(before_granted_codes.difference(after_granted_codes)),
        "auto_linked_dependencies": auto_linked_dependencies,
        "effective_page_permission_codes": sorted(after_effective_codes.intersection(module_pages)),
        "effective_feature_permission_codes": sorted(
            after_effective_codes.intersection(module_features)
        ),
        "before_effective_page_permission_codes": sorted(
            before_effective_codes.intersection(module_pages)
        ),
        "before_effective_feature_permission_codes": sorted(
            before_effective_codes.intersection(module_features)
        ),
    }


def _apply_role_permission_changes(
    db: Session,
    *,
    role_code: str,
    changed_codes: list[str],
    after_granted_codes: set[str],
) -> int:
    if not changed_codes:
        return 0
    grant_rows = db.execute(
        select(RolePermissionGrant).where(
            RolePermissionGrant.role_code == role_code,
            RolePermissionGrant.permission_code.in_(changed_codes),
        )
    ).scalars().all()
    row_by_permission = {row.permission_code: row for row in grant_rows}
    updated_count = 0
    for permission_code in changed_codes:
        should_grant = permission_code in after_granted_codes
        row = row_by_permission.get(permission_code)
        if row is None:
            db.add(
                RolePermissionGrant(
                    role_code=role_code,
                    permission_code=permission_code,
                    granted=should_grant,
                )
            )
            updated_count += 1
            continue
        if bool(row.granted) != should_grant:
            row.granted = should_grant
            updated_count += 1
    return updated_count


def get_permission_hierarchy_catalog(
    db: Session,
    *,
    module_code: str,
) -> dict[str, object]:
    normalized_module = _normalize_module_code(module_code)
    ensure_authz_defaults(db)
    available_module_codes = sorted(
        {
            row.module_code
            for row in _module_permission_catalog_rows(db)
            if row.module_code.strip()
        }
    )
    if normalized_module not in available_module_codes:
        raise ValueError(f"module_code is invalid: {normalized_module}")

    return {
        "module_code": normalized_module,
        "module_codes": available_module_codes,
        "module_permission_code": MODULE_PERMISSION_BY_MODULE_CODE.get(
            normalized_module,
            module_permission_code(normalized_module),
        ),
        "module_name": MODULE_NAME_BY_CODE.get(normalized_module, normalized_module),
        "pages": _page_items_for_module(normalized_module),
        "features": _feature_items_for_module(normalized_module),
    }


def get_permission_hierarchy_role_config(
    db: Session,
    *,
    role_code: str,
    module_code: str,
) -> dict[str, object]:
    normalized_module = _normalize_module_code(module_code)
    ensure_authz_defaults(db)
    role_row = db.execute(select(Role).where(Role.code == role_code)).scalars().first()
    if role_row is None:
        raise ValueError(f"Role not found: {role_code}")
    hierarchy_codes = _hierarchy_permission_codes_for_module(normalized_module)
    module_permission = str(hierarchy_codes["module_permission_code"])
    module_pages = set(hierarchy_codes["page_permission_codes"])
    module_features = set(hierarchy_codes["feature_permission_codes"])
    all_hierarchy_codes = _all_hierarchy_permission_codes()
    granted_codes = _role_granted_codes_for_hierarchy(
        db,
        role_code=role_code,
        valid_codes=all_hierarchy_codes,
    )
    row_by_code = _catalog_rows_by_code(db)
    effective_codes = _effective_permission_codes_from_granted(
        granted_codes=granted_codes,
        row_by_code=row_by_code,
    )
    return {
        "role_code": role_row.code,
        "role_name": role_row.name,
        "readonly": role_row.code == ROLE_SYSTEM_ADMIN,
        "module_code": normalized_module,
        "module_enabled": module_permission in granted_codes,
        "granted_page_permission_codes": sorted(granted_codes.intersection(module_pages)),
        "granted_feature_permission_codes": sorted(granted_codes.intersection(module_features)),
        "effective_page_permission_codes": sorted(effective_codes.intersection(module_pages)),
        "effective_feature_permission_codes": sorted(effective_codes.intersection(module_features)),
    }


def update_permission_hierarchy_role_config(
    db: Session,
    *,
    role_code: str,
    module_code: str,
    module_enabled: bool,
    page_permission_codes: list[str],
    feature_permission_codes: list[str],
    dry_run: bool = False,
    operator: User | None = None,
) -> dict[str, object]:
    ensure_authz_defaults(db)
    role_row = db.execute(select(Role).where(Role.code == role_code)).scalars().first()
    if role_row is None:
        raise ValueError(f"Role not found: {role_code}")

    if role_row.code == ROLE_SYSTEM_ADMIN:
        config = get_permission_hierarchy_role_config(
            db,
            role_code=role_row.code,
            module_code=module_code,
        )
        return {
            "role_code": role_row.code,
            "role_name": role_row.name,
            "readonly": True,
            "ignored_input": True,
            "module_code": config["module_code"],
            "before_permission_codes": sorted(
                [*config["granted_page_permission_codes"], *config["granted_feature_permission_codes"]]
            ),
            "after_permission_codes": sorted(
                [*config["granted_page_permission_codes"], *config["granted_feature_permission_codes"]]
            ),
            "added_permission_codes": [],
            "removed_permission_codes": [],
            "auto_linked_dependencies": [],
            "effective_page_permission_codes": config["effective_page_permission_codes"],
            "effective_feature_permission_codes": config["effective_feature_permission_codes"],
            "updated_count": 0,
        }

    result = _calculate_role_hierarchy_update(
        db,
        role_code=role_code,
        module_code=module_code,
        module_enabled=module_enabled,
        page_permission_codes=page_permission_codes,
        feature_permission_codes=feature_permission_codes,
    )

    before_granted_codes = set(result["before_granted_codes"])
    after_granted_codes = set(result["after_granted_codes"])
    changed_codes = sorted(before_granted_codes.symmetric_difference(after_granted_codes))
    updated_count = 0

    if not dry_run and changed_codes:
        updated_count = _apply_role_permission_changes(
            db,
            role_code=role_code,
            changed_codes=changed_codes,
            after_granted_codes=after_granted_codes,
        )
        if updated_count > 0:
            _bump_authz_module_revision(
                db,
                module_code=str(result["module_code"]),
                operator=operator,
            )
            db.commit()
        else:
            db.rollback()
    else:
        updated_count = len(changed_codes)
        db.rollback()

    return {
        "role_code": role_row.code,
        "role_name": role_row.name,
        "readonly": False,
        "ignored_input": False,
        "module_code": result["module_code"],
        "before_permission_codes": result["before_selected_codes"],
        "after_permission_codes": result["after_selected_codes"],
        "added_permission_codes": result["added_permission_codes"],
        "removed_permission_codes": result["removed_permission_codes"],
        "auto_linked_dependencies": result["auto_linked_dependencies"],
        "effective_page_permission_codes": result["effective_page_permission_codes"],
        "effective_feature_permission_codes": result["effective_feature_permission_codes"],
        "updated_count": updated_count,
    }


def preview_permission_hierarchy(
    db: Session,
    *,
    module_code: str,
    role_items: list[dict[str, object]],
) -> dict[str, object]:
    ensure_authz_defaults(db)
    normalized_module = _normalize_module_code(module_code)
    if not role_items:
        return {
            "module_code": normalized_module,
            "role_results": [],
        }

    role_rows = db.execute(select(Role)).scalars().all()
    role_name_by_code = {row.code: row.name for row in role_rows}
    role_results: list[dict[str, object]] = []
    visited_role_codes: set[str] = set()
    for item in role_items:
        role_code = str(item.get("role_code", "")).strip()
        if not role_code:
            raise ValueError("role_code is required")
        if role_code in visited_role_codes:
            raise ValueError(f"duplicate role_code: {role_code}")
        visited_role_codes.add(role_code)
        if role_code not in role_name_by_code:
            raise ValueError(f"Role not found: {role_code}")
        module_enabled = bool(item.get("module_enabled", False))
        raw_pages = item.get("page_permission_codes")
        raw_features = item.get("feature_permission_codes")
        page_codes = (
            [str(code) for code in raw_pages]
            if isinstance(raw_pages, list)
            else []
        )
        feature_codes = (
            [str(code) for code in raw_features]
            if isinstance(raw_features, list)
            else []
        )
        role_result = update_permission_hierarchy_role_config(
            db,
            role_code=role_code,
            module_code=normalized_module,
            module_enabled=module_enabled,
            page_permission_codes=page_codes,
            feature_permission_codes=feature_codes,
            dry_run=True,
        )
        role_results.append(role_result)

    db.rollback()
    role_results.sort(
        key=lambda item: (
            ROLE_SORT_ORDER.get(str(item["role_code"]), 9999),
            str(item["role_code"]),
        )
    )
    return {
        "module_code": normalized_module,
        "role_results": role_results,
    }


def get_capability_pack_catalog(
    db: Session,
    *,
    module_code: str,
) -> dict[str, object]:
    normalized_module = _normalize_module_code(module_code)
    ensure_authz_defaults(db)
    available_module_codes = sorted(
        {
            row.module_code
            for row in _module_permission_catalog_rows(db)
            if row.module_code.strip()
        }
    )
    if normalized_module not in available_module_codes:
        raise ValueError(f"module_code is invalid: {normalized_module}")

    return {
        "module_code": normalized_module,
        "module_codes": available_module_codes,
        "module_name": _module_display_name(normalized_module),
        "module_revision": get_authz_module_revision(
            db,
            module_code=normalized_module,
        ),
        "module_permission_code": MODULE_PERMISSION_BY_MODULE_CODE.get(
            normalized_module,
            module_permission_code(normalized_module),
        ),
        "capability_packs": _capability_items_for_module(normalized_module),
        "role_templates": _capability_role_template_items(normalized_module),
    }


def get_capability_pack_role_config(
    db: Session,
    *,
    role_code: str,
    module_code: str,
) -> dict[str, object]:
    config = get_permission_hierarchy_role_config(
        db,
        role_code=role_code,
        module_code=module_code,
    )
    module_capability_codes = _capability_permission_codes_for_module(config["module_code"])
    granted_capability_codes = sorted(
        set(config["granted_feature_permission_codes"]).intersection(module_capability_codes)
    )
    effective_capability_codes = sorted(
        set(config["effective_feature_permission_codes"]).intersection(module_capability_codes)
    )
    return {
        "role_code": config["role_code"],
        "role_name": config["role_name"],
        "readonly": config["readonly"],
        "module_code": config["module_code"],
        "module_enabled": config["module_enabled"],
        "granted_capability_codes": granted_capability_codes,
        "effective_capability_codes": effective_capability_codes,
        "effective_page_permission_codes": config["effective_page_permission_codes"],
        "auto_linked_dependencies": [],
    }


def _capability_request_to_granted_codes(
    *,
    module_code: str,
    module_enabled: bool,
    capability_codes: set[str],
) -> tuple[set[str], list[str]]:
    normalized_capabilities, auto_linked_dependencies = _normalize_capability_codes_with_dependencies(
        requested_codes=capability_codes
    )
    requested_codes = set(normalized_capabilities)
    if module_enabled or normalized_capabilities:
        requested_codes.add(
            MODULE_PERMISSION_BY_MODULE_CODE.get(
                module_code,
                module_permission_code(module_code),
            )
        )

    for capability_code in list(normalized_capabilities):
        feature = FEATURE_BY_PERMISSION_CODE.get(capability_code)
        if feature is None:
            continue
        page_permission_code = PAGE_PERMISSION_BY_PAGE_CODE.get(feature.page_code)
        current_page_permission = page_permission_code
        while current_page_permission:
            requested_codes.add(current_page_permission)
            permission_item = PERMISSION_BY_CODE.get(current_page_permission)
            parent_permission_code = (
                permission_item.parent_permission_code if permission_item is not None else None
            )
            if not parent_permission_code or not parent_permission_code.startswith("page."):
                break
            current_page_permission = parent_permission_code
        if feature.module_code != module_code:
            requested_codes.add(
                MODULE_PERMISSION_BY_MODULE_CODE.get(
                    feature.module_code,
                    module_permission_code(feature.module_code),
                )
            )

    return requested_codes, auto_linked_dependencies


def _calculate_capability_pack_role_update(
    db: Session,
    *,
    role_code: str,
    module_code: str,
    module_enabled: bool,
    capability_codes: list[str],
) -> dict[str, object]:
    role_row = db.execute(select(Role).where(Role.code == role_code)).scalars().first()
    if role_row is None:
        raise ValueError(f"Role not found: {role_code}")

    normalized_module = _normalize_module_code(module_code)
    module_capability_codes = _capability_permission_codes_for_module(normalized_module)
    requested_capability_codes = {code.strip() for code in capability_codes if code and code.strip()}
    invalid_codes = sorted(requested_capability_codes.difference(module_capability_codes))
    if invalid_codes:
        raise ValueError(f"invalid capability codes: {', '.join(invalid_codes)}")

    if role_row.code == ROLE_SYSTEM_ADMIN:
        config = get_capability_pack_role_config(
            db,
            role_code=role_row.code,
            module_code=normalized_module,
        )
        return {
            "role_code": role_row.code,
            "role_name": role_row.name,
            "readonly": True,
            "ignored_input": True,
            "module_code": normalized_module,
            "before_capability_codes": config["granted_capability_codes"],
            "after_capability_codes": config["granted_capability_codes"],
            "added_capability_codes": [],
            "removed_capability_codes": [],
            "auto_linked_dependencies": [],
            "effective_capability_codes": config["effective_capability_codes"],
            "effective_page_permission_codes": config["effective_page_permission_codes"],
            "updated_count": 0,
            "before_granted_codes": set(),
            "after_granted_codes": set(),
            "changed_codes": [],
        }

    all_hierarchy_codes = _all_hierarchy_permission_codes()
    before_granted_codes = _role_granted_codes_for_hierarchy(
        db,
        role_code=role_code,
        valid_codes=all_hierarchy_codes,
    )
    requested_codes, auto_linked_dependencies = _capability_request_to_granted_codes(
        module_code=normalized_module,
        module_enabled=module_enabled,
        capability_codes=requested_capability_codes,
    )

    hierarchy_codes = _hierarchy_permission_codes_for_module(normalized_module)
    module_hierarchy_codes = set(hierarchy_codes["page_permission_codes"])
    module_hierarchy_codes.update(set(hierarchy_codes["feature_permission_codes"]))
    module_hierarchy_codes.add(str(hierarchy_codes["module_permission_code"]))

    after_granted_codes = set(before_granted_codes)
    after_granted_codes.difference_update(module_hierarchy_codes)
    after_granted_codes.update(requested_codes)

    row_by_code = _catalog_rows_by_code(db)
    before_effective_codes = _effective_permission_codes_from_granted(
        granted_codes=before_granted_codes,
        row_by_code=row_by_code,
    )
    after_effective_codes = _effective_permission_codes_from_granted(
        granted_codes=after_granted_codes,
        row_by_code=row_by_code,
    )

    page_codes_in_module = set(hierarchy_codes["page_permission_codes"])
    before_capabilities = sorted(before_granted_codes.intersection(module_capability_codes))
    after_capabilities = sorted(after_granted_codes.intersection(module_capability_codes))
    changed_codes = sorted(before_granted_codes.symmetric_difference(after_granted_codes))
    return {
        "role_code": role_row.code,
        "role_name": role_row.name,
        "readonly": False,
        "ignored_input": False,
        "module_code": normalized_module,
        "before_capability_codes": before_capabilities,
        "after_capability_codes": after_capabilities,
        "added_capability_codes": sorted(set(after_capabilities).difference(before_capabilities)),
        "removed_capability_codes": sorted(set(before_capabilities).difference(after_capabilities)),
        "auto_linked_dependencies": auto_linked_dependencies,
        "effective_capability_codes": sorted(after_effective_codes.intersection(module_capability_codes)),
        "effective_page_permission_codes": sorted(after_effective_codes.intersection(page_codes_in_module)),
        "updated_count": 0,
        "before_granted_codes": before_granted_codes,
        "after_granted_codes": after_granted_codes,
        "changed_codes": changed_codes,
    }


def update_capability_pack_role_config(
    db: Session,
    *,
    role_code: str,
    module_code: str,
    module_enabled: bool,
    capability_codes: list[str],
    dry_run: bool = False,
    operator: User | None = None,
    change_type: str = "apply",
    rollback_of_change_log_id: int | None = None,
    remark: str | None = None,
) -> dict[str, object]:
    ensure_authz_defaults(db)
    result = _calculate_capability_pack_role_update(
        db,
        role_code=role_code,
        module_code=module_code,
        module_enabled=module_enabled,
        capability_codes=capability_codes,
    )
    changed_codes = list(result["changed_codes"])
    updated_count = 0
    if not dry_run and changed_codes:
        updated_count = _apply_role_permission_changes(
            db,
            role_code=role_code,
            changed_codes=changed_codes,
            after_granted_codes=set(result["after_granted_codes"]),
        )
        if updated_count > 0:
            current_revision = _bump_authz_module_revision(
                db,
                module_code=str(result["module_code"]),
                operator=operator,
            )
            result["updated_count"] = updated_count
            _record_capability_pack_change_log(
                db,
                module_code=str(result["module_code"]),
                revision=current_revision,
                operator=operator,
                remark=remark,
                change_type=change_type,
                rollback_of_change_log_id=rollback_of_change_log_id,
                role_results=[result],
            )
            db.commit()
        else:
            db.rollback()
    else:
        updated_count = len(changed_codes)
        db.rollback()

    return {
        "role_code": str(result["role_code"]),
        "role_name": str(result["role_name"]),
        "readonly": bool(result["readonly"]),
        "ignored_input": bool(result["ignored_input"]),
        "module_code": str(result["module_code"]),
        "before_capability_codes": [str(code) for code in result["before_capability_codes"]],
        "after_capability_codes": [str(code) for code in result["after_capability_codes"]],
        "added_capability_codes": [str(code) for code in result["added_capability_codes"]],
        "removed_capability_codes": [str(code) for code in result["removed_capability_codes"]],
        "auto_linked_dependencies": [str(code) for code in result["auto_linked_dependencies"]],
        "effective_capability_codes": [
            str(code) for code in result["effective_capability_codes"]
        ],
        "effective_page_permission_codes": [
            str(code) for code in result["effective_page_permission_codes"]
        ],
        "updated_count": updated_count,
    }


def apply_capability_pack_role_configs(
    db: Session,
    *,
    module_code: str,
    role_items: list[dict[str, object]],
    expected_revision: int | None = None,
    operator: User | None,
    remark: str | None = None,
    change_type: str = "apply",
    rollback_of_change_log_id: int | None = None,
) -> dict[str, object]:
    ensure_authz_defaults(db)
    normalized_module = _normalize_module_code(module_code)
    current_revision = get_authz_module_revision(db, module_code=normalized_module)
    if expected_revision is not None and expected_revision != current_revision:
        raise AuthzRevisionConflictError(
            f"authz revision conflict: expected {expected_revision}, current {current_revision}"
        )
    if not role_items:
        return {
            "module_code": normalized_module,
            "module_revision": current_revision,
            "role_results": [],
        }

    role_rows = db.execute(select(Role)).scalars().all()
    role_name_by_code = {row.code: row.name for row in role_rows}
    visited_role_codes: set[str] = set()
    results: list[dict[str, object]] = []
    total_updated_count = 0

    for item in role_items:
        role_code = str(item.get("role_code", "")).strip()
        if not role_code:
            raise ValueError("role_code is required")
        if role_code in visited_role_codes:
            raise ValueError(f"duplicate role_code: {role_code}")
        if role_code not in role_name_by_code:
            raise ValueError(f"Role not found: {role_code}")
        visited_role_codes.add(role_code)

        raw_capabilities = item.get("capability_codes")
        capability_codes = [str(code) for code in raw_capabilities] if isinstance(raw_capabilities, list) else []
        result = _calculate_capability_pack_role_update(
            db,
            role_code=role_code,
            module_code=normalized_module,
            module_enabled=bool(item.get("module_enabled", False)),
            capability_codes=capability_codes,
        )
        changed_codes = [str(code) for code in result["changed_codes"]]
        result["updated_count"] = len(changed_codes)
        if not bool(result["readonly"]) and changed_codes:
            total_updated_count += _apply_role_permission_changes(
                db,
                role_code=role_code,
                changed_codes=changed_codes,
                after_granted_codes=set(result["after_granted_codes"]),
            )
        results.append(result)

    if total_updated_count > 0:
        current_revision = _bump_authz_module_revision(
            db,
            module_code=normalized_module,
            operator=operator,
        )
        _record_capability_pack_change_log(
            db,
            module_code=normalized_module,
            revision=current_revision,
            operator=operator,
            remark=remark,
            change_type=change_type,
            rollback_of_change_log_id=rollback_of_change_log_id,
            role_results=results,
        )
        db.commit()
    else:
        db.rollback()

    results.sort(
        key=lambda item: (
            ROLE_SORT_ORDER.get(str(item["role_code"]), 9999),
            str(item["role_code"]),
        )
    )
    return {
        "module_code": normalized_module,
        "module_revision": current_revision,
        "role_results": [_serialize_capability_pack_role_result(item) for item in results],
    }


def list_capability_pack_change_logs(
    db: Session,
    *,
    module_code: str,
    limit: int = 20,
) -> dict[str, object]:
    ensure_authz_defaults(db)
    normalized_module = _normalize_module_code(module_code)
    safe_limit = max(1, min(limit, 100))
    log_rows = db.execute(
        select(AuthzChangeLog)
        .where(AuthzChangeLog.module_code == normalized_module)
        .order_by(AuthzChangeLog.revision.desc(), AuthzChangeLog.id.desc())
        .limit(safe_limit)
    ).scalars().all()
    if not log_rows:
        return {
            "module_code": normalized_module,
            "module_revision": get_authz_module_revision(db, module_code=normalized_module),
            "items": [],
        }

    log_ids = [row.id for row in log_rows]
    item_rows = db.execute(
        select(AuthzChangeLogItem)
        .where(AuthzChangeLogItem.change_log_id.in_(log_ids))
        .order_by(AuthzChangeLogItem.change_log_id.desc(), AuthzChangeLogItem.role_code.asc())
    ).scalars().all()
    items_by_log_id: dict[int, list[AuthzChangeLogItem]] = defaultdict(list)
    for item_row in item_rows:
        items_by_log_id[item_row.change_log_id].append(item_row)

    current_revision = get_authz_module_revision(db, module_code=normalized_module)
    current_snapshot = _snapshot_capability_pack_module_state(db, module_code=normalized_module)
    rollback_target_ids = {
        int(row.rollback_of_change_log_id)
        for row in log_rows
        if row.rollback_of_change_log_id is not None
    }
    rollback_target_revision_by_id: dict[int, int] = {}
    if rollback_target_ids:
        rollback_target_rows = db.execute(
            select(AuthzChangeLog).where(AuthzChangeLog.id.in_(sorted(rollback_target_ids)))
        ).scalars().all()
        rollback_target_revision_by_id = {
            int(row.id): int(row.revision) for row in rollback_target_rows
        }

    return {
        "module_code": normalized_module,
        "module_revision": current_revision,
        "items": [
            {
                "change_log_id": row.id,
                "module_code": row.module_code,
                "module_revision": int(row.revision),
                "change_type": row.change_type,
                "remark": row.remark,
                "operator_user_id": row.operator_user_id,
                "operator_username": row.operator_username,
                "rollback_of_change_log_id": row.rollback_of_change_log_id,
                "rollback_of_revision": rollback_target_revision_by_id.get(
                    int(row.rollback_of_change_log_id)
                )
                if row.rollback_of_change_log_id is not None
                else None,
                "changed_role_count": sum(
                    1
                    for item in items_by_log_id.get(row.id, [])
                    if int(item.updated_count) > 0
                ),
                "added_capability_count": sum(
                    len(item.added_capability_codes)
                    for item in items_by_log_id.get(row.id, [])
                ),
                "removed_capability_count": sum(
                    len(item.removed_capability_codes)
                    for item in items_by_log_id.get(row.id, [])
                ),
                "auto_linked_dependency_count": sum(
                    len(item.auto_linked_dependencies)
                    for item in items_by_log_id.get(row.id, [])
                ),
                "is_current_revision": int(row.revision) == current_revision,
                "is_noop": _normalize_capability_pack_snapshot(list(row.snapshot_json or []))
                == _normalize_capability_pack_snapshot(current_snapshot),
                "can_rollback": _normalize_capability_pack_snapshot(list(row.snapshot_json or []))
                != _normalize_capability_pack_snapshot(current_snapshot),
                "created_at": row.created_at,
                "role_results": [
                    _serialize_capability_pack_change_log_role_item(
                        module_code=row.module_code,
                        item=item,
                    )
                    for item in items_by_log_id.get(row.id, [])
                ],
            }
            for row in log_rows
        ],
    }


def preview_capability_pack_change_log_rollback(
    db: Session,
    *,
    module_code: str,
    change_log_id: int,
) -> dict[str, object]:
    target_log = _get_capability_pack_change_log(
        db,
        module_code=module_code,
        change_log_id=change_log_id,
    )
    snapshot = _normalize_capability_pack_snapshot(list(target_log.snapshot_json or []))
    return preview_capability_packs(
        db,
        module_code=target_log.module_code,
        role_items=[dict(item) for item in snapshot],
    )


def rollback_capability_pack_change_log(
    db: Session,
    *,
    module_code: str,
    change_log_id: int,
    expected_revision: int | None = None,
    operator: User | None,
    remark: str | None = None,
) -> dict[str, object]:
    target_log = _get_capability_pack_change_log(
        db,
        module_code=module_code,
        change_log_id=change_log_id,
    )
    snapshot = _normalize_capability_pack_snapshot(list(target_log.snapshot_json or []))
    if _capability_pack_snapshot_matches_current(
        db,
        module_code=target_log.module_code,
        snapshot=snapshot,
    ):
        raise ValueError(f"目标 revision {target_log.revision} 与当前配置一致，无需回滚")
    return apply_capability_pack_role_configs(
        db,
        module_code=target_log.module_code,
        role_items=[dict(item) for item in snapshot],
        expected_revision=expected_revision,
        operator=operator,
        remark=remark or f"回滚到 revision {target_log.revision}",
        change_type="rollback",
        rollback_of_change_log_id=target_log.id,
    )


def preview_capability_packs(
    db: Session,
    *,
    module_code: str,
    role_items: list[dict[str, object]],
) -> dict[str, object]:
    ensure_authz_defaults(db)
    normalized_module = _normalize_module_code(module_code)
    if not role_items:
        return {
            "module_code": normalized_module,
            "module_revision": get_authz_module_revision(
                db,
                module_code=normalized_module,
            ),
            "role_results": [],
        }

    role_rows = db.execute(select(Role)).scalars().all()
    role_name_by_code = {row.code: row.name for row in role_rows}
    visited_role_codes: set[str] = set()
    results: list[dict[str, object]] = []
    for item in role_items:
        role_code = str(item.get("role_code", "")).strip()
        if not role_code:
            raise ValueError("role_code is required")
        if role_code in visited_role_codes:
            raise ValueError(f"duplicate role_code: {role_code}")
        if role_code not in role_name_by_code:
            raise ValueError(f"Role not found: {role_code}")
        visited_role_codes.add(role_code)
        raw_capabilities = item.get("capability_codes")
        capability_codes = [str(code) for code in raw_capabilities] if isinstance(raw_capabilities, list) else []
        result = update_capability_pack_role_config(
            db,
            role_code=role_code,
            module_code=normalized_module,
            module_enabled=bool(item.get("module_enabled", False)),
            capability_codes=capability_codes,
            dry_run=True,
        )
        results.append(result)

    db.rollback()
    results.sort(
        key=lambda item: (
            ROLE_SORT_ORDER.get(str(item["role_code"]), 9999),
            str(item["role_code"]),
        )
    )
    return {
        "module_code": normalized_module,
        "module_revision": get_authz_module_revision(
            db,
            module_code=normalized_module,
        ),
        "role_results": results,
    }


def get_capability_pack_effective_explain(
    db: Session,
    *,
    role_code: str,
    module_code: str,
) -> dict[str, object]:
    normalized_module = _normalize_module_code(module_code)
    ensure_authz_defaults(db)
    role_row = db.execute(select(Role).where(Role.code == role_code)).scalars().first()
    if role_row is None:
        raise ValueError(f"Role not found: {role_code}")

    hierarchy_codes = _hierarchy_permission_codes_for_module(normalized_module)
    module_permission = str(hierarchy_codes["module_permission_code"])
    module_capability_codes = set(hierarchy_codes["feature_permission_codes"])
    module_page_codes = set(hierarchy_codes["page_permission_codes"])
    all_hierarchy_codes = _all_hierarchy_permission_codes()
    granted_codes = _role_granted_codes_for_hierarchy(
        db,
        role_code=role_code,
        valid_codes=all_hierarchy_codes,
    )
    row_by_code = _catalog_rows_by_code(db)
    effective_codes = _effective_permission_codes_from_granted(
        granted_codes=granted_codes,
        row_by_code=row_by_code,
    )
    module_enabled = module_permission in granted_codes
    capability_items = _capability_items_for_module(normalized_module)

    capability_reasons: list[dict[str, object]] = []
    for item in capability_items:
        capability_code = str(item["capability_code"])
        capability_name = str(item["capability_name"])
        available = capability_code in effective_codes
        reason_codes: list[str] = []
        reason_messages: list[str] = []

        if capability_code not in granted_codes:
            reason_codes.append("capability_not_granted")
            reason_messages.append("未开启该能力")
        if module_permission not in effective_codes:
            reason_codes.append("module_disabled")
            reason_messages.append("模块入口未开启")

        feature = FEATURE_BY_PERMISSION_CODE.get(capability_code)
        page_permission = PAGE_PERMISSION_BY_PAGE_CODE.get(feature.page_code) if feature else None
        if page_permission and page_permission not in effective_codes:
            reason_codes.append("page_disabled")
            reason_messages.append("入口页面未开启")

        if feature is not None:
            for dependency_code in feature.dependency_permission_codes:
                if dependency_code in effective_codes:
                    continue
                reason_codes.append("dependency_missing")
                dep_name = _capability_name(
                    capability_code=dependency_code,
                    raw_name=(
                        FEATURE_BY_PERMISSION_CODE[dependency_code].permission_name
                        if dependency_code in FEATURE_BY_PERMISSION_CODE
                        else dependency_code
                    ),
                )
                reason_messages.append(f"依赖未满足：{dep_name}")

        capability_reasons.append(
            {
                "capability_code": capability_code,
                "capability_name": capability_name,
                "available": available,
                "reason_codes": reason_codes,
                "reason_messages": reason_messages,
            }
        )

    return {
        "role_code": role_row.code,
        "role_name": role_row.name,
        "module_code": normalized_module,
        "module_enabled": module_enabled,
        "effective_page_permission_codes": sorted(effective_codes.intersection(module_page_codes)),
        "effective_capability_codes": sorted(effective_codes.intersection(module_capability_codes)),
        "capability_items": capability_reasons,
    }


def validate_permission_code(permission_code: str) -> PermissionCatalogItem:
    item = PERMISSION_BY_CODE.get(permission_code)
    if item is None:
        raise ValueError(f"Unknown permission code: {permission_code}")
    return item
