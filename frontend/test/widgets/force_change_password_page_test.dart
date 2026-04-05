import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/pages/force_change_password_page.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeForceChangePasswordUserService extends UserService {
  _FakeForceChangePasswordUserService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  int changePasswordCalls = 0;

  @override
  Future<void> changeMyPassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    changePasswordCalls += 1;
  }
}

void main() {
  testWidgets('首次强制改密页直接展示并校验密码规则', (tester) async {
    final userService = _FakeForceChangePasswordUserService();
    var reloginCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ForceChangePasswordPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onRequireRelogin: () {
            reloginCalls += 1;
          },
          userService: userService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('不能与系统中已有用户密码相同'), findsNothing);
    expect(find.text('密码规则：至少6位；不能包含连续4位相同字符；不能与当前密码相同。'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'OldPass1');
    await tester.enterText(find.byType(TextFormField).at(1), '12345');
    await tester.enterText(find.byType(TextFormField).at(2), '12345');
    await tester.tap(find.widgetWithText(FilledButton, '确认修改'));
    await tester.pump();
    expect(find.text('密码至少 6 个字符'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'aaaaaa');
    await tester.enterText(find.byType(TextFormField).at(2), 'aaaaaa');
    await tester.tap(find.widgetWithText(FilledButton, '确认修改'));
    await tester.pump();
    expect(find.text('新密码不能包含连续4位相同字符'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'OldPass1');
    await tester.enterText(find.byType(TextFormField).at(2), 'OldPass1');
    await tester.tap(find.widgetWithText(FilledButton, '确认修改'));
    await tester.pump();
    expect(find.text('新密码不能与当前密码相同'), findsOneWidget);

    expect(userService.changePasswordCalls, 0);
    expect(reloginCalls, 0);
  });
}
