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
PAGE_PRODUCT = "product"
PAGE_PRODUCT_MANAGEMENT = "product_management"
PAGE_PRODUCT_PARAMETER_MANAGEMENT = "product_parameter_management"
PAGE_PRODUCT_PARAMETER_QUERY = "product_parameter_query"
PAGE_EQUIPMENT = "equipment"
PAGE_EQUIPMENT_LEDGER = "equipment_ledger"
PAGE_MAINTENANCE_ITEM = "maintenance_item"
PAGE_MAINTENANCE_PLAN = "maintenance_plan"
PAGE_MAINTENANCE_EXECUTION = "maintenance_execution"
PAGE_MAINTENANCE_RECORD = "maintenance_record"


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
    {
        "code": PAGE_PRODUCT,
        "name": "产品",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 30,
    },
    {
        "code": PAGE_PRODUCT_MANAGEMENT,
        "name": "产品管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCT,
        "always_visible": False,
        "sort_order": 31,
    },
    {
        "code": PAGE_PRODUCT_PARAMETER_MANAGEMENT,
        "name": "产品参数管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCT,
        "always_visible": False,
        "sort_order": 32,
    },
    {
        "code": PAGE_PRODUCT_PARAMETER_QUERY,
        "name": "产品参数查询",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCT,
        "always_visible": False,
        "sort_order": 33,
    },
    {
        "code": PAGE_EQUIPMENT,
        "name": "设备",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 40,
    },
    {
        "code": PAGE_EQUIPMENT_LEDGER,
        "name": "设备台账",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_EQUIPMENT,
        "always_visible": False,
        "sort_order": 41,
    },
    {
        "code": PAGE_MAINTENANCE_ITEM,
        "name": "保养项目",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_EQUIPMENT,
        "always_visible": False,
        "sort_order": 42,
    },
    {
        "code": PAGE_MAINTENANCE_PLAN,
        "name": "保养计划",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_EQUIPMENT,
        "always_visible": False,
        "sort_order": 43,
    },
    {
        "code": PAGE_MAINTENANCE_EXECUTION,
        "name": "保养执行",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_EQUIPMENT,
        "always_visible": False,
        "sort_order": 44,
    },
    {
        "code": PAGE_MAINTENANCE_RECORD,
        "name": "保养记录",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_EQUIPMENT,
        "always_visible": False,
        "sort_order": 45,
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
        PAGE_PRODUCT,
        PAGE_PRODUCT_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_QUERY,
        PAGE_EQUIPMENT,
        PAGE_EQUIPMENT_LEDGER,
        PAGE_MAINTENANCE_ITEM,
        PAGE_MAINTENANCE_PLAN,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
    },
    ROLE_PRODUCTION_ADMIN: {
        PAGE_HOME,
        PAGE_PRODUCT,
        PAGE_PRODUCT_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_QUERY,
        PAGE_EQUIPMENT,
        PAGE_EQUIPMENT_LEDGER,
        PAGE_MAINTENANCE_ITEM,
        PAGE_MAINTENANCE_PLAN,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
    },
    ROLE_QUALITY_ADMIN: {
        PAGE_HOME,
        PAGE_EQUIPMENT,
        PAGE_MAINTENANCE_RECORD,
    },
    ROLE_OPERATOR: {
        PAGE_HOME,
        PAGE_EQUIPMENT,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
    },
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
