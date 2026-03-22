import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/account_settings_page.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeUserService extends UserService {
  _FakeUserService() : super(AppSession(baseUrl: '', accessToken: ''));

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
    return CurrentSessionResult(
      sessionTokenId: 'session-1',
      loginTime: DateTime.parse('2026-03-21T08:00:00Z'),
      lastActiveAt: DateTime.parse('2026-03-21T08:30:00Z'),
      expiresAt: DateTime.parse('2026-03-21T10:00:00Z'),
      status: 'active',
      remainingSeconds: 3600,
    );
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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-settings-change-password-anchor')),
      findsNothing,
    );
  });
}
