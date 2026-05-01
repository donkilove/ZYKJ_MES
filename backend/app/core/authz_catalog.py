from __future__ import annotations

from dataclasses import dataclass

from app.core.authz_hierarchy_catalog import (
    FEATURE_DEFINITIONS,
    MODULE_DEFINITIONS,
    module_permission_code,
)
from app.core.rbac import ROLE_SYSTEM_ADMIN


AUTHZ_MODULE_SYSTEM = "system"
AUTHZ_MODULE_USER = "user"
AUTHZ_MODULE_PRODUCT = "product"
AUTHZ_MODULE_EQUIPMENT = "equipment"
AUTHZ_MODULE_CRAFT = "craft"
AUTHZ_MODULE_QUALITY = "quality"
AUTHZ_MODULE_PRODUCTION = "production"
AUTHZ_MODULE_MESSAGE = "message"

AUTHZ_RESOURCE_PAGE = "page"
AUTHZ_RESOURCE_ACTION = "action"
AUTHZ_RESOURCE_MODULE = "module"
AUTHZ_RESOURCE_FEATURE = "feature"


# Core/system permissions.
PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW = "page.function_permission_config.view"
PERM_AUTHZ_PERMISSION_CATALOG_VIEW = "authz.permissions.catalog.view"
PERM_AUTHZ_MY_PERMISSIONS_VIEW = "authz.permissions.me.view"
PERM_AUTHZ_ROLE_PERMISSIONS_VIEW = "authz.role_permissions.view"
PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE = "authz.role_permissions.update"


# Production page permissions.
PERM_PAGE_PRODUCTION_VIEW = "page.production.view"
PERM_PAGE_PRODUCTION_ORDER_MANAGEMENT_VIEW = "page.production_order_management.view"
PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW = "page.production_order_query.view"
PERM_PAGE_PRODUCTION_ASSIST_RECORDS_VIEW = "page.production_assist_records.view"
PERM_PAGE_PRODUCTION_DATA_QUERY_VIEW = "page.production_data_query.view"
PERM_PAGE_PRODUCTION_SCRAP_STATISTICS_VIEW = "page.production_scrap_statistics.view"
PERM_PAGE_PRODUCTION_REPAIR_ORDERS_VIEW = "page.production_repair_orders.view"


# Production action permissions.
PERM_PROD_ORDERS_LIST = "production.orders.list"
PERM_PROD_ORDERS_CREATE = "production.orders.create"
PERM_PROD_ORDERS_DETAIL = "production.orders.detail"
PERM_PROD_ORDERS_DETAIL_ALL = "production.orders.detail_all"
PERM_PROD_ORDERS_UPDATE = "production.orders.update"
PERM_PROD_ORDERS_DELETE = "production.orders.delete"
PERM_PROD_ORDERS_COMPLETE = "production.orders.complete"
PERM_PROD_ORDERS_PIPELINE_MODE_VIEW = "production.orders.pipeline_mode.view"
PERM_PROD_ORDERS_PIPELINE_MODE_VIEW_ALL = "production.orders.pipeline_mode.view_all"
PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE = "production.orders.pipeline_mode.update"
PERM_PROD_MY_ORDERS_LIST = "production.my_orders.list"
PERM_PROD_MY_ORDERS_PROXY = "production.my_orders.proxy"
PERM_PROD_MY_ORDERS_VIEW_ALL = "production.my_orders.view_all"
PERM_PROD_MY_ORDERS_CONTEXT = "production.my_orders.context"
PERM_PROD_MY_ORDERS_EXPORT = "production.my_orders.export"
PERM_PROD_EXECUTION_FIRST_ARTICLE = "production.execution.first_article"
PERM_PROD_EXECUTION_END_PRODUCTION = "production.execution.end_production"
PERM_PROD_STATS_OVERVIEW = "production.stats.overview"
PERM_PROD_STATS_PROCESSES = "production.stats.processes"
PERM_PROD_STATS_OPERATORS = "production.stats.operators"
PERM_PROD_DATA_TODAY_REALTIME = "production.data.today_realtime"
PERM_PROD_DATA_UNFINISHED_PROGRESS = "production.data.unfinished_progress"
PERM_PROD_DATA_MANUAL = "production.data.manual"
PERM_PROD_DATA_MANUAL_EXPORT = "production.data.manual.export"
PERM_PROD_SCRAP_STATISTICS_LIST = "production.scrap_statistics.list"
PERM_PROD_SCRAP_STATISTICS_EXPORT = "production.scrap_statistics.export"
PERM_PROD_REPAIR_ORDERS_LIST = "production.repair_orders.list"
PERM_PROD_REPAIR_ORDERS_CREATE_MANUAL = "production.repair_orders.create_manual"
PERM_PROD_REPAIR_ORDERS_PHENOMENA_SUMMARY = "production.repair_orders.phenomena_summary"
PERM_PROD_REPAIR_ORDERS_COMPLETE = "production.repair_orders.complete"
PERM_PROD_REPAIR_ORDERS_EXPORT = "production.repair_orders.export"
PERM_PROD_ASSIST_AUTHORIZATIONS_LIST = "production.assist_authorizations.list"
PERM_PROD_ASSIST_AUTHORIZATIONS_CREATE = "production.assist_authorizations.create"
PERM_PROD_ASSIST_AUTHORIZATIONS_CANCEL = "production.assist_authorizations.cancel"
PERM_PROD_ASSIST_USER_OPTIONS_LIST = "production.assist_user_options.list"
PERM_PROD_ORDERS_EXPORT = "production.orders.export"
PERM_PROD_PIPELINE_INSTANCES_LIST = "production.pipeline_instances.list"
PERM_PROD_SCRAP_STATISTICS_DETAIL = "production.scrap_statistics.detail"
PERM_PROD_REPAIR_ORDERS_DETAIL = "production.repair_orders.detail"
PERM_QUALITY_SCRAP_STATISTICS_LIST = "quality.scrap_statistics.list"
PERM_QUALITY_SCRAP_STATISTICS_DETAIL = "quality.scrap_statistics.detail"
PERM_QUALITY_SCRAP_STATISTICS_EXPORT = "quality.scrap_statistics.export"
PERM_QUALITY_SUPPLIERS_LIST = "quality.suppliers.list"
PERM_QUALITY_SUPPLIERS_DETAIL = "quality.suppliers.detail"
PERM_QUALITY_SUPPLIERS_CREATE = "quality.suppliers.create"
PERM_QUALITY_SUPPLIERS_UPDATE = "quality.suppliers.update"
PERM_QUALITY_SUPPLIERS_DELETE = "quality.suppliers.delete"
PERM_QUALITY_REPAIR_ORDERS_LIST = "quality.repair_orders.list"
PERM_QUALITY_REPAIR_ORDERS_DETAIL = "quality.repair_orders.detail"
PERM_QUALITY_REPAIR_ORDERS_PHENOMENA_SUMMARY = "quality.repair_orders.phenomena_summary"
PERM_QUALITY_REPAIR_ORDERS_COMPLETE = "quality.repair_orders.complete"
PERM_QUALITY_REPAIR_ORDERS_EXPORT = "quality.repair_orders.export"
PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW = "quality.first_articles.scan_review"


@dataclass(frozen=True, slots=True)
class PermissionCatalogItem:
    permission_code: str
    permission_name: str
    module_code: str
    resource_type: str
    parent_permission_code: str | None = None
    is_enabled: bool = True


PAGE_DEFINITIONS: list[tuple[str, str, str, str | None]] = [
    ("user", "用户模块", AUTHZ_MODULE_USER, None),
    ("user_management", "用户管理", AUTHZ_MODULE_USER, "user"),
    ("registration_approval", "注册审批", AUTHZ_MODULE_USER, "user"),
    ("role_management", "角色管理", AUTHZ_MODULE_USER, "user"),
    ("audit_log", "操作审计日志", AUTHZ_MODULE_USER, "user"),
    ("account_settings", "个人中心/账号设置", AUTHZ_MODULE_USER, "user"),
    ("login_session", "登录日志/在线会话", AUTHZ_MODULE_USER, "user"),
    ("function_permission_config", "功能权限配置", AUTHZ_MODULE_SYSTEM, "user"),
    ("product", "产品模块", AUTHZ_MODULE_PRODUCT, None),
    ("product_management", "产品管理", AUTHZ_MODULE_PRODUCT, "product"),
    ("product_version_management", "版本管理", AUTHZ_MODULE_PRODUCT, "product"),
    ("product_parameter_management", "产品参数管理", AUTHZ_MODULE_PRODUCT, "product"),
    ("product_parameter_query", "产品参数查询", AUTHZ_MODULE_PRODUCT, "product"),
    ("equipment", "设备模块", AUTHZ_MODULE_EQUIPMENT, None),
    ("equipment_ledger", "设备台账", AUTHZ_MODULE_EQUIPMENT, "equipment"),
    ("maintenance_item", "保养项目", AUTHZ_MODULE_EQUIPMENT, "equipment"),
    ("maintenance_plan", "保养计划", AUTHZ_MODULE_EQUIPMENT, "equipment"),
    ("maintenance_execution", "保养执行", AUTHZ_MODULE_EQUIPMENT, "equipment"),
    ("maintenance_record", "保养记录", AUTHZ_MODULE_EQUIPMENT, "equipment"),
    ("equipment_rule_parameter", "规则与参数", AUTHZ_MODULE_EQUIPMENT, "equipment"),
    ("production", "生产模块", AUTHZ_MODULE_PRODUCTION, None),
    ("production_order_management", "订单管理", AUTHZ_MODULE_PRODUCTION, "production"),
    ("production_order_query", "订单查询", AUTHZ_MODULE_PRODUCTION, "production"),
    ("production_assist_records", "代班记录", AUTHZ_MODULE_PRODUCTION, "production"),
    ("production_data_query", "生产数据", AUTHZ_MODULE_PRODUCTION, "production"),
    ("production_scrap_statistics", "报废统计", AUTHZ_MODULE_PRODUCTION, "production"),
    ("production_repair_orders", "维修订单", AUTHZ_MODULE_PRODUCTION, "production"),
    (
        "production_pipeline_instances",
        "并行实例追踪",
        AUTHZ_MODULE_PRODUCTION,
        "production",
    ),
    ("quality", "质量模块", AUTHZ_MODULE_QUALITY, None),
    ("first_article_management", "每日首件", AUTHZ_MODULE_QUALITY, "quality"),
    ("quality_data_query", "质量数据", AUTHZ_MODULE_QUALITY, "quality"),
    ("quality_scrap_statistics", "报废统计（品质）", AUTHZ_MODULE_QUALITY, "quality"),
    ("quality_repair_orders", "维修订单（品质）", AUTHZ_MODULE_QUALITY, "quality"),
    ("quality_trend", "质量趋势", AUTHZ_MODULE_QUALITY, "quality"),
    ("quality_defect_analysis", "不良分析", AUTHZ_MODULE_QUALITY, "quality"),
    (
        "quality_supplier_management",
        "供应商管理",
        AUTHZ_MODULE_QUALITY,
        "quality",
    ),
    ("craft", "工艺模块", AUTHZ_MODULE_CRAFT, None),
    ("process_management", "工序管理", AUTHZ_MODULE_CRAFT, "craft"),
    ("production_process_config", "生产工序配置", AUTHZ_MODULE_CRAFT, "craft"),
    ("craft_reference_analysis", "工艺引用分析", AUTHZ_MODULE_CRAFT, "craft"),
    ("craft_kanban", "工艺看板", AUTHZ_MODULE_CRAFT, "craft"),
    ("message", "消息模块", AUTHZ_MODULE_MESSAGE, None),
    ("message_center", "消息中心", AUTHZ_MODULE_MESSAGE, "message"),
]

PAGE_PERMISSION_BY_PAGE_CODE: dict[str, str] = {
    page_code: f"page.{page_code}.view" for page_code, _, _, _ in PAGE_DEFINITIONS
}

PRODUCTION_PAGE_PERMISSION_BY_PAGE_CODE: dict[str, str] = {
    "production": PERM_PAGE_PRODUCTION_VIEW,
    "production_order_management": PERM_PAGE_PRODUCTION_ORDER_MANAGEMENT_VIEW,
    "production_order_query": PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW,
    "production_assist_records": PERM_PAGE_PRODUCTION_ASSIST_RECORDS_VIEW,
    "production_data_query": PERM_PAGE_PRODUCTION_DATA_QUERY_VIEW,
    "production_scrap_statistics": PERM_PAGE_PRODUCTION_SCRAP_STATISTICS_VIEW,
    "production_repair_orders": PERM_PAGE_PRODUCTION_REPAIR_ORDERS_VIEW,
}
PRODUCTION_PAGE_CODES = set(PRODUCTION_PAGE_PERMISSION_BY_PAGE_CODE.keys())


PAGE_PERMISSION_CATALOG: list[PermissionCatalogItem] = []
for page_code, page_name, module_code, parent_code in PAGE_DEFINITIONS:
    PAGE_PERMISSION_CATALOG.append(
        PermissionCatalogItem(
            permission_code=PAGE_PERMISSION_BY_PAGE_CODE[page_code],
            permission_name=f"页面访问：{page_name}",
            module_code=module_code,
            resource_type=AUTHZ_RESOURCE_PAGE,
            parent_permission_code=(
                PAGE_PERMISSION_BY_PAGE_CODE[parent_code] if parent_code else None
            ),
        )
    )

MODULE_PERMISSION_CATALOG: list[PermissionCatalogItem] = [
    PermissionCatalogItem(
        permission_code=module_permission_code(item.module_code),
        permission_name=f"模块入口：{item.module_name}",
        module_code=item.module_code,
        resource_type=AUTHZ_RESOURCE_MODULE,
        parent_permission_code=None,
    )
    for item in MODULE_DEFINITIONS
]


MODULE_PERMISSION_BY_MODULE_CODE: dict[str, str] = {
    item.module_code: module_permission_code(item.module_code)
    for item in MODULE_DEFINITIONS
}


FEATURE_PERMISSION_CATALOG: list[PermissionCatalogItem] = []
for feature in FEATURE_DEFINITIONS:
    parent_permission_code = PAGE_PERMISSION_BY_PAGE_CODE.get(feature.page_code)
    FEATURE_PERMISSION_CATALOG.append(
        PermissionCatalogItem(
            permission_code=feature.permission_code,
            permission_name=feature.permission_name,
            module_code=feature.module_code,
            resource_type=AUTHZ_RESOURCE_FEATURE,
            parent_permission_code=parent_permission_code,
        )
    )


def _page_perm(code: str) -> str:
    return PAGE_PERMISSION_BY_PAGE_CODE[code]


ACTION_DEFINITIONS: list[tuple[str, str, str, str | None]] = [
    (
        PERM_AUTHZ_PERMISSION_CATALOG_VIEW,
        "查看权限目录",
        AUTHZ_MODULE_SYSTEM,
        "function_permission_config",
    ),
    (PERM_AUTHZ_MY_PERMISSIONS_VIEW, "查看我的权限", AUTHZ_MODULE_SYSTEM, None),
    (
        PERM_AUTHZ_ROLE_PERMISSIONS_VIEW,
        "查看角色权限配置",
        AUTHZ_MODULE_SYSTEM,
        "function_permission_config",
    ),
    (
        PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE,
        "更新角色权限配置",
        AUTHZ_MODULE_SYSTEM,
        "function_permission_config",
    ),
    ("user.users.list", "查看用户列表", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.create", "创建用户", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.detail", "查看用户详情", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.update", "编辑用户", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.delete", "删除用户", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.restore", "恢复用户", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.enable", "启用用户", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.disable", "停用用户", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.reset_password", "重置用户密码", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.export", "导出用户列表", AUTHZ_MODULE_USER, "user_management"),
    ("user.users.import", "批量导入用户", AUTHZ_MODULE_USER, "user_management"),
    ("user.roles.list", "查看角色列表", AUTHZ_MODULE_USER, "user_management"),
    ("user.roles.detail", "查看角色详情", AUTHZ_MODULE_USER, "user_management"),
    ("user.roles.create", "新建角色", AUTHZ_MODULE_USER, "role_management"),
    ("user.roles.update", "编辑角色", AUTHZ_MODULE_USER, "role_management"),
    ("user.roles.enable", "启用角色", AUTHZ_MODULE_USER, "role_management"),
    ("user.roles.disable", "停用角色", AUTHZ_MODULE_USER, "role_management"),
    ("user.roles.delete", "删除角色", AUTHZ_MODULE_USER, "role_management"),
    (
        "user.processes.list",
        "查看工序列表（用户配置）",
        AUTHZ_MODULE_USER,
        "user_management",
    ),
    (
        "user.registration_requests.list",
        "查看注册申请",
        AUTHZ_MODULE_USER,
        "registration_approval",
    ),
    (
        "user.registration_requests.approve",
        "通过注册申请",
        AUTHZ_MODULE_USER,
        "registration_approval",
    ),
    (
        "user.registration_requests.reject",
        "拒绝注册申请",
        AUTHZ_MODULE_USER,
        "registration_approval",
    ),
    ("user.audit_logs.list", "查看操作审计日志", AUTHZ_MODULE_USER, "audit_log"),
    ("user.profile.view", "查看个人中心", AUTHZ_MODULE_USER, "account_settings"),
    (
        "user.profile.password.update",
        "修改本人密码",
        AUTHZ_MODULE_USER,
        "account_settings",
    ),
    (
        "user.sessions.overview",
        "查看当前会话概览",
        AUTHZ_MODULE_USER,
        "account_settings",
    ),
    (
        "user.sessions.login_logs.list",
        "查看登录日志",
        AUTHZ_MODULE_USER,
        "login_session",
    ),
    ("user.sessions.online.list", "查看在线会话", AUTHZ_MODULE_USER, "login_session"),
    ("user.sessions.force_offline", "强制下线", AUTHZ_MODULE_USER, "login_session"),
    (
        "user.sessions.force_offline.batch",
        "批量强制下线",
        AUTHZ_MODULE_USER,
        "login_session",
    ),
    (
        "product.products.list",
        "查看产品列表",
        AUTHZ_MODULE_PRODUCT,
        "product_management",
    ),
    ("product.products.create", "创建产品", AUTHZ_MODULE_PRODUCT, "product_management"),
    ("product.products.delete", "删除产品", AUTHZ_MODULE_PRODUCT, "product_management"),
    (
        "product.parameters.view",
        "查看产品参数",
        AUTHZ_MODULE_PRODUCT,
        "product_parameter_query",
    ),
    (
        "product.parameters.update",
        "更新产品参数",
        AUTHZ_MODULE_PRODUCT,
        "product_parameter_management",
    ),
    (
        "product.impact.analysis",
        "查看产品影响分析",
        AUTHZ_MODULE_PRODUCT,
        "product_management",
    ),
    (
        "product.lifecycle.update",
        "更新产品生命周期",
        AUTHZ_MODULE_PRODUCT,
        "product_management",
    ),
    (
        "product.products.export",
        "导出产品列表",
        AUTHZ_MODULE_PRODUCT,
        "product_management",
    ),
    (
        "product.versions.list",
        "查看产品版本列表",
        AUTHZ_MODULE_PRODUCT,
        "product_management",
    ),
    (
        "product.versions.compare",
        "比较产品版本",
        AUTHZ_MODULE_PRODUCT,
        "product_management",
    ),
    (
        "product.versions.manage",
        "管理产品版本（新建/复制/生效/停用/删除）",
        AUTHZ_MODULE_PRODUCT,
        "product_management",
    ),
    (
        "product.versions.activate",
        "生效产品版本",
        AUTHZ_MODULE_PRODUCT,
        "product_version_management",
    ),
    ("product.rollback", "回滚产品版本", AUTHZ_MODULE_PRODUCT, "product_management"),
    (
        "product.parameter_history.list",
        "查看参数历史",
        AUTHZ_MODULE_PRODUCT,
        "product_parameter_query",
    ),
    (
        "product.parameters.export",
        "导出产品参数",
        AUTHZ_MODULE_PRODUCT,
        "product_parameter_query",
    ),
    (
        "equipment.admin_owners.list",
        "查看设备负责人选项",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_ledger",
    ),
    (
        "equipment.plan_owner_options.list",
        "查看计划默认执行人候选",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_plan",
    ),
    (
        "equipment.record_executor_options.list",
        "查看记录执行人筛选候选",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_record",
    ),
    (
        "equipment.ledger.list",
        "查看设备台账",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_ledger",
    ),
    (
        "equipment.ledger.create",
        "新增设备台账",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_ledger",
    ),
    (
        "equipment.ledger.update",
        "编辑设备台账",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_ledger",
    ),
    (
        "equipment.ledger.toggle",
        "启停设备台账",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_ledger",
    ),
    (
        "equipment.ledger.delete",
        "删除设备台账",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_ledger",
    ),
    (
        "equipment.items.list",
        "查看保养项目",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_item",
    ),
    (
        "equipment.items.create",
        "新增保养项目",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_item",
    ),
    (
        "equipment.items.update",
        "编辑保养项目",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_item",
    ),
    (
        "equipment.items.toggle",
        "启停保养项目",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_item",
    ),
    (
        "equipment.items.delete",
        "删除保养项目",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_item",
    ),
    (
        "equipment.plans.list",
        "查看保养计划",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_plan",
    ),
    (
        "equipment.plans.create",
        "新增保养计划",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_plan",
    ),
    (
        "equipment.plans.update",
        "编辑保养计划",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_plan",
    ),
    (
        "equipment.plans.toggle",
        "启停保养计划",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_plan",
    ),
    (
        "equipment.plans.delete",
        "删除保养计划",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_plan",
    ),
    (
        "equipment.plans.generate",
        "生成保养工单",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_plan",
    ),
    (
        "equipment.executions.list",
        "查看保养执行",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_execution",
    ),
    (
        "equipment.executions.start",
        "开始保养执行",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_execution",
    ),
    (
        "equipment.executions.complete",
        "完成保养执行",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_execution",
    ),
    (
        "equipment.executions.cancel",
        "取消保养工单",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_execution",
    ),
    (
        "equipment.records.list",
        "查看保养记录",
        AUTHZ_MODULE_EQUIPMENT,
        "maintenance_record",
    ),
    (
        "equipment.rules.list",
        "查看设备规则",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_rule_parameter",
    ),
    (
        "equipment.rules.manage",
        "管理设备规则",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_rule_parameter",
    ),
    (
        "equipment.runtime_parameters.list",
        "查看运行参数",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_rule_parameter",
    ),
    (
        "equipment.runtime_parameters.manage",
        "管理运行参数",
        AUTHZ_MODULE_EQUIPMENT,
        "equipment_rule_parameter",
    ),
    ("craft.stages.list", "查看工段", AUTHZ_MODULE_CRAFT, "process_management"),
    ("craft.stages.create", "新增工段", AUTHZ_MODULE_CRAFT, "process_management"),
    ("craft.stages.update", "编辑工段", AUTHZ_MODULE_CRAFT, "process_management"),
    ("craft.stages.delete", "删除工段", AUTHZ_MODULE_CRAFT, "process_management"),
    ("craft.processes.list", "查看工序", AUTHZ_MODULE_CRAFT, "process_management"),
    ("craft.processes.create", "新增工序", AUTHZ_MODULE_CRAFT, "process_management"),
    ("craft.processes.update", "编辑工序", AUTHZ_MODULE_CRAFT, "process_management"),
    ("craft.processes.delete", "删除工序", AUTHZ_MODULE_CRAFT, "process_management"),
    (
        "craft.system_master_template.view",
        "查看系统母版",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.system_master_template.create",
        "创建系统母版",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.system_master_template.update",
        "更新系统母版",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.kanban.process_metrics.view",
        "查看工艺看板",
        AUTHZ_MODULE_CRAFT,
        "craft_kanban",
    ),
    (
        "craft.templates.list",
        "查看模板列表",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.create",
        "创建模板",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.export",
        "导出模板",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.import",
        "导入模板",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.detail",
        "查看模板详情",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.impact.analysis",
        "查看模板影响分析",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.publish",
        "发布模板",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.versions.list",
        "查看模板版本",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.versions.compare",
        "对比模板版本",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.rollback",
        "回滚模板版本",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.update",
        "更新模板",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "craft.templates.delete",
        "删除模板",
        AUTHZ_MODULE_CRAFT,
        "production_process_config",
    ),
    (
        "quality.first_articles.list",
        "查看每日首件",
        AUTHZ_MODULE_QUALITY,
        "first_article_management",
    ),
    (
        "quality.first_articles.detail",
        "查看首件详情",
        AUTHZ_MODULE_QUALITY,
        "first_article_management",
    ),
    (
        "quality.first_articles.export",
        "导出首件记录",
        AUTHZ_MODULE_QUALITY,
        "first_article_management",
    ),
    (
        "quality.first_articles.disposition",
        "首件处置",
        AUTHZ_MODULE_QUALITY,
        "first_article_management",
    ),
    (
        PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW,
        "扫码复核首件",
        AUTHZ_MODULE_QUALITY,
        "first_article_management",
    ),
    (
        "quality.stats.overview",
        "查看质量总览统计",
        AUTHZ_MODULE_QUALITY,
        "quality_data_query",
    ),
    (
        "quality.stats.processes",
        "查看质量工序统计",
        AUTHZ_MODULE_QUALITY,
        "quality_data_query",
    ),
    (
        "quality.stats.operators",
        "查看质量人员统计",
        AUTHZ_MODULE_QUALITY,
        "quality_data_query",
    ),
    (
        "quality.stats.products",
        "查看质量产品统计",
        AUTHZ_MODULE_QUALITY,
        "quality_data_query",
    ),
    (
        "quality.stats.export",
        "导出质量统计",
        AUTHZ_MODULE_QUALITY,
        "quality_data_query",
    ),
    ("quality.trend", "查看质量趋势", AUTHZ_MODULE_QUALITY, "quality_trend"),
    (
        "quality.defect_analysis.list",
        "查看不良分析",
        AUTHZ_MODULE_QUALITY,
        "quality_defect_analysis",
    ),
    (
        "quality.defect_analysis.export",
        "导出不良分析",
        AUTHZ_MODULE_QUALITY,
        "quality_defect_analysis",
    ),
    (
        PERM_QUALITY_SUPPLIERS_LIST,
        "查看供应商",
        AUTHZ_MODULE_QUALITY,
        "quality",
    ),
    (
        PERM_QUALITY_SUPPLIERS_DETAIL,
        "查看供应商详情",
        AUTHZ_MODULE_QUALITY,
        "quality",
    ),
    (
        PERM_QUALITY_SUPPLIERS_CREATE,
        "创建供应商",
        AUTHZ_MODULE_QUALITY,
        "quality",
    ),
    (
        PERM_QUALITY_SUPPLIERS_UPDATE,
        "更新供应商",
        AUTHZ_MODULE_QUALITY,
        "quality",
    ),
    (
        PERM_QUALITY_SUPPLIERS_DELETE,
        "删除供应商",
        AUTHZ_MODULE_QUALITY,
        "quality",
    ),
    (
        PERM_QUALITY_SCRAP_STATISTICS_LIST,
        "查看品质报废统计",
        AUTHZ_MODULE_QUALITY,
        "quality_scrap_statistics",
    ),
    (
        PERM_QUALITY_SCRAP_STATISTICS_DETAIL,
        "查看品质报废统计详情",
        AUTHZ_MODULE_QUALITY,
        "quality_scrap_statistics",
    ),
    (
        PERM_QUALITY_SCRAP_STATISTICS_EXPORT,
        "导出品质报废统计",
        AUTHZ_MODULE_QUALITY,
        "quality_scrap_statistics",
    ),
    (
        PERM_QUALITY_REPAIR_ORDERS_LIST,
        "查看品质维修订单",
        AUTHZ_MODULE_QUALITY,
        "quality_repair_orders",
    ),
    (
        PERM_QUALITY_REPAIR_ORDERS_DETAIL,
        "查看品质维修订单详情",
        AUTHZ_MODULE_QUALITY,
        "quality_repair_orders",
    ),
    (
        PERM_QUALITY_REPAIR_ORDERS_PHENOMENA_SUMMARY,
        "查看品质维修现象汇总",
        AUTHZ_MODULE_QUALITY,
        "quality_repair_orders",
    ),
    (
        PERM_QUALITY_REPAIR_ORDERS_COMPLETE,
        "完成品质维修订单",
        AUTHZ_MODULE_QUALITY,
        "quality_repair_orders",
    ),
    (
        PERM_QUALITY_REPAIR_ORDERS_EXPORT,
        "导出品质维修订单",
        AUTHZ_MODULE_QUALITY,
        "quality_repair_orders",
    ),
    (
        PERM_PROD_ORDERS_LIST,
        "查看生产订单列表",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_CREATE,
        "创建生产订单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_DETAIL,
        "查看生产订单详情",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_DETAIL_ALL,
        "查看全部生产订单详情",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_UPDATE,
        "编辑生产订单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_DELETE,
        "删除生产订单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_COMPLETE,
        "结束生产订单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_PIPELINE_MODE_VIEW,
        "查看并行模式配置",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_PIPELINE_MODE_VIEW_ALL,
        "查看全部并行模式配置",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE,
        "更新并行模式配置",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_MY_ORDERS_LIST,
        "查看我的工单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_MY_ORDERS_PROXY,
        "查看代理工单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_MY_ORDERS_VIEW_ALL,
        "查看全部工单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_MY_ORDERS_CONTEXT,
        "查看工单上下文",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_MY_ORDERS_EXPORT,
        "导出工单查询结果",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_EXECUTION_FIRST_ARTICLE,
        "首件报检",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_EXECUTION_END_PRODUCTION,
        "报工",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_STATS_OVERVIEW,
        "查看生产总览统计",
        AUTHZ_MODULE_PRODUCTION,
        "production_data_query",
    ),
    (
        PERM_PROD_STATS_PROCESSES,
        "查看生产工序统计",
        AUTHZ_MODULE_PRODUCTION,
        "production_data_query",
    ),
    (
        PERM_PROD_STATS_OPERATORS,
        "查看生产人员统计",
        AUTHZ_MODULE_PRODUCTION,
        "production_data_query",
    ),
    (
        PERM_PROD_DATA_TODAY_REALTIME,
        "查看今日实时数据",
        AUTHZ_MODULE_PRODUCTION,
        "production_data_query",
    ),
    (
        PERM_PROD_DATA_UNFINISHED_PROGRESS,
        "查看未完工进度",
        AUTHZ_MODULE_PRODUCTION,
        "production_data_query",
    ),
    (
        PERM_PROD_DATA_MANUAL,
        "查看手动筛选数据",
        AUTHZ_MODULE_PRODUCTION,
        "production_data_query",
    ),
    (
        PERM_PROD_DATA_MANUAL_EXPORT,
        "导出手动筛选数据",
        AUTHZ_MODULE_PRODUCTION,
        "production_data_query",
    ),
    (
        PERM_PROD_SCRAP_STATISTICS_LIST,
        "查看报废统计",
        AUTHZ_MODULE_PRODUCTION,
        "production_scrap_statistics",
    ),
    (
        PERM_PROD_SCRAP_STATISTICS_EXPORT,
        "导出报废统计",
        AUTHZ_MODULE_PRODUCTION,
        "production_scrap_statistics",
    ),
    (
        PERM_PROD_REPAIR_ORDERS_LIST,
        "查看维修订单",
        AUTHZ_MODULE_PRODUCTION,
        "production_repair_orders",
    ),
    (
        PERM_PROD_REPAIR_ORDERS_CREATE_MANUAL,
        "手工创建维修单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_REPAIR_ORDERS_PHENOMENA_SUMMARY,
        "查看维修现象汇总",
        AUTHZ_MODULE_PRODUCTION,
        "production_repair_orders",
    ),
    (
        PERM_PROD_REPAIR_ORDERS_COMPLETE,
        "完成维修单",
        AUTHZ_MODULE_PRODUCTION,
        "production_repair_orders",
    ),
    (
        PERM_PROD_REPAIR_ORDERS_EXPORT,
        "导出维修订单",
        AUTHZ_MODULE_PRODUCTION,
        "production_repair_orders",
    ),
    (
        PERM_PROD_ASSIST_AUTHORIZATIONS_LIST,
        "查看代班记录",
        AUTHZ_MODULE_PRODUCTION,
        "production_assist_records",
    ),
    (
        PERM_PROD_ASSIST_AUTHORIZATIONS_CREATE,
        "发起代班",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_ASSIST_AUTHORIZATIONS_CANCEL,
        "撤销代班",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_ASSIST_USER_OPTIONS_LIST,
        "查看代班用户选项",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_query",
    ),
    (
        PERM_PROD_ORDERS_EXPORT,
        "导出生产订单",
        AUTHZ_MODULE_PRODUCTION,
        "production_order_management",
    ),
    (
        PERM_PROD_PIPELINE_INSTANCES_LIST,
        "查看并行实例",
        AUTHZ_MODULE_PRODUCTION,
        "production_pipeline_instances",
    ),
    (
        PERM_PROD_SCRAP_STATISTICS_DETAIL,
        "查看报废详情",
        AUTHZ_MODULE_PRODUCTION,
        "production_scrap_statistics",
    ),
    (
        PERM_PROD_REPAIR_ORDERS_DETAIL,
        "查看维修订单详情",
        AUTHZ_MODULE_PRODUCTION,
        "production_repair_orders",
    ),
    ("message.messages.list", "查看消息列表", AUTHZ_MODULE_MESSAGE, "message_center"),
    (
        "message.messages.unread_count",
        "查看未读消息数",
        AUTHZ_MODULE_MESSAGE,
        "message_center",
    ),
    ("message.messages.read", "标记消息已读", AUTHZ_MODULE_MESSAGE, "message_center"),
    (
        "message.messages.read_all",
        "全部标记已读",
        AUTHZ_MODULE_MESSAGE,
        "message_center",
    ),
    (
        "message.messages.detail",
        "查看消息详情",
        AUTHZ_MODULE_MESSAGE,
        "message_center",
    ),
    (
        "message.messages.jump",
        "使用消息来源跳转",
        AUTHZ_MODULE_MESSAGE,
        "message_center",
    ),
    (
        "message.announcements.publish",
        "发布站内公告",
        AUTHZ_MODULE_MESSAGE,
        "message_center",
    ),
]

ACTION_PERMISSION_CATALOG = [
    PermissionCatalogItem(
        permission_code=code,
        permission_name=name,
        module_code=module_code,
        resource_type=AUTHZ_RESOURCE_ACTION,
        parent_permission_code=(_page_perm(parent_page) if parent_page else None),
    )
    for code, name, module_code, parent_page in ACTION_DEFINITIONS
]

PERMISSION_CATALOG: list[PermissionCatalogItem] = (
    MODULE_PERMISSION_CATALOG
    + PAGE_PERMISSION_CATALOG
    + FEATURE_PERMISSION_CATALOG
    + ACTION_PERMISSION_CATALOG
)
PERMISSION_BY_CODE = {item.permission_code: item for item in PERMISSION_CATALOG}


def list_permission_catalog(
    module_code: str | None = None,
) -> list[PermissionCatalogItem]:
    if module_code is None or not module_code.strip():
        return list(PERMISSION_CATALOG)
    normalized = module_code.strip()
    return [item for item in PERMISSION_CATALOG if item.module_code == normalized]


def default_permission_granted(role_code: str, permission_code: str) -> bool:
    if role_code == ROLE_SYSTEM_ADMIN:
        return True

    common_user_permissions = {
        module_permission_code(AUTHZ_MODULE_USER),
        PAGE_PERMISSION_BY_PAGE_CODE["user"],
        PAGE_PERMISSION_BY_PAGE_CODE["account_settings"],
        "feature.user.account_settings.profile_view",
        "feature.user.account_settings.password_update",
        "feature.user.account_settings.session_view",
        "user.profile.view",
        "user.profile.password.update",
        "user.sessions.overview",
    }
    return permission_code in common_user_permissions
