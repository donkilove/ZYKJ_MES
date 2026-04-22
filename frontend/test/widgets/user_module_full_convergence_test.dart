import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 1600, height: 1200, child: child)),
  );
}

void main() {
  testWidgets('UserPage 接入统一总页壳层并保留稳定页签栏锚点', (tester) async {
    await tester.pumpWidget(
      _host(
        UserPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          visibleTabCodes: const [
            'user_management',
            'registration_approval',
            'role_management',
          ],
          capabilityCodes: const <String>{},
          preferredTabCode: 'user_management',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user-page-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('user-page-tab-bar')), findsOneWidget);
    expect(find.text('用户管理'), findsWidgets);
    expect(find.text('注册审批'), findsWidgets);
    expect(find.text('角色管理'), findsWidgets);
  });
}
