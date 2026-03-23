import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/audit_log_page.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeAuditUserService extends UserService {
  _FakeAuditUserService() : super(AppSession(baseUrl: '', accessToken: ''));

  int lastPage = 1;

  @override
  Future<AuditLogListResult> listAuditLogs({
    required int page,
    required int pageSize,
    String? operatorUsername,
    String? actionCode,
    String? targetType,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    lastPage = page;
    return AuditLogListResult(
      total: 210,
      items: [
        AuditLogItem(
          id: 1,
          occurredAt: DateTime.parse('2026-03-20T08:00:00Z'),
          operatorUserId: 1,
          operatorUsername: 'tester',
          actionCode: 'user.update',
          actionName: '更新用户',
          targetType: 'user',
          targetId: '1',
          targetName: '测试用户',
          result: 'success',
          beforeData: const {'status': 'inactive'},
          afterData: const {'status': 'active'},
          ipAddress: '127.0.0.1',
          terminalInfo: 'Windows',
          remark: null,
        ),
        AuditLogItem(
          id: 2,
          occurredAt: DateTime.parse('2026-03-20T09:00:00Z'),
          operatorUserId: 2,
          operatorUsername: 'auditor',
          actionCode: 'role.delete',
          actionName: '删除角色',
          targetType: 'role',
          targetId: '2',
          targetName: '旧角色',
          result: 'failed',
          beforeData: const {'role': '旧角色'},
          afterData: const {},
          ipAddress: '10.0.0.8',
          terminalInfo: 'Chrome',
          remark: null,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('audit log page renders desktop table shell', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final userService = _FakeAuditUserService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            child: AuditLogPage(
              session: AppSession(baseUrl: '', accessToken: ''),
              onLogout: () {},
              userService: userService,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('筛选条件'), findsOneWidget);
    expect(find.text('审计日志列表'), findsOneWidget);
    expect(find.text('总记录'), findsOneWidget);
    expect(find.text('本页成功'), findsOneWidget);
    expect(find.text('本页失败'), findsOneWidget);
    expect(find.text('更新用户'), findsOneWidget);
    expect(find.text('删除角色'), findsOneWidget);

    await tester.tap(find.byKey(const Key('simple-pagination-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 2 页').last);
    await tester.pumpAndSettle();

    expect(userService.lastPage, 2);
  });
}
