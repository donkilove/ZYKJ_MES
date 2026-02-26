from __future__ import annotations

from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)


PAGE_TYPE_SIDEBAR = "sidebar"
PAGE_TYPE_TAB = "tab"

PAGE_HOME = "home"
PAGE_USER = "user"
PAGE_USER_MANAGEMENT = "user_management"
PAGE_REGISTRATION_APPROVAL = "registration_approval"
PAGE_VISIBILITY_CONFIG = "page_visibility_config"


PAGE_CATALOG = [
    {
        "code": PAGE_HOME,
        "name": "首页",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": True,
        "sort_order": 10,
    },
    {
        "code": PAGE_USER,
        "name": "用户",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 20,
    },
    {
        "code": PAGE_USER_MANAGEMENT,
        "name": "用户管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 21,
    },
    {
        "code": PAGE_REGISTRATION_APPROVAL,
        "name": "注册审批",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 22,
    },
    {
        "code": PAGE_VISIBILITY_CONFIG,
        "name": "页面可见性配置",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 23,
    },
]


PAGE_BY_CODE = {item["code"]: item for item in PAGE_CATALOG}
ROLE_CODE_ORDER = [
    ROLE_SYSTEM_ADMIN,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_OPERATOR,
]
ROLE_CODE_SET = set(ROLE_CODE_ORDER)

DEFAULT_VISIBLE_PAGES_BY_ROLE = {
    ROLE_SYSTEM_ADMIN: {
        PAGE_HOME,
        PAGE_USER,
        PAGE_USER_MANAGEMENT,
        PAGE_REGISTRATION_APPROVAL,
        PAGE_VISIBILITY_CONFIG,
    },
    ROLE_PRODUCTION_ADMIN: {PAGE_HOME},
    ROLE_QUALITY_ADMIN: {PAGE_HOME},
    ROLE_OPERATOR: {PAGE_HOME},
}


def is_valid_page_code(page_code: str) -> bool:
    return page_code in PAGE_BY_CODE


def is_always_visible_page(page_code: str) -> bool:
    page = PAGE_BY_CODE.get(page_code)
    return bool(page and page.get("always_visible"))


def default_page_visible(role_code: str, page_code: str) -> bool:
    if is_always_visible_page(page_code):
        return True
    return page_code in DEFAULT_VISIBLE_PAGES_BY_ROLE.get(role_code, set())
