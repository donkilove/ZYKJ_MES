import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/login_session_page.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeSessionUserService extends UserService {
  _FakeSessionUserService() : super(AppSession(baseUrl: '', accessToken: ''));

  int lastLogPage = 1;
  int lastSessionPage = 1;
  int forceOfflineCalls = 0;

  @override
  Future<LoginLogListResult> listLoginLogs({
    required int page,
    required int pageSize,
    String? username,
    bool? success,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    lastLogPage = page;
    return LoginLogListResult(
      total: 220,
      items: [
        LoginLogItem(
          id: 1,
          loginTime: DateTime.parse('2026-03-20T08:00:00Z'),
          username: 'tester',
          success: true,
          ipAddress: '127.0.0.1',
          terminalInfo: 'Windows',
          failureReason: null,
          sessionTokenId: 'token-1',
        ),
        LoginLogItem(
          id: 2,
          loginTime: DateTime.parse('2026-03-20T09:00:00Z'),
          username: 'auditor',
          success: false,
          ipAddress: '10.0.0.2',
          terminalInfo: 'Chrome',
          failureReason: '密码错误',
          sessionTokenId: 'token-2',
        ),
      ],
    );
  }

  @override
  Future<OnlineSessionListResult> listOnlineSessions({
    required int page,
    required int pageSize,
    String? keyword,
    String? statusFilter,
  }) async {
    lastSessionPage = page;
    return OnlineSessionListResult(
      total: 205,
      items: [
        OnlineSessionItem(
          id: 1,
          sessionTokenId: 'session-1',
          userId: 10,
          username: 'tester',
          roleCode: 'system_admin',
          roleName: '系统管理员',
          stageId: null,
          stageName: '一车间',
          loginTime: DateTime.parse('2026-03-20T08:00:00Z'),
          lastActiveAt: DateTime.parse('2026-03-20T08:30:00Z'),
          expiresAt: DateTime.parse('2026-03-20T10:00:00Z'),
          ipAddress: '127.0.0.1',
          terminalInfo: 'Windows',
          status: 'active',
        ),
        OnlineSessionItem(
          id: 2,
          sessionTokenId: 'session-2',
          userId: 11,
          username: 'viewer',
          roleCode: 'quality_admin',
          roleName: '品质管理员',
          stageId: null,
          stageName: '二车间',
          loginTime: DateTime.parse('2026-03-20T07:00:00Z'),
          lastActiveAt: DateTime.parse('2026-03-20T07:10:00Z'),
          expiresAt: DateTime.parse('2026-03-20T08:00:00Z'),
          ipAddress: '10.0.0.9',
          terminalInfo: 'Edge',
          status: 'offline',
        ),
      ],
    );
  }

  @override
  Future<ForceOfflineResult> batchForceOffline({
    required List<String> sessionTokenIds,
  }) async {
    forceOfflineCalls += 1;
    return ForceOfflineResult(affected: sessionTokenIds.length);
  }
}

void main() {
  testWidgets('login session page renders desktop list shells', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final userService = _FakeSessionUserService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            child: LoginSessionPage(
              session: AppSession(baseUrl: '', accessToken: ''),
              onLogout: () {},
              canViewLoginLogs: true,
              canViewOnlineSessions: true,
              canForceOffline: true,
              userService: userService,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('登录日志'), findsWidgets);
    expect(find.text('总记录'), findsOneWidget);
    expect(find.text('本页成功'), findsOneWidget);
    expect(find.text('tester'), findsOneWidget);

    await tester.tap(find.text('在线会话').last);
    await tester.pumpAndSettle();

    expect(find.text('总会话'), findsOneWidget);
    expect(find.text('本页在线'), findsOneWidget);
    expect(find.text('批量强制下线（0）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（1）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('simple-pagination-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 2 页').last);
    await tester.pumpAndSettle();

    expect(userService.lastSessionPage, 2);
  });
}
