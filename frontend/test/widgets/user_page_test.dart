import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/user/presentation/account_settings_page.dart';
import 'package:mes_client/features/user/presentation/audit_log_page.dart';
import 'package:mes_client/features/user/presentation/function_permission_config_page.dart';
import 'package:mes_client/features/user/presentation/login_session_page.dart';
import 'package:mes_client/features/user/presentation/registration_approval_page.dart';
import 'package:mes_client/features/user/presentation/role_management_page.dart';
import 'package:mes_client/features/user/presentation/user_management_page.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';

Finder _findSemanticsLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: $label)',
  );
}

List<String> _tabTitles(WidgetTester tester) {
  final tabBar = tester.widget<TabBar>(find.byType(TabBar));
  return tabBar.tabs.map((tab) {
    final semantics = (tab as Tab).child! as Semantics;
    final padding = semantics.child! as Padding;
    final text = padding.child! as Text;
    return text.data!;
  }).toList();
}

void main() {
  testWidgets('用户页会按默认顺序装配页签并自动补齐个人中心', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['role_management', 'user_management'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'account_settings',
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('用户管理'), findsOneWidget);
    expect(find.text('角色管理'), findsOneWidget);
    expect(find.text('个人中心'), findsOneWidget);
    expect(find.text('tab:account_settings'), findsOneWidget);
  });

  testWidgets('用户页会按固定顺序装配全部页签并保持完整装配', (tester) async {
    final capturedChildren = <String, Type>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const [
              'function_permission_config',
              'audit_log',
              'role_management',
              'login_session',
              'registration_approval',
              'user_management',
            ],
            capabilityCodes: const <String>{},
            preferredTabCode: 'user_management',
            tabPageBuilder: (tabCode, child) {
              capturedChildren[tabCode] = child.runtimeType;
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_tabTitles(tester), const [
      '用户管理',
      '注册审批',
      '角色管理',
      '审计日志',
      '个人中心',
      '登录会话',
      '功能权限配置',
    ]);
    expect(capturedChildren, {
      'user_management': LegacyLegacyUserManagementPage,
      'registration_approval': RegistrationApprovalPage,
      'role_management': RoleManagementPage,
      'audit_log': AuditLogPage,
      'account_settings': AccountSettingsPage,
      'login_session': LoginSessionPage,
      'function_permission_config': FunctionPermissionConfigPage,
    });
  });

  testWidgets('用户页在无可见页签时仍会保留个人中心入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const <String>[],
            capabilityCodes: const <String>{},
            preferredTabCode: 'account_settings',
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('个人中心'), findsOneWidget);
    expect(find.text('tab:account_settings'), findsOneWidget);
    expect(find.text('当前账号没有可访问的用户模块页面'), findsNothing);
  });

  testWidgets('用户页仅在个人中心为目标页签时透传 routePayloadJson', (tester) async {
    AccountSettingsPage? accountSettingsPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['login_session'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'login_session',
            routePayloadJson: '{"action":"change_password"}',
            tabPageBuilder: (tabCode, child) {
              if (child is AccountSettingsPage) {
                accountSettingsPage = child;
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(accountSettingsPage, isNotNull);
    expect(accountSettingsPage!.routePayloadJson, isNull);
    expect(find.text('tab:login_session'), findsOneWidget);
  });

  testWidgets('用户页在个人中心为目标页签时透传 routePayloadJson', (tester) async {
    AccountSettingsPage? accountSettingsPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['login_session'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'account_settings',
            routePayloadJson: '{"action":"change_password"}',
            tabPageBuilder: (tabCode, child) {
              if (child is AccountSettingsPage) {
                accountSettingsPage = child;
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(accountSettingsPage, isNotNull);
    expect(
      accountSettingsPage!.routePayloadJson,
      '{"action":"change_password"}',
    );
    expect(find.text('tab:account_settings'), findsOneWidget);
  });

  testWidgets('用户页会将可见性刷新回调透传到功能权限配置页', (tester) async {
    FunctionPermissionConfigPage? permissionPage;
    var callbackCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['function_permission_config'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'function_permission_config',
            onVisibilityConfigSaved: () {
              callbackCalls += 1;
            },
            tabPageBuilder: (tabCode, child) {
              if (child is FunctionPermissionConfigPage) {
                permissionPage = child;
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(permissionPage, isNotNull);
    await permissionPage!.onPermissionsChanged?.call();
    expect(callbackCalls, 1);
  });

  testWidgets('用户页更新 preferredTabCode 时会切换到目标页签', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['role_management', 'audit_log'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'role_management',
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('tab:role_management'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['role_management', 'audit_log'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'audit_log',
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('tab:audit_log'), findsOneWidget);
  });

  testWidgets('用户管理页存在时会透传跳转到角色管理回调', (tester) async {
    LegacyLegacyUserManagementPage? userManagementPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['user_management', 'role_management'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'user_management',
            tabPageBuilder: (tabCode, child) {
              if (child is LegacyLegacyUserManagementPage) {
                userManagementPage = child;
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(userManagementPage, isNotNull);
    expect(userManagementPage!.onNavigateToRoleManagement, isNotNull);

    userManagementPage!.onNavigateToRoleManagement!.call();
    await tester.pumpAndSettle();

    expect(find.text('tab:role_management'), findsOneWidget);
  });

  testWidgets('角色管理页签不可见时不提供用户管理跳转回调', (tester) async {
    LegacyLegacyUserManagementPage? userManagementPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const ['user_management'],
            capabilityCodes: const <String>{},
            preferredTabCode: 'user_management',
            tabPageBuilder: (tabCode, child) {
              if (child is LegacyLegacyUserManagementPage) {
                userManagementPage = child;
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(userManagementPage, isNotNull);
    expect(userManagementPage!.onNavigateToRoleManagement, isNull);
  });

  testWidgets('用户页为长标题页签提供稳定语义标签', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {},
            visibleTabCodes: const [
              'account_settings',
              'login_session',
              'function_permission_config',
            ],
            capabilityCodes: const <String>{},
            preferredTabCode: 'account_settings',
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_findSemanticsLabel('用户模块页签栏'), findsOneWidget);
    expect(_findSemanticsLabel('个人中心页签'), findsOneWidget);
    expect(_findSemanticsLabel('登录会话页签'), findsOneWidget);
    expect(_findSemanticsLabel('功能权限配置页签'), findsOneWidget);
  });
}
