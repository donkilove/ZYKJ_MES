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
  int enableCalls = 0;
  int disableCalls = 0;
  int resetPasswordCalls = 0;
  int deleteCalls = 0;
  String? lastListRoleCode;
  int? lastListStageId;
  bool? lastListIsOnline;
  bool? lastListIsActive;

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
    lastListRoleCode = roleCode;
    lastListStageId = stageId;
    lastListIsOnline = isOnline;
    lastListIsActive = isActive;
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
    String? roleCode,
    String? remark,
    int? stageId,
    bool? isActive,
  }) async {
    updateCalls += 1;
    lastUpdateStageId = stageId;
  }

  @override
  Future<void> enableUser({required int userId}) async {
    enableCalls += 1;
  }

  @override
  Future<void> disableUser({required int userId}) async {
    disableCalls += 1;
  }

  @override
  Future<void> resetUserPassword({
    required int userId,
    required String password,
  }) async {
    resetPasswordCalls += 1;
  }

  @override
  Future<void> deleteUser({required int userId}) async {
    deleteCalls += 1;
  }
}

class _FakeCraftService extends CraftService {
  _FakeCraftService({List<List<CraftStageItem>>? responses})
    : _responses = responses,
      super(AppSession(baseUrl: '', accessToken: 'token'));

  final List<List<CraftStageItem>>? _responses;
  int listStagesCalls = 0;

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    listStagesCalls += 1;
    final responses = _responses;
    final items = responses != null && responses.isNotEmpty
        ? responses[(listStagesCalls - 1).clamp(0, responses.length - 1)]
        : _defaultStages;
    return CraftStageListResult(total: items.length, items: items);
  }
}

final List<CraftStageItem> _defaultStages = [
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
];

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
  bool canCreateUser = true,
  bool canEditUser = true,
  bool canToggleUser = true,
  bool canResetPassword = true,
  bool canDeleteUser = true,
  bool canExport = true,
  VoidCallback? onNavigateToRoleManagement,
  Size surfaceSize = const Size(1920, 1200),
}) async {
  tester.view.physicalSize = surfaceSize;
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
          canCreateUser: canCreateUser,
          canEditUser: canEditUser,
          canToggleUser: canToggleUser,
          canResetPassword: canResetPassword,
          canDeleteUser: canDeleteUser,
          canExport: canExport,
          onNavigateToRoleManagement: onNavigateToRoleManagement,
          userService: userService,
          craftService: craftService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _toolbarRect(WidgetTester tester, String key) {
  return tester.getRect(find.byKey(ValueKey<String>(key)));
}

void main() {
  testWidgets('用户管理工具栏仅保留搜索与角色状态筛选', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('工段'), findsNothing);
    expect(find.text('在线状态'), findsNothing);
    expect(find.text('查询用户'), findsOneWidget);
    expect(find.text('导出用户'), findsOneWidget);
    expect(find.text('用户角色'), findsOneWidget);
    expect(find.text('账号状态'), findsOneWidget);
    expect(find.text('按账号搜索'), findsOneWidget);

    expect(userService.lastListStageId, isNull);
    expect(userService.lastListIsOnline, isNull);
  });

  testWidgets('角色和账号状态筛选变更后仍自动触发查询', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.byKey(const ValueKey('userToolbarRoleFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('操作员').last);
    await tester.pumpAndSettle();

    expect(userService.lastListRoleCode, 'operator');

    await tester.tap(find.byKey(const ValueKey('userToolbarStatusFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pumpAndSettle();

    expect(userService.lastListIsActive, isFalse);
    expect(userService.lastListStageId, isNull);
    expect(userService.lastListIsOnline, isNull);
  });

  testWidgets('桌面工具栏搜索框会吃满剩余宽度且与按钮保持同一行', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      onNavigateToRoleManagement: () {},
      surfaceSize: const Size(1440, 1200),
    );

    final searchRect = _toolbarRect(tester, 'userToolbarKeywordField');
    final roleRect = _toolbarRect(tester, 'userToolbarRoleFilter');
    final statusRect = _toolbarRect(tester, 'userToolbarStatusFilter');
    final queryButtonRect = tester.getRect(
      find.widgetWithText(FilledButton, '查询用户'),
    );
    final createButtonRect = tester.getRect(
      find.widgetWithText(FilledButton, '新建用户'),
    );
    final roleManageButtonRect = tester.getRect(
      find.widgetWithText(OutlinedButton, '角色管理'),
    );
    final exportButtonRect = tester.getRect(
      find.widgetWithText(OutlinedButton, '导出用户'),
    );

    expect(searchRect.width, greaterThan(roleRect.width));
    expect(searchRect.width, greaterThan(statusRect.width));
    expect(searchRect.left, lessThan(statusRect.left));
    expect(statusRect.left, lessThan(roleRect.left));

    expect(
      (searchRect.center.dy - queryButtonRect.center.dy).abs(),
      lessThan(1),
    );
    expect((roleRect.center.dy - queryButtonRect.center.dy).abs(), lessThan(1));
    expect(
      (statusRect.center.dy - queryButtonRect.center.dy).abs(),
      lessThan(1),
    );
    expect(
      (createButtonRect.center.dy - queryButtonRect.center.dy).abs(),
      lessThan(1),
    );
    expect(
      (roleManageButtonRect.center.dy - queryButtonRect.center.dy).abs(),
      lessThan(1),
    );
    expect(
      (exportButtonRect.center.dy - queryButtonRect.center.dy).abs(),
      lessThan(1),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('窄宽度工具栏仍按搜索账号状态角色顺序排列', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      surfaceSize: const Size(700, 1200),
    );

    final searchRect = _toolbarRect(tester, 'userToolbarKeywordField');
    final statusRect = _toolbarRect(tester, 'userToolbarStatusFilter');
    final roleRect = _toolbarRect(tester, 'userToolbarRoleFilter');

    expect((searchRect.center.dy - statusRect.center.dy).abs(), lessThan(1));
    expect((statusRect.center.dy - roleRect.center.dy).abs(), lessThan(1));
    expect(searchRect.left, lessThan(statusRect.left));
    expect(statusRect.left, lessThan(roleRect.left));
  });

  testWidgets('新建用户弹窗打开时会刷新工段列表', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(craftService.listStagesCalls, 1);

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    expect(craftService.listStagesCalls, 2);
  });

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

  testWidgets('创建操作员允许选择无启用工序的工段', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'op_zero');
    await tester.enterText(find.byType(TextFormField).at(1), 'OpZero@123');

    await tester.tap(find.text('操作员').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('装配二段').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(userService.createCalls, 1);
    expect(userService.lastCreateStageId, 11);
  });

  testWidgets('新建用户密码输入框使用掩码展示', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    final editableTexts = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(editableTexts.any((item) => item.obscureText), isTrue);
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

  testWidgets('编辑操作员允许保留无启用工序的工段', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 6,
          username: 'op_zero',
          roleCode: 'operator',
          roleName: '操作员',
          stageId: 11,
        ),
      ],
    );
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

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
    expect(userService.lastUpdateStageId, 11);
  });

  testWidgets('编辑用户弹窗打开时会刷新工段列表', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 3,
          username: 'op_refresh',
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

    expect(craftService.listStagesCalls, 1);

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(craftService.listStagesCalls, 2);
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

  testWidgets('编辑用户弹窗不再提供密码输入框', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 4,
          username: 'edit_only',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    );
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.text('新密码（留空不修改）'), findsNothing);
  });

  testWidgets('用户操作菜单按细粒度权限展示并允许独立启停', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 5,
          username: 'toggle_only',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    );
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      canCreateUser: false,
      canEditUser: false,
      canToggleUser: true,
      canResetPassword: false,
      canDeleteUser: false,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();
    expect(find.text('新建用户'), findsOneWidget);

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();

    expect(find.text('停用'), findsOneWidget);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('重置密码'), findsNothing);
    expect(find.text('删除'), findsNothing);

    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pumpAndSettle();

    expect(userService.disableCalls, 1);
    expect(userService.resetPasswordCalls, 0);
  });

  testWidgets('无导出权限时不显示导出按钮', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      canExport: false,
    );

    expect(find.text('导出用户'), findsNothing);
  });
}
