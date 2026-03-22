import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/message_models.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/message_center_page.dart';
import 'package:mes_client/services/message_service.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeMessageService extends MessageService {
  _FakeMessageService() : super(AppSession(baseUrl: '', accessToken: ''));

  bool lastTodoOnly = false;
  int batchReadCount = 0;
  int publishCount = 0;

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
      'target_tab_code': 'production_assist_approval',
      'target_route_payload_json': '{"action":"detail","authorization_id":101}',
      'status': 'active',
      'published_at': '2026-03-19T08:00:00Z',
      'is_read': false,
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
      'is_read': false,
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
    }),
  ];

  @override
  Future<MessageSummaryResult> getSummary() async {
    return const MessageSummaryResult(
      totalCount: 2,
      unreadCount: 2,
      todoUnreadCount: 1,
      urgentUnreadCount: 1,
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
    lastTodoOnly = todoOnly;
    final filtered = todoOnly
        ? _items.where((item) => item.messageType == 'todo').toList()
        : _items;
    return MessageListResult(
      items: filtered,
      total: filtered.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> markRead(int messageId) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<int> markBatchRead(List<int> messageIds) async {
    batchReadCount = messageIds.length;
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
      }),
      ..._items,
    ];
    return const AnnouncementPublishResult(messageId: 99, recipientCount: 2);
  }
}

class _FakeUserService extends UserService {
  _FakeUserService() : super(AppSession(baseUrl: '', accessToken: ''));

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
    return UserListResult(
      total: 2,
      items: [
        UserItem(
          id: 11,
          username: 'admin',
          fullName: '管理员',
          remark: null,
          isOnline: true,
          isActive: true,
          isDeleted: false,
          mustChangePassword: false,
          lastSeenAt: null,
          stageId: null,
          stageName: null,
          roleCode: 'system_admin',
          roleName: '系统管理员',
          lastLoginAt: null,
          lastLoginIp: null,
          passwordChangedAt: null,
          createdAt: null,
          updatedAt: null,
        ),
        UserItem(
          id: 12,
          username: 'quality',
          fullName: '质检员',
          remark: null,
          isOnline: false,
          isActive: true,
          isDeleted: false,
          mustChangePassword: false,
          lastSeenAt: null,
          stageId: null,
          stageName: null,
          roleCode: 'quality_admin',
          roleName: '品质管理员',
          lastLoginAt: null,
          lastLoginIp: null,
          passwordChangedAt: null,
          createdAt: null,
          updatedAt: null,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('message center supports preview, publish and batch read', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeMessageService();
    final userService = _FakeUserService();
    String? navigatedPage;
    String? navigatedTab;
    String? navigatedRoutePayloadJson;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            child: MessageCenterPage(
              session: AppSession(baseUrl: '', accessToken: ''),
              onLogout: () {},
              canPublishAnnouncement: true,
              service: service,
              userService: userService,
              onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
                navigatedPage = pageCode;
                navigatedTab = tabCode;
                navigatedRoutePayloadJson = routePayloadJson;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('消息详情预览'), findsOneWidget);
    expect(find.text('暂无目标页面访问权限'), findsOneWidget);

    await tester.tap(find.text('待办消息').first);
    await tester.pumpAndSettle();
    expect(find.text('正文内容'), findsOneWidget);

    await tester.tap(find.text('仅看待处理'));
    await tester.pumpAndSettle();
    expect(service.lastTodoOnly, isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('批量已读'));
    await tester.pumpAndSettle();
    expect(service.batchReadCount, 1);

    await tester.tap(find.text('发布公告'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '系统公告');
    await tester.enterText(find.widgetWithText(TextField, '正文'), '今晚发布公告');
    await tester.tap(find.text('指定角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('系统管理员(system_admin)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认发布'));
    await tester.pumpAndSettle();
    expect(service.publishCount, 1);
    await tester.tap(find.text('仅看待处理'));
    await tester.pumpAndSettle();
    expect(find.text('系统公告'), findsOneWidget);

    await tester.tap(find.text('待办消息').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳转').first);
    await tester.pumpAndSettle();
    expect(navigatedPage, 'production');
    expect(navigatedTab, 'production_assist_approval');
    expect(
      navigatedRoutePayloadJson,
      '{"action":"detail","authorization_id":101}',
    );

    await tester.tap(find.text('注册审批通过').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳转').last);
    await tester.pumpAndSettle();
    expect(navigatedPage, 'user');
    expect(navigatedTab, 'account_settings');
    expect(navigatedRoutePayloadJson, '{"action":"change_password"}');
  });
}
