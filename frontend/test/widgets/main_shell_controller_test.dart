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
  _ControllerAuthzService() : super(testSession);

  @override
  Future<AuthzSnapshotResult> loadAuthzSnapshot() async => buildSnapshot();
}

class _ControllerPageCatalogService extends PageCatalogService {
  _ControllerPageCatalogService() : super(testSession);

  @override
  Future<List<PageCatalogItem>> listPageCatalog() async => buildCatalog();
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
  VoidCallback? onLogout,
}) {
  return MainShellController(
    session: testSession,
    onLogout: onLogout ?? () {},
    authService: authService ?? _ControllerAuthService(),
    authzService: authzService ?? _ControllerAuthzService(),
    pageCatalogService: pageCatalogService ?? _ControllerPageCatalogService(),
    messageService: messageService ?? _ControllerMessageService(),
    homeDashboardService:
        homeDashboardService ?? _ControllerHomeDashboardService(),
    messageWsServiceFactory: ({
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
      onLogout: () {
        logoutCalled = true;
      },
    );

    await controller.initialize();

    expect(logoutCalled, isTrue);
  });
}
