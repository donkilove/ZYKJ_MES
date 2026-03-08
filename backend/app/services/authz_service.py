from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.authz_catalog import (
    PERMISSION_BY_CODE,
    PERMISSION_CATALOG,
    PermissionCatalogItem,
    default_permission_granted,
    list_permission_catalog,
)
from app.core.rbac import ROLE_SYSTEM_ADMIN
from app.models.permission_catalog import PermissionCatalog
from app.models.role import Role
from app.models.role_permission_grant import RolePermissionGrant
from app.models.user import User


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
    if ROLE_SYSTEM_ADMIN in role_codes:
        rows = list_permission_catalog_rows(db, module_code=module_code)
        return {row.permission_code for row in rows if row.is_enabled}

    if not role_codes:
        return set()

    stmt = (
        select(RolePermissionGrant.permission_code)
        .join(
            PermissionCatalog,
            PermissionCatalog.permission_code == RolePermissionGrant.permission_code,
        )
        .where(
            RolePermissionGrant.role_code.in_(role_codes),
            RolePermissionGrant.granted.is_(True),
            PermissionCatalog.is_enabled.is_(True),
        )
    )
    if module_code and module_code.strip():
        stmt = stmt.where(PermissionCatalog.module_code == module_code.strip())

    rows = db.execute(stmt).scalars().all()
    return set(rows)


def get_permission_codes_for_role_codes(
    db: Session,
    *,
    role_codes: list[str],
    module_code: str | None = None,
) -> set[str]:
    ensure_authz_defaults(db)
    normalized_roles = sorted({code for code in role_codes if code})
    if not normalized_roles:
        return set()
    if ROLE_SYSTEM_ADMIN in normalized_roles:
        rows = list_permission_catalog_rows(db, module_code=module_code)
        return {row.permission_code for row in rows if row.is_enabled}

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
    return set(rows)


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
    stmt = (
        select(RolePermissionGrant.id)
        .join(
            PermissionCatalog,
            PermissionCatalog.permission_code == RolePermissionGrant.permission_code,
        )
        .where(
            RolePermissionGrant.role_code.in_(role_codes),
            RolePermissionGrant.permission_code == permission_code,
            RolePermissionGrant.granted.is_(True),
            PermissionCatalog.is_enabled.is_(True),
        )
        .limit(1)
    )
    return db.execute(stmt).scalar() is not None


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

    grant_rows = db.execute(
        select(RolePermissionGrant).where(
            RolePermissionGrant.role_code == role_code,
            RolePermissionGrant.permission_code.in_(catalog_codes),
        )
    ).scalars().all()
    granted_map = {row.permission_code: bool(row.granted) for row in grant_rows}

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
                "granted": bool(granted_map.get(row.permission_code, False)),
                "is_enabled": bool(row.is_enabled),
            }
        )
    return role_row.name, items


def replace_role_permissions_for_module(
    db: Session,
    *,
    role_code: str,
    module_code: str,
    granted_permission_codes: list[str],
    operator: User | None,
    remark: str | None = None,
) -> tuple[int, list[str], list[str]]:
    _ = operator
    _ = remark
    normalized_module = module_code.strip()
    if not normalized_module:
        raise ValueError("module_code is required")

    ensure_authz_defaults(db)
    role_row = db.execute(select(Role).where(Role.code == role_code)).scalars().first()
    if role_row is None:
        raise ValueError(f"Role not found: {role_code}")

    catalog_items = list_permission_catalog(normalized_module)
    if not catalog_items:
        raise ValueError(f"module_code is invalid: {normalized_module}")
    valid_codes = {item.permission_code for item in catalog_items}
    target_codes = {code.strip() for code in granted_permission_codes if code and code.strip()}
    invalid_codes = sorted(target_codes.difference(valid_codes))
    if invalid_codes:
        raise ValueError(f"invalid permission codes: {', '.join(invalid_codes)}")

    rows = db.execute(
        select(RolePermissionGrant).where(
            RolePermissionGrant.role_code == role_code,
            RolePermissionGrant.permission_code.in_(valid_codes),
        )
    ).scalars().all()
    row_by_code = {row.permission_code: row for row in rows}

    before_granted = sorted([row.permission_code for row in rows if row.granted])
    updated_count = 0
    for permission_code in sorted(valid_codes):
        should_grant = permission_code in target_codes
        row = row_by_code.get(permission_code)
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
        after_granted = sorted(target_codes)
        db.commit()
        return updated_count, before_granted, after_granted

    db.rollback()
    return 0, before_granted, before_granted


def validate_permission_code(permission_code: str) -> PermissionCatalogItem:
    item = PERMISSION_BY_CODE.get(permission_code)
    if item is None:
        raise ValueError(f"Unknown permission code: {permission_code}")
    return item
