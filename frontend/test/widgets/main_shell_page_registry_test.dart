import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/message/presentation/message_center_page.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page_registry.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

import 'main_shell_test_support.dart';

void main() {
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
      softwareSettingsController: SoftwareSettingsController.memory(),
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
            return const Text('override-user-page');
          },
    );

    expect(widget, isA<Text>());
    expect((widget as Text).data, 'override-user-page');
  });

  test('消息模块会透传 refreshTick 与 routePayloadJson', () {
    const registry = MainShellPageRegistry();
    final state = MainShellViewState(
      currentUser: buildCurrentUser(),
      authzSnapshot: buildSnapshot(
        visibleSidebarCodes: const ['message'],
        tabCodesByParent: const {
          'message': ['message_center'],
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
      catalog: buildCatalog(),
      tabCodesByParent: const {
        'message': ['message_center'],
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
      softwareSettingsController: SoftwareSettingsController.memory(),
    );

    expect(widget, isA<MessageCenterPage>());
    final messagePage = widget as MessageCenterPage;
    expect(messagePage.refreshTick, 3);
    expect(messagePage.routePayloadJson, '{"preset":"todo_only"}');
  });
}
