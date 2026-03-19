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

String assistAuthorizationStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return '待审批';
    case 'approved':
      return '已审批';
    case 'rejected':
      return '已拒绝';
    case 'consumed':
      return '已消耗';
    default:
      return status;
  }
}

String repairOrderStatusLabel(String status) {
  switch (status) {
    case 'in_repair':
      return '维修中';
    case 'completed':
      return '维修完成';
    default:
      return status;
  }
}

String scrapProgressLabel(String status) {
  switch (status) {
    case 'pending_apply':
      return '待处理';
    case 'applied':
      return '已处理';
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
    required this.productVersion,
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
    required this.pipelineEnabled,
    required this.pipelineProcessCodes,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String orderCode;
  final int productId;
  final String productName;
  final int? productVersion;
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
  final bool pipelineEnabled;
  final List<String> pipelineProcessCodes;
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
      productVersion: json['product_version'] as int?,
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
      pipelineEnabled: (json['pipeline_enabled'] as bool?) ?? false,
      pipelineProcessCodes:
          (json['pipeline_process_codes'] as List<dynamic>? ?? const [])
              .map((entry) => entry.toString())
              .toList(),
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
    required this.orderId,
    required this.orderCode,
    required this.orderStatus,
    required this.productName,
    required this.processCode,
    required this.eventType,
    required this.eventTitle,
    required this.eventDetail,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.payloadJson,
    required this.createdAt,
  });

  final int id;
  final int? orderId;
  final String? orderCode;
  final String? orderStatus;
  final String? productName;
  final String? processCode;
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
      orderId: json['order_id'] as int?,
      orderCode: json['order_code'] as String?,
      orderStatus: json['order_status'] as String?,
      productName: json['product_name'] as String?,
      processCode: json['process_code'] as String?,
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
    required this.operatorUserId,
    required this.operatorUsername,
    required this.workView,
    required this.assistAuthorizationId,
    required this.pipelineModeEnabled,
    required this.pipelineStartAllowed,
    required this.pipelineEndAllowed,
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
  final int? operatorUserId;
  final String? operatorUsername;
  final String workView;
  final int? assistAuthorizationId;
  final bool pipelineModeEnabled;
  final bool pipelineStartAllowed;
  final bool pipelineEndAllowed;
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
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: json['operator_username'] as String?,
      workView: (json['work_view'] as String?) ?? 'own',
      assistAuthorizationId: json['assist_authorization_id'] as int?,
      pipelineModeEnabled: (json['pipeline_mode_enabled'] as bool?) ?? false,
      pipelineStartAllowed: (json['pipeline_start_allowed'] as bool?) ?? false,
      pipelineEndAllowed: (json['pipeline_end_allowed'] as bool?) ?? false,
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

class MyOrderContextResult {
  MyOrderContextResult({required this.found, required this.item});

  final bool found;
  final MyOrderItem? item;

  factory MyOrderContextResult.fromJson(Map<String, dynamic> json) {
    return MyOrderContextResult(
      found: (json['found'] as bool?) ?? false,
      item: json['item'] is Map<String, dynamic>
          ? MyOrderItem.fromJson(json['item'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OrderPipelineModeItem {
  OrderPipelineModeItem({
    required this.orderId,
    required this.enabled,
    required this.processCodes,
    required this.availableProcessCodes,
  });

  final int orderId;
  final bool enabled;
  final List<String> processCodes;
  final List<String> availableProcessCodes;

  factory OrderPipelineModeItem.fromJson(Map<String, dynamic> json) {
    return OrderPipelineModeItem(
      orderId: (json['order_id'] as int?) ?? 0,
      enabled: (json['enabled'] as bool?) ?? false,
      processCodes: (json['process_codes'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      availableProcessCodes:
          (json['available_process_codes'] as List<dynamic>? ?? const [])
              .map((entry) => entry.toString())
              .toList(),
    );
  }
}

class PipelineInstanceItem {
  PipelineInstanceItem({
    required this.id,
    required this.subOrderId,
    required this.orderId,
    required this.orderCode,
    required this.orderProcessId,
    required this.processCode,
    required this.pipelineSeq,
    required this.pipelineSubOrderNo,
    required this.isActive,
    required this.invalidReason,
    required this.invalidatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int subOrderId;
  final int orderId;
  final String orderCode;
  final int orderProcessId;
  final String processCode;
  final int pipelineSeq;
  final String pipelineSubOrderNo;
  final bool isActive;
  final String? invalidReason;
  final DateTime? invalidatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PipelineInstanceItem.fromJson(Map<String, dynamic> json) {
    return PipelineInstanceItem(
      id: json['id'] as int,
      subOrderId: (json['sub_order_id'] as int?) ?? 0,
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      orderProcessId: (json['order_process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      pipelineSeq: (json['pipeline_seq'] as int?) ?? 0,
      pipelineSubOrderNo: (json['pipeline_sub_order_no'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? false,
      invalidReason: json['invalid_reason'] as String?,
      invalidatedAt: json['invalidated_at'] != null
          ? DateTime.tryParse(json['invalidated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class PipelineInstanceListResult {
  PipelineInstanceListResult({required this.total, required this.items});

  final int total;
  final List<PipelineInstanceItem> items;
}

class AssistAuthorizationItem {
  AssistAuthorizationItem({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.orderProcessId,
    required this.processCode,
    required this.processName,
    required this.targetOperatorUserId,
    required this.targetOperatorUsername,
    required this.requesterUserId,
    required this.requesterUsername,
    required this.helperUserId,
    required this.helperUsername,
    required this.status,
    required this.reason,
    required this.reviewRemark,
    required this.reviewerUserId,
    required this.reviewerUsername,
    required this.reviewedAt,
    required this.firstArticleUsedAt,
    required this.endProductionUsedAt,
    required this.consumedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int orderId;
  final String orderCode;
  final int orderProcessId;
  final String processCode;
  final String processName;
  final int targetOperatorUserId;
  final String targetOperatorUsername;
  final int requesterUserId;
  final String requesterUsername;
  final int helperUserId;
  final String helperUsername;
  final String status;
  final String? reason;
  final String? reviewRemark;
  final int? reviewerUserId;
  final String? reviewerUsername;
  final DateTime? reviewedAt;
  final DateTime? firstArticleUsedAt;
  final DateTime? endProductionUsedAt;
  final DateTime? consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AssistAuthorizationItem.fromJson(Map<String, dynamic> json) {
    return AssistAuthorizationItem(
      id: json['id'] as int,
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      orderProcessId: (json['order_process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      targetOperatorUserId: (json['target_operator_user_id'] as int?) ?? 0,
      targetOperatorUsername:
          (json['target_operator_username'] as String?) ?? '',
      requesterUserId: (json['requester_user_id'] as int?) ?? 0,
      requesterUsername: (json['requester_username'] as String?) ?? '',
      helperUserId: (json['helper_user_id'] as int?) ?? 0,
      helperUsername: (json['helper_username'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      reason: json['reason'] as String?,
      reviewRemark: json['review_remark'] as String?,
      reviewerUserId: json['reviewer_user_id'] as int?,
      reviewerUsername: json['reviewer_username'] as String?,
      reviewedAt: _parseDateOrNull(json['reviewed_at']),
      firstArticleUsedAt: _parseDateOrNull(json['first_article_used_at']),
      endProductionUsedAt: _parseDateOrNull(json['end_production_used_at']),
      consumedAt: _parseDateOrNull(json['consumed_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class AssistAuthorizationListResult {
  AssistAuthorizationListResult({required this.total, required this.items});

  final int total;
  final List<AssistAuthorizationItem> items;
}

class AssistUserOptionItem {
  AssistUserOptionItem({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleCodes,
  });

  final int id;
  final String username;
  final String? fullName;
  final List<String> roleCodes;

  String get displayName {
    final normalized = (fullName ?? '').trim();
    if (normalized.isEmpty) {
      return username;
    }
    return '$username ($normalized)';
  }

  factory AssistUserOptionItem.fromJson(Map<String, dynamic> json) {
    return AssistUserOptionItem(
      id: json['id'] as int,
      username: (json['username'] as String?) ?? '',
      fullName: json['full_name'] as String?,
      roleCodes: (json['role_codes'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
    );
  }
}

class AssistUserOptionListResult {
  AssistUserOptionListResult({required this.total, required this.items});

  final int total;
  final List<AssistUserOptionItem> items;
}

class ProductionDefectItemInput {
  const ProductionDefectItemInput({
    required this.phenomenon,
    required this.quantity,
  });

  final String phenomenon;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {'phenomenon': phenomenon, 'quantity': quantity};
  }
}

class RepairCauseItemInput {
  const RepairCauseItemInput({
    required this.phenomenon,
    required this.reason,
    required this.quantity,
    required this.isScrap,
  });

  final String phenomenon;
  final String reason;
  final int quantity;
  final bool isScrap;

  Map<String, dynamic> toJson() {
    return {
      'phenomenon': phenomenon,
      'reason': reason,
      'quantity': quantity,
      'is_scrap': isScrap,
    };
  }
}

class RepairReturnAllocationInput {
  const RepairReturnAllocationInput({
    required this.targetOrderProcessId,
    required this.quantity,
  });

  final int targetOrderProcessId;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
      'target_order_process_id': targetOrderProcessId,
      'quantity': quantity,
    };
  }
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

class ProductionTodayRealtimeRow {
  ProductionTodayRealtimeRow({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.latestTime,
    required this.latestTimeText,
  });

  final int productId;
  final String productName;
  final int quantity;
  final DateTime? latestTime;
  final String latestTimeText;

  factory ProductionTodayRealtimeRow.fromJson(Map<String, dynamic> json) {
    return ProductionTodayRealtimeRow(
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      latestTime: _parseDateOrNull(json['latest_time']),
      latestTimeText: (json['latest_time_text'] as String?) ?? '',
    );
  }
}

class ProductionTodayRealtimeChartItem {
  ProductionTodayRealtimeChartItem({required this.label, required this.value});

  final String label;
  final int value;

  factory ProductionTodayRealtimeChartItem.fromJson(Map<String, dynamic> json) {
    return ProductionTodayRealtimeChartItem(
      label: (json['label'] as String?) ?? '',
      value: (json['value'] as int?) ?? 0,
    );
  }
}

class ProductionTodayRealtimeSummary {
  ProductionTodayRealtimeSummary({
    required this.totalProducts,
    required this.totalQuantity,
  });

  final int totalProducts;
  final int totalQuantity;

  factory ProductionTodayRealtimeSummary.fromJson(Map<String, dynamic> json) {
    return ProductionTodayRealtimeSummary(
      totalProducts: (json['total_products'] as int?) ?? 0,
      totalQuantity: (json['total_quantity'] as int?) ?? 0,
    );
  }
}

class ProductionTodayRealtimeResult {
  ProductionTodayRealtimeResult({
    required this.statMode,
    required this.summary,
    required this.tableRows,
    required this.chartData,
    required this.querySignature,
  });

  final String statMode;
  final ProductionTodayRealtimeSummary summary;
  final List<ProductionTodayRealtimeRow> tableRows;
  final List<ProductionTodayRealtimeChartItem> chartData;
  final String querySignature;

  factory ProductionTodayRealtimeResult.fromJson(Map<String, dynamic> json) {
    return ProductionTodayRealtimeResult(
      statMode: (json['stat_mode'] as String?) ?? 'main_order',
      summary: ProductionTodayRealtimeSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      tableRows: (json['table_rows'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ProductionTodayRealtimeRow.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      chartData: (json['chart_data'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ProductionTodayRealtimeChartItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      querySignature: (json['query_signature'] as String?) ?? '',
    );
  }
}

class ProductionUnfinishedProgressRow {
  ProductionUnfinishedProgressRow({
    required this.orderId,
    required this.orderCode,
    required this.productId,
    required this.productName,
    required this.orderStatus,
    required this.currentProcessName,
    required this.remainingQuantity,
    required this.processCount,
    required this.producedTotal,
    required this.targetTotal,
    required this.progressPercent,
  });

  final int orderId;
  final String orderCode;
  final int productId;
  final String productName;
  final String orderStatus;
  final String currentProcessName;
  final int remainingQuantity;
  final int processCount;
  final int producedTotal;
  final int targetTotal;
  final double progressPercent;

  factory ProductionUnfinishedProgressRow.fromJson(Map<String, dynamic> json) {
    return ProductionUnfinishedProgressRow(
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      orderStatus: (json['order_status'] as String?) ?? '',
      currentProcessName: (json['current_process_name'] as String?) ?? '',
      remainingQuantity: (json['remaining_quantity'] as int?) ?? 0,
      processCount: (json['process_count'] as int?) ?? 0,
      producedTotal: (json['produced_total'] as int?) ?? 0,
      targetTotal: (json['target_total'] as int?) ?? 0,
      progressPercent: ((json['progress_percent'] as num?) ?? 0).toDouble(),
    );
  }
}

class ProductionUnfinishedProgressSummary {
  ProductionUnfinishedProgressSummary({
    required this.totalOrders,
    required this.avgProgressPercent,
  });

  final int totalOrders;
  final double avgProgressPercent;

  factory ProductionUnfinishedProgressSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProductionUnfinishedProgressSummary(
      totalOrders: (json['total_orders'] as int?) ?? 0,
      avgProgressPercent: ((json['avg_progress_percent'] as num?) ?? 0)
          .toDouble(),
    );
  }
}

class ProductionUnfinishedProgressResult {
  ProductionUnfinishedProgressResult({
    required this.summary,
    required this.tableRows,
    required this.querySignature,
  });

  final ProductionUnfinishedProgressSummary summary;
  final List<ProductionUnfinishedProgressRow> tableRows;
  final String querySignature;

  factory ProductionUnfinishedProgressResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProductionUnfinishedProgressResult(
      summary: ProductionUnfinishedProgressSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      tableRows: (json['table_rows'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ProductionUnfinishedProgressRow.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      querySignature: (json['query_signature'] as String?) ?? '',
    );
  }
}

class ProductionManualRow {
  ProductionManualRow({
    required this.orderId,
    required this.orderCode,
    required this.productId,
    required this.productName,
    required this.stageId,
    required this.stageCode,
    required this.stageName,
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.quantity,
    required this.productionTime,
    required this.productionTimeText,
    required this.orderStatus,
  });

  final int orderId;
  final String orderCode;
  final int productId;
  final String productName;
  final int? stageId;
  final String? stageCode;
  final String? stageName;
  final int processId;
  final String processCode;
  final String processName;
  final int? operatorUserId;
  final String operatorUsername;
  final int quantity;
  final DateTime? productionTime;
  final String productionTimeText;
  final String orderStatus;

  factory ProductionManualRow.fromJson(Map<String, dynamic> json) {
    return ProductionManualRow(
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      stageId: json['stage_id'] as int?,
      stageCode: json['stage_code'] as String?,
      stageName: json['stage_name'] as String?,
      processId: (json['process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      productionTime: _parseDateOrNull(json['production_time']),
      productionTimeText: (json['production_time_text'] as String?) ?? '',
      orderStatus: (json['order_status'] as String?) ?? '',
    );
  }
}

class ProductionManualModelChartItem {
  ProductionManualModelChartItem({
    required this.productName,
    required this.quantity,
  });

  final String productName;
  final int quantity;

  factory ProductionManualModelChartItem.fromJson(Map<String, dynamic> json) {
    return ProductionManualModelChartItem(
      productName: (json['product_name'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class ProductionManualTrendChartItem {
  ProductionManualTrendChartItem({
    required this.bucket,
    required this.quantity,
  });

  final String bucket;
  final int quantity;

  factory ProductionManualTrendChartItem.fromJson(Map<String, dynamic> json) {
    return ProductionManualTrendChartItem(
      bucket: (json['bucket'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class ProductionManualPieChartItem {
  ProductionManualPieChartItem({required this.name, required this.quantity});

  final String name;
  final int quantity;

  factory ProductionManualPieChartItem.fromJson(Map<String, dynamic> json) {
    return ProductionManualPieChartItem(
      name: (json['name'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class ProductionManualChartData {
  ProductionManualChartData({
    required this.singleDay,
    required this.modelOutput,
    required this.trendOutput,
    required this.pieOutput,
  });

  final bool singleDay;
  final List<ProductionManualModelChartItem> modelOutput;
  final List<ProductionManualTrendChartItem> trendOutput;
  final List<ProductionManualPieChartItem> pieOutput;

  factory ProductionManualChartData.fromJson(Map<String, dynamic> json) {
    return ProductionManualChartData(
      singleDay: (json['single_day'] as bool?) ?? false,
      modelOutput: (json['model_output'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ProductionManualModelChartItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      trendOutput: (json['trend_output'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ProductionManualTrendChartItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      pieOutput: (json['pie_output'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ProductionManualPieChartItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class ProductionManualSummary {
  ProductionManualSummary({
    required this.rows,
    required this.filteredTotal,
    required this.timeRangeTotal,
    required this.ratioPercent,
  });

  final int rows;
  final int filteredTotal;
  final int timeRangeTotal;
  final double ratioPercent;

  factory ProductionManualSummary.fromJson(Map<String, dynamic> json) {
    return ProductionManualSummary(
      rows: (json['rows'] as int?) ?? 0,
      filteredTotal: (json['filtered_total'] as int?) ?? 0,
      timeRangeTotal: (json['time_range_total'] as int?) ?? 0,
      ratioPercent: ((json['ratio_percent'] as num?) ?? 0).toDouble(),
    );
  }
}

class ProductionManualQueryResult {
  ProductionManualQueryResult({
    required this.statMode,
    required this.summary,
    required this.tableRows,
    required this.chartData,
    required this.querySignature,
  });

  final String statMode;
  final ProductionManualSummary summary;
  final List<ProductionManualRow> tableRows;
  final ProductionManualChartData chartData;
  final String querySignature;

  factory ProductionManualQueryResult.fromJson(Map<String, dynamic> json) {
    return ProductionManualQueryResult(
      statMode: (json['stat_mode'] as String?) ?? 'main_order',
      summary: ProductionManualSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      tableRows: (json['table_rows'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductionManualRow.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      chartData: ProductionManualChartData.fromJson(
        json['chart_data'] as Map<String, dynamic>? ?? const {},
      ),
      querySignature: (json['query_signature'] as String?) ?? '',
    );
  }
}

class ProductionManualExportResult {
  ProductionManualExportResult({
    required this.fileName,
    required this.mimeType,
    required this.contentBase64,
  });

  final String fileName;
  final String mimeType;
  final String contentBase64;

  factory ProductionManualExportResult.fromJson(Map<String, dynamic> json) {
    return ProductionManualExportResult(
      fileName: (json['file_name'] as String?) ?? '',
      mimeType: (json['mime_type'] as String?) ?? 'text/csv',
      contentBase64: (json['content_base64'] as String?) ?? '',
    );
  }
}

class RepairOrderItem {
  RepairOrderItem({
    required this.id,
    required this.repairOrderCode,
    required this.sourceOrderId,
    required this.sourceOrderCode,
    required this.productId,
    required this.productName,
    required this.sourceOrderProcessId,
    required this.sourceProcessCode,
    required this.sourceProcessName,
    required this.senderUserId,
    required this.senderUsername,
    required this.productionQuantity,
    required this.repairQuantity,
    required this.repairedQuantity,
    required this.scrapQuantity,
    required this.scrapReplenished,
    required this.repairTime,
    required this.status,
    required this.completedAt,
    required this.repairOperatorUserId,
    required this.repairOperatorUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String repairOrderCode;
  final int? sourceOrderId;
  final String? sourceOrderCode;
  final int? productId;
  final String? productName;
  final int? sourceOrderProcessId;
  final String sourceProcessCode;
  final String sourceProcessName;
  final int? senderUserId;
  final String? senderUsername;
  final int productionQuantity;
  final int repairQuantity;
  final int repairedQuantity;
  final int scrapQuantity;
  final bool scrapReplenished;
  final DateTime repairTime;
  final String status;
  final DateTime? completedAt;
  final int? repairOperatorUserId;
  final String? repairOperatorUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RepairOrderItem.fromJson(Map<String, dynamic> json) {
    return RepairOrderItem(
      id: (json['id'] as int?) ?? 0,
      repairOrderCode: (json['repair_order_code'] as String?) ?? '',
      sourceOrderId: json['source_order_id'] as int?,
      sourceOrderCode: json['source_order_code'] as String?,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String?,
      sourceOrderProcessId: json['source_order_process_id'] as int?,
      sourceProcessCode: (json['source_process_code'] as String?) ?? '',
      sourceProcessName: (json['source_process_name'] as String?) ?? '',
      senderUserId: json['sender_user_id'] as int?,
      senderUsername: json['sender_username'] as String?,
      productionQuantity: (json['production_quantity'] as int?) ?? 0,
      repairQuantity: (json['repair_quantity'] as int?) ?? 0,
      repairedQuantity: (json['repaired_quantity'] as int?) ?? 0,
      scrapQuantity: (json['scrap_quantity'] as int?) ?? 0,
      scrapReplenished: (json['scrap_replenished'] as bool?) ?? false,
      repairTime: DateTime.parse(json['repair_time'] as String),
      status: (json['status'] as String?) ?? 'in_repair',
      completedAt: _parseDateOrNull(json['completed_at']),
      repairOperatorUserId: json['repair_operator_user_id'] as int?,
      repairOperatorUsername: json['repair_operator_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class RepairOrderListResult {
  RepairOrderListResult({required this.total, required this.items});

  final int total;
  final List<RepairOrderItem> items;
}

class RepairOrderPhenomenonSummaryItem {
  RepairOrderPhenomenonSummaryItem({
    required this.phenomenon,
    required this.quantity,
  });

  final String phenomenon;
  final int quantity;

  factory RepairOrderPhenomenonSummaryItem.fromJson(Map<String, dynamic> json) {
    return RepairOrderPhenomenonSummaryItem(
      phenomenon: (json['phenomenon'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class RepairOrderPhenomenaSummaryResult {
  RepairOrderPhenomenaSummaryResult({
    required this.repairOrderId,
    required this.items,
  });

  final int repairOrderId;
  final List<RepairOrderPhenomenonSummaryItem> items;

  factory RepairOrderPhenomenaSummaryResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return RepairOrderPhenomenaSummaryResult(
      repairOrderId: (json['repair_order_id'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) => RepairOrderPhenomenonSummaryItem.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class ScrapStatisticsItem {
  ScrapStatisticsItem({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.productId,
    required this.productName,
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.scrapReason,
    required this.scrapQuantity,
    required this.lastScrapTime,
    required this.progress,
    required this.appliedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.relatedRepairOrders,
  });

  final int id;
  final int? orderId;
  final String? orderCode;
  final int? productId;
  final String? productName;
  final int? processId;
  final String? processCode;
  final String? processName;
  final String scrapReason;
  final int scrapQuantity;
  final DateTime? lastScrapTime;
  final String progress;
  final DateTime? appliedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ScrapRelatedRepairOrderItem> relatedRepairOrders;

  factory ScrapStatisticsItem.fromJson(Map<String, dynamic> json) {
    return ScrapStatisticsItem(
      id: (json['id'] as int?) ?? 0,
      orderId: json['order_id'] as int?,
      orderCode: json['order_code'] as String?,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String?,
      processId: json['process_id'] as int?,
      processCode: json['process_code'] as String?,
      processName: json['process_name'] as String?,
      scrapReason: (json['scrap_reason'] as String?) ?? '',
      scrapQuantity: (json['scrap_quantity'] as int?) ?? 0,
      lastScrapTime: _parseDateOrNull(json['last_scrap_time']),
      progress: (json['progress'] as String?) ?? 'pending_apply',
      appliedAt: _parseDateOrNull(json['applied_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      relatedRepairOrders:
          (json['related_repair_orders'] as List<dynamic>? ?? const [])
              .map(
                (entry) => ScrapRelatedRepairOrderItem.fromJson(
                  entry as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class ScrapRelatedRepairOrderItem {
  ScrapRelatedRepairOrderItem({
    required this.id,
    required this.repairOrderCode,
    required this.status,
    required this.repairQuantity,
    required this.repairedQuantity,
    required this.scrapQuantity,
    required this.repairTime,
    required this.completedAt,
  });

  final int id;
  final String repairOrderCode;
  final String status;
  final int repairQuantity;
  final int repairedQuantity;
  final int scrapQuantity;
  final DateTime repairTime;
  final DateTime? completedAt;

  factory ScrapRelatedRepairOrderItem.fromJson(Map<String, dynamic> json) {
    return ScrapRelatedRepairOrderItem(
      id: (json['id'] as int?) ?? 0,
      repairOrderCode: (json['repair_order_code'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      repairQuantity: (json['repair_quantity'] as int?) ?? 0,
      repairedQuantity: (json['repaired_quantity'] as int?) ?? 0,
      scrapQuantity: (json['scrap_quantity'] as int?) ?? 0,
      repairTime: DateTime.parse(json['repair_time'] as String),
      completedAt: _parseDateOrNull(json['completed_at']),
    );
  }
}

class ScrapStatisticsListResult {
  ScrapStatisticsListResult({required this.total, required this.items});

  final int total;
  final List<ScrapStatisticsItem> items;
}

class ProductionExportResult {
  ProductionExportResult({
    required this.fileName,
    required this.mimeType,
    required this.contentBase64,
    required this.exportedCount,
  });

  final String fileName;
  final String mimeType;
  final String contentBase64;
  final int exportedCount;

  factory ProductionExportResult.fromJson(Map<String, dynamic> json) {
    return ProductionExportResult(
      fileName: (json['file_name'] as String?) ?? '',
      mimeType: (json['mime_type'] as String?) ?? 'text/csv',
      contentBase64: (json['content_base64'] as String?) ?? '',
      exportedCount: (json['exported_count'] as int?) ?? 0,
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

class RepairDefectPhenomenonDetailItem {
  RepairDefectPhenomenonDetailItem({
    required this.id,
    required this.phenomenon,
    required this.quantity,
  });

  final int id;
  final String phenomenon;
  final int quantity;

  factory RepairDefectPhenomenonDetailItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return RepairDefectPhenomenonDetailItem(
      id: (json['id'] as int?) ?? 0,
      phenomenon: (json['phenomenon'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class RepairCauseDetailItem {
  RepairCauseDetailItem({
    required this.id,
    required this.phenomenon,
    required this.reason,
    required this.quantity,
    required this.isScrap,
  });

  final int id;
  final String phenomenon;
  final String reason;
  final int quantity;
  final bool isScrap;

  factory RepairCauseDetailItem.fromJson(Map<String, dynamic> json) {
    return RepairCauseDetailItem(
      id: (json['id'] as int?) ?? 0,
      phenomenon: (json['phenomenon'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      isScrap: (json['is_scrap'] as bool?) ?? false,
    );
  }
}

class RepairReturnRouteDetailItem {
  RepairReturnRouteDetailItem({
    required this.id,
    required this.targetProcessId,
    required this.targetProcessCode,
    required this.targetProcessName,
    required this.returnQuantity,
  });

  final int id;
  final int? targetProcessId;
  final String targetProcessCode;
  final String targetProcessName;
  final int returnQuantity;

  factory RepairReturnRouteDetailItem.fromJson(Map<String, dynamic> json) {
    return RepairReturnRouteDetailItem(
      id: (json['id'] as int?) ?? 0,
      targetProcessId: json['target_process_id'] as int?,
      targetProcessCode: (json['target_process_code'] as String?) ?? '',
      targetProcessName: (json['target_process_name'] as String?) ?? '',
      returnQuantity: (json['return_quantity'] as int?) ?? 0,
    );
  }
}

class RepairOrderDetailItem {
  RepairOrderDetailItem({
    required this.id,
    required this.repairOrderCode,
    required this.sourceOrderId,
    required this.sourceOrderCode,
    required this.productId,
    required this.productName,
    required this.sourceOrderProcessId,
    required this.sourceProcessCode,
    required this.sourceProcessName,
    required this.senderUserId,
    required this.senderUsername,
    required this.productionQuantity,
    required this.repairQuantity,
    required this.repairedQuantity,
    required this.scrapQuantity,
    required this.scrapReplenished,
    required this.repairTime,
    required this.status,
    required this.completedAt,
    required this.repairOperatorUserId,
    required this.repairOperatorUsername,
    required this.defectRows,
    required this.causeRows,
    required this.returnRoutes,
    required this.eventLogs,
  });

  final int id;
  final String repairOrderCode;
  final int? sourceOrderId;
  final String? sourceOrderCode;
  final int? productId;
  final String? productName;
  final int? sourceOrderProcessId;
  final String sourceProcessCode;
  final String sourceProcessName;
  final int? senderUserId;
  final String? senderUsername;
  final int productionQuantity;
  final int repairQuantity;
  final int repairedQuantity;
  final int scrapQuantity;
  final bool scrapReplenished;
  final DateTime repairTime;
  final String status;
  final DateTime? completedAt;
  final int? repairOperatorUserId;
  final String? repairOperatorUsername;
  final List<RepairDefectPhenomenonDetailItem> defectRows;
  final List<RepairCauseDetailItem> causeRows;
  final List<RepairReturnRouteDetailItem> returnRoutes;
  final List<RepairEventLogDetailItem> eventLogs;

  factory RepairOrderDetailItem.fromJson(Map<String, dynamic> json) {
    return RepairOrderDetailItem(
      id: (json['id'] as int?) ?? 0,
      repairOrderCode: (json['repair_order_code'] as String?) ?? '',
      sourceOrderId: json['source_order_id'] as int?,
      sourceOrderCode: json['source_order_code'] as String?,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String?,
      sourceOrderProcessId: json['source_order_process_id'] as int?,
      sourceProcessCode: (json['source_process_code'] as String?) ?? '',
      sourceProcessName: (json['source_process_name'] as String?) ?? '',
      senderUserId: json['sender_user_id'] as int?,
      senderUsername: json['sender_username'] as String?,
      productionQuantity: (json['production_quantity'] as int?) ?? 0,
      repairQuantity: (json['repair_quantity'] as int?) ?? 0,
      repairedQuantity: (json['repaired_quantity'] as int?) ?? 0,
      scrapQuantity: (json['scrap_quantity'] as int?) ?? 0,
      scrapReplenished: (json['scrap_replenished'] as bool?) ?? false,
      repairTime: DateTime.parse(json['repair_time'] as String),
      status: (json['status'] as String?) ?? 'in_repair',
      completedAt: _parseDateOrNull(json['completed_at']),
      repairOperatorUserId: json['repair_operator_user_id'] as int?,
      repairOperatorUsername: json['repair_operator_username'] as String?,
      defectRows: (json['defect_rows'] as List<dynamic>? ?? const [])
          .map(
            (e) => RepairDefectPhenomenonDetailItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      causeRows: (json['cause_rows'] as List<dynamic>? ?? const [])
          .map(
            (e) => RepairCauseDetailItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      returnRoutes: (json['return_routes'] as List<dynamic>? ?? const [])
          .map(
            (e) => RepairReturnRouteDetailItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      eventLogs: (json['event_logs'] as List<dynamic>? ?? const [])
          .map(
            (e) => RepairEventLogDetailItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class RepairEventLogDetailItem {
  RepairEventLogDetailItem({
    required this.id,
    required this.eventType,
    required this.eventTitle,
    required this.eventDetail,
    required this.createdAt,
  });

  final int id;
  final String eventType;
  final String eventTitle;
  final String? eventDetail;
  final DateTime createdAt;

  factory RepairEventLogDetailItem.fromJson(Map<String, dynamic> json) {
    return RepairEventLogDetailItem(
      id: (json['id'] as int?) ?? 0,
      eventType: (json['event_type'] as String?) ?? '',
      eventTitle: (json['event_title'] as String?) ?? '',
      eventDetail: json['event_detail'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
