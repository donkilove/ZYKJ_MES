import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/account_settings_page.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/auth_service.dart';
import 'package:mes_client/services/user_service.dart';

Finder _findSemanticsLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: $label)',
  );
}

class _FakeUserService extends UserService {
  _FakeUserService() : super(AppSession(baseUrl: '', accessToken: ''));

  int changePasswordCalls = 0;
  int getMySessionCalls = 0;
  Object? getMySessionError;
  Object? changePasswordError;
  CurrentSessionResult currentSession = CurrentSessionResult(
    sessionTokenId: 'session-1',
    loginTime: DateTime.parse('2026-03-21T08:00:00Z'),
    lastActiveAt: DateTime.parse('2026-03-21T08:30:00Z'),
    expiresAt: DateTime.parse('2026-03-21T10:00:00Z'),
    status: 'active',
    remainingSeconds: 3600,
  );

  @override
  Future<ProfileResult> getMyProfile() async {
    return ProfileResult(
      id: 1,
      username: 'tester',
      fullName: '测试用户',
      roleCode: 'quality_admin',
      roleName: '品质管理员',
      stageId: null,
      stageName: null,
      isActive: true,
      createdAt: DateTime.parse('2026-03-20T08:00:00Z'),
      lastLoginAt: DateTime.parse('2026-03-21T08:00:00Z'),
      lastLoginIp: '127.0.0.1',
      passwordChangedAt: DateTime.parse('2026-03-21T09:00:00Z'),
    );
  }

  @override
  Future<CurrentSessionResult> getMySession() async {
    getMySessionCalls += 1;
    final error = getMySessionError;
    if (error != null) {
      throw error;
    }
    return currentSession;
  }

  @override
  Future<void> changeMyPassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final error = changePasswordError;
    if (error != null) {
      throw error;
    }
    changePasswordCalls += 1;
  }
}

class _FakeAuthService extends AuthService {
  int logoutCalls = 0;

  @override
  Future<void> logout({
    required String baseUrl,
    required String accessToken,
  }) async {
    logoutCalls += 1;
  }
}

void main() {
  testWidgets('account settings auto lands on change password section once', (
    tester,
  ) async {
    const routePayloadJson = '{"action":"change_password"}';

    Future<void> pumpPage() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSettingsPage(
              session: AppSession(baseUrl: '', accessToken: ''),
              onLogout: () {},
              canChangePassword: true,
              canViewSession: false,
              routePayloadJson: routePayloadJson,
              userService: _FakeUserService(),
            ),
          ),
        ),
      );
    }

    await pumpPage();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('account-settings-change-password-anchor')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-settings-change-password-anchor')),
      findsNothing,
    );

    await pumpPage();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('account-settings-change-password-anchor')),
      findsNothing,
    );
  });

  testWidgets('账号设置页直接展示并校验最新密码规则', (tester) async {
    final userService = _FakeUserService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canChangePassword: true,
            canViewSession: false,
            userService: userService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('不能与系统中已有用户密码相同'), findsNothing);
    expect(find.text('密码规则：至少6位；不能包含连续4位相同字符；不能与原密码相同。'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'OldPass1');
    await tester.enterText(find.byType(TextFormField).at(1), '12345');
    await tester.enterText(find.byType(TextFormField).at(2), '12345');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '修改密码'));
    await tester.tap(find.widgetWithText(FilledButton, '修改密码'));
    await tester.pump();
    expect(find.text('新密码长度不能少于 6 位'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'aaaaaa');
    await tester.enterText(find.byType(TextFormField).at(2), 'aaaaaa');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '修改密码'));
    await tester.tap(find.widgetWithText(FilledButton, '修改密码'));
    await tester.pump();
    expect(find.text('新密码不能包含连续4位相同字符'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'OldPass1');
    await tester.enterText(find.byType(TextFormField).at(2), 'OldPass1');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '修改密码'));
    await tester.tap(find.widgetWithText(FilledButton, '修改密码'));
    await tester.pump();
    expect(find.text('新密码不能与原密码相同'), findsOneWidget);
    expect(userService.changePasswordCalls, 0);
  });

  testWidgets('账号设置页主动退出当前登录会调用登出与退出回调', (tester) async {
    final authService = _FakeAuthService();
    var logoutCallbackCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsPage(
            session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
            onLogout: () {
              logoutCallbackCalls += 1;
            },
            canChangePassword: true,
            canViewSession: true,
            userService: _FakeUserService(),
            authService: authService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '退出当前登录'));
    await tester.tap(find.widgetWithText(OutlinedButton, '退出当前登录'));
    await tester.pumpAndSettle();

    expect(authService.logoutCalls, 1);
    expect(logoutCallbackCalls, 1);
  });

  testWidgets('账号设置页会话即将过期时展示提示弹窗', (tester) async {
    final userService = _FakeUserService()
      ..currentSession = CurrentSessionResult(
        sessionTokenId: 'session-warning',
        loginTime: DateTime.parse('2026-03-21T08:00:00Z'),
        lastActiveAt: DateTime.parse('2026-03-21T08:30:00Z'),
        expiresAt: DateTime.parse('2026-03-21T08:34:00Z'),
        status: 'active',
        remainingSeconds: 240,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canChangePassword: true,
            canViewSession: true,
            userService: userService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('会话即将过期'), findsOneWidget);
    expect(find.textContaining('当前会话将在 4 分钟 后过期'), findsOneWidget);
    expect(find.text('即将过期'), findsWidgets);
  });

  testWidgets('账号设置页会话失效后自动登出并提示', (tester) async {
    final userService = _FakeUserService()
      ..currentSession = CurrentSessionResult(
        sessionTokenId: 'session-invalid',
        loginTime: DateTime.parse('2026-03-21T08:00:00Z'),
        lastActiveAt: DateTime.parse('2026-03-21T08:30:00Z'),
        expiresAt: DateTime.parse('2026-03-21T10:00:00Z'),
        status: 'expired',
        remainingSeconds: 0,
      );
    var logoutCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {
              logoutCalls += 1;
            },
            canChangePassword: true,
            canViewSession: true,
            userService: userService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前登录会话已失效，请重新登录。'), findsOneWidget);
    expect(logoutCalls, 1);
  });

  testWidgets('账号设置页刷新会话遇到 401 时自动登出', (tester) async {
    final userService = _FakeUserService();
    var logoutCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {
              logoutCalls += 1;
            },
            canChangePassword: true,
            canViewSession: true,
            userService: userService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    userService.getMySessionError = ApiException('未登录', 401);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text('登录状态已失效，请重新登录。'), findsOneWidget);
    expect(logoutCalls, 1);
    expect(userService.getMySessionCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('账号设置页修改密码失败时展示错误提示', (tester) async {
    final userService = _FakeUserService()
      ..changePasswordError = ApiException('原密码错误', 400);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canChangePassword: true,
            canViewSession: false,
            userService: userService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'OldPass1');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPass1');
    await tester.enterText(find.byType(TextFormField).at(2), 'NewPass1');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '修改密码'));
    await tester.tap(find.widgetWithText(FilledButton, '修改密码'));
    await tester.pumpAndSettle();

    expect(find.text('修改密码失败：原密码错误'), findsOneWidget);
    expect(userService.changePasswordCalls, 0);
  });

  testWidgets('账号设置页暴露稳定主区域语义标签', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canChangePassword: true,
            canViewSession: true,
            userService: _FakeUserService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_findSemanticsLabel('个人中心主区域'), findsOneWidget);
  });
}
