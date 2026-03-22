const int maintenanceCycleWeekly = 7;
const int maintenanceCycleMonthly = 30;
const int maintenanceCycleQuarterly = 90;
const int maintenanceCycleYearly = 365;

class EquipmentLedgerItem {
  EquipmentLedgerItem({
    required this.id,
    required this.code,
    required this.name,
    required this.model,
    required this.location,
    required this.ownerName,
    required this.remark,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String code;
  final String name;
  final String model;
  final String location;
  final String ownerName;
  final String remark;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EquipmentLedgerItem.fromJson(Map<String, dynamic> json) {
    return EquipmentLedgerItem(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      ownerName: (json['owner_name'] as String?) ?? '',
      remark: (json['remark'] as String?) ?? '',
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class EquipmentLedgerListResult {
  EquipmentLedgerListResult({required this.total, required this.items});

  final int total;
  final List<EquipmentLedgerItem> items;
}

class EquipmentOwnerOption {
  EquipmentOwnerOption({
    required this.userId,
    required this.username,
    required this.fullName,
  });

  final int userId;
  final String username;
  final String? fullName;

  String get displayName {
    if (fullName == null || fullName!.trim().isEmpty) {
      return username;
    }
    return '$username (${fullName!.trim()})';
  }

  factory EquipmentOwnerOption.fromJson(Map<String, dynamic> json) {
    return EquipmentOwnerOption(
      userId: (json['id'] as int?) ?? 0,
      username: (json['username'] as String?) ?? '',
      fullName: json['full_name'] as String?,
    );
  }
}

class MaintenanceItemEntry {
  MaintenanceItemEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultCycleDays,
    required this.defaultDurationMinutes,
    required this.standardDescription,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String category;
  final int defaultCycleDays;
  final int defaultDurationMinutes;
  final String standardDescription;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get executionDateLabel {
    switch (defaultCycleDays) {
      case maintenanceCycleWeekly:
        return '每周五执行';
      case maintenanceCycleMonthly:
        return '每月执行';
      case maintenanceCycleQuarterly:
        return '每季度执行';
      case maintenanceCycleYearly:
        return '每年执行';
      default:
        return '每$defaultCycleDays天执行';
    }
  }

  factory MaintenanceItemEntry.fromJson(Map<String, dynamic> json) {
    return MaintenanceItemEntry(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      defaultCycleDays: (json['default_cycle_days'] as int?) ?? 0,
      defaultDurationMinutes: (json['default_duration_minutes'] as int?) ?? 60,
      standardDescription: (json['standard_description'] as String?) ?? '',
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MaintenanceItemListResult {
  MaintenanceItemListResult({required this.total, required this.items});

  final int total;
  final List<MaintenanceItemEntry> items;
}

class MaintenancePlanItem {
  MaintenancePlanItem({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.itemId,
    required this.itemName,
    required this.cycleDays,
    required this.executionProcessCode,
    required this.executionProcessName,
    required this.estimatedDurationMinutes,
    required this.startDate,
    required this.nextDueDate,
    required this.defaultExecutorUserId,
    required this.defaultExecutorUsername,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int equipmentId;
  final String equipmentName;
  final int itemId;
  final String itemName;
  final int cycleDays;
  final String executionProcessCode;
  final String executionProcessName;
  final int? estimatedDurationMinutes;
  final DateTime startDate;
  final DateTime nextDueDate;
  final int? defaultExecutorUserId;
  final String? defaultExecutorUsername;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MaintenancePlanItem.fromJson(Map<String, dynamic> json) {
    return MaintenancePlanItem(
      id: json['id'] as int,
      equipmentId: json['equipment_id'] as int,
      equipmentName: (json['equipment_name'] as String?) ?? '',
      itemId: json['item_id'] as int,
      itemName: (json['item_name'] as String?) ?? '',
      cycleDays: (json['cycle_days'] as int?) ?? 1,
      executionProcessCode: (json['execution_process_code'] as String?) ?? '',
      executionProcessName:
          (json['execution_process_name'] as String?) ??
          ((json['execution_process_code'] as String?) ?? ''),
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      startDate: DateTime.parse(json['start_date'] as String),
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      defaultExecutorUserId: json['default_executor_user_id'] as int?,
      defaultExecutorUsername: json['default_executor_username'] as String?,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MaintenancePlanListResult {
  MaintenancePlanListResult({required this.total, required this.items});

  final int total;
  final List<MaintenancePlanItem> items;
}

class MaintenancePlanGenerateResult {
  MaintenancePlanGenerateResult({
    required this.created,
    required this.workOrderId,
    required this.dueDate,
    required this.nextDueDate,
  });

  final bool created;
  final int workOrderId;
  final DateTime dueDate;
  final DateTime nextDueDate;

  factory MaintenancePlanGenerateResult.fromJson(Map<String, dynamic> json) {
    return MaintenancePlanGenerateResult(
      created: (json['created'] as bool?) ?? false,
      workOrderId: (json['work_order_id'] as int?) ?? 0,
      dueDate: DateTime.parse(json['due_date'] as String),
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
    );
  }
}

class MaintenanceWorkOrderItem {
  MaintenanceWorkOrderItem({
    required this.id,
    required this.planId,
    required this.equipmentId,
    required this.equipmentName,
    required this.sourceEquipmentCode,
    required this.itemId,
    required this.itemName,
    required this.sourceItemName,
    required this.sourceExecutionProcessCode,
    required this.dueDate,
    required this.status,
    required this.executorUserId,
    required this.executorUsername,
    required this.startedAt,
    required this.completedAt,
    required this.resultSummary,
    required this.resultRemark,
    required this.attachmentLink,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? planId;
  final int? equipmentId;
  final String equipmentName;
  final String? sourceEquipmentCode;
  final int? itemId;
  final String itemName;
  final String? sourceItemName;
  final String? sourceExecutionProcessCode;
  final DateTime dueDate;
  final String status;
  final int? executorUserId;
  final String? executorUsername;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? resultSummary;
  final String? resultRemark;
  final String? attachmentLink;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MaintenanceWorkOrderItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceWorkOrderItem(
      id: json['id'] as int,
      planId: json['plan_id'] as int?,
      equipmentId: json['equipment_id'] as int?,
      equipmentName: (json['equipment_name'] as String?) ?? '',
      sourceEquipmentCode: json['source_equipment_code'] as String?,
      itemId: json['item_id'] as int?,
      itemName: (json['item_name'] as String?) ?? '',
      sourceItemName: json['source_item_name'] as String?,
      sourceExecutionProcessCode:
          json['source_execution_process_code'] as String?,
      dueDate: DateTime.parse(json['due_date'] as String),
      status: (json['status'] as String?) ?? 'pending',
      executorUserId: json['executor_user_id'] as int?,
      executorUsername: json['executor_username'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      resultSummary: json['result_summary'] as String?,
      resultRemark: json['result_remark'] as String?,
      attachmentLink: json['attachment_link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MaintenanceWorkOrderListResult {
  MaintenanceWorkOrderListResult({required this.total, required this.items});

  final int total;
  final List<MaintenanceWorkOrderItem> items;
}

class MaintenanceRecordItem {
  MaintenanceRecordItem({
    required this.id,
    required this.workOrderId,
    required this.equipmentName,
    required this.itemName,
    required this.dueDate,
    required this.executorUserId,
    required this.executorUsername,
    required this.completedAt,
    required this.resultSummary,
    required this.resultRemark,
    required this.attachmentLink,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int workOrderId;
  final String equipmentName;
  final String itemName;
  final DateTime dueDate;
  final int? executorUserId;
  final String? executorUsername;
  final DateTime completedAt;
  final String resultSummary;
  final String? resultRemark;
  final String? attachmentLink;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MaintenanceRecordItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecordItem(
      id: json['id'] as int,
      workOrderId: (json['work_order_id'] as int?) ?? 0,
      equipmentName: (json['equipment_name'] as String?) ?? '',
      itemName: (json['item_name'] as String?) ?? '',
      dueDate: DateTime.parse(json['due_date'] as String),
      executorUserId: json['executor_user_id'] as int?,
      executorUsername: json['executor_username'] as String?,
      completedAt: DateTime.parse(json['completed_at'] as String),
      resultSummary: (json['result_summary'] as String?) ?? '',
      resultRemark: json['result_remark'] as String?,
      attachmentLink: json['attachment_link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MaintenanceRecordListResult {
  MaintenanceRecordListResult({required this.total, required this.items});

  final int total;
  final List<MaintenanceRecordItem> items;
}

class EquipmentDetailResult {
  EquipmentDetailResult({
    required this.id,
    required this.code,
    required this.name,
    required this.model,
    required this.location,
    required this.ownerName,
    required this.remark,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.activePlanCount,
    required this.pendingWorkOrderCount,
    required this.activePlans,
    required this.pendingWorkOrders,
    required this.recentRecords,
  });

  final int id;
  final String code;
  final String name;
  final String model;
  final String location;
  final String ownerName;
  final String remark;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int activePlanCount;
  final int pendingWorkOrderCount;
  final List<MaintenancePlanItem> activePlans;
  final List<MaintenanceWorkOrderItem> pendingWorkOrders;
  final List<MaintenanceRecordItem> recentRecords;

  factory EquipmentDetailResult.fromJson(Map<String, dynamic> json) {
    return EquipmentDetailResult(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      ownerName: (json['owner_name'] as String?) ?? '',
      remark: (json['remark'] as String?) ?? '',
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      activePlanCount: (json['active_plan_count'] as int?) ?? 0,
      pendingWorkOrderCount: (json['pending_work_order_count'] as int?) ?? 0,
      activePlans: (json['active_plans'] as List<dynamic>? ?? const [])
          .map((e) => MaintenancePlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingWorkOrders:
          (json['pending_work_orders'] as List<dynamic>? ?? const [])
              .map(
                (e) => MaintenanceWorkOrderItem.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      recentRecords: (json['recent_records'] as List<dynamic>? ?? const [])
          .map((e) => MaintenanceRecordItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MaintenanceWorkOrderDetail extends MaintenanceWorkOrderItem {
  MaintenanceWorkOrderDetail({
    required super.id,
    required super.planId,
    required super.equipmentId,
    required super.equipmentName,
    required super.sourceEquipmentCode,
    required super.itemId,
    required super.itemName,
    required super.sourceItemName,
    required super.sourceExecutionProcessCode,
    required super.dueDate,
    required super.status,
    required super.executorUserId,
    required super.executorUsername,
    required super.startedAt,
    required super.completedAt,
    required super.resultSummary,
    required super.resultRemark,
    required super.attachmentLink,
    required super.createdAt,
    required super.updatedAt,
    required this.sourcePlanId,
    required this.sourcePlanCycleDays,
    required this.sourcePlanStartDate,
    required this.sourcePlanSummary,
    required this.sourceEquipmentName,
    required this.sourceItemId,
    required this.recordId,
  });

  final int? sourcePlanId;
  final int? sourcePlanCycleDays;
  final DateTime? sourcePlanStartDate;
  final String? sourcePlanSummary;
  final String? sourceEquipmentName;
  final int? sourceItemId;
  final int? recordId;

  factory MaintenanceWorkOrderDetail.fromJson(Map<String, dynamic> json) {
    return MaintenanceWorkOrderDetail(
      id: json['id'] as int,
      planId: json['plan_id'] as int?,
      equipmentId: json['equipment_id'] as int?,
      equipmentName: (json['equipment_name'] as String?) ?? '',
      sourceEquipmentCode: json['source_equipment_code'] as String?,
      itemId: json['item_id'] as int?,
      itemName: (json['item_name'] as String?) ?? '',
      sourceItemName: json['source_item_name'] as String?,
      sourceExecutionProcessCode:
          json['source_execution_process_code'] as String?,
      dueDate: DateTime.parse(json['due_date'] as String),
      status: (json['status'] as String?) ?? 'pending',
      executorUserId: json['executor_user_id'] as int?,
      executorUsername: json['executor_username'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      resultSummary: json['result_summary'] as String?,
      resultRemark: json['result_remark'] as String?,
      attachmentLink: json['attachment_link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sourcePlanId: json['source_plan_id'] as int?,
      sourcePlanCycleDays: json['source_plan_cycle_days'] as int?,
      sourcePlanStartDate: json['source_plan_start_date'] != null
          ? DateTime.parse(json['source_plan_start_date'] as String)
          : null,
      sourcePlanSummary: json['source_plan_summary'] as String?,
      sourceEquipmentName: json['source_equipment_name'] as String?,
      sourceItemId: json['source_item_id'] as int?,
      recordId: json['record_id'] as int?,
    );
  }
}

class MaintenanceRecordDetail extends MaintenanceRecordItem {
  MaintenanceRecordDetail({
    required super.id,
    required super.workOrderId,
    required super.equipmentName,
    required super.itemName,
    required super.dueDate,
    required super.executorUserId,
    required super.executorUsername,
    required super.completedAt,
    required super.resultSummary,
    required super.resultRemark,
    required super.attachmentLink,
    required super.createdAt,
    required super.updatedAt,
    required this.sourcePlanId,
    required this.sourcePlanCycleDays,
    required this.sourcePlanStartDate,
    required this.sourcePlanSummary,
    required this.sourceEquipmentCode,
    required this.sourceEquipmentName,
    required this.sourceExecutionProcessCode,
    required this.sourceItemId,
    required this.sourceItemName,
  });

  final int? sourcePlanId;
  final int? sourcePlanCycleDays;
  final DateTime? sourcePlanStartDate;
  final String? sourcePlanSummary;
  final String? sourceEquipmentCode;
  final String? sourceEquipmentName;
  final String? sourceExecutionProcessCode;
  final int? sourceItemId;
  final String? sourceItemName;

  factory MaintenanceRecordDetail.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecordDetail(
      id: json['id'] as int,
      workOrderId: (json['work_order_id'] as int?) ?? 0,
      equipmentName: (json['equipment_name'] as String?) ?? '',
      itemName: (json['item_name'] as String?) ?? '',
      dueDate: DateTime.parse(json['due_date'] as String),
      executorUserId: json['executor_user_id'] as int?,
      executorUsername: json['executor_username'] as String?,
      completedAt: DateTime.parse(json['completed_at'] as String),
      resultSummary: (json['result_summary'] as String?) ?? '',
      resultRemark: json['result_remark'] as String?,
      attachmentLink: json['attachment_link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sourcePlanId: json['source_plan_id'] as int?,
      sourcePlanCycleDays: json['source_plan_cycle_days'] as int?,
      sourcePlanStartDate: json['source_plan_start_date'] != null
          ? DateTime.parse(json['source_plan_start_date'] as String)
          : null,
      sourcePlanSummary: json['source_plan_summary'] as String?,
      sourceEquipmentCode: json['source_equipment_code'] as String?,
      sourceEquipmentName: json['source_equipment_name'] as String?,
      sourceExecutionProcessCode:
          json['source_execution_process_code'] as String?,
      sourceItemId: json['source_item_id'] as int?,
      sourceItemName: json['source_item_name'] as String?,
    );
  }
}

class EquipmentRuleItem {
  EquipmentRuleItem({
    required this.id,
    required this.equipmentId,
    required this.equipmentType,
    required this.equipmentCode,
    required this.equipmentName,
    required this.ruleCode,
    required this.ruleName,
    required this.ruleType,
    required this.conditionDesc,
    required this.isEnabled,
    required this.effectiveAt,
    required this.remark,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? equipmentId;
  final String? equipmentType;
  final String? equipmentCode;
  final String? equipmentName;
  final String ruleCode;
  final String ruleName;
  final String ruleType;
  final String conditionDesc;
  final bool isEnabled;
  final DateTime? effectiveAt;
  final String remark;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EquipmentRuleItem.fromJson(Map<String, dynamic> json) {
    return EquipmentRuleItem(
      id: json['id'] as int,
      equipmentId: json['equipment_id'] as int?,
      equipmentType: json['equipment_type'] as String?,
      equipmentCode: json['equipment_code'] as String?,
      equipmentName: json['equipment_name'] as String?,
      ruleCode: (json['rule_code'] as String?) ?? '',
      ruleName: (json['rule_name'] as String?) ?? '',
      ruleType: (json['rule_type'] as String?) ?? '',
      conditionDesc: (json['condition_desc'] as String?) ?? '',
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      effectiveAt: json['effective_at'] != null
          ? DateTime.tryParse(json['effective_at'] as String)
          : null,
      remark: (json['remark'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class EquipmentRuleListResult {
  EquipmentRuleListResult({required this.total, required this.items});
  final int total;
  final List<EquipmentRuleItem> items;
}

class EquipmentRuntimeParameterItem {
  EquipmentRuntimeParameterItem({
    required this.id,
    required this.equipmentId,
    required this.equipmentType,
    required this.equipmentCode,
    required this.equipmentName,
    required this.paramCode,
    required this.paramName,
    required this.unit,
    required this.standardValue,
    required this.upperLimit,
    required this.lowerLimit,
    required this.effectiveAt,
    required this.isEnabled,
    required this.remark,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? equipmentId;
  final String? equipmentType;
  final String? equipmentCode;
  final String? equipmentName;
  final String paramCode;
  final String paramName;
  final String unit;
  final String? standardValue;
  final String? upperLimit;
  final String? lowerLimit;
  final DateTime? effectiveAt;
  final bool isEnabled;
  final String remark;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EquipmentRuntimeParameterItem.fromJson(Map<String, dynamic> json) {
    return EquipmentRuntimeParameterItem(
      id: json['id'] as int,
      equipmentId: json['equipment_id'] as int?,
      equipmentType: json['equipment_type'] as String?,
      equipmentCode: json['equipment_code'] as String?,
      equipmentName: json['equipment_name'] as String?,
      paramCode: (json['param_code'] as String?) ?? '',
      paramName: (json['param_name'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? '',
      standardValue: json['standard_value']?.toString(),
      upperLimit: json['upper_limit']?.toString(),
      lowerLimit: json['lower_limit']?.toString(),
      effectiveAt: json['effective_at'] != null
          ? DateTime.tryParse(json['effective_at'] as String)
          : null,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      remark: (json['remark'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class EquipmentRuntimeParameterListResult {
  EquipmentRuntimeParameterListResult({
    required this.total,
    required this.items,
  });
  final int total;
  final List<EquipmentRuntimeParameterItem> items;
}
