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
from app.core.rbac import ROLE_DEFINITIONS, ROLE_SYSTEM_ADMIN
from app.models.permission_catalog import PermissionCatalog
from app.models.role import Role
from app.models.role_permission_grant import RolePermissionGrant
from app.models.user import User


ROLE_SORT_ORDER = {str(item["code"]): index for index, item in enumerate(ROLE_DEFINITIONS)}


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


def ensure_authz_defaults(db: Session) -> None:
    catalog_changed = ensure_permission_catalog_defaults(db)
    grants_changed = ensure_role_permission_defaults(db)
    if catalog_changed or grants_changed:
        db.commit()


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
    for code in granted_codes:
        row = row_by_code.get(code)
        if row is None or row.resource_type != AUTHZ_RESOURCE_FEATURE:
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
        enabled_features.add(code)
    effective.update(enabled_features)

    enabled_actions: set[str] = set()
    for code in granted_codes:
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
    row_by_code = _catalog_rows_by_code(db, module_code=module_code)
    if ROLE_SYSTEM_ADMIN in normalized_roles:
        return {code for code in row_by_code}
    granted_codes = _load_granted_permission_codes_for_roles(
        db,
        role_codes=normalized_roles,
        module_code=module_code,
    )
    return _effective_permission_codes_from_granted(
        granted_codes=granted_codes,
        row_by_code=row_by_code,
    )


def _resolve_permission_for_access(
    *,
    permission_code: str,
    row_by_code: dict[str, PermissionCatalog],
) -> str:
    row = row_by_code.get(permission_code)
    if row is None:
        return permission_code
    if (
        row.resource_type == AUTHZ_RESOURCE_ACTION
        and row.parent_permission_code
        and row.parent_permission_code.startswith("page.")
    ):
        return row.parent_permission_code
    return permission_code


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
    row_by_code = _catalog_rows_by_code(db)
    required_code = _resolve_permission_for_access(
        permission_code=permission_code,
        row_by_code=row_by_code,
    )
    effective_codes = _effective_permission_codes_for_role_codes(
        db,
        role_codes=role_codes,
    )
    return required_code in effective_codes


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
        grant_rows = db.execute(
            select(RolePermissionGrant).where(
                RolePermissionGrant.role_code == role_code,
                RolePermissionGrant.permission_code.in_(changed_codes),
            )
        ).scalars().all()
        row_by_permission = {row.permission_code: row for row in grant_rows}
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
        if updated_count > 0:
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


def validate_permission_code(permission_code: str) -> PermissionCatalogItem:
    item = PERMISSION_BY_CODE.get(permission_code)
    if item is None:
        raise ValueError(f"Unknown permission code: {permission_code}")
    return item
