DateTime? _parseDateOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String productionOrderStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return '待生产';
    case 'in_progress':
      return '生产中';
    case 'completed':
      return '已完成';
    default:
      return status;
  }
}

String productionProcessStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return '待生产';
    case 'in_progress':
      return '生产中';
    case 'partial':
      return '部分完成';
    case 'completed':
      return '已完成';
    default:
      return status;
  }
}

String productionSubOrderStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return '待生产';
    case 'in_progress':
      return '生产中';
    case 'done':
      return '已完成';
    default:
      return status;
  }
}

class ProductionOrderItem {
  ProductionOrderItem({
    required this.id,
    required this.orderCode,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.status,
    required this.currentProcessCode,
    required this.currentProcessName,
    required this.startDate,
    required this.dueDate,
    required this.remark,
    required this.processTemplateId,
    required this.processTemplateName,
    required this.processTemplateVersion,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String orderCode;
  final int productId;
  final String productName;
  final int quantity;
  final String status;
  final String? currentProcessCode;
  final String? currentProcessName;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? remark;
  final int? processTemplateId;
  final String? processTemplateName;
  final int? processTemplateVersion;
  final int? createdByUserId;
  final String? createdByUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductionOrderItem.fromJson(Map<String, dynamic> json) {
    return ProductionOrderItem(
      id: json['id'] as int,
      orderCode: (json['order_code'] as String?) ?? '',
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      currentProcessCode: json['current_process_code'] as String?,
      currentProcessName: json['current_process_name'] as String?,
      startDate: _parseDateOrNull(json['start_date']),
      dueDate: _parseDateOrNull(json['due_date']),
      remark: json['remark'] as String?,
      processTemplateId: json['process_template_id'] as int?,
      processTemplateName: json['process_template_name'] as String?,
      processTemplateVersion: json['process_template_version'] as int?,
      createdByUserId: json['created_by_user_id'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductionOrderListResult {
  ProductionOrderListResult({required this.total, required this.items});

  final int total;
  final List<ProductionOrderItem> items;
}

class ProductionOrderProcessItem {
  ProductionOrderProcessItem({
    required this.id,
    required this.stageId,
    required this.stageCode,
    required this.stageName,
    required this.processCode,
    required this.processName,
    required this.processOrder,
    required this.status,
    required this.visibleQuantity,
    required this.completedQuantity,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? stageId;
  final String? stageCode;
  final String? stageName;
  final String processCode;
  final String processName;
  final int processOrder;
  final String status;
  final int visibleQuantity;
  final int completedQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductionOrderProcessItem.fromJson(Map<String, dynamic> json) {
    return ProductionOrderProcessItem(
      id: json['id'] as int,
      stageId: json['stage_id'] as int?,
      stageCode: json['stage_code'] as String?,
      stageName: json['stage_name'] as String?,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      processOrder: (json['process_order'] as int?) ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      visibleQuantity: (json['visible_quantity'] as int?) ?? 0,
      completedQuantity: (json['completed_quantity'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductionSubOrderItem {
  ProductionSubOrderItem({
    required this.id,
    required this.orderProcessId,
    required this.processCode,
    required this.processName,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.assignedQuantity,
    required this.completedQuantity,
    required this.status,
    required this.isVisible,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int orderProcessId;
  final String processCode;
  final String processName;
  final int operatorUserId;
  final String operatorUsername;
  final int assignedQuantity;
  final int completedQuantity;
  final String status;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductionSubOrderItem.fromJson(Map<String, dynamic> json) {
    return ProductionSubOrderItem(
      id: json['id'] as int,
      orderProcessId: (json['order_process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      operatorUserId: (json['operator_user_id'] as int?) ?? 0,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      assignedQuantity: (json['assigned_quantity'] as int?) ?? 0,
      completedQuantity: (json['completed_quantity'] as int?) ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      isVisible: (json['is_visible'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductionRecordItem {
  ProductionRecordItem({
    required this.id,
    required this.orderProcessId,
    required this.processCode,
    required this.processName,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.productionQuantity,
    required this.recordType,
    required this.createdAt,
  });

  final int id;
  final int orderProcessId;
  final String processCode;
  final String processName;
  final int operatorUserId;
  final String operatorUsername;
  final int productionQuantity;
  final String recordType;
  final DateTime createdAt;

  factory ProductionRecordItem.fromJson(Map<String, dynamic> json) {
    return ProductionRecordItem(
      id: json['id'] as int,
      orderProcessId: (json['order_process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      operatorUserId: (json['operator_user_id'] as int?) ?? 0,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      productionQuantity: (json['production_quantity'] as int?) ?? 0,
      recordType: (json['record_type'] as String?) ?? 'production',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProductionEventLogItem {
  ProductionEventLogItem({
    required this.id,
    required this.eventType,
    required this.eventTitle,
    required this.eventDetail,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.payloadJson,
    required this.createdAt,
  });

  final int id;
  final String eventType;
  final String eventTitle;
  final String? eventDetail;
  final int? operatorUserId;
  final String? operatorUsername;
  final String? payloadJson;
  final DateTime createdAt;

  factory ProductionEventLogItem.fromJson(Map<String, dynamic> json) {
    return ProductionEventLogItem(
      id: json['id'] as int,
      eventType: (json['event_type'] as String?) ?? '',
      eventTitle: (json['event_title'] as String?) ?? '',
      eventDetail: json['event_detail'] as String?,
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: json['operator_username'] as String?,
      payloadJson: json['payload_json'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProductionOrderDetail {
  ProductionOrderDetail({
    required this.order,
    required this.processes,
    required this.subOrders,
    required this.records,
    required this.events,
  });

  final ProductionOrderItem order;
  final List<ProductionOrderProcessItem> processes;
  final List<ProductionSubOrderItem> subOrders;
  final List<ProductionRecordItem> records;
  final List<ProductionEventLogItem> events;

  factory ProductionOrderDetail.fromJson(Map<String, dynamic> json) {
    return ProductionOrderDetail(
      order: ProductionOrderItem.fromJson(
        json['order'] as Map<String, dynamic>,
      ),
      processes: (json['processes'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ProductionOrderProcessItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      subOrders: (json['sub_orders'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductionSubOrderItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      records: (json['records'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductionRecordItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      events: (json['events'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductionEventLogItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class MyOrderItem {
  MyOrderItem({
    required this.orderId,
    required this.orderCode,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.orderStatus,
    required this.currentProcessId,
    required this.currentStageId,
    required this.currentStageCode,
    required this.currentStageName,
    required this.currentProcessCode,
    required this.currentProcessName,
    required this.currentProcessOrder,
    required this.processStatus,
    required this.visibleQuantity,
    required this.processCompletedQuantity,
    required this.userSubOrderId,
    required this.userAssignedQuantity,
    required this.userCompletedQuantity,
    required this.maxProducibleQuantity,
    required this.canFirstArticle,
    required this.canEndProduction,
    required this.updatedAt,
  });

  final int orderId;
  final String orderCode;
  final int productId;
  final String productName;
  final int quantity;
  final String orderStatus;
  final int currentProcessId;
  final int? currentStageId;
  final String? currentStageCode;
  final String? currentStageName;
  final String currentProcessCode;
  final String currentProcessName;
  final int currentProcessOrder;
  final String processStatus;
  final int visibleQuantity;
  final int processCompletedQuantity;
  final int? userSubOrderId;
  final int? userAssignedQuantity;
  final int? userCompletedQuantity;
  final int maxProducibleQuantity;
  final bool canFirstArticle;
  final bool canEndProduction;
  final DateTime updatedAt;

  factory MyOrderItem.fromJson(Map<String, dynamic> json) {
    return MyOrderItem(
      orderId: json['order_id'] as int,
      orderCode: (json['order_code'] as String?) ?? '',
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      orderStatus: (json['order_status'] as String?) ?? 'pending',
      currentProcessId: (json['current_process_id'] as int?) ?? 0,
      currentStageId: json['current_stage_id'] as int?,
      currentStageCode: json['current_stage_code'] as String?,
      currentStageName: json['current_stage_name'] as String?,
      currentProcessCode: (json['current_process_code'] as String?) ?? '',
      currentProcessName: (json['current_process_name'] as String?) ?? '',
      currentProcessOrder: (json['current_process_order'] as int?) ?? 0,
      processStatus: (json['process_status'] as String?) ?? 'pending',
      visibleQuantity: (json['visible_quantity'] as int?) ?? 0,
      processCompletedQuantity:
          (json['process_completed_quantity'] as int?) ?? 0,
      userSubOrderId: json['user_sub_order_id'] as int?,
      userAssignedQuantity: json['user_assigned_quantity'] as int?,
      userCompletedQuantity: json['user_completed_quantity'] as int?,
      maxProducibleQuantity: (json['max_producible_quantity'] as int?) ?? 0,
      canFirstArticle: (json['can_first_article'] as bool?) ?? false,
      canEndProduction: (json['can_end_production'] as bool?) ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MyOrderListResult {
  MyOrderListResult({required this.total, required this.items});

  final int total;
  final List<MyOrderItem> items;
}

class ProductionActionResult {
  ProductionActionResult({
    required this.orderId,
    required this.status,
    required this.message,
  });

  final int orderId;
  final String status;
  final String message;

  factory ProductionActionResult.fromJson(Map<String, dynamic> json) {
    return ProductionActionResult(
      orderId: (json['order_id'] as int?) ?? 0,
      status: (json['status'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
    );
  }
}

class ProductionStatsOverview {
  ProductionStatsOverview({
    required this.totalOrders,
    required this.pendingOrders,
    required this.inProgressOrders,
    required this.completedOrders,
    required this.totalQuantity,
    required this.finishedQuantity,
  });

  final int totalOrders;
  final int pendingOrders;
  final int inProgressOrders;
  final int completedOrders;
  final int totalQuantity;
  final int finishedQuantity;

  factory ProductionStatsOverview.fromJson(Map<String, dynamic> json) {
    return ProductionStatsOverview(
      totalOrders: (json['total_orders'] as int?) ?? 0,
      pendingOrders: (json['pending_orders'] as int?) ?? 0,
      inProgressOrders: (json['in_progress_orders'] as int?) ?? 0,
      completedOrders: (json['completed_orders'] as int?) ?? 0,
      totalQuantity: (json['total_quantity'] as int?) ?? 0,
      finishedQuantity: (json['finished_quantity'] as int?) ?? 0,
    );
  }
}

class ProductionProcessStatItem {
  ProductionProcessStatItem({
    required this.processCode,
    required this.processName,
    required this.totalOrders,
    required this.pendingOrders,
    required this.inProgressOrders,
    required this.partialOrders,
    required this.completedOrders,
    required this.totalVisibleQuantity,
    required this.totalCompletedQuantity,
  });

  final String processCode;
  final String processName;
  final int totalOrders;
  final int pendingOrders;
  final int inProgressOrders;
  final int partialOrders;
  final int completedOrders;
  final int totalVisibleQuantity;
  final int totalCompletedQuantity;

  factory ProductionProcessStatItem.fromJson(Map<String, dynamic> json) {
    return ProductionProcessStatItem(
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      totalOrders: (json['total_orders'] as int?) ?? 0,
      pendingOrders: (json['pending_orders'] as int?) ?? 0,
      inProgressOrders: (json['in_progress_orders'] as int?) ?? 0,
      partialOrders: (json['partial_orders'] as int?) ?? 0,
      completedOrders: (json['completed_orders'] as int?) ?? 0,
      totalVisibleQuantity: (json['total_visible_quantity'] as int?) ?? 0,
      totalCompletedQuantity: (json['total_completed_quantity'] as int?) ?? 0,
    );
  }
}

class ProductionOperatorStatItem {
  ProductionOperatorStatItem({
    required this.operatorUserId,
    required this.operatorUsername,
    required this.processCode,
    required this.processName,
    required this.productionRecords,
    required this.productionQuantity,
    required this.lastProductionAt,
  });

  final int operatorUserId;
  final String operatorUsername;
  final String processCode;
  final String processName;
  final int productionRecords;
  final int productionQuantity;
  final DateTime? lastProductionAt;

  factory ProductionOperatorStatItem.fromJson(Map<String, dynamic> json) {
    return ProductionOperatorStatItem(
      operatorUserId: (json['operator_user_id'] as int?) ?? 0,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      productionRecords: (json['production_records'] as int?) ?? 0,
      productionQuantity: (json['production_quantity'] as int?) ?? 0,
      lastProductionAt: _parseDateOrNull(json['last_production_at']),
    );
  }
}

class ProductionProductOption {
  ProductionProductOption({required this.id, required this.name});

  final int id;
  final String name;

  factory ProductionProductOption.fromJson(Map<String, dynamic> json) {
    return ProductionProductOption(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
    );
  }
}

class ProductionProcessOption {
  ProductionProcessOption({
    required this.id,
    required this.code,
    required this.name,
    required this.stageId,
    required this.stageCode,
    required this.stageName,
  });

  final int id;
  final String code;
  final String name;
  final int? stageId;
  final String? stageCode;
  final String? stageName;

  factory ProductionProcessOption.fromJson(Map<String, dynamic> json) {
    return ProductionProcessOption(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      stageId: json['stage_id'] as int?,
      stageCode: json['stage_code'] as String?,
      stageName: json['stage_name'] as String?,
    );
  }
}

class ProductionOrderProcessStepInput {
  const ProductionOrderProcessStepInput({
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
