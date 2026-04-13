class HomeDashboardTodoSummary {
  const HomeDashboardTodoSummary({
    required this.totalCount,
    required this.pendingApprovalCount,
    required this.highPriorityCount,
    required this.exceptionCount,
    required this.overdueCount,
  });

  final int totalCount;
  final int pendingApprovalCount;
  final int highPriorityCount;
  final int exceptionCount;
  final int overdueCount;

  factory HomeDashboardTodoSummary.fromJson(Map<String, dynamic> json) {
    return HomeDashboardTodoSummary(
      totalCount: _asInt(json['total_count']),
      pendingApprovalCount: _asInt(json['pending_approval_count']),
      highPriorityCount: _asInt(json['high_priority_count']),
      exceptionCount: _asInt(json['exception_count']),
      overdueCount: _asInt(json['overdue_count']),
    );
  }
}

class HomeDashboardMetricItem {
  const HomeDashboardMetricItem({
    required this.code,
    required this.label,
    required this.value,
    this.targetPageCode,
    this.targetTabCode,
    this.targetRoutePayloadJson,
  });

  final String code;
  final String label;
  final String value;
  final String? targetPageCode;
  final String? targetTabCode;
  final String? targetRoutePayloadJson;

  factory HomeDashboardMetricItem.fromJson(Map<String, dynamic> json) {
    return HomeDashboardMetricItem(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      targetPageCode: json['target_page_code'] as String?,
      targetTabCode: json['target_tab_code'] as String?,
      targetRoutePayloadJson: json['target_route_payload_json'] as String?,
    );
  }
}

class HomeDashboardTodoItem {
  const HomeDashboardTodoItem({
    required this.id,
    required this.title,
    required this.categoryLabel,
    required this.priorityLabel,
    this.sourceModule,
    this.targetPageCode,
    this.targetTabCode,
    this.targetRoutePayloadJson,
  });

  final int id;
  final String title;
  final String categoryLabel;
  final String priorityLabel;
  final String? sourceModule;
  final String? targetPageCode;
  final String? targetTabCode;
  final String? targetRoutePayloadJson;

  factory HomeDashboardTodoItem.fromJson(Map<String, dynamic> json) {
    return HomeDashboardTodoItem(
      id: _asInt(json['id']),
      title: (json['title'] ?? '').toString(),
      categoryLabel: (json['category_label'] ?? '').toString(),
      priorityLabel: (json['priority_label'] ?? '').toString(),
      sourceModule: json['source_module'] as String?,
      targetPageCode: json['target_page_code'] as String?,
      targetTabCode: json['target_tab_code'] as String?,
      targetRoutePayloadJson: json['target_route_payload_json'] as String?,
    );
  }
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.generatedAt,
    required this.noticeCount,
    required this.todoSummary,
    required this.todoItems,
    required this.riskItems,
    required this.kpiItems,
    required this.degradedBlocks,
  });

  final DateTime? generatedAt;
  final int noticeCount;
  final HomeDashboardTodoSummary todoSummary;
  final List<HomeDashboardTodoItem> todoItems;
  final List<HomeDashboardMetricItem> riskItems;
  final List<HomeDashboardMetricItem> kpiItems;
  final List<String> degradedBlocks;

  factory HomeDashboardData.fromJson(Map<String, dynamic> json) {
    final generatedAtRaw = json['generated_at'];
    final todoSummaryRaw = json['todo_summary'];

    return HomeDashboardData(
      generatedAt: generatedAtRaw is String ? DateTime.tryParse(generatedAtRaw) : null,
      noticeCount: _asInt(json['notice_count']),
      todoSummary: HomeDashboardTodoSummary.fromJson(
        todoSummaryRaw is Map<String, dynamic> ? todoSummaryRaw : const {},
      ),
      todoItems: _parseList(json['todo_items'])
          .map((item) => HomeDashboardTodoItem.fromJson(item))
          .toList(),
      riskItems: _parseList(json['risk_items'])
          .map((item) => HomeDashboardMetricItem.fromJson(item))
          .toList(),
      kpiItems: _parseList(json['kpi_items'])
          .map((item) => HomeDashboardMetricItem.fromJson(item))
          .toList(),
      degradedBlocks: _parseDegradedBlocks(json['degraded_blocks']),
    );
  }
}

List<Map<String, dynamic>> _parseList(dynamic raw) {
  if (raw is! List<dynamic>) {
    return const [];
  }
  return raw.whereType<Map<String, dynamic>>().toList();
}

List<String> _parseDegradedBlocks(dynamic raw) {
  if (raw is! List<dynamic>) {
    return const [];
  }
  return raw
      .map((item) {
        if (item is String) {
          return item;
        }
        if (item is Map<String, dynamic>) {
          return (item['code'] ?? '').toString();
        }
        return '';
      })
      .where((code) => code.isNotEmpty)
      .toList();
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
