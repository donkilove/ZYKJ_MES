class MessageItem {
  const MessageItem({
    required this.id,
    required this.messageType,
    required this.priority,
    required this.title,
    required this.summary,
    required this.content,
    required this.sourceModule,
    required this.sourceType,
    required this.sourceCode,
    required this.targetPageCode,
    required this.targetTabCode,
    required this.targetRoutePayloadJson,
    required this.status,
    required this.inactiveReason,
    required this.publishedAt,
    required this.expiresAt,
    required this.isRead,
    required this.readAt,
    required this.deliveredAt,
    required this.deliveryStatus,
    required this.deliveryAttemptCount,
    required this.lastPushAt,
    required this.nextRetryAt,
  });

  final int id;
  final String messageType;
  final String priority;
  final String title;
  final String? summary;
  final String? content;
  final String? sourceModule;
  final String? sourceType;
  final String? sourceCode;
  final String? targetPageCode;
  final String? targetTabCode;
  final String? targetRoutePayloadJson;
  final String status;
  final String? inactiveReason;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final String deliveryStatus;
  final int deliveryAttemptCount;
  final DateTime? lastPushAt;
  final DateTime? nextRetryAt;

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] as int,
      messageType: json['message_type'] as String,
      priority: json['priority'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      content: json['content'] as String?,
      sourceModule: json['source_module'] as String?,
      sourceType: json['source_type'] as String?,
      sourceCode: json['source_code'] as String?,
      targetPageCode: json['target_page_code'] as String?,
      targetTabCode: json['target_tab_code'] as String?,
      targetRoutePayloadJson: json['target_route_payload_json'] as String?,
      status: json['status'] as String,
      inactiveReason: json['inactive_reason'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      isRead: (json['is_read'] as bool?) ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'] as String)
          : null,
      deliveryStatus: json['delivery_status'] as String? ?? 'pending',
      deliveryAttemptCount: (json['delivery_attempt_count'] as int?) ?? 0,
      lastPushAt: json['last_push_at'] != null
          ? DateTime.tryParse(json['last_push_at'] as String)
          : null,
      nextRetryAt: json['next_retry_at'] != null
          ? DateTime.tryParse(json['next_retry_at'] as String)
          : null,
    );
  }

  bool get isActive => status == 'active';

  String? get resolvedInactiveReason {
    if (inactiveReason != null && inactiveReason!.isNotEmpty) {
      return inactiveReason;
    }
    return isActive ? null : status;
  }

  String get inactiveReasonName {
    switch (resolvedInactiveReason) {
      case 'expired':
        return '消息已过期';
      case 'archived':
        return '消息已归档';
      case 'no_permission':
        return '暂无目标页面访问权限';
      case 'missing_target':
        return '未配置业务跳转目标';
      case 'source_unavailable':
        return '来源对象不可访问';
      default:
        return '来源对象不可访问';
    }
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

  String get deliveryStatusName {
    switch (deliveryStatus) {
      case 'delivered':
        return '已投递';
      case 'failed':
        return '投递失败';
      default:
        return '待投递';
    }
  }

  String get statusName {
    switch (status) {
      case 'active':
        return '有效';
      case 'expired':
        return '已过期';
      case 'archived':
        return '已归档';
      case 'no_permission':
        return '无权限';
      case 'source_unavailable':
        return '来源失效';
      default:
        return status;
    }
  }

  String get readStatusName => isRead ? '已读' : '未读';
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

class MessageSummaryResult {
  const MessageSummaryResult({
    required this.totalCount,
    required this.unreadCount,
    required this.todoUnreadCount,
    required this.urgentUnreadCount,
  });

  final int totalCount;
  final int unreadCount;
  final int todoUnreadCount;
  final int urgentUnreadCount;

  factory MessageSummaryResult.fromJson(Map<String, dynamic> json) {
    return MessageSummaryResult(
      totalCount: (json['total_count'] as int?) ?? 0,
      unreadCount: (json['unread_count'] as int?) ?? 0,
      todoUnreadCount: (json['todo_unread_count'] as int?) ?? 0,
      urgentUnreadCount: (json['urgent_unread_count'] as int?) ?? 0,
    );
  }
}

class AnnouncementPublishRequest {
  const AnnouncementPublishRequest({
    required this.title,
    required this.content,
    required this.priority,
    required this.rangeType,
    required this.roleCodes,
    required this.userIds,
    required this.expiresAt,
  });

  final String title;
  final String content;
  final String priority;
  final String rangeType;
  final List<String> roleCodes;
  final List<int> userIds;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'priority': priority,
      'range_type': rangeType,
      'role_codes': roleCodes,
      'user_ids': userIds,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
    };
  }
}

class AnnouncementPublishResult {
  const AnnouncementPublishResult({
    required this.messageId,
    required this.recipientCount,
  });

  final int messageId;
  final int recipientCount;

  factory AnnouncementPublishResult.fromJson(Map<String, dynamic> json) {
    return AnnouncementPublishResult(
      messageId: (json['message_id'] as int?) ?? 0,
      recipientCount: (json['recipient_count'] as int?) ?? 0,
    );
  }
}

class AnnouncementOfflineResult {
  const AnnouncementOfflineResult({
    required this.messageId,
    required this.status,
  });

  final int messageId;
  final String status;

  factory AnnouncementOfflineResult.fromJson(Map<String, dynamic> json) {
    return AnnouncementOfflineResult(
      messageId: (json['message_id'] as int?) ?? 0,
      status: json['status'] as String? ?? '',
    );
  }
}

class MessageMaintenanceResult {
  const MessageMaintenanceResult({
    required this.pendingCompensated,
    required this.failedRetried,
    required this.sourceUnavailableUpdated,
    required this.archivedMessages,
  });

  final int pendingCompensated;
  final int failedRetried;
  final int sourceUnavailableUpdated;
  final int archivedMessages;

  factory MessageMaintenanceResult.fromJson(Map<String, dynamic> json) {
    return MessageMaintenanceResult(
      pendingCompensated: (json['pending_compensated'] as int?) ?? 0,
      failedRetried: (json['failed_retried'] as int?) ?? 0,
      sourceUnavailableUpdated:
          (json['source_unavailable_updated'] as int?) ?? 0,
      archivedMessages: (json['archived_messages'] as int?) ?? 0,
    );
  }
}

class MessageDetailResult {
  const MessageDetailResult({
    required this.item,
    required this.sourceId,
    required this.failureReasonHint,
  });

  final MessageItem item;
  final String? sourceId;
  final String? failureReasonHint;

  factory MessageDetailResult.fromJson(Map<String, dynamic> json) {
    return MessageDetailResult(
      item: MessageItem.fromJson(json),
      sourceId: json['source_id'] as String?,
      failureReasonHint: json['failure_reason_hint'] as String?,
    );
  }
}

class MessageJumpResult {
  const MessageJumpResult({
    required this.canJump,
    required this.disabledReason,
    required this.targetPageCode,
    required this.targetTabCode,
    required this.targetRoutePayloadJson,
  });

  final bool canJump;
  final String? disabledReason;
  final String? targetPageCode;
  final String? targetTabCode;
  final String? targetRoutePayloadJson;

  factory MessageJumpResult.fromJson(Map<String, dynamic> json) {
    return MessageJumpResult(
      canJump: (json['can_jump'] as bool?) ?? false,
      disabledReason: json['disabled_reason'] as String?,
      targetPageCode: json['target_page_code'] as String?,
      targetTabCode: json['target_tab_code'] as String?,
      targetRoutePayloadJson: json['target_route_payload_json'] as String?,
    );
  }
}

class WsEvent {
  const WsEvent({
    required this.event,
    required this.userId,
    this.unreadCount,
    this.messageId,
    this.isRead,
    this.occurredAt,
  });

  final String event;
  final int userId;
  final int? unreadCount;
  final int? messageId;
  final bool? isRead;
  final DateTime? occurredAt;

  String get dedupeFingerprint => [
    event,
    '$userId',
    '${messageId ?? ''}',
    '${unreadCount ?? ''}',
    '${isRead ?? ''}',
  ].join('|');

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      event: json['event'] as String? ?? '',
      userId: (json['user_id'] as int?) ?? 0,
      unreadCount: json['unread_count'] as int?,
      messageId: json['message_id'] as int?,
      isRead: json['is_read'] as bool?,
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'] as String)
          : null,
    );
  }
}
