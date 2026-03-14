class MessageItem {
  const MessageItem({
    required this.id,
    required this.messageType,
    required this.priority,
    required this.title,
    required this.summary,
    required this.sourceModule,
    required this.sourceType,
    required this.sourceCode,
    required this.targetPageCode,
    required this.targetTabCode,
    required this.targetRoutePayloadJson,
    required this.status,
    required this.publishedAt,
    required this.isRead,
    required this.readAt,
    required this.deliveredAt,
  });

  final int id;
  final String messageType;
  final String priority;
  final String title;
  final String? summary;
  final String? sourceModule;
  final String? sourceType;
  final String? sourceCode;
  final String? targetPageCode;
  final String? targetTabCode;
  final String? targetRoutePayloadJson;
  final String status;
  final DateTime? publishedAt;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? deliveredAt;

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] as int,
      messageType: json['message_type'] as String,
      priority: json['priority'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      sourceModule: json['source_module'] as String?,
      sourceType: json['source_type'] as String?,
      sourceCode: json['source_code'] as String?,
      targetPageCode: json['target_page_code'] as String?,
      targetTabCode: json['target_tab_code'] as String?,
      targetRoutePayloadJson: json['target_route_payload_json'] as String?,
      status: json['status'] as String,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      isRead: (json['is_read'] as bool?) ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'] as String)
          : null,
    );
  }

  String get messageTypeName {
    switch (messageType) {
      case 'todo':
        return '待处理';
      case 'notice':
        return '通知';
      case 'announcement':
        return '公告';
      case 'warning':
        return '预警';
      default:
        return messageType;
    }
  }

  String get priorityName {
    switch (priority) {
      case 'urgent':
        return '紧急';
      case 'important':
        return '重要';
      default:
        return '普通';
    }
  }

  String get sourceModuleName {
    switch (sourceModule) {
      case 'user':
        return '用户';
      case 'production':
        return '生产';
      case 'equipment':
        return '设备';
      case 'quality':
        return '品质';
      case 'craft':
        return '工艺';
      case 'product':
        return '产品';
      default:
        return sourceModule ?? '';
    }
  }
}

class MessageListResult {
  const MessageListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<MessageItem> items;
  final int total;
  final int page;
  final int pageSize;

  factory MessageListResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return MessageListResult(
      items: rawItems
          .map((e) => MessageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as int?) ?? 0,
      page: (json['page'] as int?) ?? 1,
      pageSize: (json['page_size'] as int?) ?? 20,
    );
  }
}

class WsEvent {
  const WsEvent({
    required this.event,
    required this.userId,
    this.unreadCount,
    this.messageId,
  });

  final String event;
  final int userId;
  final int? unreadCount;
  final int? messageId;

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      event: json['event'] as String? ?? '',
      userId: (json['user_id'] as int?) ?? 0,
      unreadCount: json['unread_count'] as int?,
      messageId: json['message_id'] as int?,
    );
  }
}
