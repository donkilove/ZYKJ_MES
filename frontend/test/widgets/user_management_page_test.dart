import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/user_management_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/user_service.dart';

class _FakeUserService extends UserService {
  _FakeUserService({required this.initialUsers})
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  final List<UserItem> initialUsers;

  int? lastCreateStageId;
  int? lastUpdateStageId;
  int createCalls = 0;
  int updateCalls = 0;

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
  Future<ProcessListResult> listProcesses() async {
    return ProcessListResult(
      total: 1,
      items: [
        ProcessItem(
          id: 1,
          code: '10-01',
          name: '装配工序',
          stageId: 10,
          stageCode: '10',
          stageName: '装配一段',
        ),
      ],
    );
  }

  @override
  Future<UserListResult> listUsers({
    required int page,
    required int pageSize,
    String? keyword,
    String? roleCode,
    int? stageId,
    bool? isOnline,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    return UserListResult(total: initialUsers.length, items: initialUsers);
  }

  @override
  Future<ProfileResult> getMyProfile() async {
    return ProfileResult(
      id: 99,
      username: 'admin',
      fullName: '管理员',
      roleCode: 'system_admin',
      roleName: '系统管理员',
      stageId: null,
      stageName: null,
      isActive: true,
      createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
      lastLoginAt: null,
      lastLoginIp: null,
      passwordChangedAt: null,
    );
  }

  @override
  Future<void> createUser({
    required String account,
    required String password,
    required String roleCode,
    String? remark,
    int? stageId,
    bool isActive = true,
  }) async {
    createCalls += 1;
    lastCreateStageId = stageId;
  }

  @override
  Future<void> updateUser({
    required int userId,
    String? account,
    String? password,
    String? roleCode,
    String? remark,
    int? stageId,
    bool? isActive,
  }) async {
    updateCalls += 1;
    lastUpdateStageId = stageId;
  }
}

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(
      total: 2,
      items: [
        CraftStageItem(
          id: 10,
          code: '10',
          name: '装配一段',
          sortOrder: 1,
          isEnabled: true,
          processCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
        CraftStageItem(
          id: 11,
          code: '11',
          name: '装配二段',
          sortOrder: 2,
          isEnabled: true,
          processCount: 0,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }
}

UserItem _buildUser({
  required int id,
  required String username,
  required String roleCode,
  required String roleName,
  int? stageId,
}) {
  return UserItem(
    id: id,
    username: username,
    fullName: username,
    remark: null,
    isOnline: false,
    isActive: true,
    isDeleted: false,
    mustChangePassword: false,
    lastSeenAt: null,
    stageId: stageId,
    stageName: stageId == null ? null : '装配一段',
    roleCode: roleCode,
    roleName: roleName,
    lastLoginAt: null,
    lastLoginIp: null,
    passwordChangedAt: null,
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeUserService userService,
  required _FakeCraftService craftService,
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
        body: UserManagementPage(
          session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
          onLogout: () {},
          canWrite: true,
          userService: userService,
          craftService: craftService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('创建操作员时会携带 stageId 提交', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'op_new');
    await tester.enterText(find.byType(TextFormField).at(1), 'OpNew@123');

    await tester.tap(find.text('操作员').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('装配一段').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(userService.createCalls, 1);
    expect(userService.lastCreateStageId, 10);
  });

  testWidgets('编辑操作员时会携带 stageId 提交', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 1,
          username: 'op_edit',
          roleCode: 'operator',
          roleName: '操作员',
          stageId: 10,
        ),
      ],
    );
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.byType(DataTable), findsOneWidget);
    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(userService.updateCalls, 1);
    expect(userService.lastUpdateStageId, 10);
  });

  testWidgets('编辑未配置工段的操作员时提示必须选择工段', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 2,
          username: 'op_unknown_process',
          roleCode: 'operator',
          roleName: '操作员',
          stageId: null,
        ),
      ],
    );
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.byType(DataTable), findsOneWidget);
    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.text('操作员角色必须选择一个工段'), findsOneWidget);
  });
}
