from __future__ import annotations

from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
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
PAGE_ROLE_MANAGEMENT = "role_management"
PAGE_AUDIT_LOG = "audit_log"
PAGE_ACCOUNT_SETTINGS = "account_settings"
PAGE_LOGIN_SESSION = "login_session"
PAGE_FUNCTION_PERMISSION_CONFIG = "function_permission_config"
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
PAGE_EQUIPMENT_RULE_PARAMETER = "equipment_rule_parameter"
PAGE_PRODUCTION = "production"
PAGE_PRODUCTION_ORDER_MANAGEMENT = "production_order_management"
PAGE_PRODUCTION_ORDER_QUERY = "production_order_query"
PAGE_PRODUCTION_ASSIST_APPROVAL = "production_assist_approval"
PAGE_PRODUCTION_DATA_QUERY = "production_data_query"
PAGE_PRODUCTION_SCRAP_STATISTICS = "production_scrap_statistics"
PAGE_PRODUCTION_REPAIR_ORDERS = "production_repair_orders"
PAGE_PRODUCTION_PIPELINE_INSTANCES = "production_pipeline_instances"
PAGE_QUALITY = "quality"
PAGE_FIRST_ARTICLE_MANAGEMENT = "first_article_management"
PAGE_QUALITY_DATA_QUERY = "quality_data_query"
PAGE_QUALITY_SCRAP_STATISTICS = "quality_scrap_statistics"
PAGE_QUALITY_REPAIR_ORDERS = "quality_repair_orders"
PAGE_QUALITY_TREND = "quality_trend"
PAGE_QUALITY_DEFECT_ANALYSIS = "quality_defect_analysis"
PAGE_CRAFT = "craft"
PAGE_PROCESS_MANAGEMENT = "process_management"
PAGE_PRODUCTION_PROCESS_CONFIG = "production_process_config"
PAGE_CRAFT_KANBAN = "craft_kanban"
PAGE_CRAFT_REFERENCE_ANALYSIS = "craft_reference_analysis"
PAGE_PRODUCT_VERSION_MANAGEMENT = "product_version_management"
PAGE_MESSAGE = "message"
PAGE_MESSAGE_CENTER = "message_center"


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
        "code": PAGE_ROLE_MANAGEMENT,
        "name": "角色管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 23,
    },
    {
        "code": PAGE_AUDIT_LOG,
        "name": "操作审计日志",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 24,
    },
    {
        "code": PAGE_ACCOUNT_SETTINGS,
        "name": "个人中心/账号设置",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 25,
    },
    {
        "code": PAGE_LOGIN_SESSION,
        "name": "登录日志/在线会话",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 26,
    },
    {
        "code": PAGE_FUNCTION_PERMISSION_CONFIG,
        "name": "功能权限配置",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_USER,
        "always_visible": False,
        "sort_order": 27,
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
        "code": PAGE_PRODUCT_VERSION_MANAGEMENT,
        "name": "版本管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCT,
        "always_visible": False,
        "sort_order": 32,
    },
    {
        "code": PAGE_PRODUCT_PARAMETER_MANAGEMENT,
        "name": "产品参数管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCT,
        "always_visible": False,
        "sort_order": 33,
    },
    {
        "code": PAGE_PRODUCT_PARAMETER_QUERY,
        "name": "产品参数查询",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCT,
        "always_visible": False,
        "sort_order": 34,
    },
    {
        "code": PAGE_EQUIPMENT,
        "name": "设备",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 70,
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
    {
        "code": PAGE_EQUIPMENT_RULE_PARAMETER,
        "name": "规则与参数",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_EQUIPMENT,
        "always_visible": False,
        "sort_order": 46,
    },
    {
        "code": PAGE_PRODUCTION,
        "name": "生产",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 50,
    },
    {
        "code": PAGE_PRODUCTION_ORDER_MANAGEMENT,
        "name": "订单管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCTION,
        "always_visible": False,
        "sort_order": 51,
    },
    {
        "code": PAGE_PRODUCTION_ORDER_QUERY,
        "name": "订单查询",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCTION,
        "always_visible": False,
        "sort_order": 52,
    },
    {
        "code": PAGE_PRODUCTION_ASSIST_APPROVAL,
        "name": "代班记录",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCTION,
        "always_visible": False,
        "sort_order": 53,
    },
    {
        "code": PAGE_PRODUCTION_DATA_QUERY,
        "name": "生产数据",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCTION,
        "always_visible": False,
        "sort_order": 54,
    },
    {
        "code": PAGE_PRODUCTION_SCRAP_STATISTICS,
        "name": "报废统计",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCTION,
        "always_visible": False,
        "sort_order": 55,
    },
    {
        "code": PAGE_PRODUCTION_REPAIR_ORDERS,
        "name": "维修订单",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCTION,
        "always_visible": False,
        "sort_order": 56,
    },
    {
        "code": PAGE_PRODUCTION_PIPELINE_INSTANCES,
        "name": "并行实例追踪",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_PRODUCTION,
        "always_visible": False,
        "sort_order": 57,
    },
    {
        "code": PAGE_QUALITY,
        "name": "质量",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 60,
    },
    {
        "code": PAGE_FIRST_ARTICLE_MANAGEMENT,
        "name": "首件管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_QUALITY,
        "always_visible": False,
        "sort_order": 61,
    },
    {
        "code": PAGE_QUALITY_DATA_QUERY,
        "name": "质量数据",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_QUALITY,
        "always_visible": False,
        "sort_order": 62,
    },
    {
        "code": PAGE_QUALITY_SCRAP_STATISTICS,
        "name": "报废统计",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_QUALITY,
        "always_visible": False,
        "sort_order": 63,
    },
    {
        "code": PAGE_QUALITY_REPAIR_ORDERS,
        "name": "维修订单",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_QUALITY,
        "always_visible": False,
        "sort_order": 64,
    },
    {
        "code": PAGE_QUALITY_TREND,
        "name": "质量趋势",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_QUALITY,
        "always_visible": False,
        "sort_order": 65,
    },
    {
        "code": PAGE_QUALITY_DEFECT_ANALYSIS,
        "name": "不良分析",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_QUALITY,
        "always_visible": False,
        "sort_order": 66,
    },
    {
        "code": PAGE_CRAFT,
        "name": "工艺",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 40,
    },
    {
        "code": PAGE_PROCESS_MANAGEMENT,
        "name": "工序管理",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_CRAFT,
        "always_visible": False,
        "sort_order": 71,
    },
    {
        "code": PAGE_PRODUCTION_PROCESS_CONFIG,
        "name": "生产工序配置",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_CRAFT,
        "always_visible": False,
        "sort_order": 72,
    },
    {
        "code": PAGE_CRAFT_KANBAN,
        "name": "工艺看板",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_CRAFT,
        "always_visible": False,
        "sort_order": 73,
    },
    {
        "code": PAGE_CRAFT_REFERENCE_ANALYSIS,
        "name": "引用分析",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_CRAFT,
        "always_visible": False,
        "sort_order": 74,
    },
    {
        "code": PAGE_MESSAGE,
        "name": "消息",
        "page_type": PAGE_TYPE_SIDEBAR,
        "parent_code": None,
        "always_visible": False,
        "sort_order": 80,
    },
    {
        "code": PAGE_MESSAGE_CENTER,
        "name": "消息中心",
        "page_type": PAGE_TYPE_TAB,
        "parent_code": PAGE_MESSAGE,
        "always_visible": False,
        "sort_order": 81,
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
        PAGE_ROLE_MANAGEMENT,
        PAGE_AUDIT_LOG,
        PAGE_ACCOUNT_SETTINGS,
        PAGE_LOGIN_SESSION,
        PAGE_FUNCTION_PERMISSION_CONFIG,
        PAGE_PRODUCT,
        PAGE_PRODUCT_MANAGEMENT,
        PAGE_PRODUCT_VERSION_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_QUERY,
        PAGE_EQUIPMENT,
        PAGE_EQUIPMENT_LEDGER,
        PAGE_MAINTENANCE_ITEM,
        PAGE_MAINTENANCE_PLAN,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
        PAGE_EQUIPMENT_RULE_PARAMETER,
        PAGE_PRODUCTION,
        PAGE_PRODUCTION_ORDER_MANAGEMENT,
        PAGE_PRODUCTION_ORDER_QUERY,
        PAGE_PRODUCTION_ASSIST_APPROVAL,
        PAGE_PRODUCTION_DATA_QUERY,
        PAGE_PRODUCTION_SCRAP_STATISTICS,
        PAGE_PRODUCTION_REPAIR_ORDERS,
        PAGE_PRODUCTION_PIPELINE_INSTANCES,
        PAGE_QUALITY,
        PAGE_FIRST_ARTICLE_MANAGEMENT,
        PAGE_QUALITY_DATA_QUERY,
        PAGE_QUALITY_SCRAP_STATISTICS,
        PAGE_QUALITY_REPAIR_ORDERS,
        PAGE_QUALITY_TREND,
        PAGE_QUALITY_DEFECT_ANALYSIS,
        PAGE_CRAFT,
        PAGE_PROCESS_MANAGEMENT,
        PAGE_PRODUCTION_PROCESS_CONFIG,
        PAGE_CRAFT_KANBAN,
        PAGE_CRAFT_REFERENCE_ANALYSIS,
        PAGE_MESSAGE,
        PAGE_MESSAGE_CENTER,
    },
    ROLE_PRODUCTION_ADMIN: {
        PAGE_HOME,
        PAGE_USER,
        PAGE_ACCOUNT_SETTINGS,
        PAGE_PRODUCT,
        PAGE_PRODUCT_MANAGEMENT,
        PAGE_PRODUCT_VERSION_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_MANAGEMENT,
        PAGE_PRODUCT_PARAMETER_QUERY,
        PAGE_EQUIPMENT,
        PAGE_EQUIPMENT_LEDGER,
        PAGE_MAINTENANCE_ITEM,
        PAGE_MAINTENANCE_PLAN,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
        PAGE_EQUIPMENT_RULE_PARAMETER,
        PAGE_PRODUCTION,
        PAGE_PRODUCTION_ORDER_MANAGEMENT,
        PAGE_PRODUCTION_ORDER_QUERY,
        PAGE_PRODUCTION_ASSIST_APPROVAL,
        PAGE_PRODUCTION_DATA_QUERY,
        PAGE_PRODUCTION_SCRAP_STATISTICS,
        PAGE_PRODUCTION_REPAIR_ORDERS,
        PAGE_PRODUCTION_PIPELINE_INSTANCES,
        PAGE_QUALITY,
        PAGE_FIRST_ARTICLE_MANAGEMENT,
        PAGE_QUALITY_DATA_QUERY,
        PAGE_QUALITY_SCRAP_STATISTICS,
        PAGE_QUALITY_REPAIR_ORDERS,
        PAGE_QUALITY_TREND,
        PAGE_QUALITY_DEFECT_ANALYSIS,
        PAGE_CRAFT,
        PAGE_PROCESS_MANAGEMENT,
        PAGE_PRODUCTION_PROCESS_CONFIG,
        PAGE_CRAFT_KANBAN,
        PAGE_CRAFT_REFERENCE_ANALYSIS,
        PAGE_MESSAGE,
        PAGE_MESSAGE_CENTER,
    },
    ROLE_QUALITY_ADMIN: {
        PAGE_HOME,
        PAGE_USER,
        PAGE_ACCOUNT_SETTINGS,
        PAGE_EQUIPMENT,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
        PAGE_PRODUCTION,
        PAGE_PRODUCTION_ORDER_QUERY,
        PAGE_PRODUCTION_DATA_QUERY,
        PAGE_PRODUCTION_SCRAP_STATISTICS,
        PAGE_PRODUCTION_REPAIR_ORDERS,
        PAGE_QUALITY,
        PAGE_FIRST_ARTICLE_MANAGEMENT,
        PAGE_QUALITY_DATA_QUERY,
        PAGE_QUALITY_SCRAP_STATISTICS,
        PAGE_QUALITY_REPAIR_ORDERS,
        PAGE_QUALITY_TREND,
        PAGE_QUALITY_DEFECT_ANALYSIS,
        PAGE_MESSAGE,
        PAGE_MESSAGE_CENTER,
    },
    ROLE_OPERATOR: {
        PAGE_HOME,
        PAGE_USER,
        PAGE_ACCOUNT_SETTINGS,
        PAGE_EQUIPMENT,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
        PAGE_PRODUCTION,
        PAGE_PRODUCTION_ORDER_QUERY,
        PAGE_MESSAGE,
        PAGE_MESSAGE_CENTER,
    },
    ROLE_MAINTENANCE_STAFF: {
        PAGE_HOME,
        PAGE_USER,
        PAGE_ACCOUNT_SETTINGS,
        PAGE_EQUIPMENT,
        PAGE_MAINTENANCE_EXECUTION,
        PAGE_MAINTENANCE_RECORD,
        PAGE_MESSAGE,
        PAGE_MESSAGE_CENTER,
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
