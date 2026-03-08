class PermissionCatalogItem {
  const PermissionCatalogItem({
    required this.permissionCode,
    required this.permissionName,
    required this.moduleCode,
    required this.resourceType,
    required this.parentPermissionCode,
    required this.isEnabled,
  });

  final String permissionCode;
  final String permissionName;
  final String moduleCode;
  final String resourceType;
  final String? parentPermissionCode;
  final bool isEnabled;

  factory PermissionCatalogItem.fromJson(Map<String, dynamic> json) {
    return PermissionCatalogItem(
      permissionCode: json['permission_code'] as String,
      permissionName: json['permission_name'] as String,
      moduleCode: json['module_code'] as String,
      resourceType: json['resource_type'] as String,
      parentPermissionCode: json['parent_permission_code'] as String?,
      isEnabled: (json['is_enabled'] as bool?) ?? false,
    );
  }
}

class RolePermissionItem {
  const RolePermissionItem({
    required this.roleCode,
    required this.roleName,
    required this.permissionCode,
    required this.permissionName,
    required this.moduleCode,
    required this.resourceType,
    required this.parentPermissionCode,
    required this.granted,
    required this.isEnabled,
  });

  final String roleCode;
  final String roleName;
  final String permissionCode;
  final String permissionName;
  final String moduleCode;
  final String resourceType;
  final String? parentPermissionCode;
  final bool granted;
  final bool isEnabled;

  factory RolePermissionItem.fromJson(Map<String, dynamic> json) {
    return RolePermissionItem(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      permissionCode: json['permission_code'] as String,
      permissionName: json['permission_name'] as String,
      moduleCode: json['module_code'] as String,
      resourceType: json['resource_type'] as String,
      parentPermissionCode: json['parent_permission_code'] as String?,
      granted: (json['granted'] as bool?) ?? false,
      isEnabled: (json['is_enabled'] as bool?) ?? false,
    );
  }
}

class RolePermissionResult {
  const RolePermissionResult({
    required this.roleCode,
    required this.roleName,
    required this.moduleCode,
    required this.items,
  });

  final String roleCode;
  final String roleName;
  final String moduleCode;
  final List<RolePermissionItem> items;

  factory RolePermissionResult.fromJson(Map<String, dynamic> json) {
    return RolePermissionResult(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      moduleCode: json['module_code'] as String,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((entry) => RolePermissionItem.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RolePermissionUpdateResult {
  const RolePermissionUpdateResult({
    required this.roleCode,
    required this.moduleCode,
    required this.updatedCount,
    required this.beforePermissionCodes,
    required this.afterPermissionCodes,
  });

  final String roleCode;
  final String moduleCode;
  final int updatedCount;
  final List<String> beforePermissionCodes;
  final List<String> afterPermissionCodes;

  factory RolePermissionUpdateResult.fromJson(Map<String, dynamic> json) {
    return RolePermissionUpdateResult(
      roleCode: json['role_code'] as String,
      moduleCode: json['module_code'] as String,
      updatedCount: (json['updated_count'] as int?) ?? 0,
      beforePermissionCodes:
          (json['before_permission_codes'] as List<dynamic>? ?? const []).cast<String>(),
      afterPermissionCodes:
          (json['after_permission_codes'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }
}

class ProductionPermissionCodes {
  static const String pageProductionView = 'page.production.view';
  static const String pageOrderManagementView =
      'page.production_order_management.view';
  static const String pageOrderQueryView = 'page.production_order_query.view';
  static const String pageAssistRecordsView =
      'page.production_assist_approval.view';
  static const String pageDataQueryView = 'page.production_data_query.view';
  static const String pageScrapStatisticsView =
      'page.production_scrap_statistics.view';
  static const String pageRepairOrdersView =
      'page.production_repair_orders.view';

  static const String ordersCreate = 'production.orders.create';
  static const String ordersUpdate = 'production.orders.update';
  static const String ordersDelete = 'production.orders.delete';
  static const String ordersComplete = 'production.orders.complete';
  static const String ordersPipelineUpdate =
      'production.orders.pipeline_mode.update';
  static const String ordersPipelineView = 'production.orders.pipeline_mode.view';

  static const String myOrdersProxy = 'production.my_orders.proxy';
  static const String executionFirstArticle = 'production.execution.first_article';
  static const String executionEndProduction = 'production.execution.end_production';
  static const String assistCreate = 'production.assist_authorizations.create';
  static const String assistList = 'production.assist_authorizations.list';

  static const String dataManualExport = 'production.data.manual.export';
  static const String scrapExport = 'production.scrap_statistics.export';
  static const String repairComplete = 'production.repair_orders.complete';
  static const String repairExport = 'production.repair_orders.export';
  static const String repairCreateManual = 'production.repair_orders.create_manual';
}
