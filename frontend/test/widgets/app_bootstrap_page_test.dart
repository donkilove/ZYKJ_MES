import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/main.dart';

void main() {
  testWidgets('应用启动后直接进入登录页而不是显示启动清理态', (tester) async {
    await tester.pumpWidget(const MesClientApp());

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byKey(const Key('login-account-field')), findsOneWidget);
  });
}
