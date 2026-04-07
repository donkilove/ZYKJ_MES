import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/pages/register_page.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/auth_service.dart';

class _FakeRegisterAuthService extends AuthService {
  int registerCalls = 0;
  String? lastBaseUrl;
  String? lastAccount;
  String? lastPassword;
  Object? registerError;
  Completer<void>? registerCompleter;

  @override
  Future<void> register({
    required String baseUrl,
    required String account,
    required String password,
  }) async {
    registerCalls += 1;
    lastBaseUrl = baseUrl;
    lastAccount = account;
    lastPassword = password;
    if (registerError != null) {
      throw registerError!;
    }
    if (registerCompleter != null) {
      await registerCompleter!.future;
    }
  }
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _pumpRegisterFlow(
  WidgetTester tester, {
  required AuthService authService,
  required ValueChanged<RegisterPageResult?> onResult,
  String initialBaseUrl = 'http://example.test/api/v1',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute<RegisterPageResult>(
                    builder: (_) => RegisterPage(
                      initialBaseUrl: initialBaseUrl,
                      authService: authService,
                    ),
                  ),
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.widgetWithText(FilledButton, 'open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('注册页主链路成功后返回注册结果', (tester) async {
    final authService = _FakeRegisterAuthService();
    RegisterPageResult? capturedResult;

    await _pumpRegisterFlow(
      tester,
      authService: authService,
      onResult: (result) {
        capturedResult = result;
      },
    );

    await tester.enterText(_field('接口地址'), 'http://new.example.test/api/v1/');
    await tester.enterText(_field('账号'), 'new_user');
    await tester.enterText(_field('密码'), 'Pass123');
    await tester.enterText(_field('确认密码'), 'Pass123');
    await tester.tap(find.widgetWithText(FilledButton, '提交注册申请'));
    await tester.pumpAndSettle();

    expect(authService.registerCalls, 1);
    expect(authService.lastBaseUrl, 'http://new.example.test/api/v1');
    expect(authService.lastAccount, 'new_user');
    expect(authService.lastPassword, 'Pass123');
    expect(find.byType(RegisterPage), findsNothing);
    expect(capturedResult, isNotNull);
    expect(capturedResult!.baseUrl, 'http://new.example.test/api/v1');
    expect(capturedResult!.account, 'new_user');
  });

  testWidgets('注册失败时展示服务端错误提示', (tester) async {
    final authService = _FakeRegisterAuthService()
      ..registerError = ApiException('账号已存在', 409);

    await _pumpRegisterFlow(tester, authService: authService, onResult: (_) {});

    await tester.enterText(_field('账号'), 'new_user');
    await tester.enterText(_field('密码'), 'Pass123');
    await tester.enterText(_field('确认密码'), 'Pass123');
    await tester.tap(find.widgetWithText(FilledButton, '提交注册申请'));
    await tester.pumpAndSettle();

    expect(find.text('账号已存在，请更换账号后重试。'), findsOneWidget);
    expect(authService.registerCalls, 1);
  });

  testWidgets('注册页会执行基础表单校验', (tester) async {
    final authService = _FakeRegisterAuthService();

    await _pumpRegisterFlow(tester, authService: authService, onResult: (_) {});

    await tester.enterText(_field('接口地址'), '');
    await tester.tap(find.widgetWithText(FilledButton, '提交注册申请'));
    await tester.pump();

    expect(find.text('请输入接口地址'), findsOneWidget);
    expect(find.text('请输入账号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(find.text('请再次输入密码'), findsOneWidget);

    await tester.enterText(_field('接口地址'), 'http://example.test/api/v1');
    await tester.enterText(_field('账号'), 'a');
    await tester.enterText(_field('密码'), '12345');
    await tester.enterText(_field('确认密码'), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '提交注册申请'));
    await tester.pump();

    expect(find.text('账号至少 2 个字符'), findsOneWidget);
    expect(find.text('密码至少 6 个字符'), findsOneWidget);
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(authService.registerCalls, 0);
  });

  testWidgets('注册页会校验账号最大长度和连续字符密码规则', (tester) async {
    final authService = _FakeRegisterAuthService();

    await _pumpRegisterFlow(tester, authService: authService, onResult: (_) {});

    await tester.enterText(_field('接口地址'), 'http://example.test/api/v1');
    await tester.enterText(_field('账号'), 'abcdefghijk');
    await tester.enterText(_field('密码'), 'aaaaaa');
    await tester.enterText(_field('确认密码'), 'aaaaaa');
    await tester.tap(find.widgetWithText(FilledButton, '提交注册申请'));
    await tester.pump();

    expect(find.text('账号最多 10 个字符'), findsOneWidget);
    expect(find.text('密码不能包含连续4位相同字符'), findsOneWidget);
    expect(authService.registerCalls, 0);
  });
}
