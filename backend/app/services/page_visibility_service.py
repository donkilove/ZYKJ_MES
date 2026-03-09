from __future__ import annotations

from app.core.authz_catalog import PAGE_PERMISSION_BY_PAGE_CODE
from app.core.page_catalog import PAGE_CATALOG, PAGE_TYPE_SIDEBAR, PAGE_TYPE_TAB, ROLE_CODE_ORDER
from app.core.rbac import ROLE_DEFINITIONS
from app.services.authz_service import get_permission_codes_for_role_codes


def list_page_catalog_items() -> list[dict[str, object]]:
    return [dict(item) for item in PAGE_CATALOG]


def get_user_visible_pages(db, role_codes: list[str]) -> tuple[list[str], dict[str, list[str]]]:
    permission_codes = get_permission_codes_for_role_codes(db, role_codes=role_codes)

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


def get_page_visibility_config(db) -> list[dict[str, object]]:
    role_name_by_code = {str(item["code"]): str(item["name"]) for item in ROLE_DEFINITIONS}
    items: list[dict[str, object]] = []
    for role_code in ROLE_CODE_ORDER:
        permission_codes = get_permission_codes_for_role_codes(db, role_codes=[role_code])
        for page in PAGE_CATALOG:
            page_code = str(page["code"])
            always_visible = bool(page.get("always_visible", False))
            permission_code = PAGE_PERMISSION_BY_PAGE_CODE.get(page_code)
            is_visible = always_visible or bool(
                permission_code and permission_code in permission_codes
            )
            items.append(
                {
                    "role_code": role_code,
                    "role_name": role_name_by_code.get(role_code, role_code),
                    "page_code": page_code,
                    "page_name": str(page["name"]),
                    "page_type": str(page["page_type"]),
                    "parent_code": page.get("parent_code"),
                    "editable": False,
                    "is_visible": is_visible,
                    "always_visible": always_visible,
                }
            )
    return items


def update_page_visibility_config(db, updates: list[dict[str, object]]) -> tuple[int, list[str]]:
    _ = db
    _ = updates
    return 0, ["页面可见性配置已下线，请改用功能权限配置"]


def ensure_visibility_defaults(db) -> None:
    _ = db
