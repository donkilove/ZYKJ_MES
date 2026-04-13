import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';
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
    roleCode: 'system_admin',
    roleName: '系统管理员',
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

AuthzSnapshotResult _buildSnapshot() {
  return const AuthzSnapshotResult(
    revision: 1,
    roleCodes: ['system_admin'],
    visibleSidebarCodes: ['message'],
    tabCodesByParent: {
      'message': ['message_center'],
    },
    moduleItems: [],
  );
}

HomeDashboardData _buildDashboardData() {
  return HomeDashboardData(
    generatedAt: DateTime.parse('2026-04-12T12:00:00Z'),
    noticeCount: 2,
    todoSummary: const HomeDashboardTodoSummary(
      totalCount: 4,
      pendingApprovalCount: 1,
      highPriorityCount: 1,
      exceptionCount: 1,
      overdueCount: 0,
    ),
    todoItems: const [
      HomeDashboardTodoItem(
        id: 1,
        title: '待办 A',
        categoryLabel: '审批',
        priorityLabel: '高优',
        targetPageCode: 'user',
      ),
      HomeDashboardTodoItem(
        id: 2,
        title: '待办 B',
        categoryLabel: '生产',
        priorityLabel: '普通',
        targetPageCode: 'production',
      ),
      HomeDashboardTodoItem(
        id: 3,
        title: '待办 C',
        categoryLabel: '质量',
        priorityLabel: '普通',
        targetPageCode: 'quality',
      ),
      HomeDashboardTodoItem(
        id: 4,
        title: '待办 D',
        categoryLabel: '设备',
        priorityLabel: '普通',
        targetPageCode: 'equipment',
      ),
    ],
    riskItems: const [],
    kpiItems: const [],
    degradedBlocks: const [],
  );
}

class _FakeAuthService extends AuthService {
  @override
  Future<CurrentUser> getCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
    return _buildCurrentUser();
  }
}

class _FakeAuthzService extends AuthzService {
  _FakeAuthzService() : super(_session);

  @override
  Future<AuthzSnapshotResult> loadAuthzSnapshot() async {
    return _buildSnapshot();
  }
}

class _FakePageCatalogService extends PageCatalogService {
  _FakePageCatalogService() : super(_session);

  @override
  Future<List<PageCatalogItem>> listPageCatalog() async {
    return _buildCatalog();
  }
}

class _FakeMessageService extends MessageService {
  _FakeMessageService() : super(_session);

  bool lastTodoOnly = false;

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<MessageSummaryResult> getSummary() async {
    return const MessageSummaryResult(
      totalCount: 1,
      unreadCount: 1,
      todoUnreadCount: 1,
      urgentUnreadCount: 0,
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
    return const MessageListResult(
      items: [],
      total: 0,
      page: 1,
      pageSize: 20,
    );
  }
}

class _FakeHomeDashboardService extends HomeDashboardService {
  _FakeHomeDashboardService() : super(_session);

  @override
  Future<HomeDashboardData> load() async {
    return _buildDashboardData();
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

  @override
  void disconnect() {}

  @override
  void reconnect() {}
}

Future<void> _pumpHomeDashboardShell(
  WidgetTester tester, {
  required _FakeMessageService messageService,
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
        onLogout: () {},
        authService: _FakeAuthService(),
        authzService: _FakeAuthzService(),
        pageCatalogService: _FakePageCatalogService(),
        messageService: messageService,
        homeDashboardService: _FakeHomeDashboardService(),
        messageWsServiceFactory: ({
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登录后首页工作台展示 4 条待办并可跳转到消息待办视图', (tester) async {
    final messageService = _FakeMessageService();
    await _pumpHomeDashboardShell(tester, messageService: messageService);

    expect(find.text('我的待办队列'), findsOneWidget);
    expect(find.text('待办 A'), findsOneWidget);
    expect(find.text('待办 B'), findsOneWidget);
    expect(find.text('待办 C'), findsOneWidget);
    expect(find.text('待办 D'), findsOneWidget);

    await tester.tap(find.text('查看全部待办'));
    await tester.pumpAndSettle();

    expect(find.text('消息中心'), findsOneWidget);
    expect(messageService.lastTodoOnly, isTrue);
  });
}
