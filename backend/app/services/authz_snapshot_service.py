from __future__ import annotations

from collections import defaultdict

from sqlalchemy.orm import Session

from app.core.authz_catalog import (
    AUTHZ_RESOURCE_ACTION,
    AUTHZ_RESOURCE_FEATURE,
    AUTHZ_RESOURCE_PAGE,
    MODULE_PERMISSION_BY_MODULE_CODE,
    PAGE_PERMISSION_BY_PAGE_CODE,
)
from app.core.authz_hierarchy_catalog import MODULE_NAME_BY_CODE, module_permission_code
from app.core.page_catalog import PAGE_CATALOG, PAGE_TYPE_SIDEBAR, PAGE_TYPE_TAB
from app.models.permission_catalog import PermissionCatalog
from app.models.user import User
from app.services.authz_service import (
    get_authz_module_revision_map,
    get_user_permission_codes,
    list_permission_catalog_rows,
)


def _visible_pages_from_permission_codes(
    permission_codes: set[str],
) -> tuple[list[str], dict[str, list[str]]]:
    sidebar_codes: list[str] = []
    tab_codes_by_parent: dict[str, list[str]] = {}
    visible_sidebar_set: set[str] = set()

    for page in PAGE_CATALOG:
        page_code = str(page["code"])
        page_type = str(page["page_type"])
        parent_code = page.get("parent_code")
        always_visible = bool(page.get("always_visible", False))
        permission_code = PAGE_PERMISSION_BY_PAGE_CODE.get(page_code)
        visible = always_visible or bool(permission_code and permission_code in permission_codes)
        if not visible:
            continue

        if page_type == PAGE_TYPE_SIDEBAR:
            sidebar_codes.append(page_code)
            visible_sidebar_set.add(page_code)
            continue
        if page_type == PAGE_TYPE_TAB and isinstance(parent_code, str):
            if parent_code not in visible_sidebar_set:
                continue
            tab_codes_by_parent.setdefault(parent_code, []).append(page_code)

    return sidebar_codes, tab_codes_by_parent


def get_authz_snapshot(
    db: Session,
    *,
    user: User,
) -> dict[str, object]:
    catalog_rows = list_permission_catalog_rows(db)
    row_by_code: dict[str, PermissionCatalog] = {
        row.permission_code: row for row in catalog_rows
    }
    effective_codes = get_user_permission_codes(db, user=user)
    sidebar_codes, tab_codes_by_parent = _visible_pages_from_permission_codes(
        effective_codes,
    )

    revision_by_module = get_authz_module_revision_map(db)
    permissions_by_module: dict[str, list[str]] = defaultdict(list)
    page_permissions_by_module: dict[str, list[str]] = defaultdict(list)
    capability_codes_by_module: dict[str, list[str]] = defaultdict(list)
    action_codes_by_module: dict[str, list[str]] = defaultdict(list)

    for code in sorted(effective_codes):
        row = row_by_code.get(code)
        if row is None:
            continue
        module_code = str(row.module_code).strip()
        if not module_code:
            continue
        permissions_by_module[module_code].append(code)
        if row.resource_type == AUTHZ_RESOURCE_PAGE:
            page_permissions_by_module[module_code].append(code)
        elif row.resource_type == AUTHZ_RESOURCE_FEATURE:
            capability_codes_by_module[module_code].append(code)
        elif row.resource_type == AUTHZ_RESOURCE_ACTION:
            action_codes_by_module[module_code].append(code)

    role_codes = sorted({role.code for role in user.roles})
    module_codes = sorted(
        {
            *revision_by_module.keys(),
            *(str(row.module_code).strip() for row in catalog_rows if str(row.module_code).strip()),
        }
    )
    module_items: list[dict[str, object]] = []
    for module_code in module_codes:
        module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
            module_code,
            module_permission_code(module_code),
        )
        module_items.append(
            {
                "module_code": module_code,
                "module_name": MODULE_NAME_BY_CODE.get(module_code, module_code),
                "module_revision": revision_by_module.get(module_code, 0),
                "module_enabled": module_permission in effective_codes,
                "effective_permission_codes": permissions_by_module.get(module_code, []),
                "effective_page_permission_codes": page_permissions_by_module.get(module_code, []),
                "effective_capability_codes": capability_codes_by_module.get(module_code, []),
                "effective_action_permission_codes": action_codes_by_module.get(module_code, []),
            }
        )

    return {
        "revision": max(revision_by_module.values(), default=0),
        "role_codes": role_codes,
        "visible_sidebar_codes": sidebar_codes,
        "tab_codes_by_parent": tab_codes_by_parent,
        "module_items": module_items,
    }
