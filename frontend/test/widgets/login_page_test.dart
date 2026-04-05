import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/pages/login_page.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/auth_service.dart';

class _FakeAuthService extends AuthService {
  int loginCalls = 0;
  String? lastBaseUrl;
  String? lastUsername;
  String? lastPassword;
  Object? loginError;

  @override
  Future<List<String>> listAccounts({required String baseUrl}) async {
    return ['tester', 'operator_a'];
  }

  @override
  Future<({String token, bool mustChangePassword})> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    loginCalls += 1;
    lastBaseUrl = baseUrl;
    lastUsername = username;
    lastPassword = password;
    if (loginError != null) {
      throw loginError!;
    }
    return (token: 'token-123', mustChangePassword: true);
  }
}

void main() {
  testWidgets('登录页完成登录主链路并回传会话', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final authService = _FakeAuthService();
    AppSession? capturedSession;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          defaultBaseUrl: 'http://example.test/api/v1',
          authService: authService,
          onLoginSuccess: (session) {
            capturedSession = session;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '账号'), 'tester');
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), 'Pass123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '登录'));
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(authService.loginCalls, 1);
    expect(authService.lastBaseUrl, 'http://example.test/api/v1');
    expect(authService.lastUsername, 'tester');
    expect(authService.lastPassword, 'Pass123');
    expect(capturedSession, isNotNull);
    expect(capturedSession!.accessToken, 'token-123');
    expect(capturedSession!.mustChangePassword, isTrue);
  });

  testWidgets('登录失败时会展示服务端错误消息', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final authService = _FakeAuthService()
      ..loginError = ApiException('账号或密码错误', 401);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          defaultBaseUrl: 'http://example.test/api/v1',
          authService: authService,
          onLoginSuccess: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '账号'), 'tester');
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'wrong-pass',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, '登录'));
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('登录失败：账号或密码错误'), findsOneWidget);
  });
}
