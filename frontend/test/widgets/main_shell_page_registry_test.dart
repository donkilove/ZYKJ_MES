import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/message/presentation/message_page.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_page.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/software_settings_page.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page_registry.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

import 'main_shell_test_support.dart';

void main() {
  final fixedClock = _FixedEffectiveClock();
  final softwareSettingsController = SoftwareSettingsController.memory();
  final timeSyncController = _buildTimeSyncController(
    softwareSettingsController,
    effectiveClock: fixedClock,
  );

  test('用户模块优先使用注入 builder', () {
    const registry = MainShellPageRegistry();
    final state = MainShellViewState(
      currentUser: buildCurrentUser(),
      authzSnapshot: buildSnapshot(),
      catalog: buildCatalog(),
      tabCodesByParent: const {
        'user': ['user_management'],
      },
      menus: const [
        MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
        MainShellMenuItem(code: 'user', title: '用户', icon: Icons.group),
      ],
      selectedPageCode: 'user',
    );

    final widget = registry.build(
      pageCode: 'user',
      session: testSession,
      state: state,
      onLogout: () {},
      onRefreshShellData: ({bool loadCatalog = true}) async {},
      onNavigateToPageTarget:
          ({required pageCode, String? tabCode, String? routePayloadJson}) {},
      onVisibilityConfigSaved: () {},
      onUnreadCountChanged: (_) {},
      messageService: MessageService(testSession),
      softwareSettingsController: softwareSettingsController,
      timeSyncController: timeSyncController,
      userPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            required bool moduleActive,
            String? preferredTabCode,
            String? routePayloadJson,
            VoidCallback? onVisibilityConfigSaved,
          }) {
            return const Text('override-user-page');
          },
    );

    expect(widget, isA<Text>());
    expect((widget as Text).data, 'override-user-page');
  });

  test('消息模块会返回 MessagePage 容器并透传页签与刷新参数', () {
    const registry = MainShellPageRegistry();
    final state = MainShellViewState(
      currentUser: buildCurrentUser(),
      authzSnapshot: buildSnapshot(
        visibleSidebarCodes: const ['message'],
        tabCodesByParent: const {
          'message': ['message_center', 'announcement_management'],
        },
        moduleItems: [
          buildModuleItem(
            'message',
            capabilityCodes: const [
              'feature.message.detail.view',
              'feature.message.announcement.publish',
            ],
          ),
        ],
      ),
      catalog: [
        ...buildCatalog(),
        const PageCatalogItem(
          code: 'announcement_management',
          name: '公告管理',
          pageType: 'tab',
          parentCode: 'message',
          alwaysVisible: false,
          sortOrder: 82,
        ),
      ],
      tabCodesByParent: const {
        'message': ['message_center', 'announcement_management'],
      },
      menus: const [
        MainShellMenuItem(
          code: 'message',
          title: '消息',
          icon: Icons.notifications,
        ),
      ],
      selectedPageCode: 'message',
      messageRefreshTick: 3,
      preferredTabCode: 'announcement_management',
      preferredRoutePayloadJson: '{"preset":"todo_only"}',
    );

    final widget = registry.build(
      pageCode: 'message',
      session: testSession,
      state: state,
      onLogout: () {},
      onRefreshShellData: ({bool loadCatalog = true}) async {},
      onNavigateToPageTarget:
          ({required pageCode, String? tabCode, String? routePayloadJson}) {},
      onVisibilityConfigSaved: () {},
      onUnreadCountChanged: (_) {},
      messageService: MessageService(testSession),
      softwareSettingsController: softwareSettingsController,
      timeSyncController: timeSyncController,
    );

    expect(widget, isA<MessagePage>());
    final messagePage = widget as MessagePage;
    expect(messagePage.visibleTabCodes, [
      'message_center',
      'announcement_management',
    ]);
    expect(messagePage.preferredTabCode, 'announcement_management');
    expect(messagePage.refreshTick, 3);
    expect(messagePage.routePayloadJson, '{"preset":"todo_only"}');
    expect(
      messagePage.nowProvider().toUtc(),
      DateTime.utc(2026, 4, 20, 10, 30),
    );
  });

  test('软件设置工具页会透传 timeSyncController 与 apiBaseUrl', () {
    const registry = MainShellPageRegistry();
    final state = MainShellViewState(
      currentUser: buildCurrentUser(),
      authzSnapshot: buildSnapshot(),
      catalog: buildCatalog(),
      tabCodesByParent: const {
        'user': ['user_management'],
      },
      menus: const [
        MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
      ],
      selectedPageCode: 'home',
    );

    final widget = registry.build(
      pageCode: softwareSettingsUtilityCode,
      session: testSession,
      state: state,
      onLogout: () {},
      onRefreshShellData: ({bool loadCatalog = true}) async {},
      onNavigateToPageTarget:
          ({required pageCode, String? tabCode, String? routePayloadJson}) {},
      onVisibilityConfigSaved: () {},
      onUnreadCountChanged: (_) {},
      messageService: MessageService(testSession),
      softwareSettingsController: softwareSettingsController,
      timeSyncController: timeSyncController,
    );

    expect(widget, isA<SoftwareSettingsPage>());
    final settingsPage = widget as SoftwareSettingsPage;
    expect(identical(settingsPage.timeSyncController, timeSyncController), isTrue);
    expect(settingsPage.apiBaseUrl, testSession.baseUrl);
  });

  test('插件中心工具页会返回 PluginHostPage', () {
    const registry = MainShellPageRegistry();
    final pluginHostController = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );
    final state = MainShellViewState(
      currentUser: buildCurrentUser(),
      authzSnapshot: buildSnapshot(),
      catalog: buildCatalog(),
      tabCodesByParent: const {
        'user': ['user_management'],
      },
      menus: const [
        MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
      ],
      selectedPageCode: 'home',
    );

    final widget = registry.build(
      pageCode: pluginHostUtilityCode,
      session: testSession,
      state: state,
      onLogout: () {},
      onRefreshShellData: ({bool loadCatalog = true}) async {},
      onNavigateToPageTarget:
          ({required pageCode, String? tabCode, String? routePayloadJson}) {},
      onVisibilityConfigSaved: () {},
      onUnreadCountChanged: (_) {},
      messageService: MessageService(testSession),
      softwareSettingsController: softwareSettingsController,
      timeSyncController: timeSyncController,
      pluginHostController: pluginHostController,
    );

    expect(widget, isA<PluginHostPage>());
  });
}

TimeSyncController _buildTimeSyncController(
  SoftwareSettingsController settingsController, {
  EffectiveClock? effectiveClock,
}) {
  return TimeSyncController(
    softwareSettingsController: settingsController,
    serverTimeService: _FakeServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: effectiveClock ?? EffectiveClock(),
  );
}

class _FakeServerTimeService extends ServerTimeService {
  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    return ServerTimeSnapshot(
      serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 0),
      serverTimezoneOffsetMinutes: 480,
      sampledAtEpochMs:
          DateTime.utc(2026, 4, 20, 2, 0, 0).millisecondsSinceEpoch,
    );
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {}

class _FixedEffectiveClock extends EffectiveClock {
  @override
  DateTime now() => DateTime.utc(2026, 4, 20, 10, 30);
}

class _StubCatalogService extends PluginCatalogService {
  _StubCatalogService() : super(pluginRootResolver: () async => '');

  @override
  Future<List<PluginCatalogItem>> scan() async {
    return const <PluginCatalogItem>[];
  }
}

class _StubProcessService extends PluginProcessService {
  _StubProcessService();
}

class _StubRuntimeLocator extends PluginRuntimeLocator {
  _StubRuntimeLocator()
    : super(
        executablePath: r'C:\ZYKJ_MES\mes_client.exe',
        environment: const {},
      );
}
