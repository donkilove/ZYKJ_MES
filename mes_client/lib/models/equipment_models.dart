class EquipmentLedgerItem {
  EquipmentLedgerItem({
    required this.id,
    required this.name,
    required this.model,
    required this.location,
    required this.ownerName,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String model;
  final String location;
  final String ownerName;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EquipmentLedgerItem.fromJson(Map<String, dynamic> json) {
    return EquipmentLedgerItem(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      ownerName: (json['owner_name'] as String?) ?? '',
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

class MaintenanceItemEntry {
  MaintenanceItemEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultCycleDays,
    required this.defaultDurationMinutes,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String category;
  final int defaultCycleDays;
  final int defaultDurationMinutes;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MaintenanceItemEntry.fromJson(Map<String, dynamic> json) {
    return MaintenanceItemEntry(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      defaultCycleDays: (json['default_cycle_days'] as int?) ?? 0,
      defaultDurationMinutes: (json['default_duration_minutes'] as int?) ?? 0,
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
    required this.itemId,
    required this.itemName,
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
  final int planId;
  final int equipmentId;
  final String equipmentName;
  final int itemId;
  final String itemName;
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
      planId: json['plan_id'] as int,
      equipmentId: json['equipment_id'] as int,
      equipmentName: (json['equipment_name'] as String?) ?? '',
      itemId: json['item_id'] as int,
      itemName: (json['item_name'] as String?) ?? '',
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
