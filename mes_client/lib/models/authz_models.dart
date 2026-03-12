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

class AuthzSnapshotModuleItem {
  const AuthzSnapshotModuleItem({
    required this.moduleCode,
    required this.moduleName,
    required this.moduleRevision,
    required this.moduleEnabled,
    required this.effectivePermissionCodes,
    required this.effectivePagePermissionCodes,
    required this.effectiveCapabilityCodes,
    required this.effectiveActionPermissionCodes,
  });

  final String moduleCode;
  final String moduleName;
  final int moduleRevision;
  final bool moduleEnabled;
  final List<String> effectivePermissionCodes;
  final List<String> effectivePagePermissionCodes;
  final List<String> effectiveCapabilityCodes;
  final List<String> effectiveActionPermissionCodes;

  factory AuthzSnapshotModuleItem.fromJson(Map<String, dynamic> json) {
    return AuthzSnapshotModuleItem(
      moduleCode: json['module_code'] as String,
      moduleName: json['module_name'] as String,
      moduleRevision: (json['module_revision'] as int?) ?? 0,
      moduleEnabled: (json['module_enabled'] as bool?) ?? false,
      effectivePermissionCodes:
          (json['effective_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      effectivePagePermissionCodes:
          (json['effective_page_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      effectiveCapabilityCodes:
          (json['effective_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      effectiveActionPermissionCodes:
          (json['effective_action_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
    );
  }
}

class AuthzSnapshotResult {
  const AuthzSnapshotResult({
    required this.revision,
    required this.roleCodes,
    required this.visibleSidebarCodes,
    required this.tabCodesByParent,
    required this.moduleItems,
  });

  final int revision;
  final List<String> roleCodes;
  final List<String> visibleSidebarCodes;
  final Map<String, List<String>> tabCodesByParent;
  final List<AuthzSnapshotModuleItem> moduleItems;

  Map<String, AuthzSnapshotModuleItem> get moduleByCode {
    return {for (final item in moduleItems) item.moduleCode: item};
  }

  Set<String> capabilityCodesForModule(String moduleCode) {
    return moduleByCode[moduleCode]?.effectiveCapabilityCodes.toSet() ??
        const <String>{};
  }

  Set<String> permissionCodesForModule(String moduleCode) {
    return moduleByCode[moduleCode]?.effectivePermissionCodes.toSet() ??
        const <String>{};
  }

  int moduleRevisionFor(String moduleCode) {
    return moduleByCode[moduleCode]?.moduleRevision ?? 0;
  }

  factory AuthzSnapshotResult.fromJson(Map<String, dynamic> json) {
    final rawTabs =
        json['tab_codes_by_parent'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return AuthzSnapshotResult(
      revision: (json['revision'] as int?) ?? 0,
      roleCodes: (json['role_codes'] as List<dynamic>? ?? const [])
          .cast<String>(),
      visibleSidebarCodes:
          (json['visible_sidebar_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      tabCodesByParent: rawTabs.map(
        (key, value) =>
            MapEntry(key, (value as List<dynamic>? ?? const []).cast<String>()),
      ),
      moduleItems: (json['module_items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                AuthzSnapshotModuleItem.fromJson(entry as Map<String, dynamic>),
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

class PermissionHierarchyPageItem {
  const PermissionHierarchyPageItem({
    required this.pageCode,
    required this.pageName,
    required this.permissionCode,
    required this.parentPageCode,
  });

  final String pageCode;
  final String pageName;
  final String permissionCode;
  final String? parentPageCode;

  factory PermissionHierarchyPageItem.fromJson(Map<String, dynamic> json) {
    return PermissionHierarchyPageItem(
      pageCode: json['page_code'] as String,
      pageName: json['page_name'] as String,
      permissionCode: json['permission_code'] as String,
      parentPageCode: json['parent_page_code'] as String?,
    );
  }
}

class PermissionHierarchyFeatureItem {
  const PermissionHierarchyFeatureItem({
    required this.featureCode,
    required this.featureName,
    required this.permissionCode,
    required this.pagePermissionCode,
    required this.linkedActionPermissionCodes,
    required this.dependencyPermissionCodes,
  });

  final String featureCode;
  final String featureName;
  final String permissionCode;
  final String? pagePermissionCode;
  final List<String> linkedActionPermissionCodes;
  final List<String> dependencyPermissionCodes;

  factory PermissionHierarchyFeatureItem.fromJson(Map<String, dynamic> json) {
    return PermissionHierarchyFeatureItem(
      featureCode: json['feature_code'] as String,
      featureName: json['feature_name'] as String,
      permissionCode: json['permission_code'] as String,
      pagePermissionCode: json['page_permission_code'] as String?,
      linkedActionPermissionCodes:
          (json['linked_action_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      dependencyPermissionCodes:
          (json['dependency_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
    );
  }
}

class PermissionHierarchyCatalogResult {
  const PermissionHierarchyCatalogResult({
    required this.moduleCode,
    required this.moduleCodes,
    required this.modulePermissionCode,
    required this.moduleName,
    required this.pages,
    required this.features,
  });

  final String moduleCode;
  final List<String> moduleCodes;
  final String modulePermissionCode;
  final String moduleName;
  final List<PermissionHierarchyPageItem> pages;
  final List<PermissionHierarchyFeatureItem> features;

  factory PermissionHierarchyCatalogResult.fromJson(Map<String, dynamic> json) {
    return PermissionHierarchyCatalogResult(
      moduleCode: json['module_code'] as String,
      moduleCodes: (json['module_codes'] as List<dynamic>? ?? const [])
          .cast<String>(),
      modulePermissionCode: json['module_permission_code'] as String,
      moduleName: json['module_name'] as String,
      pages: (json['pages'] as List<dynamic>? ?? const [])
          .map(
            (entry) => PermissionHierarchyPageItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      features: (json['features'] as List<dynamic>? ?? const [])
          .map(
            (entry) => PermissionHierarchyFeatureItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class PermissionHierarchyRoleConfigResult {
  const PermissionHierarchyRoleConfigResult({
    required this.roleCode,
    required this.roleName,
    required this.readonly,
    required this.moduleCode,
    required this.moduleEnabled,
    required this.grantedPagePermissionCodes,
    required this.grantedFeaturePermissionCodes,
    required this.effectivePagePermissionCodes,
    required this.effectiveFeaturePermissionCodes,
  });

  final String roleCode;
  final String roleName;
  final bool readonly;
  final String moduleCode;
  final bool moduleEnabled;
  final List<String> grantedPagePermissionCodes;
  final List<String> grantedFeaturePermissionCodes;
  final List<String> effectivePagePermissionCodes;
  final List<String> effectiveFeaturePermissionCodes;

  factory PermissionHierarchyRoleConfigResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return PermissionHierarchyRoleConfigResult(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      readonly: (json['readonly'] as bool?) ?? false,
      moduleCode: json['module_code'] as String,
      moduleEnabled: (json['module_enabled'] as bool?) ?? false,
      grantedPagePermissionCodes:
          (json['granted_page_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      grantedFeaturePermissionCodes:
          (json['granted_feature_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      effectivePagePermissionCodes:
          (json['effective_page_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      effectiveFeaturePermissionCodes:
          (json['effective_feature_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
    );
  }
}

class PermissionHierarchyRoleDraftItem {
  const PermissionHierarchyRoleDraftItem({
    required this.roleCode,
    required this.moduleEnabled,
    required this.pagePermissionCodes,
    required this.featurePermissionCodes,
  });

  final String roleCode;
  final bool moduleEnabled;
  final List<String> pagePermissionCodes;
  final List<String> featurePermissionCodes;

  Map<String, dynamic> toJson() {
    return {
      'role_code': roleCode,
      'module_enabled': moduleEnabled,
      'page_permission_codes': pagePermissionCodes,
      'feature_permission_codes': featurePermissionCodes,
    };
  }
}

class PermissionHierarchyRoleUpdateResult {
  const PermissionHierarchyRoleUpdateResult({
    required this.roleCode,
    required this.roleName,
    required this.readonly,
    required this.ignoredInput,
    required this.moduleCode,
    required this.beforePermissionCodes,
    required this.afterPermissionCodes,
    required this.addedPermissionCodes,
    required this.removedPermissionCodes,
    required this.autoLinkedDependencies,
    required this.effectivePagePermissionCodes,
    required this.effectiveFeaturePermissionCodes,
    required this.updatedCount,
    required this.dryRun,
  });

  final String roleCode;
  final String roleName;
  final bool readonly;
  final bool ignoredInput;
  final String moduleCode;
  final List<String> beforePermissionCodes;
  final List<String> afterPermissionCodes;
  final List<String> addedPermissionCodes;
  final List<String> removedPermissionCodes;
  final List<String> autoLinkedDependencies;
  final List<String> effectivePagePermissionCodes;
  final List<String> effectiveFeaturePermissionCodes;
  final int updatedCount;
  final bool dryRun;

  factory PermissionHierarchyRoleUpdateResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return PermissionHierarchyRoleUpdateResult(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      readonly: (json['readonly'] as bool?) ?? false,
      ignoredInput: (json['ignored_input'] as bool?) ?? false,
      moduleCode: json['module_code'] as String,
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
      autoLinkedDependencies:
          (json['auto_linked_dependencies'] as List<dynamic>? ?? const [])
              .cast<String>(),
      effectivePagePermissionCodes:
          (json['effective_page_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      effectiveFeaturePermissionCodes:
          (json['effective_feature_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      updatedCount: (json['updated_count'] as int?) ?? 0,
      dryRun: (json['dry_run'] as bool?) ?? false,
    );
  }
}

class PermissionHierarchyPreviewResult {
  const PermissionHierarchyPreviewResult({
    required this.moduleCode,
    required this.roleResults,
  });

  final String moduleCode;
  final List<PermissionHierarchyRoleUpdateResult> roleResults;

  factory PermissionHierarchyPreviewResult.fromJson(Map<String, dynamic> json) {
    return PermissionHierarchyPreviewResult(
      moduleCode: json['module_code'] as String,
      roleResults: (json['role_results'] as List<dynamic>? ?? const [])
          .map(
            (entry) => PermissionHierarchyRoleUpdateResult.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CapabilityPackItem {
  const CapabilityPackItem({
    required this.capabilityCode,
    required this.capabilityName,
    required this.groupCode,
    required this.groupName,
    required this.pageCode,
    required this.pageName,
    required this.description,
    required this.dependencyCapabilityCodes,
    required this.linkedActionPermissionCodes,
  });

  final String capabilityCode;
  final String capabilityName;
  final String groupCode;
  final String groupName;
  final String pageCode;
  final String pageName;
  final String? description;
  final List<String> dependencyCapabilityCodes;
  final List<String> linkedActionPermissionCodes;

  factory CapabilityPackItem.fromJson(Map<String, dynamic> json) {
    return CapabilityPackItem(
      capabilityCode: json['capability_code'] as String,
      capabilityName: json['capability_name'] as String,
      groupCode: json['group_code'] as String,
      groupName: json['group_name'] as String,
      pageCode: json['page_code'] as String,
      pageName: json['page_name'] as String,
      description: json['description'] as String?,
      dependencyCapabilityCodes:
          (json['dependency_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      linkedActionPermissionCodes:
          (json['linked_action_permission_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
    );
  }
}

class CapabilityPackRoleTemplateItem {
  const CapabilityPackRoleTemplateItem({
    required this.roleCode,
    required this.roleName,
    required this.capabilityCodes,
    required this.description,
  });

  final String roleCode;
  final String roleName;
  final List<String> capabilityCodes;
  final String? description;

  factory CapabilityPackRoleTemplateItem.fromJson(Map<String, dynamic> json) {
    return CapabilityPackRoleTemplateItem(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      capabilityCodes: (json['capability_codes'] as List<dynamic>? ?? const [])
          .cast<String>(),
      description: json['description'] as String?,
    );
  }
}

class CapabilityPackCatalogResult {
  const CapabilityPackCatalogResult({
    required this.moduleCode,
    required this.moduleCodes,
    required this.moduleName,
    required this.moduleRevision,
    required this.modulePermissionCode,
    required this.capabilityPacks,
    required this.roleTemplates,
  });

  final String moduleCode;
  final List<String> moduleCodes;
  final String moduleName;
  final int moduleRevision;
  final String modulePermissionCode;
  final List<CapabilityPackItem> capabilityPacks;
  final List<CapabilityPackRoleTemplateItem> roleTemplates;

  factory CapabilityPackCatalogResult.fromJson(Map<String, dynamic> json) {
    return CapabilityPackCatalogResult(
      moduleCode: json['module_code'] as String,
      moduleCodes: (json['module_codes'] as List<dynamic>? ?? const [])
          .cast<String>(),
      moduleName: json['module_name'] as String,
      moduleRevision: (json['module_revision'] as int?) ?? 0,
      modulePermissionCode: json['module_permission_code'] as String,
      capabilityPacks: (json['capability_packs'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                CapabilityPackItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      roleTemplates: (json['role_templates'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CapabilityPackRoleTemplateItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CapabilityPackRoleConfigResult {
  const CapabilityPackRoleConfigResult({
    required this.roleCode,
    required this.roleName,
    required this.readonly,
    required this.moduleCode,
    required this.moduleEnabled,
    required this.grantedCapabilityCodes,
    required this.effectiveCapabilityCodes,
    required this.effectivePagePermissionCodes,
    required this.autoLinkedDependencies,
  });

  final String roleCode;
  final String roleName;
  final bool readonly;
  final String moduleCode;
  final bool moduleEnabled;
  final List<String> grantedCapabilityCodes;
  final List<String> effectiveCapabilityCodes;
  final List<String> effectivePagePermissionCodes;
  final List<String> autoLinkedDependencies;

  factory CapabilityPackRoleConfigResult.fromJson(Map<String, dynamic> json) {
    return CapabilityPackRoleConfigResult(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      readonly: (json['readonly'] as bool?) ?? false,
      moduleCode: json['module_code'] as String,
      moduleEnabled: (json['module_enabled'] as bool?) ?? false,
      grantedCapabilityCodes:
          (json['granted_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      effectiveCapabilityCodes:
          (json['effective_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      effectivePagePermissionCodes:
          (json['effective_page_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      autoLinkedDependencies:
          (json['auto_linked_dependencies'] as List<dynamic>? ?? const [])
              .cast<String>(),
    );
  }
}

class CapabilityPackRoleDraftItem {
  const CapabilityPackRoleDraftItem({
    required this.roleCode,
    required this.moduleEnabled,
    required this.capabilityCodes,
  });

  final String roleCode;
  final bool moduleEnabled;
  final List<String> capabilityCodes;

  Map<String, dynamic> toJson() {
    return {
      'role_code': roleCode,
      'module_enabled': moduleEnabled,
      'capability_codes': capabilityCodes,
    };
  }
}

class CapabilityPackRoleUpdateResult {
  const CapabilityPackRoleUpdateResult({
    required this.roleCode,
    required this.roleName,
    required this.readonly,
    required this.ignoredInput,
    required this.moduleCode,
    required this.beforeCapabilityCodes,
    required this.afterCapabilityCodes,
    required this.addedCapabilityCodes,
    required this.removedCapabilityCodes,
    required this.autoLinkedDependencies,
    required this.effectiveCapabilityCodes,
    required this.effectivePagePermissionCodes,
    required this.updatedCount,
    required this.dryRun,
  });

  final String roleCode;
  final String roleName;
  final bool readonly;
  final bool ignoredInput;
  final String moduleCode;
  final List<String> beforeCapabilityCodes;
  final List<String> afterCapabilityCodes;
  final List<String> addedCapabilityCodes;
  final List<String> removedCapabilityCodes;
  final List<String> autoLinkedDependencies;
  final List<String> effectiveCapabilityCodes;
  final List<String> effectivePagePermissionCodes;
  final int updatedCount;
  final bool dryRun;

  factory CapabilityPackRoleUpdateResult.fromJson(Map<String, dynamic> json) {
    return CapabilityPackRoleUpdateResult(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      readonly: (json['readonly'] as bool?) ?? false,
      ignoredInput: (json['ignored_input'] as bool?) ?? false,
      moduleCode: json['module_code'] as String,
      beforeCapabilityCodes:
          (json['before_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      afterCapabilityCodes:
          (json['after_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      addedCapabilityCodes:
          (json['added_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      removedCapabilityCodes:
          (json['removed_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      autoLinkedDependencies:
          (json['auto_linked_dependencies'] as List<dynamic>? ?? const [])
              .cast<String>(),
      effectiveCapabilityCodes:
          (json['effective_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      effectivePagePermissionCodes:
          (json['effective_page_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      updatedCount: (json['updated_count'] as int?) ?? 0,
      dryRun: (json['dry_run'] as bool?) ?? false,
    );
  }
}

class CapabilityPackPreviewResult {
  const CapabilityPackPreviewResult({
    required this.moduleCode,
    required this.moduleRevision,
    required this.roleResults,
  });

  final String moduleCode;
  final int moduleRevision;
  final List<CapabilityPackRoleUpdateResult> roleResults;

  factory CapabilityPackPreviewResult.fromJson(Map<String, dynamic> json) {
    return CapabilityPackPreviewResult(
      moduleCode: json['module_code'] as String,
      moduleRevision: (json['module_revision'] as int?) ?? 0,
      roleResults: (json['role_results'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CapabilityPackRoleUpdateResult.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CapabilityPackChangeLogItem {
  const CapabilityPackChangeLogItem({
    required this.changeLogId,
    required this.moduleCode,
    required this.moduleRevision,
    required this.changeType,
    required this.remark,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.rollbackOfChangeLogId,
    required this.rollbackOfRevision,
    required this.changedRoleCount,
    required this.addedCapabilityCount,
    required this.removedCapabilityCount,
    required this.autoLinkedDependencyCount,
    required this.isCurrentRevision,
    required this.isNoop,
    required this.canRollback,
    required this.createdAt,
    required this.roleResults,
  });

  final int changeLogId;
  final String moduleCode;
  final int moduleRevision;
  final String changeType;
  final String? remark;
  final int? operatorUserId;
  final String? operatorUsername;
  final int? rollbackOfChangeLogId;
  final int? rollbackOfRevision;
  final int changedRoleCount;
  final int addedCapabilityCount;
  final int removedCapabilityCount;
  final int autoLinkedDependencyCount;
  final bool isCurrentRevision;
  final bool isNoop;
  final bool canRollback;
  final DateTime createdAt;
  final List<CapabilityPackRoleUpdateResult> roleResults;

  factory CapabilityPackChangeLogItem.fromJson(Map<String, dynamic> json) {
    return CapabilityPackChangeLogItem(
      changeLogId: (json['change_log_id'] as int?) ?? 0,
      moduleCode: json['module_code'] as String,
      moduleRevision: (json['module_revision'] as int?) ?? 0,
      changeType: json['change_type'] as String,
      remark: json['remark'] as String?,
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: json['operator_username'] as String?,
      rollbackOfChangeLogId: json['rollback_of_change_log_id'] as int?,
      rollbackOfRevision: json['rollback_of_revision'] as int?,
      changedRoleCount: (json['changed_role_count'] as int?) ?? 0,
      addedCapabilityCount: (json['added_capability_count'] as int?) ?? 0,
      removedCapabilityCount: (json['removed_capability_count'] as int?) ?? 0,
      autoLinkedDependencyCount:
          (json['auto_linked_dependency_count'] as int?) ?? 0,
      isCurrentRevision: (json['is_current_revision'] as bool?) ?? false,
      isNoop: (json['is_noop'] as bool?) ?? false,
      canRollback: (json['can_rollback'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      roleResults: (json['role_results'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CapabilityPackRoleUpdateResult.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CapabilityPackChangeLogListResult {
  const CapabilityPackChangeLogListResult({
    required this.moduleCode,
    required this.moduleRevision,
    required this.items,
  });

  final String moduleCode;
  final int moduleRevision;
  final List<CapabilityPackChangeLogItem> items;

  factory CapabilityPackChangeLogListResult.fromJson(Map<String, dynamic> json) {
    return CapabilityPackChangeLogListResult(
      moduleCode: json['module_code'] as String,
      moduleRevision: (json['module_revision'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CapabilityPackChangeLogItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class PermissionExplainCapabilityItem {
  const PermissionExplainCapabilityItem({
    required this.capabilityCode,
    required this.capabilityName,
    required this.available,
    required this.reasonCodes,
    required this.reasonMessages,
  });

  final String capabilityCode;
  final String capabilityName;
  final bool available;
  final List<String> reasonCodes;
  final List<String> reasonMessages;

  factory PermissionExplainCapabilityItem.fromJson(Map<String, dynamic> json) {
    return PermissionExplainCapabilityItem(
      capabilityCode: json['capability_code'] as String,
      capabilityName: json['capability_name'] as String,
      available: (json['available'] as bool?) ?? false,
      reasonCodes: (json['reason_codes'] as List<dynamic>? ?? const [])
          .cast<String>(),
      reasonMessages: (json['reason_messages'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }
}

class PermissionExplainResult {
  const PermissionExplainResult({
    required this.roleCode,
    required this.roleName,
    required this.moduleCode,
    required this.moduleEnabled,
    required this.effectivePagePermissionCodes,
    required this.effectiveCapabilityCodes,
    required this.capabilityItems,
  });

  final String roleCode;
  final String roleName;
  final String moduleCode;
  final bool moduleEnabled;
  final List<String> effectivePagePermissionCodes;
  final List<String> effectiveCapabilityCodes;
  final List<PermissionExplainCapabilityItem> capabilityItems;

  factory PermissionExplainResult.fromJson(Map<String, dynamic> json) {
    return PermissionExplainResult(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      moduleCode: json['module_code'] as String,
      moduleEnabled: (json['module_enabled'] as bool?) ?? false,
      effectivePagePermissionCodes:
          (json['effective_page_permission_codes'] as List<dynamic>? ??
                  const [])
              .cast<String>(),
      effectiveCapabilityCodes:
          (json['effective_capability_codes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      capabilityItems: (json['capability_items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => PermissionExplainCapabilityItem.fromJson(
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

class SystemPermissionCodes {
  static const String pageFunctionPermissionConfigView =
      'page.function_permission_config.view';
  static const String rolePermissionsView = 'authz.role_permissions.view';
  static const String rolePermissionsUpdate = 'authz.role_permissions.update';
}

class UserPermissionCodes {
  static const String pageUserView = 'page.user.view';
  static const String pageUserManagementView = 'page.user_management.view';
  static const String pageRegistrationApprovalView =
      'page.registration_approval.view';
  static const String pageRoleManagementView = 'page.role_management.view';
  static const String pageAuditLogView = 'page.audit_log.view';
  static const String pageAccountSettingsView = 'page.account_settings.view';
  static const String pageLoginSessionView = 'page.login_session.view';

  static const String usersList = 'user.users.list';
  static const String usersCreate = 'user.users.create';
  static const String usersDetail = 'user.users.detail';
  static const String usersUpdate = 'user.users.update';
  static const String usersDelete = 'user.users.delete';
  static const String usersEnable = 'user.users.enable';
  static const String usersDisable = 'user.users.disable';
  static const String usersResetPassword = 'user.users.reset_password';
  static const String usersExport = 'user.users.export';

  static const String rolesList = 'user.roles.list';
  static const String rolesDetail = 'user.roles.detail';
  static const String rolesCreate = 'user.roles.create';
  static const String rolesUpdate = 'user.roles.update';
  static const String rolesEnable = 'user.roles.enable';
  static const String rolesDisable = 'user.roles.disable';
  static const String rolesDelete = 'user.roles.delete';
  static const String processesList = 'user.processes.list';

  static const String registrationRequestsList =
      'user.registration_requests.list';
  static const String registrationRequestsApprove =
      'user.registration_requests.approve';
  static const String registrationRequestsReject =
      'user.registration_requests.reject';

  static const String auditLogsList = 'user.audit_logs.list';
  static const String profileView = 'user.profile.view';
  static const String profilePasswordUpdate = 'user.profile.password.update';
  static const String sessionsOverview = 'user.sessions.overview';
  static const String sessionsLoginLogsList = 'user.sessions.login_logs.list';
  static const String sessionsOnlineList = 'user.sessions.online.list';
  static const String sessionsForceOffline = 'user.sessions.force_offline';
  static const String sessionsForceOfflineBatch =
      'user.sessions.force_offline.batch';
}

class ProductPermissionCodes {
  static const String pageProductView = 'page.product.view';
  static const String pageProductManagementView =
      'page.product_management.view';
  static const String pageProductParameterManagementView =
      'page.product_parameter_management.view';
  static const String pageProductParameterQueryView =
      'page.product_parameter_query.view';

  static const String productsList = 'product.products.list';
  static const String productsCreate = 'product.products.create';
  static const String productsDelete = 'product.products.delete';
  static const String lifecycleUpdate = 'product.lifecycle.update';
  static const String versionsList = 'product.versions.list';
  static const String versionsCompare = 'product.versions.compare';
  static const String rollback = 'product.rollback';
  static const String impactAnalysis = 'product.impact.analysis';
  static const String parametersView = 'product.parameters.view';
  static const String parametersUpdate = 'product.parameters.update';
  static const String parameterHistoryList = 'product.parameter_history.list';
}

class EquipmentPermissionCodes {
  static const String pageEquipmentView = 'page.equipment.view';
  static const String pageEquipmentLedgerView = 'page.equipment_ledger.view';
  static const String pageMaintenanceItemView = 'page.maintenance_item.view';
  static const String pageMaintenancePlanView = 'page.maintenance_plan.view';
  static const String pageMaintenanceExecutionView =
      'page.maintenance_execution.view';
  static const String pageMaintenanceRecordView =
      'page.maintenance_record.view';

  static const String adminOwnersList = 'equipment.admin_owners.list';
  static const String ledgerList = 'equipment.ledger.list';
  static const String ledgerCreate = 'equipment.ledger.create';
  static const String ledgerUpdate = 'equipment.ledger.update';
  static const String ledgerToggle = 'equipment.ledger.toggle';
  static const String ledgerDelete = 'equipment.ledger.delete';

  static const String itemsList = 'equipment.items.list';
  static const String itemsCreate = 'equipment.items.create';
  static const String itemsUpdate = 'equipment.items.update';
  static const String itemsToggle = 'equipment.items.toggle';
  static const String itemsDelete = 'equipment.items.delete';

  static const String plansList = 'equipment.plans.list';
  static const String plansCreate = 'equipment.plans.create';
  static const String plansUpdate = 'equipment.plans.update';
  static const String plansToggle = 'equipment.plans.toggle';
  static const String plansDelete = 'equipment.plans.delete';
  static const String plansGenerate = 'equipment.plans.generate';

  static const String executionsList = 'equipment.executions.list';
  static const String executionsStart = 'equipment.executions.start';
  static const String executionsComplete = 'equipment.executions.complete';
  static const String recordsList = 'equipment.records.list';
}

class CraftPermissionCodes {
  static const String pageCraftView = 'page.craft.view';
  static const String pageProcessManagementView =
      'page.process_management.view';
  static const String pageProductionProcessConfigView =
      'page.production_process_config.view';
  static const String pageCraftKanbanView = 'page.craft_kanban.view';

  static const String stagesList = 'craft.stages.list';
  static const String stagesCreate = 'craft.stages.create';
  static const String stagesUpdate = 'craft.stages.update';
  static const String stagesDelete = 'craft.stages.delete';

  static const String processesList = 'craft.processes.list';
  static const String processesCreate = 'craft.processes.create';
  static const String processesUpdate = 'craft.processes.update';
  static const String processesDelete = 'craft.processes.delete';

  static const String systemMasterTemplateView =
      'craft.system_master_template.view';
  static const String systemMasterTemplateCreate =
      'craft.system_master_template.create';
  static const String systemMasterTemplateUpdate =
      'craft.system_master_template.update';
  static const String kanbanProcessMetricsView =
      'craft.kanban.process_metrics.view';

  static const String templatesList = 'craft.templates.list';
  static const String templatesCreate = 'craft.templates.create';
  static const String templatesExport = 'craft.templates.export';
  static const String templatesImport = 'craft.templates.import';
  static const String templatesDetail = 'craft.templates.detail';
  static const String templatesImpactAnalysis =
      'craft.templates.impact.analysis';
  static const String templatesPublish = 'craft.templates.publish';
  static const String templatesVersionsList = 'craft.templates.versions.list';
  static const String templatesVersionsCompare =
      'craft.templates.versions.compare';
  static const String templatesRollback = 'craft.templates.rollback';
  static const String templatesUpdate = 'craft.templates.update';
  static const String templatesDelete = 'craft.templates.delete';
}

class QualityPermissionCodes {
  static const String pageQualityView = 'page.quality.view';
  static const String pageFirstArticleManagementView =
      'page.first_article_management.view';
  static const String pageQualityDataQueryView = 'page.quality_data_query.view';

  static const String firstArticlesList = 'quality.first_articles.list';
  static const String statsOverview = 'quality.stats.overview';
  static const String statsProcesses = 'quality.stats.processes';
  static const String statsOperators = 'quality.stats.operators';
}

class UserFeaturePermissionCodes {
  static const String userManagementView = 'feature.user.user_management.view';
  static const String userManagementManage =
      'feature.user.user_management.manage';
  static const String registrationApprovalReview =
      'feature.user.registration_approval.review';
  static const String roleManagementView = 'feature.user.role_management.view';
  static const String roleManagementManage =
      'feature.user.role_management.manage';
  static const String auditLogView = 'feature.user.audit_log.view';
  static const String accountSettingsView =
      'feature.user.account_settings.view';
  static const String accountSettingsManage =
      'feature.user.account_settings.manage';
  static const String loginSessionView = 'feature.user.login_session.view';
  static const String loginSessionManage =
      'feature.user.login_session.manage';
}

class ProductFeaturePermissionCodes {
  static const String catalogRead = 'feature.product.catalog.read';
  static const String productManagementManage =
      'feature.product.product_management.manage';
  static const String versionAnalysisView =
      'feature.product.version_analysis.view';
  static const String parametersView = 'feature.product.parameters.view';
  static const String parametersEdit = 'feature.product.parameters.edit';
}

class EquipmentFeaturePermissionCodes {
  static const String ledgerManage = 'feature.equipment.ledger.manage';
  static const String itemsManage = 'feature.equipment.items.manage';
  static const String plansManage = 'feature.equipment.plans.manage';
  static const String executionsOperate =
      'feature.equipment.executions.operate';
  static const String recordsView = 'feature.equipment.records.view';
}

class CraftFeaturePermissionCodes {
  static const String processBasicsView = 'feature.craft.process_basics.view';
  static const String processBasicsManage =
      'feature.craft.process_basics.manage';
  static const String processTemplatesView =
      'feature.craft.process_templates.view';
  static const String processTemplatesManage =
      'feature.craft.process_templates.manage';
  static const String kanbanView = 'feature.craft.kanban.view';
}

class QualityFeaturePermissionCodes {
  static const String firstArticlesView = 'feature.quality.first_articles.view';
  static const String statsView = 'feature.quality.stats.view';
}

class ProductionFeaturePermissionCodes {
  static const String orderManagementManage =
      'feature.production.order_management.manage';
  static const String pipelineModeManage =
      'feature.production.pipeline_mode.manage';
  static const String orderQueryExecute =
      'feature.production.order_query.execute';
  static const String orderQueryProxy = 'feature.production.order_query.proxy';
  static const String assistLaunch = 'feature.production.assist.launch';
  static const String assistRecordsView =
      'feature.production.assist.records.view';
  static const String dataQueryView = 'feature.production.data_query.view';
  static const String dataExportUse = 'feature.production.data_export.use';
  static const String scrapStatisticsView =
      'feature.production.scrap_statistics.view';
  static const String scrapExportUse = 'feature.production.scrap_export.use';
  static const String repairOrdersManage =
      'feature.production.repair_orders.manage';
  static const String repairOrdersExport =
      'feature.production.repair_orders.export';
  static const String repairOrdersCreateManual =
      'feature.production.repair_orders.create_manual';
}
