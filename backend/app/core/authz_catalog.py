from __future__ import annotations

from dataclasses import dataclass

from app.core.rbac import ROLE_SYSTEM_ADMIN


AUTHZ_MODULE_PRODUCTION = "production"
AUTHZ_MODULE_SYSTEM = "system"

AUTHZ_RESOURCE_PAGE = "page"
AUTHZ_RESOURCE_ACTION = "action"


# System permissions.
PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW = "page.function_permission_config.view"
PERM_AUTHZ_PERMISSION_CATALOG_VIEW = "authz.permissions.catalog.view"
PERM_AUTHZ_MY_PERMISSIONS_VIEW = "authz.permissions.me.view"
PERM_AUTHZ_ROLE_PERMISSIONS_VIEW = "authz.role_permissions.view"
PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE = "authz.role_permissions.update"


# Production page visibility permissions.
PERM_PAGE_PRODUCTION_VIEW = "page.production.view"
PERM_PAGE_PRODUCTION_ORDER_MANAGEMENT_VIEW = "page.production_order_management.view"
PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW = "page.production_order_query.view"
PERM_PAGE_PRODUCTION_ASSIST_RECORDS_VIEW = "page.production_assist_approval.view"
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
PERM_PROD_ASSIST_AUTHORIZATIONS_REVIEW = "production.assist_authorizations.review"
PERM_PROD_ASSIST_USER_OPTIONS_LIST = "production.assist_user_options.list"


PRODUCTION_PAGE_PERMISSION_BY_PAGE_CODE: dict[str, str] = {
    "production": PERM_PAGE_PRODUCTION_VIEW,
    "production_order_management": PERM_PAGE_PRODUCTION_ORDER_MANAGEMENT_VIEW,
    "production_order_query": PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW,
    "production_assist_approval": PERM_PAGE_PRODUCTION_ASSIST_RECORDS_VIEW,
    "production_data_query": PERM_PAGE_PRODUCTION_DATA_QUERY_VIEW,
    "production_scrap_statistics": PERM_PAGE_PRODUCTION_SCRAP_STATISTICS_VIEW,
    "production_repair_orders": PERM_PAGE_PRODUCTION_REPAIR_ORDERS_VIEW,
}

PRODUCTION_PAGE_CODES = set(PRODUCTION_PAGE_PERMISSION_BY_PAGE_CODE.keys())


@dataclass(frozen=True, slots=True)
class PermissionCatalogItem:
    permission_code: str
    permission_name: str
    module_code: str
    resource_type: str
    parent_permission_code: str | None = None
    is_enabled: bool = True


PERMISSION_CATALOG: list[PermissionCatalogItem] = [
    PermissionCatalogItem(
        permission_code=PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW,
        permission_name="Function permission config page view",
        module_code=AUTHZ_MODULE_SYSTEM,
        resource_type=AUTHZ_RESOURCE_PAGE,
    ),
    PermissionCatalogItem(
        permission_code=PERM_AUTHZ_PERMISSION_CATALOG_VIEW,
        permission_name="View permission catalog",
        module_code=AUTHZ_MODULE_SYSTEM,
        resource_type=AUTHZ_RESOURCE_ACTION,
        parent_permission_code=PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_AUTHZ_MY_PERMISSIONS_VIEW,
        permission_name="View my permissions",
        module_code=AUTHZ_MODULE_SYSTEM,
        resource_type=AUTHZ_RESOURCE_ACTION,
    ),
    PermissionCatalogItem(
        permission_code=PERM_AUTHZ_ROLE_PERMISSIONS_VIEW,
        permission_name="View role permission config",
        module_code=AUTHZ_MODULE_SYSTEM,
        resource_type=AUTHZ_RESOURCE_ACTION,
        parent_permission_code=PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE,
        permission_name="Update role permission config",
        module_code=AUTHZ_MODULE_SYSTEM,
        resource_type=AUTHZ_RESOURCE_ACTION,
        parent_permission_code=PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_PAGE_PRODUCTION_VIEW,
        permission_name="Production module view",
        module_code=AUTHZ_MODULE_PRODUCTION,
        resource_type=AUTHZ_RESOURCE_PAGE,
    ),
    PermissionCatalogItem(
        permission_code=PERM_PAGE_PRODUCTION_ORDER_MANAGEMENT_VIEW,
        permission_name="Production order management tab view",
        module_code=AUTHZ_MODULE_PRODUCTION,
        resource_type=AUTHZ_RESOURCE_PAGE,
        parent_permission_code=PERM_PAGE_PRODUCTION_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_PAGE_PRODUCTION_ORDER_QUERY_VIEW,
        permission_name="Production order query tab view",
        module_code=AUTHZ_MODULE_PRODUCTION,
        resource_type=AUTHZ_RESOURCE_PAGE,
        parent_permission_code=PERM_PAGE_PRODUCTION_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_PAGE_PRODUCTION_ASSIST_RECORDS_VIEW,
        permission_name="Production assist records tab view",
        module_code=AUTHZ_MODULE_PRODUCTION,
        resource_type=AUTHZ_RESOURCE_PAGE,
        parent_permission_code=PERM_PAGE_PRODUCTION_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_PAGE_PRODUCTION_DATA_QUERY_VIEW,
        permission_name="Production data tab view",
        module_code=AUTHZ_MODULE_PRODUCTION,
        resource_type=AUTHZ_RESOURCE_PAGE,
        parent_permission_code=PERM_PAGE_PRODUCTION_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_PAGE_PRODUCTION_SCRAP_STATISTICS_VIEW,
        permission_name="Production scrap statistics tab view",
        module_code=AUTHZ_MODULE_PRODUCTION,
        resource_type=AUTHZ_RESOURCE_PAGE,
        parent_permission_code=PERM_PAGE_PRODUCTION_VIEW,
    ),
    PermissionCatalogItem(
        permission_code=PERM_PAGE_PRODUCTION_REPAIR_ORDERS_VIEW,
        permission_name="Production repair orders tab view",
        module_code=AUTHZ_MODULE_PRODUCTION,
        resource_type=AUTHZ_RESOURCE_PAGE,
        parent_permission_code=PERM_PAGE_PRODUCTION_VIEW,
    ),
    PermissionCatalogItem(PERM_PROD_ORDERS_LIST, "List production orders", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_CREATE, "Create production order", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_DETAIL, "View production order detail", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_DETAIL_ALL, "View all production order detail", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_UPDATE, "Update production order", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_DELETE, "Delete production order", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_COMPLETE, "Complete production order", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_PIPELINE_MODE_VIEW, "View pipeline mode", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_PIPELINE_MODE_VIEW_ALL, "View all pipeline mode", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE, "Update pipeline mode", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_MY_ORDERS_LIST, "List my orders", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_MY_ORDERS_PROXY, "Proxy my orders view", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_MY_ORDERS_VIEW_ALL, "My orders view all", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_MY_ORDERS_CONTEXT, "Get my order context", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_EXECUTION_FIRST_ARTICLE, "Submit first article", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_EXECUTION_END_PRODUCTION, "Submit end production", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_STATS_OVERVIEW, "View production overview stats", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_STATS_PROCESSES, "View production process stats", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_STATS_OPERATORS, "View production operator stats", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_DATA_TODAY_REALTIME, "View today realtime production data", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_DATA_UNFINISHED_PROGRESS, "View unfinished progress", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_DATA_MANUAL, "View manual production data", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_DATA_MANUAL_EXPORT, "Export manual production data", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_SCRAP_STATISTICS_LIST, "List scrap statistics", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_SCRAP_STATISTICS_EXPORT, "Export scrap statistics", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_REPAIR_ORDERS_LIST, "List repair orders", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_REPAIR_ORDERS_CREATE_MANUAL, "Create manual repair order", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_REPAIR_ORDERS_PHENOMENA_SUMMARY, "View repair phenomena summary", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_REPAIR_ORDERS_COMPLETE, "Complete repair order", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_REPAIR_ORDERS_EXPORT, "Export repair orders", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ASSIST_AUTHORIZATIONS_LIST, "List assist records", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ASSIST_AUTHORIZATIONS_CREATE, "Create assist authorization", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ASSIST_AUTHORIZATIONS_REVIEW, "Review assist authorization (compat)", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
    PermissionCatalogItem(PERM_PROD_ASSIST_USER_OPTIONS_LIST, "List assist user options", AUTHZ_MODULE_PRODUCTION, AUTHZ_RESOURCE_ACTION),
]

PERMISSION_BY_CODE = {item.permission_code: item for item in PERMISSION_CATALOG}


def list_permission_catalog(module_code: str | None = None) -> list[PermissionCatalogItem]:
    if module_code is None or not module_code.strip():
        return list(PERMISSION_CATALOG)
    normalized = module_code.strip()
    return [item for item in PERMISSION_CATALOG if item.module_code == normalized]


def default_permission_granted(role_code: str, permission_code: str) -> bool:
    _ = permission_code
    return role_code == ROLE_SYSTEM_ADMIN
