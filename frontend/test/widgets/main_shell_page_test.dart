import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';

final AppSession _session = AppSession(
  baseUrl: 'http://example.test/api/v1',
  accessToken: 'token',
);

CurrentUser _buildCurrentUser() {
  return CurrentUser(
    id: 1,
    username: 'tester',
    fullName: '测试用户',
    roleCode: 'quality_admin',
    roleName: '品质管理员',
    stageId: null,
    stageName: null,
  );
}

List<PageCatalogItem> _buildCatalog() {
  return const [
    PageCatalogItem(
      code: 'home',
      name: '首页',
      pageType: 'sidebar',
      parentCode: null,
      alwaysVisible: true,
      sortOrder: 10,
    ),
    PageCatalogItem(
      code: 'user',
      name: '用户',
      pageType: 'sidebar',
      parentCode: null,
      alwaysVisible: false,
      sortOrder: 20,
    ),
    PageCatalogItem(
      code: 'user_management',
      name: '用户管理',
      pageType: 'tab',
      parentCode: 'user',
      alwaysVisible: false,
      sortOrder: 21,
    ),
    PageCatalogItem(
      code: 'role_management',
      name: '角色管理',
      pageType: 'tab',
      parentCode: 'user',
      alwaysVisible: false,
      sortOrder: 23,
    ),
    PageCatalogItem(
      code: 'account_settings',
      name: '个人中心',
      pageType: 'tab',
      parentCode: 'user',
      alwaysVisible: false,
      sortOrder: 25,
    ),
    PageCatalogItem(
      code: 'message',
      name: '消息',
      pageType: 'sidebar',
      parentCode: null,
      alwaysVisible: false,
      sortOrder: 80,
    ),
    PageCatalogItem(
      code: 'message_center',
      name: '消息中心',
      pageType: 'tab',
      parentCode: 'message',
      alwaysVisible: false,
      sortOrder: 81,
    ),
  ];
}

AuthzSnapshotModuleItem _buildModuleItem(
  String moduleCode, {
  List<String> capabilityCodes = const [],
}) {
  return AuthzSnapshotModuleItem(
    moduleCode: moduleCode,
    moduleName: moduleCode,
    moduleRevision: 1,
    moduleEnabled: true,
    effectivePermissionCodes: const [],
    effectivePagePermissionCodes: const [],
    effectiveCapabilityCodes: capabilityCodes,
    effectiveActionPermissionCodes: const [],
  );
}

AuthzSnapshotResult _buildSnapshot({
  List<String> visibleSidebarCodes = const ['user'],
  Map<String, List<String>> tabCodesByParent = const {
    'user': ['role_management', 'user_management'],
  },
  List<AuthzSnapshotModuleItem>? moduleItems,
}) {
  return AuthzSnapshotResult(
    revision: 1,
    roleCodes: const ['quality_admin'],
    visibleSidebarCodes: visibleSidebarCodes,
    tabCodesByParent: tabCodesByParent,
    moduleItems:
        moduleItems ?? [_buildModuleItem('user'), _buildModuleItem('message')],
  );
}

MessageItem _buildMessageItem() {
  return MessageItem(
    id: 301,
    messageType: 'todo',
    priority: 'important',
    title: '请处理账号设置',
    summary: '点击后跳转到个人中心',
    content: '消息内容',
    sourceModule: 'user',
    sourceType: 'account',
    sourceCode: 'U-301',
    targetPageCode: 'account_settings',
    targetTabCode: null,
    targetRoutePayloadJson:
        '{"target_tab_code":"account_settings","anchor":"account-settings-change-password-anchor"}',
    status: 'active',
    inactiveReason: null,
    publishedAt: DateTime.parse('2026-04-01T08:00:00Z'),
    isRead: false,
    readAt: null,
    deliveredAt: DateTime.parse('2026-04-01T08:00:00Z'),
    deliveryStatus: 'delivered',
    deliveryAttemptCount: 1,
    lastPushAt: DateTime.parse('2026-04-01T08:00:00Z'),
    nextRetryAt: null,
  );
}

HomeDashboardData _buildDashboardData() {
  return const HomeDashboardData(
    generatedAt: null,
    noticeCount: 0,
    todoSummary: HomeDashboardTodoSummary(
      totalCount: 0,
      pendingApprovalCount: 0,
      highPriorityCount: 0,
      exceptionCount: 0,
      overdueCount: 0,
    ),
    todoItems: [],
    riskItems: [],
    kpiItems: [],
    degradedBlocks: [],
  );
}

class _TestShellAuthService extends AuthService {
  _TestShellAuthService({this.error});

  final Object? error;

  @override
  Future<CurrentUser> getCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
    if (error != null) {
      throw error!;
    }
    return _buildCurrentUser();
  }
}

class _CountingShellAuthService extends _TestShellAuthService {
  _CountingShellAuthService();

  int callCount = 0;

  @override
  Future<CurrentUser> getCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
    callCount += 1;
    return super.getCurrentUser(baseUrl: baseUrl, accessToken: accessToken);
  }
}

class _TestShellAuthzService extends AuthzService {
  _TestShellAuthzService({this.snapshot, this.error}) : super(_session);

  final AuthzSnapshotResult? snapshot;
  final Object? error;

  @override
  Future<AuthzSnapshotResult> loadAuthzSnapshot() async {
    if (error != null) {
      throw error!;
    }
    return snapshot ?? _buildSnapshot();
  }
}

class _TestShellPageCatalogService extends PageCatalogService {
  _TestShellPageCatalogService({this.error}) : super(_session);

  final Object? error;

  @override
  Future<List<PageCatalogItem>> listPageCatalog() async {
    if (error != null) {
      throw error!;
    }
    return _buildCatalog();
  }
}

class _CountingShellPageCatalogService extends _TestShellPageCatalogService {
  _CountingShellPageCatalogService();

  int callCount = 0;

  @override
  Future<List<PageCatalogItem>> listPageCatalog() async {
    callCount += 1;
    return super.listPageCatalog();
  }
}

class _TestShellMessageService extends MessageService {
  _TestShellMessageService({
    List<MessageItem>? items,
    Map<int, MessageJumpResult>? jumpResults,
  }) : items = items ?? const [],
       jumpResults = jumpResults ?? const {},
       super(_session);

  int unreadCount = 0;
  final List<MessageItem> items;
  final Map<int, MessageJumpResult> jumpResults;

  @override
  Future<int> getUnreadCount() async => unreadCount;

  @override
  Future<MessageSummaryResult> getSummary() async {
    final unread = items.where((item) => !item.isRead).length;
    return MessageSummaryResult(
      totalCount: items.length,
      unreadCount: unread,
      todoUnreadCount: unread,
      urgentUnreadCount: items
          .where((item) => item.priority == 'urgent')
          .length,
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
    return MessageListResult(
      items: items,
      total: items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<MessageJumpResult> getMessageJumpTarget(int messageId) async {
    return jumpResults[messageId] ??
        const MessageJumpResult(
          canJump: false,
          disabledReason: 'missing_target',
          targetPageCode: null,
          targetTabCode: null,
          targetRoutePayloadJson: null,
        );
  }
}

class _CountingShellMessageService extends _TestShellMessageService {
  _CountingShellMessageService();

  int unreadCountCallCount = 0;

  @override
  Future<int> getUnreadCount() async {
    unreadCountCallCount += 1;
    return super.getUnreadCount();
  }
}

class _FakeMessageWsService extends MessageWsService {
  _FakeMessageWsService({
    required super.baseUrl,
    required super.accessToken,
    required super.onEvent,
    required super.onDisconnected,
  });

  @override
  void connect() {}

  void emit(WsEvent event) {
    onEvent(event);
  }

  @override
  void disconnect() {}

  @override
  void reconnect() {}
}

class _CountingHomeDashboardService extends HomeDashboardService {
  _CountingHomeDashboardService() : super(_session);

  int loadCount = 0;

  @override
  Future<HomeDashboardData> load() async {
    loadCount += 1;
    return _buildDashboardData();
  }
}

class _ControlledHomeDashboardService extends HomeDashboardService {
  _ControlledHomeDashboardService() : super(_session);

  int loadCount = 0;
  Completer<HomeDashboardData>? secondLoadCompleter;

  @override
  Future<HomeDashboardData> load() {
    loadCount += 1;
    if (loadCount == 2) {
      secondLoadCompleter = Completer<HomeDashboardData>();
      return secondLoadCompleter!.future;
    }
    return Future.value(_buildDashboardData());
  }
}

Future<void> _pumpMainShellPage(
  WidgetTester tester, {
  AuthService? authService,
  AuthzService? authzService,
  PageCatalogService? pageCatalogService,
  MessageService? messageService,
  MessageWsService Function({
    required String baseUrl,
    required String accessToken,
    required WsEventCallback onEvent,
    required void Function() onDisconnected,
  })?
  messageWsServiceFactory,
  HomeDashboardService? homeDashboardService,
  Widget Function({
    required AppSession session,
    required VoidCallback onLogout,
    required List<String> visibleTabCodes,
    required Set<String> capabilityCodes,
    String? preferredTabCode,
    String? routePayloadJson,
    VoidCallback? onVisibilityConfigSaved,
  })?
  userPageBuilder,
  required VoidCallback onLogout,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MainShellPage(
        session: _session,
        onLogout: onLogout,
        authService: authService,
        authzService: authzService,
        pageCatalogService: pageCatalogService,
        messageService: messageService,
        messageWsServiceFactory: messageWsServiceFactory,
        homeDashboardService: homeDashboardService,
        userPageBuilder: userPageBuilder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('主壳页会把用户模块可见页签按目录顺序装配给用户页', (tester) async {
    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      userPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
            VoidCallback? onVisibilityConfigSaved,
          }) {
            return Center(
              child: Text(
                'tabs:${visibleTabCodes.join(',')}|preferred:${preferredTabCode ?? '-'}',
              ),
            );
          },
      onLogout: () {},
    );

    await tester.tap(find.byKey(const ValueKey('main-shell-menu-user')));
    await tester.pumpAndSettle();

    expect(
      find.text('tabs:user_management,role_management|preferred:-'),
      findsOneWidget,
    );
  });

  testWidgets('页面目录接口失败时会回退到本地目录并保留页签排序', (tester) async {
    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(
        snapshot: _buildSnapshot(
          visibleSidebarCodes: const ['user'],
          tabCodesByParent: const {
            'user': ['role_management', 'user_management', 'missing_tab'],
          },
        ),
      ),
      pageCatalogService: _TestShellPageCatalogService(
        error: ApiException('目录服务不可用', 500),
      ),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      userPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
            VoidCallback? onVisibilityConfigSaved,
          }) {
            return Center(child: Text('tabs:${visibleTabCodes.join(',')}'));
          },
      onLogout: () {},
    );

    expect(find.text('页面目录加载失败，已使用本地兜底配置。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-shell-menu-user')));
    await tester.pumpAndSettle();

    expect(find.text('tabs:user_management,role_management'), findsOneWidget);
  });

  testWidgets('首页快捷跳转按可见菜单动态展示并优先携带首个可见页签', (tester) async {
    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(
        snapshot: _buildSnapshot(
          visibleSidebarCodes: const ['user'],
          tabCodesByParent: const {
            'user': ['role_management', 'user_management'],
          },
        ),
      ),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      userPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
            VoidCallback? onVisibilityConfigSaved,
          }) {
            return Center(
              child: Text(
                'tabs:${visibleTabCodes.join(',')}|preferred:${preferredTabCode ?? '-'}|payload:${routePayloadJson ?? '-'}',
              ),
            );
          },
      onLogout: () {},
    );

    final todoCard = find.ancestor(
      of: find.text('我的待办队列'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: todoCard, matching: find.text('用户')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: todoCard, matching: find.text('产品')),
      findsNothing,
    );

    await tester.tap(find.descendant(of: todoCard, matching: find.text('用户')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'tabs:user_management,role_management|preferred:user_management|payload:{"target_tab_code":"user_management"}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('首页刷新按钮不会重拉目录且会重拉用户与未读数', (tester) async {
    final authService = _CountingShellAuthService();
    final pageCatalogService = _CountingShellPageCatalogService();
    final messageService = _CountingShellMessageService();

    await _pumpMainShellPage(
      tester,
      authService: authService,
      authzService: _TestShellAuthzService(),
      pageCatalogService: pageCatalogService,
      messageService: messageService,
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      onLogout: () {},
    );

    expect(authService.callCount, 1);
    expect(pageCatalogService.callCount, 1);
    expect(messageService.unreadCountCallCount, 0);

    await tester.tap(find.byTooltip('刷新业务数据'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(authService.callCount, 2);
    expect(pageCatalogService.callCount, 1);
    expect(messageService.unreadCountCallCount, 1);
    expect(find.textContaining('上次刷新：'), findsOneWidget);
  });

  testWidgets('首页首次加载与消息事件后会刷新工作台数据', (tester) async {
    _FakeMessageWsService? wsService;
    final homeDashboardService = _CountingHomeDashboardService();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) {
            wsService = _FakeMessageWsService(
              baseUrl: baseUrl,
              accessToken: accessToken,
              onEvent: onEvent,
              onDisconnected: onDisconnected,
            );
            return wsService!;
          },
      homeDashboardService: homeDashboardService,
      onLogout: () {},
    );

    expect(homeDashboardService.loadCount, 1);

    wsService!.emit(
      const WsEvent(event: 'message_created', userId: 1, unreadCount: 3),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(homeDashboardService.loadCount, 2);
  });

  testWidgets('防抖窗口内多次消息事件会合并为一次工作台刷新', (tester) async {
    _FakeMessageWsService? wsService;
    final homeDashboardService = _CountingHomeDashboardService();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) {
            wsService = _FakeMessageWsService(
              baseUrl: baseUrl,
              accessToken: accessToken,
              onEvent: onEvent,
              onDisconnected: onDisconnected,
            );
            return wsService!;
          },
      homeDashboardService: homeDashboardService,
      onLogout: () {},
    );

    expect(homeDashboardService.loadCount, 1);

    wsService!.emit(
      const WsEvent(event: 'message_created', userId: 1, unreadCount: 3),
    );
    await tester.pump(const Duration(milliseconds: 600));
    wsService!.emit(
      const WsEvent(
        event: 'message_read_state_changed',
        userId: 1,
        unreadCount: 2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    wsService!.emit(
      const WsEvent(event: 'unread_count_changed', userId: 1, unreadCount: 4),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(homeDashboardService.loadCount, 1);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(homeDashboardService.loadCount, 2);
  });

  testWidgets('当前不在首页时消息事件不会触发工作台刷新', (tester) async {
    _FakeMessageWsService? wsService;
    final homeDashboardService = _CountingHomeDashboardService();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) {
            wsService = _FakeMessageWsService(
              baseUrl: baseUrl,
              accessToken: accessToken,
              onEvent: onEvent,
              onDisconnected: onDisconnected,
            );
            return wsService!;
          },
      homeDashboardService: homeDashboardService,
      onLogout: () {},
    );

    expect(homeDashboardService.loadCount, 1);

    await tester.tap(find.byKey(const ValueKey('main-shell-menu-user')));
    await tester.pumpAndSettle();

    wsService!.emit(
      const WsEvent(event: 'message_created', userId: 1, unreadCount: 3),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(homeDashboardService.loadCount, 1);
  });

  testWidgets('首页手动刷新会触发一次工作台刷新', (tester) async {
    final homeDashboardService = _CountingHomeDashboardService();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      homeDashboardService: homeDashboardService,
      onLogout: () {},
    );

    expect(homeDashboardService.loadCount, 1);

    await tester.tap(find.byTooltip('刷新业务数据'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(homeDashboardService.loadCount, 2);
  });

  testWidgets('加载中收到刷新请求会在完成后补一次工作台刷新', (tester) async {
    _FakeMessageWsService? wsService;
    final homeDashboardService = _ControlledHomeDashboardService();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) {
            wsService = _FakeMessageWsService(
              baseUrl: baseUrl,
              accessToken: accessToken,
              onEvent: onEvent,
              onDisconnected: onDisconnected,
            );
            return wsService!;
          },
      homeDashboardService: homeDashboardService,
      onLogout: () {},
    );

    expect(homeDashboardService.loadCount, 1);

    await tester.tap(find.byTooltip('刷新业务数据'));
    await tester.pump();
    expect(homeDashboardService.loadCount, 2);

    wsService!.emit(
      const WsEvent(event: 'message_created', userId: 1, unreadCount: 5),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    homeDashboardService.secondLoadCompleter!.complete(_buildDashboardData());
    await tester.pumpAndSettle();

    expect(homeDashboardService.loadCount, 3);
  });

  testWidgets('pending 置位后页面销毁不应再触发补刷', (tester) async {
    _FakeMessageWsService? wsService;
    final homeDashboardService = _ControlledHomeDashboardService();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) {
            wsService = _FakeMessageWsService(
              baseUrl: baseUrl,
              accessToken: accessToken,
              onEvent: onEvent,
              onDisconnected: onDisconnected,
            );
            return wsService!;
          },
      homeDashboardService: homeDashboardService,
      onLogout: () {},
    );

    expect(homeDashboardService.loadCount, 1);

    await tester.tap(find.byTooltip('刷新业务数据'));
    await tester.pump();
    expect(homeDashboardService.loadCount, 2);

    wsService!.emit(
      const WsEvent(event: 'message_created', userId: 1, unreadCount: 6),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    homeDashboardService.secondLoadCompleter!.complete(_buildDashboardData());
    await tester.pumpAndSettle();

    expect(homeDashboardService.loadCount, 2);
  });

  testWidgets('成功加载但无任何可访问模块时显示空菜单提示', (tester) async {
    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(
        snapshot: _buildSnapshot(
          visibleSidebarCodes: const [],
          tabCodesByParent: const {},
        ),
      ),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      onLogout: () {},
    );

    expect(find.text('当前账号暂无可访问页面'), findsOneWidget);
    expect(find.text('请联系系统管理员分配页面可见权限'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '退出登录'), findsOneWidget);
  });

  testWidgets('当前用户加载失败时显示错误态', (tester) async {
    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(error: ApiException('用户接口失败', 500)),
      authzService: _TestShellAuthzService(),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      onLogout: () {},
    );

    expect(find.textContaining('加载当前用户失败：用户接口失败'), findsOneWidget);
  });

  testWidgets('权限快照加载失败时显示错误态', (tester) async {
    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(error: ApiException('权限快照失败', 500)),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      onLogout: () {},
    );

    expect(find.textContaining('加载权限快照失败：权限快照失败'), findsOneWidget);
  });

  testWidgets('消息未读角标会随着 websocket 事件刷新', (tester) async {
    _FakeMessageWsService? wsService;

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(
        snapshot: _buildSnapshot(
          visibleSidebarCodes: const ['user', 'message'],
          tabCodesByParent: const {
            'user': ['account_settings'],
            'message': ['message_center'],
          },
        ),
      ),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) {
            wsService = _FakeMessageWsService(
              baseUrl: baseUrl,
              accessToken: accessToken,
              onEvent: onEvent,
              onDisconnected: onDisconnected,
            );
            return wsService!;
          },
      onLogout: () {},
    );

    expect(find.byType(Badge), findsNothing);

    wsService!.emit(
      const WsEvent(event: 'unread_count_changed', userId: 1, unreadCount: 7),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('从消息中心跳转时会落到父模块并带上目标页签和载荷', (tester) async {
    final message = _buildMessageItem();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(
        snapshot: _buildSnapshot(
          visibleSidebarCodes: const ['user', 'message'],
          tabCodesByParent: const {
            'user': ['account_settings'],
            'message': ['message_center'],
          },
          moduleItems: [
            _buildModuleItem('user'),
            _buildModuleItem(
              'message',
              capabilityCodes: const ['feature.message.jump.use'],
            ),
          ],
        ),
      ),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'account_settings',
            targetTabCode: null,
            targetRoutePayloadJson:
                '{"target_tab_code":"account_settings","anchor":"account-settings-change-password-anchor"}',
          ),
        },
      ),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      userPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
            VoidCallback? onVisibilityConfigSaved,
          }) {
            return Center(
              child: Text(
                'user-tab:${preferredTabCode ?? '-'}|payload:${routePayloadJson ?? '-'}',
              ),
            );
          },
      onLogout: () {},
    );

    await tester.tap(find.byKey(const ValueKey('main-shell-menu-message')));
    await tester.pumpAndSettle();

    expect(find.text('请处理账号设置'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('message-center-jump-301')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'user-tab:account_settings|payload:{"target_tab_code":"account_settings","anchor":"account-settings-change-password-anchor"}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('无权限目标跳转会提示并保持当前页面，不会静默回退', (tester) async {
    final message = _buildMessageItem();

    await _pumpMainShellPage(
      tester,
      authService: _TestShellAuthService(),
      authzService: _TestShellAuthzService(
        snapshot: _buildSnapshot(
          visibleSidebarCodes: const ['message'],
          tabCodesByParent: const {
            'message': ['message_center'],
          },
          moduleItems: [
            _buildModuleItem(
              'message',
              capabilityCodes: const ['feature.message.jump.use'],
            ),
          ],
        ),
      ),
      pageCatalogService: _TestShellPageCatalogService(),
      messageService: _TestShellMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'account_settings',
            targetTabCode: null,
            targetRoutePayloadJson:
                '{"target_tab_code":"account_settings","anchor":"account-settings-change-password-anchor"}',
          ),
        },
      ),
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _FakeMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      onLogout: () {},
    );

    await tester.tap(find.byKey(const ValueKey('main-shell-menu-message')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('main-shell-content-message')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('message-center-jump-301')));
    await tester.pumpAndSettle();

    expect(find.text('您没有访问该页面的权限'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('main-shell-content-message')),
      findsOneWidget,
    );
  });
}
