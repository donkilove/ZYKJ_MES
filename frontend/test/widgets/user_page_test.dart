import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/pages/account_settings_page.dart';
import 'package:mes_client/pages/function_permission_config_page.dart';
import 'package:mes_client/pages/user_page.dart';

Finder _findSemanticsLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: $label)',
  );
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
