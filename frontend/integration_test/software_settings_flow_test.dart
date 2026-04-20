import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';
import 'package:mes_client/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return const AuthzSnapshotResult(
      revision: 1,
      roleCodes: ['system_admin'],
      visibleSidebarCodes: ['message'],
      tabCodesByParent: {
        'message': ['message_center'],
      },
      moduleItems: [
        AuthzSnapshotModuleItem(
          moduleCode: 'message',
          moduleName: '消息',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: [],
          effectiveActionPermissionCodes: [],
        ),
      ],
    );
  }
}

class _FakePageCatalogService extends PageCatalogService {
  _FakePageCatalogService() : super(_session);

  @override
  Future<List<PageCatalogItem>> listPageCatalog() async {
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
}

class _FakeMessageService extends MessageService {
  _FakeMessageService() : super(_session);

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<MessageSummaryResult> getSummary() async {
    return const MessageSummaryResult(
      totalCount: 0,
      unreadCount: 0,
      todoUnreadCount: 0,
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
    return const MessageListResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

class _FakeHomeDashboardService extends HomeDashboardService {
  _FakeHomeDashboardService() : super(_session);

  @override
  Future<HomeDashboardData> load() async {
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

TimeSyncController _buildTimeSyncController(
  SoftwareSettingsController controller,
) {
  return TimeSyncController(
    softwareSettingsController: controller,
    serverTimeService: _FakeServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
  );
}

class _FakeServerTimeService extends ServerTimeService {
  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    return ServerTimeSnapshot(
      serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 0),
      serverTimezoneOffsetMinutes: 480,
      sampledAtEpochMs: DateTime.utc(
        2026,
        4,
        20,
        2,
        0,
        0,
      ).millisecondsSinceEpoch,
    );
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {}

Future<void> _pumpMainShellPage(
  WidgetTester tester, {
  required SoftwareSettingsController controller,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MainShellPage(
        session: _session,
        onLogout: () {},
        softwareSettingsController: controller,
        timeSyncController: _buildTimeSyncController(controller),
        authService: _FakeAuthService(),
        authzService: _FakeAuthzService(),
        pageCatalogService: _FakePageCatalogService(),
        messageService: _FakeMessageService(),
        homeDashboardService: _FakeHomeDashboardService(),
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('软件设置页可切换到时间同步并展示统一页头', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final controller = SoftwareSettingsController(
      service: await SoftwareSettingsService.create(),
    );
    await controller.load();

    await _pumpMainShellPage(tester, controller: controller);

    await tester.tap(
      find.byKey(const ValueKey('main-shell-entry-software-settings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('控制本机软件的外观、布局和时间同步偏好。'), findsOneWidget);

    await tester.tap(find.text('时间同步').first);
    await tester.pumpAndSettle();

    expect(find.text('启用时间同步'), findsOneWidget);
    expect(find.text('立即检查并同步'), findsOneWidget);
  });

  testWidgets('修改软件设置后重建应用会保留主题偏好但仍显示登录页', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final firstController = SoftwareSettingsController(
      service: await SoftwareSettingsService.create(),
    );
    await firstController.load();

    await _pumpMainShellPage(tester, controller: firstController);

    await tester.tap(
      find.byKey(const ValueKey('main-shell-entry-software-settings')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(RadioListTile<AppThemePreference>, '深色'),
    );
    await tester.pumpAndSettle();

    expect(firstController.settings.themePreference, AppThemePreference.dark);

    final secondController = SoftwareSettingsController(
      service: await SoftwareSettingsService.create(),
    );
    await secondController.load();

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: secondController,
        timeSyncController: _buildTimeSyncController(secondController),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
