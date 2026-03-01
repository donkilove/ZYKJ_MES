const int maintenanceCycleWeekly = 7;
const int maintenanceCycleMonthly = 30;
const int maintenanceCycleQuarterly = 90;
const int maintenanceCycleYearly = 365;

const String processCodeLaserMarking = 'laser_marking';
const String processCodeProductTesting = 'product_testing';
const String processCodeProductAssembly = 'product_assembly';
const String processCodeProductPackaging = 'product_packaging';

const List<String> maintenanceExecutionProcessOrder = <String>[
  processCodeLaserMarking,
  processCodeProductTesting,
  processCodeProductAssembly,
  processCodeProductPackaging,
];

String maintenanceExecutionProcessName(String code) {
  switch (code) {
    case processCodeLaserMarking:
      return '激光打标';
    case processCodeProductTesting:
      return '产品测试';
    case processCodeProductAssembly:
      return '产品组装';
    case processCodeProductPackaging:
      return '产品包装';
    default:
      return code;
  }
}

class EquipmentLedgerItem {
  EquipmentLedgerItem({
    required this.id,
    required this.code,
    required this.name,
    required this.model,
    required this.location,
    required this.ownerName,
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
  EquipmentOwnerOption({required this.username, required this.fullName});

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
      username: (json['username'] as String?) ?? '',
      fullName: json['full_name'] as String?,
    );
  }
}

class MaintenanceItemEntry {
  MaintenanceItemEntry({
    required this.id,
    required this.name,
    required this.defaultCycleDays,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int defaultCycleDays;
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
        return '自定义';
    }
  }

  factory MaintenanceItemEntry.fromJson(Map<String, dynamic> json) {
    return MaintenanceItemEntry(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      defaultCycleDays: (json['default_cycle_days'] as int?) ?? 0,
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
      executionProcessCode:
          (json['execution_process_code'] as String?) ?? processCodeLaserMarking,
      executionProcessName:
          (json['execution_process_name'] as String?) ??
          maintenanceExecutionProcessName(
            (json['execution_process_code'] as String?) ?? processCodeLaserMarking,
          ),
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
  final int? planId;
  final int? equipmentId;
  final String equipmentName;
  final int? itemId;
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
      planId: json['plan_id'] as int?,
      equipmentId: json['equipment_id'] as int?,
      equipmentName: (json['equipment_name'] as String?) ?? '',
      itemId: json['item_id'] as int?,
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
