import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/message_models.dart';
import 'package:mes_client/pages/craft_page.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/message_center_page.dart';
import 'package:mes_client/pages/product_page.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/message_service.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeMessageService extends MessageService {
  _FakeMessageService() : super(AppSession(baseUrl: '', accessToken: ''));

  bool lastTodoOnly = false;
  int lastPage = 1;
  int lastPageSize = 20;
  int batchReadCount = 0;
  int publishCount = 0;
  int maintenanceRunCount = 0;
  int markAllReadCount = 0;
  int unreadCount = 4;
  String? lastKeyword;
  String? lastStatus;
  String? lastMessageType;
  String? lastPriority;
  String? lastSourceModule;
  DateTime? lastStartTime;
  DateTime? lastEndTime;
  bool lastActiveOnly = true;
  List<int> lastBatchReadIds = <int>[];
  Object? listError;
  Object? markAllReadError;
  final Map<int, Object> detailErrors = <int, Object>{};
  final Map<int, Object> jumpErrors = <int, Object>{};
  final Map<int, Object> markReadErrors = <int, Object>{};
  final Map<int, MessageJumpResult> jumpOverrides = <int, MessageJumpResult>{};

  List<MessageItem> _items = <MessageItem>[
    MessageItem.fromJson({
      'id': 1,
      'message_type': 'todo',
      'priority': 'urgent',
      'title': '待办消息',
      'summary': '请尽快处理',
      'content': '正文内容',
      'source_module': 'production',
      'source_type': 'assist_authorization',
      'source_code': 'PO-ASSIST-1',
      'target_page_code': 'production',
      'target_tab_code': 'production_assist_records',
      'target_route_payload_json': '{"action":"detail","authorization_id":101}',
      'status': 'active',
      'published_at': '2026-03-19T08:00:00Z',
      'is_read': false,
      'delivery_status': 'failed',
      'delivery_attempt_count': 2,
      'last_push_at': '2026-03-19T08:05:00Z',
      'next_retry_at': '2026-03-19T08:10:00Z',
    }),
    MessageItem.fromJson({
      'id': 2,
      'message_type': 'notice',
      'priority': 'normal',
      'title': '普通通知',
      'summary': '仅展示',
      'content': '正文内容',
      'source_module': 'quality',
      'source_type': 'first_article_record',
      'source_code': 'FA-1',
      'target_page_code': 'quality',
      'target_tab_code': 'first_article_management',
      'status': 'no_permission',
      'inactive_reason': 'no_permission',
      'published_at': '2026-03-19T09:00:00Z',
      'is_read': true,
      'read_at': '2026-03-19T09:05:00Z',
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
    MessageItem.fromJson({
      'id': 3,
      'message_type': 'notice',
      'priority': 'important',
      'title': '注册审批通过',
      'summary': '请尽快修改初始密码',
      'content': '您的账号已创建，请进入个人中心修改密码。',
      'source_module': 'user',
      'source_type': 'registration_request',
      'source_code': 'REG-3',
      'target_page_code': 'user',
      'target_tab_code': 'account_settings',
      'target_route_payload_json': '{"action":"change_password"}',
      'status': 'active',
      'published_at': '2026-03-19T10:00:00Z',
      'is_read': false,
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
    MessageItem.fromJson({
      'id': 4,
      'message_type': 'notice',
      'priority': 'important',
      'title': '产品版本已发布',
      'summary': '查看产品版本',
      'content': '已发布到 V1.2',
      'source_module': 'product',
      'source_type': 'product_version',
      'source_code': '产品A/V1.2',
      'target_page_code': 'product',
      'target_tab_code': 'product_version_management',
      'target_route_payload_json':
          '{"action":"view_version","product_id":66,"product_name":"产品A","target_version":3}',
      'status': 'active',
      'published_at': '2026-03-19T11:00:00Z',
      'is_read': false,
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
    MessageItem.fromJson({
      'id': 5,
      'message_type': 'notice',
      'priority': 'important',
      'title': '工艺模板已发布',
      'summary': '查看模板版本',
      'content': '模板已发布到 V5',
      'source_module': 'craft',
      'source_type': 'product_process_template',
      'source_code': '模板A/V5',
      'target_page_code': 'craft',
      'target_tab_code': 'production_process_config',
      'target_route_payload_json':
          '{"action":"view_template_version","template_id":88,"version":5}',
      'status': 'active',
      'published_at': '2026-03-19T12:00:00Z',
      'is_read': false,
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
    MessageItem.fromJson({
      'id': 6,
      'message_type': 'warning',
      'priority': 'urgent',
      'title': '设备点检超时',
      'summary': '来源对象失效验证',
      'content': '设备点检记录已失效',
      'source_module': 'equipment',
      'source_type': 'inspection',
      'source_code': 'EQ-6',
      'target_page_code': 'equipment',
      'target_tab_code': 'equipment_inspection',
      'status': 'active',
      'published_at': '2026-03-17T08:00:00Z',
      'is_read': false,
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
    MessageItem.fromJson({
      'id': 7,
      'message_type': 'notice',
      'priority': 'normal',
      'title': '流程页签未配置',
      'summary': '缺少跳转目标验证',
      'content': '消息未绑定跳转目标',
      'source_module': 'production',
      'source_type': 'process',
      'source_code': 'PROC-7',
      'target_page_code': 'production',
      'target_tab_code': 'production_process_config',
      'status': 'active',
      'published_at': '2026-03-16T08:00:00Z',
      'is_read': false,
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
    MessageItem.fromJson({
      'id': 8,
      'message_type': 'announcement',
      'priority': 'normal',
      'title': '历史公告',
      'summary': '用于历史消息筛选',
      'content': '这是历史公告',
      'source_module': 'message',
      'source_type': 'announcement',
      'source_code': 'ANN-HIS',
      'status': 'archived',
      'inactive_reason': 'archived',
      'published_at': '2026-03-15T08:00:00Z',
      'is_read': true,
      'read_at': '2026-03-15T08:05:00Z',
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
    for (var i = 0; i < 6; i++)
      MessageItem.fromJson({
        'id': 100 + i,
        'message_type': 'notice',
        'priority': 'normal',
        'title': '扩展消息$i',
        'summary': '用于分页验证',
        'content': '分页测试数据',
        'source_module': 'message',
        'source_type': 'announcement',
        'source_code': 'ANN-$i',
        'status': 'active',
        'published_at': '2026-03-18T12:00:00Z',
        'is_read': false,
        'delivery_status': 'pending',
        'delivery_attempt_count': 0,
      }),
  ];

  MessageItem _copyItem(MessageItem item, {bool? isRead, DateTime? readAt}) {
    return MessageItem.fromJson({
      'id': item.id,
      'message_type': item.messageType,
      'priority': item.priority,
      'title': item.title,
      'summary': item.summary,
      'content': item.content,
      'source_module': item.sourceModule,
      'source_type': item.sourceType,
      'source_code': item.sourceCode,
      'target_page_code': item.targetPageCode,
      'target_tab_code': item.targetTabCode,
      'target_route_payload_json': item.targetRoutePayloadJson,
      'status': item.status,
      'inactive_reason': item.inactiveReason,
      'published_at': item.publishedAt?.toUtc().toIso8601String(),
      'is_read': isRead ?? item.isRead,
      'read_at': (readAt ?? item.readAt)?.toUtc().toIso8601String(),
      'delivery_status': item.deliveryStatus,
      'delivery_attempt_count': item.deliveryAttemptCount,
      'last_push_at': item.lastPushAt?.toUtc().toIso8601String(),
      'next_retry_at': item.nextRetryAt?.toUtc().toIso8601String(),
    });
  }

  @override
  Future<MessageSummaryResult> getSummary() async {
    final unreadItems = _items.where((item) => !item.isRead).length;
    final todoUnreadItems = _items
        .where((item) => item.messageType == 'todo' && !item.isRead)
        .length;
    final urgentUnreadItems = _items
        .where((item) => item.priority == 'urgent' && !item.isRead)
        .length;
    unreadCount = unreadItems;
    return MessageSummaryResult(
      totalCount: _items.length,
      unreadCount: unreadItems,
      todoUnreadCount: todoUnreadItems,
      urgentUnreadCount: urgentUnreadItems,
    );
  }

  @override
  Future<MessageListResult> listMessages({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
    String? messageType,
    String? priority,
    String? sourceModule,
    DateTime? startTime,
    DateTime? endTime,
    bool todoOnly = false,
    bool activeOnly = true,
  }) async {
    if (listError != null) {
      throw listError!;
    }
    lastTodoOnly = todoOnly;
    lastPage = page;
    lastPageSize = pageSize;
    lastKeyword = keyword;
    lastStatus = status;
    lastMessageType = messageType;
    lastPriority = priority;
    lastSourceModule = sourceModule;
    lastStartTime = startTime;
    lastEndTime = endTime;
    lastActiveOnly = activeOnly;
    final normalizedKeyword = keyword?.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (todoOnly && item.messageType != 'todo') {
        return false;
      }
      if (activeOnly && !item.isActive) {
        return false;
      }
      if (status == 'read' && !item.isRead) {
        return false;
      }
      if (status == 'unread' && item.isRead) {
        return false;
      }
      if (messageType != null &&
          messageType.isNotEmpty &&
          item.messageType != messageType) {
        return false;
      }
      if (priority != null &&
          priority.isNotEmpty &&
          item.priority != priority) {
        return false;
      }
      if (sourceModule != null &&
          sourceModule.isNotEmpty &&
          item.sourceModule != sourceModule) {
        return false;
      }
      if (startTime != null &&
          item.publishedAt != null &&
          item.publishedAt!.isBefore(startTime)) {
        return false;
      }
      if (endTime != null &&
          item.publishedAt != null &&
          item.publishedAt!.isAfter(endTime)) {
        return false;
      }
      if (normalizedKeyword != null && normalizedKeyword.isNotEmpty) {
        final haystack = <String?>[
          item.title,
          item.summary,
          item.content,
          item.sourceCode,
        ].whereType<String>().join(' ').toLowerCase();
        if (!haystack.contains(normalizedKeyword)) {
          return false;
        }
      }
      return true;
    }).toList();
    final start = (page - 1) * pageSize;
    final paged = start >= filtered.length
        ? const <MessageItem>[]
        : filtered.skip(start).take(pageSize).toList();
    return MessageListResult(
      items: paged,
      total: filtered.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> markRead(int messageId) async {
    if (markReadErrors.containsKey(messageId)) {
      throw markReadErrors[messageId]!;
    }
    final now = DateTime.utc(2026, 3, 20, 9, 30);
    _items = _items
        .map(
          (item) => item.id == messageId
              ? _copyItem(item, isRead: true, readAt: now)
              : item,
        )
        .toList();
  }

  @override
  Future<void> markAllRead() async {
    if (markAllReadError != null) {
      throw markAllReadError!;
    }
    markAllReadCount += 1;
    final now = DateTime.utc(2026, 3, 20, 9, 30);
    _items = _items
        .map((item) => _copyItem(item, isRead: true, readAt: now))
        .toList();
  }

  @override
  Future<int> markBatchRead(List<int> messageIds) async {
    batchReadCount = messageIds.length;
    lastBatchReadIds = List<int>.from(messageIds);
    final now = DateTime.utc(2026, 3, 20, 9, 30);
    _items = _items
        .map(
          (item) => messageIds.contains(item.id)
              ? _copyItem(item, isRead: true, readAt: now)
              : item,
        )
        .toList();
    return batchReadCount;
  }

  @override
  Future<AnnouncementPublishResult> publishAnnouncement(
    AnnouncementPublishRequest request,
  ) async {
    publishCount += 1;
    _items = <MessageItem>[
      MessageItem.fromJson({
        'id': 99,
        'message_type': 'announcement',
        'priority': request.priority,
        'title': request.title,
        'summary': request.content,
        'content': request.content,
        'source_module': 'message',
        'source_type': 'announcement',
        'source_code': request.rangeType,
        'status': 'active',
        'published_at': '2026-03-20T10:00:00Z',
        'is_read': false,
        'delivery_status': 'pending',
        'delivery_attempt_count': 0,
      }),
      ..._items,
    ];
    return const AnnouncementPublishResult(messageId: 99, recipientCount: 2);
  }

  @override
  Future<MessageMaintenanceResult> runMaintenance() async {
    maintenanceRunCount += 1;
    return const MessageMaintenanceResult(
      pendingCompensated: 2,
      failedRetried: 1,
      sourceUnavailableUpdated: 0,
      archivedMessages: 0,
    );
  }

  @override
  Future<MessageDetailResult> getMessageDetail(int messageId) async {
    if (detailErrors.containsKey(messageId)) {
      throw detailErrors[messageId]!;
    }
    final item = _items.firstWhere((entry) => entry.id == messageId);
    return MessageDetailResult(
      item: item,
      sourceId: messageId == 1 ? '101' : null,
      failureReasonHint: messageId == 1 ? '实时推送失败，系统将按计划继续重试。' : null,
    );
  }

  @override
  Future<MessageJumpResult> getMessageJumpTarget(int messageId) async {
    if (jumpErrors.containsKey(messageId)) {
      throw jumpErrors[messageId]!;
    }
    if (jumpOverrides.containsKey(messageId)) {
      return jumpOverrides[messageId]!;
    }
    final item = _items.firstWhere((entry) => entry.id == messageId);
    return MessageJumpResult(
      canJump: item.isActive && item.targetPageCode != null,
      disabledReason: item.isActive ? null : item.inactiveReason,
      targetPageCode: item.targetPageCode,
      targetTabCode: item.targetTabCode,
      targetRoutePayloadJson: item.targetRoutePayloadJson,
    );
  }
}

class _FakeUserService extends UserService {
  _FakeUserService() : super(AppSession(baseUrl: '', accessToken: ''));

  final List<UserItem> _allUsers = List<UserItem>.generate(205, (index) {
    final id = index + 11;
    final username = index == 204 ? 'overflow_user' : 'user_$id';
    final fullName = index == 204 ? '第205位用户' : '用户$id';
    return UserItem(
      id: id,
      username: username,
      fullName: fullName,
      remark: null,
      isOnline: index.isEven,
      isActive: true,
      isDeleted: false,
      mustChangePassword: false,
      lastSeenAt: null,
      stageId: null,
      stageName: null,
      roleCode: index.isEven ? 'system_admin' : 'quality_admin',
      roleName: index.isEven ? '系统管理员' : '品质管理员',
      lastLoginAt: null,
      lastLoginIp: null,
      passwordChangedAt: null,
      createdAt: null,
      updatedAt: null,
    );
  });

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) async {
    return RoleListResult(
      total: 2,
      items: [
        RoleItem(
          id: 1,
          code: 'system_admin',
          name: '系统管理员',
          description: null,
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 1,
          createdAt: null,
          updatedAt: null,
        ),
        RoleItem(
          id: 2,
          code: 'quality_admin',
          name: '品质管理员',
          description: null,
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 1,
          createdAt: null,
          updatedAt: null,
        ),
      ],
    );
  }

  @override
  Future<UserListResult> listUsers({
    required int page,
    required int pageSize,
    String? keyword,
    String? roleCode,
    int? stageId,
    bool? isOnline,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    final start = (page - 1) * pageSize;
    final items = start >= _allUsers.length
        ? const <UserItem>[]
        : _allUsers.skip(start).take(pageSize).toList();
    return UserListResult(total: _allUsers.length, items: items);
  }
}

Future<void> _pumpMessageCenterPage(
  WidgetTester tester, {
  required _FakeMessageService service,
  _FakeUserService? userService,
  bool canPublishAnnouncement = true,
  bool canViewDetail = true,
  bool canUseJump = true,
  void Function(int count)? onUnreadCountChanged,
  VoidCallback? onLogout,
  void Function(String pageCode, {String? tabCode, String? routePayloadJson})?
  onNavigateToPage,
  Future<DateTimeRange?> Function(DateTimeRange?)? onPickDateRange,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1280,
          child: MessageCenterPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: onLogout ?? () {},
            canPublishAnnouncement: canPublishAnnouncement,
            canViewDetail: canViewDetail,
            canUseJump: canUseJump,
            service: service,
            userService: userService ?? _FakeUserService(),
            onUnreadCountChanged: onUnreadCountChanged,
            onNavigateToPage:
                onNavigateToPage ?? (pageCode, {tabCode, routePayloadJson}) {},
            onPickDateRange: onPickDateRange,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'message center supports filters, preview, read actions and jumps',
    (tester) async {
      final service = _FakeMessageService();
      final userService = _FakeUserService();
      String? navigatedPage;
      String? navigatedTab;
      String? navigatedRoutePayloadJson;
      int? unreadCountFromPage;

      await _pumpMessageCenterPage(
        tester,
        service: service,
        userService: userService,
        onUnreadCountChanged: (count) {
          unreadCountFromPage = count;
        },
        onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
          navigatedPage = pageCode;
          navigatedTab = tabCode;
          navigatedRoutePayloadJson = routePayloadJson;
        },
        onPickDateRange: (initialDateRange) async => DateTimeRange(
          start: DateTime.utc(2026, 3, 17),
          end: DateTime.utc(2026, 3, 19, 23, 59, 59),
        ),
      );

      expect(find.text('消息详情预览'), findsOneWidget);
      expect(find.text('有效'), findsWidgets);
      expect(find.text('详情'), findsWidgets);
      expect(unreadCountFromPage, 12);
      expect(find.text('全部消息'), findsOneWidget);

      await tester.tap(find.text('待办消息').first);
      await tester.pumpAndSettle();
      expect(find.text('正文内容'), findsOneWidget);
      expect(find.text('投递失败'), findsWidgets);
      expect(find.text('查看详情'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('message-center-preview-read-1')),
      );
      await tester.pumpAndSettle();
      expect(unreadCountFromPage, 11);
      expect(
        find.byKey(const ValueKey('message-center-preview-read-1')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('message-center-keyword-field')),
        '注册审批',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(service.lastKeyword, '注册审批');
      expect(find.text('注册审批通过'), findsWidgets);
      expect(find.text('待办消息'), findsNothing);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('message-center-filter-状态')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已读').last);
      await tester.pumpAndSettle();
      expect(service.lastStatus, 'read');

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('message-center-filter-分类')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('预警').last);
      await tester.pumpAndSettle();
      expect(service.lastMessageType, 'warning');
      expect(find.text('设备点检超时'), findsWidgets);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('message-center-filter-优先级')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('紧急').last);
      await tester.pumpAndSettle();
      expect(service.lastPriority, 'urgent');
      expect(find.text('待办消息'), findsWidgets);
      expect(find.text('设备点检超时'), findsWidgets);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('message-center-filter-来源模块')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('产品').last);
      await tester.pumpAndSettle();
      expect(service.lastSourceModule, 'product');
      expect(find.text('产品版本已发布'), findsWidgets);
      expect(find.text('注册审批通过'), findsNothing);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('message-center-date-range-button')),
      );
      await tester.pumpAndSettle();
      expect(service.lastStartTime, DateTime.utc(2026, 3, 17));
      expect(service.lastEndTime, DateTime.utc(2026, 3, 19, 23, 59, 59));
      expect(find.text('03-17 ~ 03-19'), findsOneWidget);
      expect(find.text('设备点检超时'), findsWidgets);
      expect(find.text('历史公告'), findsNothing);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('20条').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('10条').last);
      await tester.pumpAndSettle();
      expect(service.lastPageSize, 10);
      expect(find.text('下一页'), findsOneWidget);

      await tester.tap(find.text('下一页'));
      await tester.pumpAndSettle();
      expect(service.lastPage, 2);

      await tester.tap(find.text('仅看待处理'));
      await tester.pumpAndSettle();
      expect(service.lastTodoOnly, isTrue);
      expect(service.lastPage, 1);
      expect(service.lastPageSize, 10);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('message-center-select-3')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('message-center-mark-batch-read-button')),
      );
      await tester.pumpAndSettle();
      expect(service.batchReadCount, 1);
      expect(service.lastBatchReadIds, [3]);
      expect(unreadCountFromPage, 10);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('包含历史消息'));
      await tester.pumpAndSettle();
      expect(service.lastActiveOnly, isFalse);
      expect(find.text('历史公告'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('message-center-mark-all-read-button')),
      );
      await tester.pumpAndSettle();
      expect(service.markAllReadCount, 1);
      expect(unreadCountFromPage, 0);

      await tester.tap(find.text('执行维护'));
      await tester.pumpAndSettle();
      expect(service.maintenanceRunCount, 1);
      expect(find.textContaining('维护完成：补偿2条，重试1条'), findsOneWidget);

      await tester.tap(find.text('发布公告'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('指定用户'));
      await tester.pumpAndSettle();
      expect(find.textContaining('可选用户 205 人'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '标题'), '系统公告');
      await tester.enterText(find.widgetWithText(TextField, '正文'), '今晚发布公告');
      await tester.tap(find.text('指定角色'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('系统管理员(system_admin)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认发布'));
      await tester.pumpAndSettle();
      expect(service.publishCount, 1);

      await tester.tap(find.text('待办消息').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('详情').first);
      await tester.pumpAndSettle();
      expect(find.text('消息详情'), findsOneWidget);
      expect(find.text('阅读状态'), findsWidgets);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跳转').first);
      await tester.pumpAndSettle();
      expect(navigatedPage, 'production');
      expect(navigatedTab, 'production_assist_records');
      expect(
        navigatedRoutePayloadJson,
        '{"action":"detail","authorization_id":101}',
      );

      await tester.tap(find.text('注册审批通过').first);
      await tester.pumpAndSettle();
      final userRow = find.ancestor(
        of: find.text('注册审批通过').first,
        matching: find.byType(InkWell),
      );
      await tester.tap(find.descendant(of: userRow, matching: find.text('跳转')));
      await tester.pumpAndSettle();
      expect(navigatedPage, 'user');
      expect(navigatedTab, 'account_settings');
      expect(navigatedRoutePayloadJson, '{"action":"change_password"}');

      await tester.tap(find.text('产品版本已发布').first);
      await tester.pumpAndSettle();
      final productRow = find.ancestor(
        of: find.text('产品版本已发布').first,
        matching: find.byType(InkWell),
      );
      await tester.tap(
        find.descendant(of: productRow, matching: find.text('跳转')),
      );
      await tester.pumpAndSettle();
      expect(navigatedPage, 'product');
      expect(navigatedTab, 'product_version_management');
      expect(
        navigatedRoutePayloadJson,
        '{"action":"view_version","product_id":66,"product_name":"产品A","target_version":3}',
      );

      await tester.tap(find.text('工艺模板已发布').first);
      await tester.pumpAndSettle();
      final craftRow = find.ancestor(
        of: find.text('工艺模板已发布').first,
        matching: find.byType(InkWell),
      );
      await tester.tap(
        find.descendant(of: craftRow, matching: find.text('跳转')),
      );
      await tester.pumpAndSettle();
      expect(navigatedPage, 'craft');
      expect(navigatedTab, 'production_process_config');
      expect(
        navigatedRoutePayloadJson,
        '{"action":"view_template_version","template_id":88,"version":5}',
      );
    },
  );

  testWidgets('message center handles failures and permission states', (
    tester,
  ) async {
    final service = _FakeMessageService();
    var logoutCount = 0;

    await _pumpMessageCenterPage(
      tester,
      service: service,
      canViewDetail: false,
      canUseJump: false,
    );

    expect(find.text('当前账号未开通消息详情查看权限'), findsOneWidget);
    expect(find.text('当前账号未开通业务跳转权限'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-center-jump-1')), findsNothing);

    service.listError = ApiException('无权限访问消息接口', 403);
    final refreshButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '刷新'),
    );
    refreshButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('无权限访问消息接口'), findsOneWidget);

    await _pumpMessageCenterPage(tester, service: service);

    service.listError = null;
    service.detailErrors[1] = ApiException('无详情权限', 403);
    await tester.tap(find.byKey(const ValueKey('message-center-detail-1')));
    await tester.pumpAndSettle();
    expect(find.text('无详情权限'), findsOneWidget);

    service.markAllReadError = ApiException('全部已读失败', 403);
    final markAllReadButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('message-center-mark-all-read-button')),
    );
    markAllReadButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('全部已读失败'), findsOneWidget);

    service.markAllReadError = null;
    service.markReadErrors[6] = ApiException('单条已读失败', 403);
    final markReadButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('message-center-read-6')),
    );
    markReadButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('单条已读失败'), findsOneWidget);

    await _pumpMessageCenterPage(
      tester,
      service: service,
      onLogout: () {
        logoutCount += 1;
      },
    );

    service.listError = ApiException('登录已过期，请重新登录', 401);
    final refreshButtonAfterLogout = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '刷新'),
    );
    refreshButtonAfterLogout.onPressed!.call();
    await tester.pumpAndSettle();
    expect(logoutCount, 1);

    service.listError = null;
    for (final entry in <(int, MessageJumpResult, String)>[
      (
        3,
        const MessageJumpResult(
          canJump: false,
          disabledReason: 'expired',
          targetPageCode: 'user',
          targetTabCode: 'account_settings',
          targetRoutePayloadJson: null,
        ),
        '该消息已过期，无法继续跳转',
      ),
    ]) {
      service.jumpOverrides.clear();
      service.jumpOverrides[entry.$1] = entry.$2;
      await _pumpMessageCenterPage(tester, service: service);
      final jumpButton = tester.widget<TextButton>(
        find.byKey(ValueKey('message-center-jump-${entry.$1}')),
      );
      jumpButton.onPressed!.call();
      await tester.pumpAndSettle();
      expect(find.text(entry.$3), findsOneWidget);
    }
  });

  test('parses product and craft message jump payloads', () {
    final productPayload = parseProductMessageJumpPayload(
      '{"action":"view_version","product_id":66,"product_name":"产品A","target_version":3,"target_tab_code":"product_version_management"}',
    );
    final craftPayload = parseCraftMessageJumpPayload(
      '{"template_id":88,"version":5,"target_tab_code":"production_process_config"}',
    );

    expect(productPayload, isNotNull);
    expect(productPayload!.productId, 66);
    expect(productPayload.targetTabCode, 'product_version_management');
    expect(productPayload.targetVersion, 3);
    expect(craftPayload, isNotNull);
    expect(craftPayload!.templateId, 88);
    expect(craftPayload.version, 5);
    expect(craftPayload.targetTabCode, 'production_process_config');
  });

  test('maps message jump disabled reasons', () {
    expect(messageJumpDisabledReasonName('expired'), '该消息已过期，无法继续跳转');
    expect(messageJumpDisabledReasonName('archived'), '该消息已归档，无法继续跳转');
    expect(messageJumpDisabledReasonName('no_permission'), '当前账号暂无目标页面访问权限');
    expect(
      messageJumpDisabledReasonName('source_unavailable'),
      '来源对象已失效，无法继续跳转',
    );
    expect(messageJumpDisabledReasonName('missing_target'), '该消息未配置业务跳转目标');
    expect(messageJumpDisabledReasonName('unknown'), '当前消息暂不可跳转');
  });
}
