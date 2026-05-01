import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/misc/presentation/register_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';

class _FakeAuthService extends AuthService {
  int loginCalls = 0;
  int listAccountsCalls = 0;
  String? lastBaseUrl;
  String? lastUsername;
  String? lastPassword;
  Object? loginError;
  Object? listAccountsError;
  List<String> accounts = ['tester', 'operator_a'];
  Completer<({String token, bool mustChangePassword, int expiresIn})>? loginCompleter;

  @override
  Future<List<String>> listAccounts({required String baseUrl}) async {
    listAccountsCalls += 1;
    lastBaseUrl = baseUrl;
    if (listAccountsError != null) {
      throw listAccountsError!;
    }
    return accounts;
  }

  @override
  Future<({String token, bool mustChangePassword, int expiresIn})> login({
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
    if (loginCompleter != null) {
      return loginCompleter!.future;
    }
    return (token: 'token-123', mustChangePassword: true, expiresIn: 7200);
  }
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _pumpLoginPage(
  WidgetTester tester, {
  required AuthService authService,
  String defaultBaseUrl = 'http://example.test/api/v1',
  String? initialMessage,
  ValueChanged<AppSession>? onLoginSuccess,
  Future<List<MessageItem>> Function(String baseUrl)? publicAnnouncementLoader,
}) async {
  _setDesktopViewport(tester);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: LoginPage(
        defaultBaseUrl: defaultBaseUrl,
        initialMessage: initialMessage,
        authService: authService,
        publicAnnouncementLoader: publicAnnouncementLoader,
        onLoginSuccess: onLoginSuccess ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('登录页完成登录主链路并回传会话', (tester) async {
    final authService = _FakeAuthService();
    AppSession? capturedSession;

    await _pumpLoginPage(
      tester,
      authService: authService,
      onLoginSuccess: (session) {
        capturedSession = session;
      },
    );

    await tester.enterText(_field('账号'), 'tester');
    await tester.enterText(_field('密码'), 'Pass123');
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

  testWidgets('接口地址不合法时会阻止提交并展示校验信息', (tester) async {
    final authService = _FakeAuthService();

    await _pumpLoginPage(tester, authService: authService);

    await tester.enterText(_field('接口地址'), 'example.test/api/v1');
    await tester.enterText(_field('账号'), 'tester');
    await tester.enterText(_field('密码'), 'Pass123');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(find.text('地址必须以 http:// 或 https:// 开头'), findsOneWidget);
    expect(authService.loginCalls, 0);
  });

  testWidgets('点击刷新会重新拉取账号列表并支持下拉选择', (tester) async {
    final authService = _FakeAuthService();

    await _pumpLoginPage(tester, authService: authService);
    expect(authService.listAccountsCalls, 1);

    authService.accounts = ['operator_a', 'operator_b'];
    await tester.tap(find.byTooltip('刷新账号列表'));
    await tester.pumpAndSettle();

    expect(authService.listAccountsCalls, 2);
    expect(authService.lastBaseUrl, 'http://example.test/api/v1');

    await tester.enterText(_field('账号'), 'operator');
    await tester.pumpAndSettle();
    await tester.tap(find.text('operator_b').last);
    await tester.pumpAndSettle();

    final accountField = tester.widget<TextFormField>(_field('账号'));
    expect(accountField.controller!.text, 'operator_b');
  });

  testWidgets('账号列表加载失败时展示错误消息', (tester) async {
    final authService = _FakeAuthService()
      ..listAccountsError = ApiException('网络异常', 500);

    await _pumpLoginPage(tester, authService: authService);

    expect(find.text('加载账号列表失败：网络异常'), findsOneWidget);
  });

  testWidgets('回车键会触发登录提交', (tester) async {
    final authService = _FakeAuthService();

    await _pumpLoginPage(tester, authService: authService);

    await tester.enterText(_field('账号'), 'tester');
    await tester.enterText(_field('密码'), 'Pass123');
    await tester.tap(_field('密码'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(authService.loginCalls, 1);
  });

  testWidgets('小键盘回车会触发登录提交', (tester) async {
    final authService = _FakeAuthService();

    await _pumpLoginPage(tester, authService: authService);

    await tester.enterText(_field('账号'), 'tester');
    await tester.enterText(_field('密码'), 'Pass123');
    await tester.tap(_field('密码'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();

    expect(authService.loginCalls, 1);
  });

  testWidgets('登录进行中按钮会禁用并阻止重复提交', (tester) async {
    final authService = _FakeAuthService()
      ..loginCompleter = Completer<({String token, bool mustChangePassword, int expiresIn})>();

    await _pumpLoginPage(tester, authService: authService);

    await tester.enterText(_field('账号'), 'tester');
    await tester.enterText(_field('密码'), 'Pass123');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(authService.loginCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    authService.loginCompleter!.complete((
      token: 'token-123',
      mustChangePassword: false,
      expiresIn: 7200,
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('初始消息会直接展示', (tester) async {
    await _pumpLoginPage(
      tester,
      authService: _FakeAuthService(),
      initialMessage: '请先登录系统',
    );

    expect(find.text('请先登录系统'), findsOneWidget);
  });

  testWidgets('去注册返回后会回填账号与提示消息', (tester) async {
    final authService = _FakeAuthService();

    await _pumpLoginPage(tester, authService: authService);

    await tester.enterText(_field('接口地址'), 'http://new.example.test/api/v1');
    await tester.tap(find.widgetWithText(OutlinedButton, '去注册'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop(
      const RegisterPageResult(
        baseUrl: 'http://new.example.test/api/v1',
        account: 'new_user',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('注册申请已提交，请等待系统管理员审批后再登录。'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(_field('接口地址')).controller!.text,
      'http://new.example.test/api/v1',
    );
    expect(
      tester.widget<TextFormField>(_field('账号')).controller!.text,
      'new_user',
    );
    expect(authService.listAccountsCalls, 2);
    expect(authService.lastBaseUrl, 'http://new.example.test/api/v1');
  });

  testWidgets('公告区基础内容可正常渲染', (tester) async {
    await _pumpLoginPage(tester, authService: _FakeAuthService());

    expect(find.text('系统公告'), findsOneWidget);
    expect(find.text('生产运行提醒'), findsOneWidget);
    expect(find.text('质量与追溯要求'), findsOneWidget);
    expect(find.text('账号使用规范'), findsOneWidget);
  });

  testWidgets('登录页未登录时会加载后端全员公告', (tester) async {
    await _pumpLoginPage(
      tester,
      authService: _FakeAuthService(),
      publicAnnouncementLoader: (_) async => [
        MessageItem(
          id: 101,
          messageType: 'announcement',
          priority: 'important',
          title: '停机维护公告',
          summary: '今晚 20:00 维护',
          content: '今晚 20:00 至 21:00 执行停机维护，请提前保存数据。',
          sourceModule: 'message',
          sourceType: 'announcement',
          sourceCode: 'all',
          targetPageCode: null,
          targetTabCode: null,
          targetRoutePayloadJson: null,
          status: 'active',
          inactiveReason: null,
          publishedAt: DateTime.parse('2026-04-22T12:00:00Z'),
          expiresAt: DateTime.parse('2026-04-23T12:00:00Z'),
          isRead: false,
          readAt: null,
          deliveredAt: null,
          deliveryStatus: 'pending',
          deliveryAttemptCount: 0,
          lastPushAt: null,
          nextRetryAt: null,
        ),
      ],
    );

    expect(find.text('停机维护公告'), findsOneWidget);
    expect(find.textContaining('共 1 条公告'), findsOneWidget);
  });

  testWidgets('登录失败时会展示服务端错误消息', (tester) async {
    final authService = _FakeAuthService()
      ..loginError = ApiException('账号或密码错误', 401);

    await _pumpLoginPage(tester, authService: authService);

    await tester.enterText(_field('账号'), 'tester');
    await tester.enterText(_field('密码'), 'wrong-pass');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '登录'));
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('账号或密码错误，请重新输入。'), findsOneWidget);
  });

  testWidgets('登录失败时会映射驳回申请提示', (tester) async {
    final authService = _FakeAuthService()
      ..loginError = ApiException(
        'Account is rejected, please resubmit registration',
        403,
      );

    await _pumpLoginPage(tester, authService: authService);

    await tester.enterText(_field('账号'), 'tester');
    await tester.enterText(_field('密码'), 'wrong-pass');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '登录'));
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('该账号的注册申请已被驳回，请重新注册后再登录。'), findsOneWidget);
  });
}
