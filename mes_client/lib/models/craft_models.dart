class CraftStageItem {
  CraftStageItem({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String code;
  final String name;
  final int sortOrder;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CraftStageItem.fromJson(Map<String, dynamic> json) {
    return CraftStageItem(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
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
