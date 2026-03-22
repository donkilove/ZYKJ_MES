import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/message_models.dart';
import 'package:mes_client/pages/craft_page.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/message_center_page.dart';
import 'package:mes_client/pages/product_page.dart';
import 'package:mes_client/services/message_service.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeMessageService extends MessageService {
  _FakeMessageService() : super(AppSession(baseUrl: '', accessToken: ''));

  bool lastTodoOnly = false;
  int batchReadCount = 0;
  int publishCount = 0;
  int unreadCount = 4;

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
    }),
  ];

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
  Future<void> markRead(int messageId) async {
    _items = _items
        .map(
          (item) => item.id == messageId
              ? MessageItem.fromJson({
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
                  'is_read': true,
                })
              : item,
        )
        .toList();
  }

  @override
  Future<void> markAllRead() async {
    _items = _items
        .map(
          (item) => MessageItem.fromJson({
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
            'is_read': true,
          }),
        )
        .toList();
  }

  @override
  Future<int> markBatchRead(List<int> messageIds) async {
    batchReadCount = messageIds.length;
    _items = _items
        .map(
          (item) => messageIds.contains(item.id)
              ? MessageItem.fromJson({
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
                  'is_read': true,
                })
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
    int? unreadCountFromPage;

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
              onUnreadCountChanged: (count) {
                unreadCountFromPage = count;
              },
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
    expect(unreadCountFromPage, 5);

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
    expect(unreadCountFromPage, 4);

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
    await tester.tap(find.descendant(of: craftRow, matching: find.text('跳转')));
    await tester.pumpAndSettle();
    expect(navigatedPage, 'craft');
    expect(navigatedTab, 'production_process_config');
    expect(
      navigatedRoutePayloadJson,
      '{"action":"view_template_version","template_id":88,"version":5}',
    );
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
}
