import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/registration_approval_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeApprovalUserService extends UserService {
  _FakeApprovalUserService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  int approveCalls = 0;
  int rejectCalls = 0;
  int? lastApprovedStageId;

  @override
  Future<RegistrationRequestListResult> listRegistrationRequests({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
  }) async {
    return RegistrationRequestListResult(
      total: 1,
      items: [
        RegistrationRequestItem(
          id: 1,
          account: 'pending_user',
          status: 'pending',
          rejectedReason: null,
          reviewedByUserId: null,
          reviewedAt: null,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 200,
    String? keyword,
  }) async {
    return RoleListResult(
      total: 2,
      items: [
        RoleItem(
          id: 1,
          code: 'operator',
          name: '操作员',
          description: null,
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
        RoleItem(
          id: 2,
          code: 'production_admin',
          name: '生产管理员',
          description: null,
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<void> approveRegistrationRequest({
    required int requestId,
    required String account,
    required String roleCode,
    String? password,
    int? stageId,
  }) async {
    approveCalls += 1;
    lastApprovedStageId = stageId;
  }

  @override
  Future<void> rejectRegistrationRequest({
    required int requestId,
    String? reason,
  }) async {
    rejectCalls += 1;
  }
}

class _FakeApprovalCraftService extends CraftService {
  _FakeApprovalCraftService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  int listStagesCalls = 0;

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    listStagesCalls += 1;
    final items = listStagesCalls == 1
        ? [
            CraftStageItem(
              id: 10,
              code: '10',
              name: '旧工段',
              sortOrder: 1,
              isEnabled: true,
              processCount: 1,
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ]
        : [
            CraftStageItem(
              id: 11,
              code: '11',
              name: '最新工段',
              sortOrder: 1,
              isEnabled: true,
              processCount: 1,
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ];
    return CraftStageListResult(total: items.length, items: items);
  }
}

Future<void> _pumpApprovalPage(
  WidgetTester tester, {
  required _FakeApprovalUserService userService,
  required _FakeApprovalCraftService craftService,
  bool canApprove = true,
  bool canReject = true,
}) async {
  tester.view.physicalSize = const Size(1920, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RegistrationApprovalPage(
          session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
          onLogout: () {},
          canApprove: canApprove,
          canReject: canReject,
          userService: userService,
          craftService: craftService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('审批通过弹窗打开时会刷新工段列表', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(craftService.listStagesCalls, 1);

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();

    expect(craftService.listStagesCalls, 2);

    await tester.tap(find.text('操作员').first);
    await tester.pumpAndSettle();

    expect(find.text('最新工段'), findsOneWidget);
  });

  testWidgets('注册审批弹窗允许展示无启用工序的工段', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('操作员').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('最新工段').last);
    await tester.pumpAndSettle();

    expect(find.text('最新工段'), findsOneWidget);
    expect(userService.approveCalls, 0);
  });

  testWidgets('注册审批按钮按通过与驳回权限分别展示', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
      canApprove: false,
      canReject: true,
    );

    expect(find.text('通过'), findsNothing);
    expect(find.text('驳回'), findsOneWidget);

    await tester.tap(find.text('驳回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('驳回').last);
    await tester.pumpAndSettle();

    expect(userService.rejectCalls, 1);
    expect(userService.approveCalls, 0);
  });
}
