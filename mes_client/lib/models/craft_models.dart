class CraftStageItem {
  CraftStageItem({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.isEnabled,
    required this.processCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String code;
  final String name;
  final int sortOrder;
  final bool isEnabled;
  final int processCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CraftStageItem.fromJson(Map<String, dynamic> json) {
    return CraftStageItem(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      processCount: (json['process_count'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CraftStageListResult {
  CraftStageListResult({required this.total, required this.items});

  final int total;
  final List<CraftStageItem> items;
}

class CraftProcessItem {
  CraftProcessItem({
    required this.id,
    required this.code,
    required this.name,
    required this.stageId,
    required this.stageCode,
    required this.stageName,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String code;
  final String name;
  final int? stageId;
  final String? stageCode;
  final String? stageName;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CraftProcessItem.fromJson(Map<String, dynamic> json) {
    return CraftProcessItem(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      stageId: json['stage_id'] as int?,
      stageCode: json['stage_code'] as String?,
      stageName: json['stage_name'] as String?,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CraftProcessListResult {
  CraftProcessListResult({required this.total, required this.items});

  final int total;
  final List<CraftProcessItem> items;
}

class CraftTemplateStepPayload {
  const CraftTemplateStepPayload({
    required this.stepOrder,
    required this.stageId,
    required this.processId,
  });

  final int stepOrder;
  final int stageId;
  final int processId;

  Map<String, dynamic> toJson() {
    return {
      'step_order': stepOrder,
      'stage_id': stageId,
      'process_id': processId,
    };
  }
}

class CraftTemplateStepItem {
  CraftTemplateStepItem({
    required this.id,
    required this.stepOrder,
    required this.stageId,
    required this.stageCode,
    required this.stageName,
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int stepOrder;
  final int stageId;
  final String stageCode;
  final String stageName;
  final int processId;
  final String processCode;
  final String processName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CraftTemplateStepItem.fromJson(Map<String, dynamic> json) {
    return CraftTemplateStepItem(
      id: json['id'] as int,
      stepOrder: (json['step_order'] as int?) ?? 0,
      stageId: (json['stage_id'] as int?) ?? 0,
      stageCode: (json['stage_code'] as String?) ?? '',
      stageName: (json['stage_name'] as String?) ?? '',
      processId: (json['process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CraftTemplateItem {
  CraftTemplateItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.templateName,
    required this.version,
    required this.lifecycleStatus,
    required this.publishedVersion,
    required this.isDefault,
    required this.isEnabled,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.updatedByUserId,
    required this.updatedByUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int productId;
  final String productName;
  final String templateName;
  final int version;
  final String lifecycleStatus;
  final int publishedVersion;
  final bool isDefault;
  final bool isEnabled;
  final int? createdByUserId;
  final String? createdByUsername;
  final int? updatedByUserId;
  final String? updatedByUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CraftTemplateItem.fromJson(Map<String, dynamic> json) {
    return CraftTemplateItem(
      id: json['id'] as int,
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      templateName: (json['template_name'] as String?) ?? '',
      version: (json['version'] as int?) ?? 0,
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'draft',
      publishedVersion: (json['published_version'] as int?) ?? 0,
      isDefault: (json['is_default'] as bool?) ?? false,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      createdByUserId: json['created_by_user_id'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      updatedByUserId: json['updated_by_user_id'] as int?,
      updatedByUsername: json['updated_by_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CraftTemplateListResult {
  CraftTemplateListResult({required this.total, required this.items});

  final int total;
  final List<CraftTemplateItem> items;
}

class CraftSystemMasterTemplateStepItem {
  CraftSystemMasterTemplateStepItem({
    required this.id,
    required this.stepOrder,
    required this.stageId,
    required this.stageCode,
    required this.stageName,
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int stepOrder;
  final int stageId;
  final String stageCode;
  final String stageName;
  final int processId;
  final String processCode;
  final String processName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CraftSystemMasterTemplateStepItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return CraftSystemMasterTemplateStepItem(
      id: (json['id'] as int?) ?? 0,
      stepOrder: (json['step_order'] as int?) ?? 0,
      stageId: (json['stage_id'] as int?) ?? 0,
      stageCode: (json['stage_code'] as String?) ?? '',
      stageName: (json['stage_name'] as String?) ?? '',
      processId: (json['process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CraftSystemMasterTemplateItem {
  CraftSystemMasterTemplateItem({
    required this.id,
    required this.version,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.updatedByUserId,
    required this.updatedByUsername,
    required this.createdAt,
    required this.updatedAt,
    required this.steps,
  });

  final int id;
  final int version;
  final int? createdByUserId;
  final String? createdByUsername;
  final int? updatedByUserId;
  final String? updatedByUsername;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CraftSystemMasterTemplateStepItem> steps;

  factory CraftSystemMasterTemplateItem.fromJson(Map<String, dynamic> json) {
    return CraftSystemMasterTemplateItem(
      id: (json['id'] as int?) ?? 0,
      version: (json['version'] as int?) ?? 0,
      createdByUserId: json['created_by_user_id'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      updatedByUserId: json['updated_by_user_id'] as int?,
      updatedByUsername: json['updated_by_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CraftSystemMasterTemplateStepItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CraftTemplateDetail {
  CraftTemplateDetail({required this.template, required this.steps});

  final CraftTemplateItem template;
  final List<CraftTemplateStepItem> steps;

  factory CraftTemplateDetail.fromJson(Map<String, dynamic> json) {
    return CraftTemplateDetail(
      template: CraftTemplateItem.fromJson(
        json['template'] as Map<String, dynamic>,
      ),
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                CraftTemplateStepItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CraftTemplateSyncOrderConflict {
  CraftTemplateSyncOrderConflict({
    required this.orderId,
    required this.orderCode,
    required this.reason,
  });

  final int orderId;
  final String orderCode;
  final String reason;

  factory CraftTemplateSyncOrderConflict.fromJson(Map<String, dynamic> json) {
    return CraftTemplateSyncOrderConflict(
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
    );
  }
}

class CraftTemplateSyncResult {
  CraftTemplateSyncResult({
    required this.total,
    required this.synced,
    required this.skipped,
    required this.reasons,
  });

  final int total;
  final int synced;
  final int skipped;
  final List<CraftTemplateSyncOrderConflict> reasons;

  factory CraftTemplateSyncResult.fromJson(Map<String, dynamic> json) {
    return CraftTemplateSyncResult(
      total: (json['total'] as int?) ?? 0,
      synced: (json['synced'] as int?) ?? 0,
      skipped: (json['skipped'] as int?) ?? 0,
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CraftTemplateSyncOrderConflict.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CraftTemplateUpdateResult {
  CraftTemplateUpdateResult({required this.detail, required this.syncResult});

  final CraftTemplateDetail detail;
  final CraftTemplateSyncResult syncResult;

  factory CraftTemplateUpdateResult.fromJson(Map<String, dynamic> json) {
    return CraftTemplateUpdateResult(
      detail: CraftTemplateDetail.fromJson(
        json['detail'] as Map<String, dynamic>,
      ),
      syncResult: CraftTemplateSyncResult.fromJson(
        json['sync_result'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class CraftTemplateImpactOrderItem {
  CraftTemplateImpactOrderItem({
    required this.orderId,
    required this.orderCode,
    required this.orderStatus,
    required this.syncable,
    required this.reason,
  });

  final int orderId;
  final String orderCode;
  final String orderStatus;
  final bool syncable;
  final String? reason;

  factory CraftTemplateImpactOrderItem.fromJson(Map<String, dynamic> json) {
    return CraftTemplateImpactOrderItem(
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      orderStatus: (json['order_status'] as String?) ?? '',
      syncable: (json['syncable'] as bool?) ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class CraftTemplateImpactAnalysis {
  CraftTemplateImpactAnalysis({
    required this.totalOrders,
    required this.pendingOrders,
    required this.inProgressOrders,
    required this.syncableOrders,
    required this.blockedOrders,
    required this.items,
  });

  final int totalOrders;
  final int pendingOrders;
  final int inProgressOrders;
  final int syncableOrders;
  final int blockedOrders;
  final List<CraftTemplateImpactOrderItem> items;

  factory CraftTemplateImpactAnalysis.fromJson(Map<String, dynamic> json) {
    return CraftTemplateImpactAnalysis(
      totalOrders: (json['total_orders'] as int?) ?? 0,
      pendingOrders: (json['pending_orders'] as int?) ?? 0,
      inProgressOrders: (json['in_progress_orders'] as int?) ?? 0,
      syncableOrders: (json['syncable_orders'] as int?) ?? 0,
      blockedOrders: (json['blocked_orders'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CraftTemplateImpactOrderItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CraftTemplateVersionItem {
  CraftTemplateVersionItem({
    required this.version,
    required this.action,
    required this.note,
    required this.sourceVersion,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.createdAt,
  });

  final int version;
  final String action;
  final String? note;
  final int? sourceVersion;
  final int? createdByUserId;
  final String? createdByUsername;
  final DateTime createdAt;

  factory CraftTemplateVersionItem.fromJson(Map<String, dynamic> json) {
    return CraftTemplateVersionItem(
      version: (json['version'] as int?) ?? 0,
      action: (json['action'] as String?) ?? '',
      note: json['note'] as String?,
      sourceVersion: json['source_version'] as int?,
      createdByUserId: json['created_by_user_id'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CraftTemplateVersionListResult {
  CraftTemplateVersionListResult({required this.total, required this.items});

  final int total;
  final List<CraftTemplateVersionItem> items;
}

class CraftTemplateVersionDiffItem {
  CraftTemplateVersionDiffItem({
    required this.stepOrder,
    required this.diffType,
    required this.fromStageCode,
    required this.fromProcessCode,
    required this.toStageCode,
    required this.toProcessCode,
  });

  final int stepOrder;
  final String diffType;
  final String? fromStageCode;
  final String? fromProcessCode;
  final String? toStageCode;
  final String? toProcessCode;

  factory CraftTemplateVersionDiffItem.fromJson(Map<String, dynamic> json) {
    return CraftTemplateVersionDiffItem(
      stepOrder: (json['step_order'] as int?) ?? 0,
      diffType: (json['diff_type'] as String?) ?? '',
      fromStageCode: json['from_stage_code'] as String?,
      fromProcessCode: json['from_process_code'] as String?,
      toStageCode: json['to_stage_code'] as String?,
      toProcessCode: json['to_process_code'] as String?,
    );
  }
}

class CraftTemplateVersionCompareResult {
  CraftTemplateVersionCompareResult({
    required this.fromVersion,
    required this.toVersion,
    required this.addedSteps,
    required this.removedSteps,
    required this.changedSteps,
    required this.items,
  });

  final int fromVersion;
  final int toVersion;
  final int addedSteps;
  final int removedSteps;
  final int changedSteps;
  final List<CraftTemplateVersionDiffItem> items;

  factory CraftTemplateVersionCompareResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return CraftTemplateVersionCompareResult(
      fromVersion: (json['from_version'] as int?) ?? 0,
      toVersion: (json['to_version'] as int?) ?? 0,
      addedSteps: (json['added_steps'] as int?) ?? 0,
      removedSteps: (json['removed_steps'] as int?) ?? 0,
      changedSteps: (json['changed_steps'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CraftTemplateVersionDiffItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CraftKanbanSampleItem {
  CraftKanbanSampleItem({
    required this.orderProcessId,
    required this.orderId,
    required this.orderCode,
    required this.startAt,
    required this.endAt,
    required this.workMinutes,
    required this.productionQty,
    required this.capacityPerHour,
  });

  final int orderProcessId;
  final int orderId;
  final String orderCode;
  final DateTime startAt;
  final DateTime endAt;
  final int workMinutes;
  final int productionQty;
  final double capacityPerHour;

  factory CraftKanbanSampleItem.fromJson(Map<String, dynamic> json) {
    return CraftKanbanSampleItem(
      orderProcessId: (json['order_process_id'] as int?) ?? 0,
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      workMinutes: (json['work_minutes'] as int?) ?? 0,
      productionQty: (json['production_qty'] as int?) ?? 0,
      capacityPerHour: ((json['capacity_per_hour'] as num?) ?? 0).toDouble(),
    );
  }
}

class CraftKanbanProcessItem {
  CraftKanbanProcessItem({
    required this.stageId,
    required this.stageCode,
    required this.stageName,
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.samples,
  });

  final int? stageId;
  final String? stageCode;
  final String? stageName;
  final int processId;
  final String processCode;
  final String processName;
  final List<CraftKanbanSampleItem> samples;

  factory CraftKanbanProcessItem.fromJson(Map<String, dynamic> json) {
    return CraftKanbanProcessItem(
      stageId: json['stage_id'] as int?,
      stageCode: json['stage_code'] as String?,
      stageName: json['stage_name'] as String?,
      processId: (json['process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      samples: (json['samples'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                CraftKanbanSampleItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CraftKanbanProcessMetricsResult {
  CraftKanbanProcessMetricsResult({
    required this.productId,
    required this.productName,
    required this.items,
  });

  final int productId;
  final String productName;
  final List<CraftKanbanProcessItem> items;

  factory CraftKanbanProcessMetricsResult.fromJson(Map<String, dynamic> json) {
    return CraftKanbanProcessMetricsResult(
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                CraftKanbanProcessItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CraftTemplateBatchExportItem {
  CraftTemplateBatchExportItem({
    required this.productId,
    required this.productName,
    required this.templateName,
    required this.isDefault,
    required this.isEnabled,
    required this.lifecycleStatus,
    required this.steps,
  });

  final int productId;
  final String productName;
  final String templateName;
  final bool isDefault;
  final bool isEnabled;
  final String lifecycleStatus;
  final List<CraftTemplateStepPayload> steps;

  factory CraftTemplateBatchExportItem.fromJson(Map<String, dynamic> json) {
    return CraftTemplateBatchExportItem(
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      templateName: (json['template_name'] as String?) ?? '',
      isDefault: (json['is_default'] as bool?) ?? false,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'draft',
      steps: (json['steps'] as List<dynamic>? ?? const []).map((entry) {
        final map = entry as Map<String, dynamic>;
        return CraftTemplateStepPayload(
          stepOrder: (map['step_order'] as int?) ?? 0,
          stageId: (map['stage_id'] as int?) ?? 0,
          processId: (map['process_id'] as int?) ?? 0,
        );
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'template_name': templateName,
      'is_default': isDefault,
      'is_enabled': isEnabled,
      'lifecycle_status': lifecycleStatus,
      'steps': steps.map((item) => item.toJson()).toList(),
    };
  }
}

class CraftTemplateBatchExportResult {
  CraftTemplateBatchExportResult({
    required this.total,
    required this.exportedAt,
    required this.items,
  });

  final int total;
  final DateTime exportedAt;
  final List<CraftTemplateBatchExportItem> items;

  factory CraftTemplateBatchExportResult.fromJson(Map<String, dynamic> json) {
    return CraftTemplateBatchExportResult(
      total: (json['total'] as int?) ?? 0,
      exportedAt: DateTime.parse(json['exported_at'] as String),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CraftTemplateBatchExportItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CraftTemplateBatchImportItem {
  const CraftTemplateBatchImportItem({
    this.productId,
    this.productName,
    required this.templateName,
    required this.isDefault,
    required this.isEnabled,
    required this.lifecycleStatus,
    required this.steps,
  });

  final int? productId;
  final String? productName;
  final String templateName;
  final bool isDefault;
  final bool isEnabled;
  final String lifecycleStatus;
  final List<CraftTemplateStepPayload> steps;

  Map<String, dynamic> toJson() {
    return {
      if (productId != null) 'product_id': productId,
      if (productName != null && productName!.trim().isNotEmpty)
        'product_name': productName!.trim(),
      'template_name': templateName,
      'is_default': isDefault,
      'is_enabled': isEnabled,
      'lifecycle_status': lifecycleStatus,
      'steps': steps.map((item) => item.toJson()).toList(),
    };
  }
}

class CraftTemplateBatchImportResultItem {
  CraftTemplateBatchImportResultItem({
    required this.templateId,
    required this.productId,
    required this.productName,
    required this.templateName,
    required this.action,
    required this.lifecycleStatus,
    required this.publishedVersion,
  });

  final int templateId;
  final int productId;
  final String productName;
  final String templateName;
  final String action;
  final String lifecycleStatus;
  final int publishedVersion;

  factory CraftTemplateBatchImportResultItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return CraftTemplateBatchImportResultItem(
      templateId: (json['template_id'] as int?) ?? 0,
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      templateName: (json['template_name'] as String?) ?? '',
      action: (json['action'] as String?) ?? '',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'draft',
      publishedVersion: (json['published_version'] as int?) ?? 0,
    );
  }
}

class CraftTemplateBatchImportResult {
  CraftTemplateBatchImportResult({
    required this.total,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.items,
    required this.errors,
  });

  final int total;
  final int created;
  final int updated;
  final int skipped;
  final List<CraftTemplateBatchImportResultItem> items;
  final List<String> errors;

  factory CraftTemplateBatchImportResult.fromJson(Map<String, dynamic> json) {
    return CraftTemplateBatchImportResult(
      total: (json['total'] as int?) ?? 0,
      created: (json['created'] as int?) ?? 0,
      updated: (json['updated'] as int?) ?? 0,
      skipped: (json['skipped'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => CraftTemplateBatchImportResultItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      errors: (json['errors'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
    );
  }
}

class CraftReferenceItem {
  CraftReferenceItem({
    required this.refType,
    required this.refId,
    required this.refName,
    required this.detail,
    this.riskLevel,
    this.riskNote,
  });

  final String refType;
  final int refId;
  final String refName;
  final String? detail;
  final String? riskLevel;
  final String? riskNote;

  factory CraftReferenceItem.fromJson(Map<String, dynamic> json) {
    return CraftReferenceItem(
      refType: (json['ref_type'] as String?) ?? '',
      refId: (json['ref_id'] as int?) ?? 0,
      refName: (json['ref_name'] as String?) ?? '',
      detail: json['detail'] as String?,
      riskLevel: json['risk_level'] as String?,
      riskNote: json['risk_note'] as String?,
    );
  }
}

class CraftStageReferenceResult {
  CraftStageReferenceResult({
    required this.stageId,
    required this.stageCode,
    required this.stageName,
    required this.total,
    required this.items,
  });

  final int stageId;
  final String stageCode;
  final String stageName;
  final int total;
  final List<CraftReferenceItem> items;

  factory CraftStageReferenceResult.fromJson(Map<String, dynamic> json) {
    return CraftStageReferenceResult(
      stageId: (json['stage_id'] as int?) ?? 0,
      stageCode: (json['stage_code'] as String?) ?? '',
      stageName: (json['stage_name'] as String?) ?? '',
      total: (json['total'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CraftReferenceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CraftProcessReferenceResult {
  CraftProcessReferenceResult({
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.total,
    required this.items,
  });

  final int processId;
  final String processCode;
  final String processName;
  final int total;
  final List<CraftReferenceItem> items;

  factory CraftProcessReferenceResult.fromJson(Map<String, dynamic> json) {
    return CraftProcessReferenceResult(
      processId: (json['process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      total: (json['total'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CraftReferenceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CraftTemplateReferenceResult {
  CraftTemplateReferenceResult({
    required this.templateId,
    required this.templateName,
    required this.productId,
    required this.productName,
    required this.total,
    required this.items,
  });

  final int templateId;
  final String templateName;
  final int productId;
  final String productName;
  final int total;
  final List<CraftReferenceItem> items;

  factory CraftTemplateReferenceResult.fromJson(Map<String, dynamic> json) {
    return CraftTemplateReferenceResult(
      templateId: (json['template_id'] as int?) ?? 0,
      templateName: (json['template_name'] as String?) ?? '',
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      total: (json['total'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CraftReferenceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
