class ProductItem {
  ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.remark,
    required this.lifecycleStatus,
    required this.currentVersion,
    required this.effectiveVersion,
    required this.effectiveAt,
    required this.inactiveReason,
    required this.lastParameterSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String category;
  final String remark;
  final String lifecycleStatus;
  final int currentVersion;
  final int effectiveVersion;
  final DateTime? effectiveAt;
  final String? inactiveReason;
  final String? lastParameterSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'] as int,
      name: json['name'] as String,
      category: (json['category'] as String?) ?? '',
      remark: (json['remark'] as String?) ?? '',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'active',
      currentVersion: (json['current_version'] as int?) ?? 1,
      effectiveVersion: (json['effective_version'] as int?) ?? 0,
      effectiveAt: (json['effective_at'] as String?) == null
          ? null
          : DateTime.parse(json['effective_at'] as String),
      inactiveReason: json['inactive_reason'] as String?,
      lastParameterSummary: json['last_parameter_summary'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductListResult {
  ProductListResult({required this.total, required this.items});

  final int total;
  final List<ProductItem> items;
}

class ProductParameterItem {
  ProductParameterItem({
    required this.name,
    required this.category,
    required this.type,
    required this.value,
    required this.description,
    required this.sortOrder,
    required this.isPreset,
  });

  final String name;
  final String category;
  final String type;
  final String value;
  final String description;
  final int sortOrder;
  final bool isPreset;

  factory ProductParameterItem.fromJson(Map<String, dynamic> json) {
    return ProductParameterItem(
      name: json['name'] as String,
      category: (json['category'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'Text',
      value: (json['value'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isPreset: (json['is_preset'] as bool?) ?? false,
    );
  }
}

class ProductParameterUpdateItem {
  ProductParameterUpdateItem({
    required this.name,
    required this.category,
    required this.type,
    required this.value,
    this.description = '',
  });

  final String name;
  final String category;
  final String type;
  final String value;
  final String description;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'type': type,
      'value': value,
      'description': description,
    };
  }
}

class ProductParameterListResult {
  ProductParameterListResult({
    required this.productId,
    required this.productName,
    required this.parameterScope,
    required this.version,
    required this.versionLabel,
    required this.lifecycleStatus,
    required this.total,
    required this.items,
  });

  final int productId;
  final String productName;
  final String parameterScope;
  final int version;
  final String versionLabel;
  final String lifecycleStatus;
  final int total;
  final List<ProductParameterItem> items;

  factory ProductParameterListResult.fromJson(Map<String, dynamic> json) {
    return ProductParameterListResult(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      parameterScope: (json['parameter_scope'] as String?) ?? 'version',
      version: (json['version'] as int?) ?? 0,
      versionLabel: (json['version_label'] as String?) ?? 'V1.0',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'draft',
      total: (json['total'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductParameterItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProductParameterVersionListItem {
  ProductParameterVersionListItem({
    required this.productId,
    required this.productName,
    required this.productCategory,
    required this.version,
    required this.versionLabel,
    required this.lifecycleStatus,
    required this.isCurrentVersion,
    required this.isEffectiveVersion,
    required this.createdAt,
    required this.parameterSummary,
    required this.lastModifiedParameter,
    required this.updatedAt,
  });

  final int productId;
  final String productName;
  final String productCategory;
  final int version;
  final String versionLabel;
  final String lifecycleStatus;
  final bool isCurrentVersion;
  final bool isEffectiveVersion;
  final DateTime createdAt;
  final String? parameterSummary;
  final String? lastModifiedParameter;
  final DateTime updatedAt;

  factory ProductParameterVersionListItem.fromJson(Map<String, dynamic> json) {
    return ProductParameterVersionListItem(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      productCategory: (json['product_category'] as String?) ?? '',
      version: (json['version'] as int?) ?? 0,
      versionLabel: (json['version_label'] as String?) ?? 'V1.0',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'draft',
      isCurrentVersion: (json['is_current_version'] as bool?) ?? false,
      isEffectiveVersion: (json['is_effective_version'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      parameterSummary: json['parameter_summary'] as String?,
      lastModifiedParameter: json['last_modified_parameter'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductParameterVersionListResult {
  ProductParameterVersionListResult({required this.total, required this.items});

  final int total;
  final List<ProductParameterVersionListItem> items;
}

class ProductParameterHistoryItem {
  ProductParameterHistoryItem({
    required this.id,
    required this.productName,
    required this.productCategory,
    required this.version,
    required this.versionLabel,
    required this.remark,
    required this.changeReason,
    required this.changeType,
    required this.parameterName,
    required this.changedKeys,
    required this.operatorUsername,
    required this.beforeSummary,
    required this.afterSummary,
    required this.beforeSnapshot,
    required this.afterSnapshot,
    required this.createdAt,
  });

  final int id;
  final String productName;
  final String productCategory;
  final int? version;
  final String? versionLabel;
  final String remark;
  final String changeReason;
  final String changeType;
  final String? parameterName;
  final List<String> changedKeys;
  final String operatorUsername;
  final String? beforeSummary;
  final String? afterSummary;
  final String beforeSnapshot;
  final String afterSnapshot;
  final DateTime createdAt;

  factory ProductParameterHistoryItem.fromJson(Map<String, dynamic> json) {
    return ProductParameterHistoryItem(
      id: json['id'] as int,
      productName: (json['product_name'] as String?) ?? '',
      productCategory: (json['product_category'] as String?) ?? '',
      version: json['version'] as int?,
      versionLabel: json['version_label'] as String?,
      remark: json['remark'] as String,
      changeReason: (json['change_reason'] as String?) ?? '',
      changeType: (json['change_type'] as String?) ?? 'edit',
      parameterName: json['parameter_name'] as String?,
      changedKeys: (json['changed_keys'] as List<dynamic>? ?? const [])
          .cast<String>(),
      operatorUsername: json['operator_username'] as String? ?? '-',
      beforeSummary: json['before_summary'] as String?,
      afterSummary: json['after_summary'] as String?,
      beforeSnapshot: (json['before_snapshot'] as String?) ?? '{}',
      afterSnapshot: (json['after_snapshot'] as String?) ?? '{}',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProductParameterHistoryListResult {
  ProductParameterHistoryListResult({
    required this.version,
    required this.versionLabel,
    required this.lifecycleStatus,
    required this.total,
    required this.items,
  });

  final int? version;
  final String? versionLabel;
  final String? lifecycleStatus;
  final int total;
  final List<ProductParameterHistoryItem> items;
}

class ProductParameterUpdateResult {
  ProductParameterUpdateResult({
    required this.parameterScope,
    required this.version,
    required this.updatedCount,
    required this.changedKeys,
  });

  final String parameterScope;
  final int version;
  final int updatedCount;
  final List<String> changedKeys;

  factory ProductParameterUpdateResult.fromJson(Map<String, dynamic> json) {
    return ProductParameterUpdateResult(
      parameterScope: (json['parameter_scope'] as String?) ?? 'version',
      version: (json['version'] as int?) ?? 0,
      updatedCount: (json['updated_count'] as int?) ?? 0,
      changedKeys: (json['changed_keys'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }
}

class ProductLifecycleUpdateRequest {
  ProductLifecycleUpdateRequest({
    required this.targetStatus,
    this.confirmed = false,
    this.note,
    this.inactiveReason,
  });

  final String targetStatus;
  final bool confirmed;
  final String? note;
  final String? inactiveReason;

  Map<String, dynamic> toJson() {
    return {
      'target_status': targetStatus,
      'confirmed': confirmed,
      'note': note,
      'inactive_reason': inactiveReason,
    };
  }
}

class ProductImpactOrderItem {
  ProductImpactOrderItem({
    required this.orderId,
    required this.orderCode,
    required this.orderStatus,
    required this.reason,
  });

  final int orderId;
  final String orderCode;
  final String orderStatus;
  final String? reason;

  factory ProductImpactOrderItem.fromJson(Map<String, dynamic> json) {
    return ProductImpactOrderItem(
      orderId: json['order_id'] as int,
      orderCode: json['order_code'] as String,
      orderStatus: json['order_status'] as String,
      reason: json['reason'] as String?,
    );
  }
}

class ProductImpactAnalysisResult {
  ProductImpactAnalysisResult({
    required this.operation,
    required this.targetStatus,
    required this.targetVersion,
    required this.totalOrders,
    required this.pendingOrders,
    required this.inProgressOrders,
    required this.requiresConfirmation,
    required this.items,
  });

  final String operation;
  final String? targetStatus;
  final int? targetVersion;
  final int totalOrders;
  final int pendingOrders;
  final int inProgressOrders;
  final bool requiresConfirmation;
  final List<ProductImpactOrderItem> items;

  factory ProductImpactAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ProductImpactAnalysisResult(
      operation: (json['operation'] as String?) ?? '',
      targetStatus: json['target_status'] as String?,
      targetVersion: json['target_version'] as int?,
      totalOrders: (json['total_orders'] as int?) ?? 0,
      pendingOrders: (json['pending_orders'] as int?) ?? 0,
      inProgressOrders: (json['in_progress_orders'] as int?) ?? 0,
      requiresConfirmation: (json['requires_confirmation'] as bool?) ?? false,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductImpactOrderItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProductVersionItem {
  ProductVersionItem({
    required this.version,
    required this.versionLabel,
    required this.lifecycleStatus,
    required this.action,
    required this.note,
    this.effectiveAt,
    required this.sourceVersion,
    required this.sourceVersionLabel,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.createdAt,
    this.updatedAt,
  });

  final int version;
  final String versionLabel;
  final String lifecycleStatus;
  final String action;
  final String? note;
  final DateTime? effectiveAt;
  final int? sourceVersion;
  final String? sourceVersionLabel;
  final int? createdByUserId;
  final String? createdByUsername;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get displayVersion => versionLabel;

  factory ProductVersionItem.fromJson(Map<String, dynamic> json) {
    return ProductVersionItem(
      version: (json['version'] as int?) ?? 0,
      versionLabel: (json['version_label'] as String?) ?? 'V1.0',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? '',
      action: (json['action'] as String?) ?? '',
      note: json['note'] as String?,
      effectiveAt: json['effective_at'] != null
          ? DateTime.parse(json['effective_at'] as String)
          : null,
      sourceVersion: json['source_version'] as int?,
      sourceVersionLabel: json['source_version_label'] as String?,
      createdByUserId: json['created_by_user_id'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

class ProductVersionListResult {
  ProductVersionListResult({required this.total, required this.items});

  final int total;
  final List<ProductVersionItem> items;
}

class ProductVersionDiffItem {
  ProductVersionDiffItem({
    required this.key,
    required this.diffType,
    required this.fromValue,
    required this.toValue,
  });

  final String key;
  final String diffType;
  final String? fromValue;
  final String? toValue;

  factory ProductVersionDiffItem.fromJson(Map<String, dynamic> json) {
    return ProductVersionDiffItem(
      key: (json['key'] as String?) ?? '',
      diffType: (json['diff_type'] as String?) ?? '',
      fromValue: json['from_value'] as String?,
      toValue: json['to_value'] as String?,
    );
  }
}

class ProductVersionCompareResult {
  ProductVersionCompareResult({
    required this.fromVersion,
    required this.toVersion,
    required this.addedItems,
    required this.removedItems,
    required this.changedItems,
    required this.items,
  });

  final int fromVersion;
  final int toVersion;
  final int addedItems;
  final int removedItems;
  final int changedItems;
  final List<ProductVersionDiffItem> items;

  factory ProductVersionCompareResult.fromJson(Map<String, dynamic> json) {
    return ProductVersionCompareResult(
      fromVersion: (json['from_version'] as int?) ?? 0,
      toVersion: (json['to_version'] as int?) ?? 0,
      addedItems: (json['added_items'] as int?) ?? 0,
      removedItems: (json['removed_items'] as int?) ?? 0,
      changedItems: (json['changed_items'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductVersionDiffItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProductRollbackResult {
  ProductRollbackResult({required this.product, required this.changedKeys});

  final ProductItem product;
  final List<String> changedKeys;

  factory ProductRollbackResult.fromJson(Map<String, dynamic> json) {
    return ProductRollbackResult(
      product: ProductItem.fromJson(json['product'] as Map<String, dynamic>),
      changedKeys: (json['changed_keys'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }
}

class ProductJumpCommand {
  const ProductJumpCommand({
    required this.seq,
    required this.targetTabCode,
    required this.action,
    required this.productId,
    required this.productName,
    this.targetVersion,
    this.targetVersionLabel,
  });

  final int seq;
  final String targetTabCode;
  final String action;
  final int productId;
  final String productName;
  final int? targetVersion;
  final String? targetVersionLabel;
}
