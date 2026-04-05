import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/models/current_user.dart';
import 'package:mes_client/models/page_catalog_models.dart';
import 'package:mes_client/pages/main_shell_page.dart';
import 'package:mes_client/services/auth_service.dart';
import 'package:mes_client/services/authz_service.dart';
import 'package:mes_client/services/message_service.dart';
import 'package:mes_client/services/message_ws_service.dart';
import 'package:mes_client/services/page_catalog_service.dart';

final AppSession _session = AppSession(
  baseUrl: 'http://example.test/api/v1',
  accessToken: 'token',
);

class _FakeShellAuthService extends AuthService {
  @override
  Future<CurrentUser> getCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
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
}

class _FakeShellAuthzService extends AuthzService {
  _FakeShellAuthzService() : super(_session);

  @override
  Future<AuthzSnapshotResult> loadAuthzSnapshot() async {
    return const AuthzSnapshotResult(
      revision: 1,
      roleCodes: ['quality_admin'],
      visibleSidebarCodes: ['user'],
      tabCodesByParent: {
        'user': ['role_management', 'user_management'],
      },
      moduleItems: [
        AuthzSnapshotModuleItem(
          moduleCode: 'user',
          moduleName: '用户管理',
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

class _FakeShellPageCatalogService extends PageCatalogService {
  _FakeShellPageCatalogService() : super(_session);

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
    ];
  }
}

class _FakeShellMessageService extends MessageService {
  _FakeShellMessageService() : super(_session);

  @override
  Future<int> getUnreadCount() async => 0;
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

void main() {
  testWidgets('主壳页会把用户模块可见页签按目录顺序装配给用户页', (tester) async {
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
          authService: _FakeShellAuthService(),
          authzService: _FakeShellAuthzService(),
          pageCatalogService: _FakeShellPageCatalogService(),
          messageService: _FakeShellMessageService(),
          messageWsServiceFactory:
              ({
                required baseUrl,
                required accessToken,
                required onEvent,
                required onDisconnected,
              }) {
                return _FakeMessageWsService(
                  baseUrl: baseUrl,
                  accessToken: accessToken,
                  onEvent: onEvent,
                  onDisconnected: onDisconnected,
                );
              },
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('用户'), findsWidgets);

    await tester.tap(find.text('用户').first);
    await tester.pumpAndSettle();

    expect(
      find.text('tabs:user_management,role_management|preferred:-'),
      findsOneWidget,
    );
  });
}
