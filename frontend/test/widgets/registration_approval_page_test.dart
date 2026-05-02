import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/registration_approval_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';

class _FakeApprovalUserService extends UserService {
  _FakeApprovalUserService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  int approveCalls = 0;
  int rejectCalls = 0;
  int listRequestCalls = 0;
  int? lastApprovedStageId;
  String? lastStatus;
  String? lastKeyword;
  Object? listError;
  Object? approveError;
  Object? rejectError;
  List<List<RegistrationRequestItem>>? listResponses;

  @override
  Future<RegistrationRequestListResult> listRegistrationRequests({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
  }) async {
    final error = listError;
    if (error != null) {
      throw error;
    }
    listRequestCalls += 1;
    lastStatus = status;
    lastKeyword = keyword;
    final responses = listResponses;
    final items = responses != null && responses.isNotEmpty
        ? responses[(listRequestCalls - 1).clamp(0, responses.length - 1)]
        : [
            RegistrationRequestItem(
              id: 1,
              account: 'pending_user',
              status: 'pending',
              rejectedReason: null,
              reviewedByUserId: null,
              reviewedAt: null,
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ];
    return RegistrationRequestListResult(total: items.length, items: items);
  }

  @override
  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 10,
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
    final error = approveError;
    if (error != null) {
      throw error;
    }
    approveCalls += 1;
    lastApprovedStageId = stageId;
  }

  @override
  Future<void> rejectRegistrationRequest({
    required int requestId,
    String? reason,
  }) async {
    final error = rejectError;
    if (error != null) {
      throw error;
    }
    rejectCalls += 1;
  }
}

class _FakeApprovalCraftService extends CraftService {
  _FakeApprovalCraftService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  int listStagesCalls = 0;
  Object? listStagesError;

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 10,
    String? keyword,
    bool? enabled,
  }) async {
    listStagesCalls += 1;
    final error = listStagesError;
    if (error != null) {
      throw error;
    }
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
  testWidgets('注册审批页将申请状态筛选收入口右上角并移除筛选卡片', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('按用户名搜索'), findsNothing);
    expect(find.text('查询'), findsNothing);
    expect(find.textContaining('当前列表总数'), findsNothing);
    expect(
      find.byKey(const ValueKey('registration-approval-filter-section')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('registration-approval-status-filter')),
      findsOneWidget,
    );
    final filterLeft = tester.getTopLeft(
      find.byKey(const ValueKey('registration-approval-status-filter')),
    );
    final refreshLeft = tester.getTopLeft(find.byTooltip('刷新'));
    expect(filterLeft.dx, lessThan(refreshLeft.dx));
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(userService.lastKeyword, isNull);

    await tester.tap(
      find.byKey(const ValueKey('registration-approval-status-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('已通过').last);
    await tester.pumpAndSettle();

    expect(userService.lastStatus, 'approved');
    expect(userService.listRequestCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('注册审批页接入公共页头组件', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.text('注册审批'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
  });

  testWidgets('注册审批页接入 CRUD 骨架并保留 route payload 定位提示', (tester) async {
    final userService = _FakeApprovalUserService()
      ..listResponses = [
        [
          RegistrationRequestItem(
            id: 572,
            account: 'pending_572',
            status: 'pending',
            rejectedReason: null,
            reviewedByUserId: null,
            reviewedAt: null,
            createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          ),
        ],
      ];
    final craftService = _FakeApprovalCraftService();

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
            canApprove: true,
            canReject: true,
            routePayloadJson: '{"request_id":572}',
            userService: userService,
            craftService: craftService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MesCrudPageScaffold), findsOneWidget);
    expect(
      find.byKey(const ValueKey('registration-approval-status-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('registration-approval-table-section')),
      findsOneWidget,
    );
    expect(find.byType(MesPaginationBar), findsOneWidget);
    expect(find.textContaining('已定位注册申请 #572'), findsOneWidget);
  });

  testWidgets('注册审批页非法 route payload 会展示反馈', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();

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
            canApprove: true,
            canReject: true,
            routePayloadJson: '{"request_id":',
            userService: userService,
            craftService: craftService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('路由参数解析失败'), findsOneWidget);
  });

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

  testWidgets('审批通过弹窗刷新工段失败时展示旧数据并提示', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    craftService.listStagesError = ApiException('工段加载失败', 500);

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();

    expect(find.text('旧工段'), findsOneWidget);
    expect(find.text('工段加载失败'), findsOneWidget);
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

    await tester.tap(
      find.byKey(const ValueKey('registration-approval-reject-button-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认驳回'));
    await tester.pumpAndSettle();

    expect(userService.rejectCalls, 1);
    expect(userService.approveCalls, 0);
  });

  testWidgets('注册审批列表的通过与驳回按钮使用绿色和红色实底样式', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    final approveMaterial = tester.widget<Material>(
      find.byKey(const ValueKey('registration-approval-approve-button-1')),
    );
    final rejectMaterial = tester.widget<Material>(
      find.byKey(const ValueKey('registration-approval-reject-button-1')),
    );
    final approveBox = tester.widget<SizedBox>(
      find.ancestor(
        of: find.text('通过'),
        matching: find.byType(SizedBox),
      ).first,
    );
    final rejectBox = tester.widget<SizedBox>(
      find.ancestor(
        of: find.text('驳回'),
        matching: find.byType(SizedBox),
      ).first,
    );

    expect(approveMaterial.color, Colors.green.shade600);
    expect(rejectMaterial.color, Colors.red.shade600);
    expect(approveBox.width, 64);
    expect(approveBox.height, 28);
    expect(rejectBox.width, 64);
    expect(rejectBox.height, 28);
    expect(approveMaterial.borderRadius, BorderRadius.circular(20));
    expect(rejectMaterial.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('注册审批页直接展示并校验初始密码规则', (tester) async {
    final userService = _FakeApprovalUserService();
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();

    expect(find.textContaining('不能与系统中已有用户密码相同'), findsNothing);
    expect(find.text('密码规则：至少6位；不能包含连续4位相同字符。'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'pending_user');
    await tester.tap(find.text('生产管理员').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '12345');
    await tester.tap(find.text('确认通过'));
    await tester.pump();
    expect(find.text('密码至少 6 个字符'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'aaaaaa');
    await tester.tap(find.text('确认通过'));
    await tester.pump();
    expect(find.text('初始密码不能包含连续4位相同字符'), findsOneWidget);
    expect(userService.approveCalls, 0);
  });

  testWidgets('注册审批通过后会刷新列表并提示成功', (tester) async {
    final userService = _FakeApprovalUserService()
      ..listResponses = [
        [
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
        const [],
      ];
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'user01');
    await tester.tap(find.text('最新工段').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'Pass123');
    await tester.tap(find.text('确认通过'));
    await tester.pumpAndSettle();

    expect(userService.approveCalls, 1);
    expect(userService.listRequestCalls, greaterThanOrEqualTo(2));
    expect(find.text('已通过账号 user01 的注册申请。'), findsOneWidget);
    expect(find.text('当前状态下暂无注册申请记录'), findsOneWidget);
  });

  testWidgets('注册审批驳回后会刷新列表并提示成功', (tester) async {
    final userService = _FakeApprovalUserService()
      ..listResponses = [
        [
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
        const [],
      ];
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(
      find.byKey(const ValueKey('registration-approval-reject-button-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认驳回'));
    await tester.pumpAndSettle();

    expect(userService.rejectCalls, 1);
    expect(userService.listRequestCalls, greaterThanOrEqualTo(2));
    expect(find.text('已驳回账号 pending_user 的注册申请。'), findsOneWidget);
    expect(find.text('当前状态下暂无注册申请记录'), findsOneWidget);
  });

  testWidgets('注册审批页 403 时展示无权限提示', (tester) async {
    final userService = _FakeApprovalUserService()
      ..listError = ApiException('禁止访问', 403);
    final craftService = _FakeApprovalCraftService();

    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('当前账号没有注册审批权限。'), findsOneWidget);
  });

  testWidgets('注册审批通过失败时展示错误提示', (tester) async {
    final userService = _FakeApprovalUserService()
      ..approveError = ApiException('审批服务异常', 500);
    final craftService = _FakeApprovalCraftService();
    await _pumpApprovalPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'user01');
    await tester.tap(find.text('最新工段').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'Pass123');
    await tester.tap(find.text('确认通过'));
    await tester.pumpAndSettle();

    expect(find.text('审批通过失败：审批服务异常'), findsOneWidget);
  });
}
