import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/presentation/main_shell_controller.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';

import 'main_shell_test_support.dart';

class _ControllerAuthService extends AuthService {
  _ControllerAuthService({this.error});

  final Object? error;

  @override
  Future<CurrentUser> getCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
    if (error != null) {
      throw error!;
    }
    return buildCurrentUser();
  }
}

class _ControllerAuthzService extends AuthzService {
  _ControllerAuthzService({this.snapshot}) : super(testSession);

  final AuthzSnapshotResult? snapshot;

  @override
  Future<AuthzSnapshotResult> loadAuthzSnapshot() async {
    return snapshot ?? buildSnapshot();
  }
}

class _ControllerPageCatalogService extends PageCatalogService {
  _ControllerPageCatalogService({this.catalog}) : super(testSession);

  final List<PageCatalogItem>? catalog;

  @override
  Future<List<PageCatalogItem>> listPageCatalog() async {
    return catalog ?? buildCatalog();
  }
}

class _ControllerMessageService extends MessageService {
  _ControllerMessageService() : super(testSession);

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
}

class _ControllerHomeDashboardService extends HomeDashboardService {
  _ControllerHomeDashboardService() : super(testSession);

  @override
  Future<HomeDashboardData> load() async => buildDashboardData();
}

class _ControllerMessageWsService extends MessageWsService {
  _ControllerMessageWsService({
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

MainShellController _buildController({
  AuthService? authService,
  AuthzService? authzService,
  PageCatalogService? pageCatalogService,
  MessageService? messageService,
  HomeDashboardService? homeDashboardService,
  SoftwareSettingsController? softwareSettingsController,
  void Function({String? reason})? onLogout,
}) {
  return MainShellController(
    session: testSession,
    onLogout: onLogout ?? ({String? reason}) {},
    authService: authService ?? _ControllerAuthService(),
    authzService: authzService ?? _ControllerAuthzService(),
    pageCatalogService: pageCatalogService ?? _ControllerPageCatalogService(),
    messageService: messageService ?? _ControllerMessageService(),
    homeDashboardService:
        homeDashboardService ?? _ControllerHomeDashboardService(),
    softwareSettingsController:
        softwareSettingsController ?? SoftwareSettingsController.memory(),
    messageWsServiceFactory:
        ({
          required String baseUrl,
          required String accessToken,
          required WsEventCallback onEvent,
          required void Function() onDisconnected,
        }) {
          return _ControllerMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          );
        },
  );
}

List<PageCatalogItem> _catalogWithQuality() {
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
      code: 'quality',
      name: '质量',
      pageType: 'sidebar',
      parentCode: null,
      alwaysVisible: false,
      sortOrder: 30,
    ),
  ];
}

void main() {
  test('initialize 成功后会写入当前用户、权限快照和菜单', () async {
    final controller = _buildController();

    await controller.initialize();

    expect(controller.state.currentUser?.username, 'tester');
    expect(controller.state.authzSnapshot, isNotNull);
    expect(controller.state.menus.map((item) => item.code), contains('home'));
  });

  test('initialize 遇到 401 会触发 onLogout', () async {
    var logoutCalled = false;
    final controller = _buildController(
      authService: _ControllerAuthService(
        error: ApiException('unauthorized', 401),
      ),
      onLogout: ({String? reason}) {
        logoutCalled = true;
      },
    );

    await controller.initialize();

    expect(logoutCalled, isTrue);
  });

  test(
    'launchTargetPreference=lastVisitedModule 且 lastVisitedPageCode=quality 时 initialize 后落到 quality',
    () async {
      final softwareSettingsController = SoftwareSettingsController.memory(
        initialSettings: const SoftwareSettings.defaults().copyWith(
          launchTargetPreference: AppLaunchTargetPreference.lastVisitedModule,
          lastVisitedPageCode: 'quality',
        ),
      );
      final controller = _buildController(
        softwareSettingsController: softwareSettingsController,
        pageCatalogService: _ControllerPageCatalogService(
          catalog: _catalogWithQuality(),
        ),
        authzService: _ControllerAuthzService(
          snapshot: buildSnapshot(
            visibleSidebarCodes: const ['user', 'quality'],
            tabCodesByParent: const {},
          ),
        ),
      );

      await controller.initialize();

      expect(controller.state.selectedPageCode, 'quality');
    },
  );

  test(
    '用户手动回到首页后 refreshVisibility 与 refreshShellDataFromUi 不应强制拉回 remembered page',
    () async {
      final softwareSettingsController = SoftwareSettingsController.memory(
        initialSettings: const SoftwareSettings.defaults().copyWith(
          launchTargetPreference: AppLaunchTargetPreference.lastVisitedModule,
          lastVisitedPageCode: 'quality',
        ),
      );
      final controller = _buildController(
        softwareSettingsController: softwareSettingsController,
        pageCatalogService: _ControllerPageCatalogService(
          catalog: _catalogWithQuality(),
        ),
        authzService: _ControllerAuthzService(
          snapshot: buildSnapshot(
            visibleSidebarCodes: const ['user', 'quality'],
            tabCodesByParent: const {},
          ),
        ),
      );

      await controller.initialize();
      expect(controller.state.selectedPageCode, 'quality');

      controller.selectMenu('home');
      expect(controller.state.selectedPageCode, 'home');

      await controller.refreshVisibility(loadCatalog: false);
      expect(controller.state.selectedPageCode, 'home');

      await controller.refreshShellDataFromUi(loadCatalog: false);
      expect(controller.state.selectedPageCode, 'home');
    },
  );

  test('openSoftwareSettings 不应清空当前业务页的 tab 与路由上下文', () async {
    final controller = _buildController();
    await controller.initialize();

    controller.navigateToPageTarget(
      pageCode: 'user',
      tabCode: 'role_management',
      routePayloadJson: '{"target_tab_code":"role_management"}',
    );
    expect(controller.state.selectedPageCode, 'user');
    expect(controller.state.preferredTabCode, 'role_management');
    expect(
      controller.state.preferredRoutePayloadJson,
      '{"target_tab_code":"role_management"}',
    );

    controller.openSoftwareSettings();
    expect(controller.state.activeUtilityCode, 'software_settings');
    expect(controller.state.preferredTabCode, 'role_management');
    expect(
      controller.state.preferredRoutePayloadJson,
      '{"target_tab_code":"role_management"}',
    );
  });

  test('从软件设置返回同模块时应保留原 tab 与路由上下文', () async {
    final controller = _buildController();
    await controller.initialize();

    controller.navigateToPageTarget(
      pageCode: 'user',
      tabCode: 'role_management',
      routePayloadJson: '{"target_tab_code":"role_management"}',
    );
    controller.openSoftwareSettings();
    controller.selectMenu('user');

    expect(controller.state.activeUtilityCode, isNull);
    expect(controller.state.selectedPageCode, 'user');
    expect(controller.state.preferredTabCode, 'role_management');
    expect(
      controller.state.preferredRoutePayloadJson,
      '{"target_tab_code":"role_management"}',
    );
  });

  test(
    'openSoftwareSettings 打开 utility page，selectMenu 会关闭 utility 并切换业务页',
    () async {
      final softwareSettingsController = SoftwareSettingsController.memory();
      final controller = _buildController(
        softwareSettingsController: softwareSettingsController,
      );

      await controller.initialize();
      controller.openSoftwareSettings();
      expect(controller.state.activeUtilityCode, 'software_settings');

      controller.selectMenu('user');
      expect(controller.state.activeUtilityCode, isNull);
      expect(controller.state.selectedPageCode, 'user');
    },
  );
}
