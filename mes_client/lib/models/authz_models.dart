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
          .map(
            (entry) =>
                RolePermissionItem.fromJson(entry as Map<String, dynamic>),
          )
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
          (json['before_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      afterPermissionCodes:
          (json['after_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
    );
  }
}

class RolePermissionMatrixItem {
  const RolePermissionMatrixItem({
    required this.roleCode,
    required this.roleName,
    required this.readonly,
    required this.isSystemAdmin,
    required this.grantedPermissionCodes,
  });

  final String roleCode;
  final String roleName;
  final bool readonly;
  final bool isSystemAdmin;
  final List<String> grantedPermissionCodes;

  factory RolePermissionMatrixItem.fromJson(Map<String, dynamic> json) {
    return RolePermissionMatrixItem(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      readonly: (json['readonly'] as bool?) ?? false,
      isSystemAdmin: (json['is_system_admin'] as bool?) ?? false,
      grantedPermissionCodes:
          (json['granted_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
    );
  }
}

class RolePermissionMatrixResult {
  const RolePermissionMatrixResult({
    required this.moduleCode,
    required this.moduleCodes,
    required this.permissions,
    required this.roleItems,
  });

  final String moduleCode;
  final List<String> moduleCodes;
  final List<PermissionCatalogItem> permissions;
  final List<RolePermissionMatrixItem> roleItems;

  factory RolePermissionMatrixResult.fromJson(Map<String, dynamic> json) {
    return RolePermissionMatrixResult(
      moduleCode: json['module_code'] as String,
      moduleCodes: (json['module_codes'] as List<dynamic>? ?? const [])
          .cast<String>(),
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                PermissionCatalogItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      roleItems: (json['role_items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => RolePermissionMatrixItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class RolePermissionMatrixRoleResult {
  const RolePermissionMatrixRoleResult({
    required this.roleCode,
    required this.roleName,
    required this.readonly,
    required this.isSystemAdmin,
    required this.ignoredInput,
    required this.beforePermissionCodes,
    required this.afterPermissionCodes,
    required this.addedPermissionCodes,
    required this.removedPermissionCodes,
    required this.autoGrantedPermissionCodes,
    required this.autoRevokedPermissionCodes,
    required this.updatedCount,
  });

  final String roleCode;
  final String roleName;
  final bool readonly;
  final bool isSystemAdmin;
  final bool ignoredInput;
  final List<String> beforePermissionCodes;
  final List<String> afterPermissionCodes;
  final List<String> addedPermissionCodes;
  final List<String> removedPermissionCodes;
  final List<String> autoGrantedPermissionCodes;
  final List<String> autoRevokedPermissionCodes;
  final int updatedCount;

  factory RolePermissionMatrixRoleResult.fromJson(Map<String, dynamic> json) {
    return RolePermissionMatrixRoleResult(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      readonly: (json['readonly'] as bool?) ?? false,
      isSystemAdmin: (json['is_system_admin'] as bool?) ?? false,
      ignoredInput: (json['ignored_input'] as bool?) ?? false,
      beforePermissionCodes:
          (json['before_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      afterPermissionCodes:
          (json['after_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      addedPermissionCodes:
          (json['added_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      removedPermissionCodes:
          (json['removed_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      autoGrantedPermissionCodes:
          (json['auto_granted_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      autoRevokedPermissionCodes:
          (json['auto_revoked_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      updatedCount: (json['updated_count'] as int?) ?? 0,
    );
  }
}

class RolePermissionMatrixUpdateResult {
  const RolePermissionMatrixUpdateResult({
    required this.moduleCode,
    required this.dryRun,
    required this.roleResults,
  });

  final String moduleCode;
  final bool dryRun;
  final List<RolePermissionMatrixRoleResult> roleResults;

  factory RolePermissionMatrixUpdateResult.fromJson(Map<String, dynamic> json) {
    return RolePermissionMatrixUpdateResult(
      moduleCode: json['module_code'] as String,
      dryRun: (json['dry_run'] as bool?) ?? false,
      roleResults: (json['role_results'] as List<dynamic>? ?? const [])
          .map(
            (entry) => RolePermissionMatrixRoleResult.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
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
  static const String ordersPipelineView =
      'production.orders.pipeline_mode.view';

  static const String myOrdersProxy = 'production.my_orders.proxy';
  static const String executionFirstArticle =
      'production.execution.first_article';
  static const String executionEndProduction =
      'production.execution.end_production';
  static const String assistCreate = 'production.assist_authorizations.create';
  static const String assistList = 'production.assist_authorizations.list';

  static const String dataManualExport = 'production.data.manual.export';
  static const String scrapExport = 'production.scrap_statistics.export';
  static const String repairComplete = 'production.repair_orders.complete';
  static const String repairExport = 'production.repair_orders.export';
  static const String repairCreateManual =
      'production.repair_orders.create_manual';
}
