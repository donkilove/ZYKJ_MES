import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/presentation/announcement_management_page.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class _FakeAnnouncementMessageService extends MessageService {
  _FakeAnnouncementMessageService({
    List<MessageItem>? items,
  }) : _items = items ?? <MessageItem>[_buildAnnouncementItem(201, '停机维护公告')],
       super(AppSession(baseUrl: '', accessToken: ''));

  int activeAnnouncementLoadCount = 0;
  int offlineCount = 0;
  int publishCount = 0;
  int lastOfflineMessageId = 0;
  int lastRequestedPage = 0;
  int lastRequestedPageSize = 0;

  List<MessageItem> _items;

  @override
  Future<MessageListResult> getActiveAnnouncements({
    int page = 1,
    int pageSize = 20,
    String? priority,
  }) async {
    activeAnnouncementLoadCount += 1;
    lastRequestedPage = page;
    lastRequestedPageSize = pageSize;
    final start = (page - 1) * pageSize;
    final pagedItems = start >= _items.length
        ? const <MessageItem>[]
        : _items.skip(start).take(pageSize).toList();
    return MessageListResult(
      items: pagedItems,
      total: _items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<AnnouncementOfflineResult> offlineAnnouncement(int messageId) async {
    offlineCount += 1;
    lastOfflineMessageId = messageId;
    _items = _items.where((item) => item.id != messageId).toList();
    return AnnouncementOfflineResult(messageId: messageId, status: 'offline');
  }

  @override
  Future<AnnouncementPublishResult> publishAnnouncement(
    AnnouncementPublishRequest request,
  ) async {
    publishCount += 1;
    return const AnnouncementPublishResult(messageId: 999, recipientCount: 2);
  }
}

MessageItem _buildAnnouncementItem(int id, String title) {
  return MessageItem.fromJson({
    'id': id,
    'message_type': 'announcement',
    'priority': 'important',
    'title': title,
    'summary': '今晚维护',
    'content': '今晚 20:00 至 21:00 维护。',
    'source_module': 'message',
    'source_type': 'announcement',
    'source_code': 'all',
    'target_page_code': null,
    'target_tab_code': null,
    'target_route_payload_json': null,
    'status': 'active',
    'inactive_reason': null,
    'published_at': '2026-05-01T08:00:00Z',
    'expires_at': '2026-05-02T08:00:00Z',
    'is_read': false,
    'read_at': null,
    'delivered_at': null,
    'delivery_status': 'pending',
    'delivery_attempt_count': 0,
    'last_push_at': null,
    'next_retry_at': null,
  });
}

class _FakeAnnouncementUserService extends UserService {
  _FakeAnnouncementUserService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) async {
    return RoleListResult(
      total: 1,
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
    String deletedScope = 'active',
    bool includeDeleted = false,
  }) async {
    return UserListResult(
      total: 1,
      items: [
        UserItem(
          id: 7,
          username: 'admin',
          fullName: '系统管理员',
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
      ],
    );
  }
}

Widget _buildTestApp({
  required _FakeAnnouncementMessageService messageService,
  UserService? userService,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AnnouncementManagementPage(
        session: AppSession(baseUrl: '', accessToken: ''),
        onLogout: () {},
        service: messageService,
        userService: userService ?? _FakeAnnouncementUserService(),
      ),
    ),
  );
}

void main() {
  testWidgets('公告管理页加载当前生效公告并展示标题', (tester) async {
    final service = _FakeAnnouncementMessageService();

    await tester.pumpWidget(_buildTestApp(messageService: service));
    await tester.pumpAndSettle();

    expect(service.activeAnnouncementLoadCount, 1);
    expect(service.lastRequestedPage, 1);
    expect(service.lastRequestedPageSize, 20);
    expect(find.text('公告管理'), findsOneWidget);
    expect(find.text('停机维护公告'), findsOneWidget);
  });

  testWidgets('公告管理页可以下线公告并刷新列表', (tester) async {
    final service = _FakeAnnouncementMessageService();

    await tester.pumpWidget(_buildTestApp(messageService: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('announcement-offline-201')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认下线'));
    await tester.pumpAndSettle();

    expect(service.offlineCount, 1);
    expect(service.lastOfflineMessageId, 201);
    expect(service.activeAnnouncementLoadCount, 2);
    expect(find.text('停机维护公告'), findsNothing);
  });

  testWidgets('最后一页最后一条公告下线后回退到有效页', (tester) async {
    final service = _FakeAnnouncementMessageService(
      items: List<MessageItem>.generate(
        21,
        (index) => _buildAnnouncementItem(
          300 + index,
          index == 20 ? '最后一页公告' : '公告 ${index + 1}',
        ),
      ),
    );

    await tester.pumpWidget(_buildTestApp(messageService: service));
    await tester.pumpAndSettle();

    expect(find.text('第 1 / 2 页'), findsOneWidget);
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();

    expect(service.lastRequestedPage, 2);
    expect(find.text('第 2 / 2 页'), findsOneWidget);
    expect(find.text('最后一页公告'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('announcement-offline-320')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认下线'));
    await tester.pumpAndSettle();

    expect(service.offlineCount, 1);
    expect(service.lastOfflineMessageId, 320);
    expect(service.lastRequestedPage, 1);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
    expect(find.text('最后一页公告'), findsNothing);
    expect(find.text('公告 1'), findsOneWidget);
  });

  testWidgets('公告管理页复用发布公告弹窗入口', (tester) async {
    final service = _FakeAnnouncementMessageService();
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_buildTestApp(messageService: service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('发布公告'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('announcement-publish-dialog')),
      findsOneWidget,
    );
  });
}
