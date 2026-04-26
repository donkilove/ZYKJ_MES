import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/user_management_page.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';

class _FakeUserService extends UserService {
  _FakeUserService({required List<UserItem> initialUsers})
    : _mutableUsers = List<UserItem>.from(initialUsers),
      super(AppSession(baseUrl: '', accessToken: 'token'));

  final List<UserItem> _mutableUsers;

  int? lastCreateStageId;
  int? lastUpdateStageId;
  int createCalls = 0;
  int updateCalls = 0;
  int enableCalls = 0;
  int disableCalls = 0;
  int resetPasswordCalls = 0;
  int deleteCalls = 0;
  int listUsersCalls = 0;
  int listAllRolesCalls = 0;
  int getMyProfileCalls = 0;
  int getUserDetailCalls = 0;
  int listOnlineUserIdsCalls = 0;
  String? lastCreateRemark;
  String? lastEnableRemark;
  String? lastDisableRemark;
  String? lastResetRemark;
  String? lastUpdateRemark;
  bool? lastUpdateIsActive;
  bool? lastUpdateMustChangePassword;
  String? lastListRoleCode;
  int? lastListStageId;
  bool? lastListIsOnline;
  bool? lastListIsActive;
  String lastListDeletedScope = 'active';
  String? lastDeleteRemark;
  String? lastRestoreRemark;
  int restoreCalls = 0;
  List<int> lastOnlineStatusQueryUserIds = const [];
  Set<int> onlineStatusUserIds = <int>{};
  String? lastExportFormat;
  String lastExportDeletedScope = 'active';
  int createExportTaskCalls = 0;
  int listExportTasksCalls = 0;
  int downloadExportTaskCalls = 0;
  Object? createExportTaskError;
  Object? listExportTasksError;
  Object? downloadExportTaskError;
  Object? listUsersError;
  Object? listAllRolesError;
  Object? listOnlineUserIdsError;
  Object? getUserDetailError;
  Object? updateUserError;
  Object? resetPasswordError;
  Object? exportError;
  Duration listUsersDelay = Duration.zero;
  Duration listOnlineStatusDelay = Duration.zero;
  String profileRoleCode = 'system_admin';
  String profileRoleName = '系统管理员';
  UserExportResult exportResult = UserExportResult(
    filename: 'users.csv',
    contentType: 'text/csv',
    contentBase64: 'YQ==',
  );
  UserExportTaskItem exportTaskItem = UserExportTaskItem(
    id: 501,
    taskCode: 'task-501',
    status: 'succeeded',
    format: 'csv',
    deletedScope: 'active',
    keyword: null,
    roleCode: null,
    isActive: null,
    recordCount: 12,
    fileName: 'users_active_20260407_101530.csv',
    mimeType: 'text/csv',
    failureReason: null,
    requestedAt: DateTime.parse('2026-04-07T10:15:30Z'),
    startedAt: DateTime.parse('2026-04-07T10:15:31Z'),
    finishedAt: DateTime.parse('2026-04-07T10:15:33Z'),
    expiresAt: DateTime.parse('2026-04-14T10:15:33Z'),
  );

  void _updateUser(int userId, UserItem Function(UserItem) updater) {
    final index = _mutableUsers.indexWhere((user) => user.id == userId);
    if (index < 0) {
      return;
    }
    _mutableUsers[index] = updater(_mutableUsers[index]);
  }

  @override
  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 10,
    String? keyword,
  }) async {
    final error = listAllRolesError;
    if (error != null) {
      throw error;
    }
    return RoleListResult(
      total: 3,
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
        RoleItem(
          id: 3,
          code: 'custom_dispatcher',
          name: '自定义调度员',
          description: null,
          roleType: 'custom',
          isBuiltin: false,
          isEnabled: true,
          userCount: 0,
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
    String deletedScope = 'active',
    bool includeDeleted = false,
  }) async {
    listUsersCalls += 1;
    final error = listUsersError;
    if (error != null) {
      throw error;
    }
    if (listUsersDelay > Duration.zero) {
      await Future<void>.delayed(listUsersDelay);
    }
    lastListRoleCode = roleCode;
    lastListStageId = stageId;
    lastListIsOnline = isOnline;
    lastListIsActive = isActive;
    lastListDeletedScope = deletedScope;
    var items = List<UserItem>.from(_mutableUsers);
    if (deletedScope == 'active') {
      items = items.where((user) => !user.isDeleted).toList();
    } else if (deletedScope == 'deleted') {
      items = items.where((user) => user.isDeleted).toList();
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      items = items
          .where((user) => user.username.contains(keyword.trim()))
          .toList();
    }
    if (roleCode != null && roleCode.trim().isNotEmpty) {
      items = items.where((user) => user.roleCode == roleCode).toList();
    }
    if (stageId != null) {
      items = items.where((user) => user.stageId == stageId).toList();
    }
    if (isOnline != null) {
      items = items.where((user) => user.isOnline == isOnline).toList();
    }
    if (isActive != null) {
      items = items.where((user) => user.isActive == isActive).toList();
    }
    return UserListResult(
      total: items.length,
      items: List<UserItem>.unmodifiable(items),
    );
  }

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) {
    listAllRolesCalls += 1;
    return listRoles(page: 1, pageSize: 200, keyword: keyword);
  }

  @override
  Future<ProfileResult> getMyProfile() async {
    getMyProfileCalls += 1;
    return ProfileResult(
      id: 99,
      username: 'admin',
      fullName: '管理员',
      roleCode: profileRoleCode,
      roleName: profileRoleName,
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
  Future<Set<int>> listOnlineUserIds({required List<int> userIds}) async {
    listOnlineUserIdsCalls += 1;
    lastOnlineStatusQueryUserIds = userIds.toList(growable: false);
    final error = listOnlineUserIdsError;
    if (error != null) {
      throw error;
    }
    if (listOnlineStatusDelay > Duration.zero) {
      await Future<void>.delayed(listOnlineStatusDelay);
    }
    return Set<int>.from(onlineStatusUserIds);
  }

  @override
  Future<UserItem> getUserDetail({required int userId}) async {
    getUserDetailCalls += 1;
    final error = getUserDetailError;
    if (error != null) {
      throw error;
    }
    UserItem? matchedUser;
    for (final user in _mutableUsers) {
      if (user.id == userId) {
        matchedUser = user;
        break;
      }
    }
    if (matchedUser == null) {
      throw ApiException('User not found', 404);
    }
    return matchedUser;
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
    lastCreateRemark = remark;
  }

  @override
  Future<void> updateUser({
    required int userId,
    String? account,
    String? roleCode,
    String? remark,
    int? stageId,
    bool? isActive,
    bool? mustChangePassword,
  }) async {
    final error = updateUserError;
    if (error != null) {
      throw error;
    }
    updateCalls += 1;
    lastUpdateStageId = stageId;
    lastUpdateRemark = remark;
    lastUpdateIsActive = isActive;
    lastUpdateMustChangePassword = mustChangePassword;
    _updateUser(
      userId,
      (user) => user.copyWith(
        username: account ?? user.username,
        fullName: account ?? user.fullName,
        roleCode: roleCode ?? user.roleCode,
        roleName: roleCode == null
            ? user.roleName
            : ({
                    'operator': '操作员',
                    'production_admin': '生产管理员',
                    'custom_dispatcher': '自定义调度员',
                  })[roleCode] ??
                  user.roleName,
        stageId: stageId ?? user.stageId,
        stageName: stageId == null
            ? null
            : stageId == 10
            ? '装配一段'
            : stageId == 11
            ? '装配二段'
            : user.stageName,
        isActive: isActive ?? user.isActive,
        mustChangePassword: mustChangePassword ?? user.mustChangePassword,
        isOnline: (isActive ?? user.isActive) ? user.isOnline : false,
      ),
    );
  }

  @override
  Future<UserLifecycleResult> enableUser({
    required int userId,
    String? remark,
  }) async {
    enableCalls += 1;
    lastEnableRemark = remark;
    _updateUser(userId, (user) => user.copyWith(isActive: true));
    return UserLifecycleResult(
      user: _mutableUsers.firstWhere((user) => user.id == userId),
      forcedOfflineSessionCount: 0,
      clearedOnlineStatus: false,
    );
  }

  @override
  Future<UserLifecycleResult> disableUser({
    required int userId,
    required String remark,
  }) async {
    disableCalls += 1;
    lastDisableRemark = remark;
    _updateUser(
      userId,
      (user) => user.copyWith(isActive: false, isOnline: false),
    );
    return UserLifecycleResult(
      user: _mutableUsers.firstWhere((user) => user.id == userId),
      forcedOfflineSessionCount: 1,
      clearedOnlineStatus: true,
    );
  }

  @override
  Future<UserPasswordResetResult> resetUserPassword({
    required int userId,
    required String password,
    required String remark,
  }) async {
    final error = resetPasswordError;
    if (error != null) {
      throw error;
    }
    resetPasswordCalls += 1;
    lastResetRemark = remark;
    _updateUser(userId, (user) => user.copyWith(isOnline: false));
    return UserPasswordResetResult(
      user: _mutableUsers.firstWhere((user) => user.id == userId),
      forcedOfflineSessionCount: 1,
      mustChangePassword: true,
      clearedOnlineStatus: true,
    );
  }

  @override
  Future<UserDeleteResult> deleteUser({
    required int userId,
    required String remark,
  }) async {
    deleteCalls += 1;
    lastDeleteRemark = remark;
    _updateUser(
      userId,
      (user) =>
          user.copyWith(isDeleted: true, isActive: false, isOnline: false),
    );
    final deletedUser = _mutableUsers.firstWhere((user) => user.id == userId);
    return UserDeleteResult(
      user: deletedUser,
      forcedOfflineSessionCount: 1,
      clearedOnlineStatus: true,
      deleted: true,
    );
  }

  @override
  Future<UserLifecycleResult> restoreUser({
    required int userId,
    required String remark,
  }) async {
    restoreCalls += 1;
    lastRestoreRemark = remark;
    _updateUser(
      userId,
      (user) =>
          user.copyWith(isDeleted: false, isActive: false, isOnline: false),
    );
    return UserLifecycleResult(
      user: _mutableUsers.firstWhere((user) => user.id == userId),
      forcedOfflineSessionCount: 0,
      clearedOnlineStatus: false,
    );
  }

  @override
  Future<UserExportResult> exportUsers({
    String? keyword,
    String? roleCode,
    int? stageId,
    bool? isOnline,
    bool? isActive,
    String deletedScope = 'active',
    bool includeDeleted = false,
    String format = 'csv',
  }) async {
    lastExportFormat = format;
    final error = exportError;
    if (error != null) {
      throw error;
    }
    return exportResult;
  }

  @override
  Future<UserExportTaskItem> createUserExportTask({
    required String format,
    String? keyword,
    String? roleCode,
    bool? isActive,
    String deletedScope = 'active',
  }) async {
    final error = createExportTaskError;
    if (error != null) {
      throw error;
    }
    createExportTaskCalls += 1;
    lastExportFormat = format;
    lastExportDeletedScope = deletedScope;
    exportTaskItem = UserExportTaskItem(
      id: exportTaskItem.id,
      taskCode: exportTaskItem.taskCode,
      status: exportTaskItem.status,
      format: format,
      deletedScope: deletedScope,
      keyword: keyword,
      roleCode: roleCode,
      isActive: isActive,
      recordCount: exportTaskItem.recordCount,
      fileName: format == 'excel'
          ? 'users_${deletedScope}_20260407_101530.xlsx'
          : 'users_${deletedScope}_20260407_101530.csv',
      mimeType: format == 'excel'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv',
      failureReason: exportTaskItem.failureReason,
      requestedAt: exportTaskItem.requestedAt,
      startedAt: exportTaskItem.startedAt,
      finishedAt: exportTaskItem.finishedAt,
      expiresAt: exportTaskItem.expiresAt,
    );
    return exportTaskItem;
  }

  @override
  Future<UserExportTaskListResult> listUserExportTasks() async {
    final error = listExportTasksError;
    if (error != null) {
      throw error;
    }
    listExportTasksCalls += 1;
    return UserExportTaskListResult(total: 1, items: [exportTaskItem]);
  }

  @override
  Future<UserExportTaskItem> getUserExportTask({required int taskId}) async {
    return exportTaskItem;
  }

  @override
  Future<UserExportDownloadResult> downloadUserExportTask({
    required int taskId,
  }) async {
    final error = downloadExportTaskError;
    if (error != null) {
      throw error;
    }
    downloadExportTaskCalls += 1;
    return UserExportDownloadResult(
      filename: exportTaskItem.fileName ?? 'users.csv',
      mimeType: exportTaskItem.mimeType ?? 'text/csv',
      bytes: [1, 2, 3],
    );
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
    int pageSize = 10,
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
  bool isActive = true,
  bool isDeleted = false,
  bool mustChangePassword = false,
  bool isOnline = false,
  DateTime? lastLoginAt,
  String? lastLoginIp,
  DateTime? passwordChangedAt,
}) {
  return UserItem(
    id: id,
    username: username,
    fullName: username,
    remark: null,
    isOnline: isOnline,
    isActive: isActive,
    isDeleted: isDeleted,
    mustChangePassword: mustChangePassword,
    lastSeenAt: null,
    stageId: stageId,
    stageName: stageId == null
        ? null
        : stageId == 11
        ? '装配二段'
        : '装配一段',
    roleCode: roleCode,
    roleName: roleName,
    lastLoginAt: lastLoginAt,
    lastLoginIp: lastLoginIp,
    passwordChangedAt: passwordChangedAt,
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
  bool canRestoreUser = true,
  bool canExport = true,
  Future<String?> Function({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    required String format,
  })?
  saveExportFile,
  VoidCallback? onNavigateToRoleManagement,
  VoidCallback? onLogout,
  Size surfaceSize = const Size(1920, 1200),
  bool isCurrentTabVisible = true,
  bool settle = true,
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
          onLogout: onLogout ?? () {},
          canCreateUser: canCreateUser,
          canEditUser: canEditUser,
          canToggleUser: canToggleUser,
          canResetPassword: canResetPassword,
          canDeleteUser: canDeleteUser,
          canRestoreUser: canRestoreUser,
          canExport: canExport,
          onNavigateToRoleManagement: onNavigateToRoleManagement,
          userService: userService,
          craftService: craftService,
          saveExportFile: saveExportFile,
          isCurrentTabVisible: isCurrentTabVisible,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Rect _toolbarRect(WidgetTester tester, String key) {
  return tester.getRect(find.byKey(ValueKey<String>(key)));
}

void main() {
  testWidgets('用户管理工具栏仅保留搜索与角色状态范围筛选', (tester) async {
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
    expect(find.text('导出当前筛选结果'), findsOneWidget);
    expect(find.text('用户角色'), findsOneWidget);
    expect(find.text('账号状态'), findsOneWidget);
    expect(find.text('数据范围'), findsOneWidget);
    expect(find.text('按账号搜索'), findsOneWidget);

    expect(userService.lastListStageId, isNull);
    expect(userService.lastListIsOnline, isNull);
  });

  testWidgets('用户管理页不显示任何总数字样', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 1,
          username: 'user_total_hidden',
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

    expect(find.textContaining('总数'), findsNothing);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
  });

  testWidgets('用户管理页接入公共页头组件', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.byType(CrudPageHeader), findsOneWidget);
    expect(find.text('用户管理'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
  });

  testWidgets('用户管理页接入 CRUD 骨架并在筛选变化后回到第一页', (tester) async {
    final userService = _FakeUserService(
      initialUsers: List<UserItem>.generate(
        12,
        (index) => _buildUser(
          id: index + 1,
          username: 'user_${index + 1}',
          roleCode: index.isEven ? 'operator' : 'production_admin',
          roleName: index.isEven ? '操作员' : '生产管理员',
          isActive: true,
        ),
      ),
    );
    final craftService = _FakeCraftService();

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.byType(MesCrudPageScaffold), findsOneWidget);
    expect(
      find.byKey(const ValueKey('user-management-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-management-table-section')),
      findsOneWidget,
    );
    expect(find.byType(MesPaginationBar), findsOneWidget);

    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 2 页'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('userToolbarStatusFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pumpAndSettle();

    expect(find.text('第 1 / 1 页'), findsOneWidget);
  });

  testWidgets('右上角刷新仅刷新用户列表，不重复加载基础缓存', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 1,
          username: 'refresh_only_users',
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

    expect(userService.listUsersCalls, 1);
    expect(userService.listAllRolesCalls, 1);
    expect(userService.getMyProfileCalls, 1);
    expect(craftService.listStagesCalls, 1);

    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();

    expect(userService.listUsersCalls, 2);
    expect(userService.listAllRolesCalls, 1);
    expect(userService.getMyProfileCalls, 1);
    expect(craftService.listStagesCalls, 1);
  });

  testWidgets('快速连续点击页头刷新保持一次请求并提示', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 7,
          username: 'header_throttle',
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

    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(userService.listUsersCalls, 2);

    await tester.tap(find.byTooltip('刷新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(userService.listUsersCalls, 2);
    expect(find.text('刚刚已刷新，无需重复操作'), findsOneWidget);
  });

  testWidgets('初始化完成前不会触发在线状态轮询请求', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 2,
          username: 'init_waiting',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..listUsersDelay = const Duration(seconds: 6);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      settle: false,
    );

    await tester.pump(const Duration(seconds: 4));
    expect(userService.listOnlineUserIdsCalls, 0);

    await tester.pump(const Duration(seconds: 3));
    expect(userService.listOnlineUserIdsCalls, 0);

    await tester.pump(const Duration(seconds: 5));
    expect(userService.listOnlineUserIdsCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('轮询走轻量在线状态接口且不重复请求整页用户列表', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 3,
          username: 'online_poll',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..onlineStatusUserIds = {3};
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    final listUsersCallsBeforePolling = userService.listUsersCalls;
    await tester.pump(const Duration(seconds: 6));

    expect(userService.listOnlineUserIdsCalls, greaterThanOrEqualTo(1));
    expect(userService.lastOnlineStatusQueryUserIds, [3]);
    expect(userService.listUsersCalls, listUsersCallsBeforePolling);
  });

  testWidgets('页签不可见会暂停轮询，可见后恢复', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 20,
          username: 'tab_hidden',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ).copyWith(isOnline: true),
      ],
    )..onlineStatusUserIds = {20};
    final craftService = _FakeCraftService();

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      isCurrentTabVisible: false,
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 10));
    expect(userService.listOnlineUserIdsCalls, 0);

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 6));
    expect(userService.listOnlineUserIdsCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('轮询失败会退避，下次成功后恢复基础间隔', (tester) async {
    final userService =
        _FakeUserService(
            initialUsers: [
              _buildUser(
                id: 30,
                username: 'poll_backoff',
                roleCode: 'production_admin',
                roleName: '生产管理员',
              ).copyWith(isOnline: true),
            ],
          )
          ..onlineStatusUserIds = {30}
          ..listOnlineUserIdsError = ApiException('接口故障', 500);
    final craftService = _FakeCraftService();

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 6));
    expect(userService.listOnlineUserIdsCalls, 1);

    userService.listOnlineUserIdsError = null;
    userService.onlineStatusUserIds = {30};

    await tester.pump(const Duration(seconds: 5));
    expect(userService.listOnlineUserIdsCalls, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(userService.listOnlineUserIdsCalls, 2);

    await tester.pump(const Duration(seconds: 5));
    expect(userService.listOnlineUserIdsCalls, 3);
  });

  testWidgets('手动刷新期间会暂停轮询，避免重叠请求', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 4,
          username: 'pause_during_refresh',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..listUsersDelay = const Duration(seconds: 6);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.byTooltip('刷新'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(userService.listOnlineUserIdsCalls, 0);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(userService.listOnlineUserIdsCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('角色账号状态和数据范围筛选变更后仍自动触发查询', (tester) async {
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

    await tester.tap(
      find.byKey(const ValueKey('userToolbarDeletedScopeFilter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅已删除').last);
    await tester.pumpAndSettle();

    expect(userService.lastListDeletedScope, 'deleted');
  });

  testWidgets('有筛选条件时空结果提示更明确', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('暂无用户'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('userToolbarStatusFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('启用').last);
    await tester.pumpAndSettle();

    final filteredHint = find.text('当前常规用户筛选未命中任何用户，请尝试修改关键词或清除筛选。');
    expect(filteredHint, findsOneWidget);
    expect(find.text('暂无用户'), findsNothing);
  });

  testWidgets('查询进行中按钮显示忙碌反馈', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    userService.listUsersDelay = const Duration(seconds: 2);
    await tester.enterText(
      find.byKey(const ValueKey('userToolbarKeywordField')),
      'busy',
    );

    await tester.tap(find.widgetWithText(FilledButton, '查询用户'));
    await tester.pump();

    expect(find.text('查询中...'), findsOneWidget);
    expect(find.byKey(const ValueKey('queryBusy')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('查询用户'), findsOneWidget);
  });

  testWidgets('点击导出当前筛选结果后会弹出导出菜单', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('导出 CSV'), findsNothing);
    expect(find.text('导出 Excel'), findsNothing);

    final exportMenuButton = find.ancestor(
      of: find.text('导出当前筛选结果'),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );

    await tester.tap(exportMenuButton);
    await tester.pumpAndSettle();

    expect(find.text('导出 CSV'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出任务'), findsOneWidget);
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
      find.widgetWithText(OutlinedButton, '导出当前筛选结果'),
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

  testWidgets('窄宽度工具栏仍按搜索账号状态角色范围顺序排列', (tester) async {
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
    final deletedScopeRect = _toolbarRect(
      tester,
      'userToolbarDeletedScopeFilter',
    );

    expect((searchRect.center.dy - statusRect.center.dy).abs(), lessThan(1));
    expect((statusRect.center.dy - roleRect.center.dy).abs(), lessThan(1));
    expect(searchRect.left, lessThan(statusRect.left));
    expect(statusRect.left, lessThan(roleRect.left));
    expect(deletedScopeRect.top, greaterThanOrEqualTo(roleRect.top));
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

  testWidgets('新建用户会在提交前预判账号冲突', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 99,
          username: 'dup_user',
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

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dup_user');
    await tester.pumpAndSettle();

    expect(find.text('账号已存在，请更换后再创建'), findsOneWidget);
  });

  testWidgets('新建用户会根据角色前置展示工段说明', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    expect(find.text('请先选择角色，再确定是否需要分配工段'), findsOneWidget);

    await tester.tap(find.text('生产管理员').first);
    await tester.pumpAndSettle();
    expect(find.text('该角色无需分配工段'), findsOneWidget);

    await tester.tap(find.text('操作员').first);
    await tester.pumpAndSettle();
    expect(find.text('操作员必须选择一个工段后才能创建'), findsOneWidget);
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
    expect(userService.lastCreateRemark, isNull);
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

  testWidgets('创建自定义角色用户时也可以携带 stageId 提交', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'custom_u');
    await tester.enterText(find.byType(TextFormField).at(1), 'Custom@123');

    await tester.tap(find.text('自定义调度员').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('装配一段').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(userService.createCalls, 1);
    expect(userService.lastCreateStageId, 10);
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

  testWidgets('用户管理新建弹窗直接展示并校验密码规则', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    expect(find.textContaining('不能与系统中已有用户密码相同'), findsNothing);
    expect(find.text('密码规则：至少6位；不能包含连续4位相同字符。'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'new_user');
    await tester.enterText(find.byType(TextFormField).at(1), '12345');
    await tester.tap(find.text('创建'));
    await tester.pump();
    expect(find.text('密码至少 6 个字符'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'aaaaaa');
    await tester.tap(find.text('创建'));
    await tester.pump();
    expect(find.text('密码不能包含连续4位相同字符'), findsOneWidget);
    expect(userService.createCalls, 0);
  });

  testWidgets('新建用户输入时会前置显示账号和密码校验', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'a');
    await tester.pumpAndSettle();
    expect(find.text('账号至少 2 个字符'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '12345');
    await tester.pumpAndSettle();
    expect(find.text('密码至少 6 个字符'), findsOneWidget);
  });

  testWidgets('用户管理重置密码弹窗直接展示并校验密码规则', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 7,
          username: 'reset_target',
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
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();

    expect(find.text('重置密码：reset_target'), findsOneWidget);
    expect(find.textContaining('不能与系统中已有用户密码相同'), findsNothing);
    expect(find.text('密码规则：至少6位；不能包含连续4位相同字符。'), findsOneWidget);
    expect(find.textContaining('旧密码会立即失效'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '重置原因'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '12345');
    await tester.tap(find.text('确认重置'));
    await tester.pump();
    expect(find.text('密码至少 6 个字符'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'aaaaaa');
    await tester.tap(find.text('确认重置'));
    await tester.pump();
    expect(find.text('新密码不能包含连续4位相同字符'), findsOneWidget);
    expect(find.text('请输入重置原因'), findsOneWidget);
    expect(userService.resetPasswordCalls, 0);
  });

  testWidgets('编辑用户弹窗展示详情上下文与新增状态控件', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 1,
          username: 'detail_user',
          roleCode: 'production_admin',
          roleName: '生产管理员',
          stageId: 10,
          isActive: false,
          mustChangePassword: true,
          lastLoginAt: DateTime.parse('2026-03-20T08:00:00Z'),
          lastLoginIp: '10.0.0.8',
          passwordChangedAt: DateTime.parse('2026-03-19T08:00:00Z'),
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

    expect(userService.getUserDetailCalls, 1);
    expect(find.text('当前信息'), findsOneWidget);
    expect(find.text('当前账号状态'), findsOneWidget);
    expect(find.text('停用'), findsWidgets);
    expect(find.text('首次登录需改密'), findsOneWidget);
    expect(find.text('最近登录 IP'), findsOneWidget);
    expect(find.text('10.0.0.8'), findsOneWidget);
    expect(find.byKey(const ValueKey('userEditStatusEnabled')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('userEditStatusDisabled')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('userEditMustChangePassword')),
      findsOneWidget,
    );
  });

  testWidgets('编辑用户无变更保存时直接关闭且不发更新请求', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 8,
          username: 'no_change_user',
          roleCode: 'custom_dispatcher',
          roleName: '自定义调度员',
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

    expect(userService.updateCalls, 0);
  });

  testWidgets('编辑操作员变更工段后先确认再提交 stageId', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 9,
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

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('装配二段').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('确认保存用户变更'), findsOneWidget);
    expect(find.text('工段：装配一段 -> 装配二段'), findsOneWidget);

    await tester.tap(find.text('确认保存'));
    await tester.pumpAndSettle();

    expect(userService.updateCalls, 1);
    expect(userService.lastUpdateStageId, 11);
  });

  testWidgets('编辑用户修改状态后弹出确认并展示停用风险', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 10,
          username: 'disable_me',
          roleCode: 'production_admin',
          roleName: '生产管理员',
          isActive: true,
          isOnline: true,
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

    await tester.tap(find.byKey(const ValueKey('userEditStatusDisabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('账号状态：启用 -> 停用'), findsOneWidget);
    expect(find.text('用户将无法继续登录，在线状态会被置为离线，并收到停用通知'), findsOneWidget);

    await tester.tap(find.text('确认保存'));
    await tester.pumpAndSettle();

    expect(userService.updateCalls, 1);
    expect(userService.lastUpdateIsActive, isFalse);
  });

  testWidgets('编辑用户开启强制改密时弹出确认并展示提示', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 11,
          username: 'force_pwd',
          roleCode: 'production_admin',
          roleName: '生产管理员',
          mustChangePassword: false,
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

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('userEditMustChangePassword')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('下次登录强制改密：关闭 -> 开启'), findsOneWidget);
    expect(find.text('用户下次登录后必须修改密码'), findsOneWidget);

    await tester.tap(find.text('确认保存'));
    await tester.pumpAndSettle();

    expect(userService.updateCalls, 1);
    expect(userService.lastUpdateMustChangePassword, isTrue);
  });

  testWidgets('新建与编辑弹窗不再显示账号提示文本和备注字段', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 7,
          username: 'dialog_check',
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

    await tester.tap(find.text('新建用户'));
    await tester.pumpAndSettle();

    expect(find.text('账号（用户名与姓名统一）'), findsNothing);
    expect(find.text('备注（可选）'), findsNothing);
    expect(find.widgetWithText(TextFormField, '账号'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.text('账号（用户名与姓名统一）'), findsNothing);
    expect(find.text('备注（可选）'), findsNothing);
    expect(find.widgetWithText(TextFormField, '账号'), findsOneWidget);
  });

  testWidgets('用户列表卡片为四角全直角', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 1,
          username: 'shape_check',
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

    final card = tester.widget<Card>(
      find.byKey(const ValueKey('userListCard')),
    );
    final shape = card.shape as RoundedRectangleBorder;

    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(shape.borderRadius, BorderRadius.zero);
    expect(card.clipBehavior, Clip.hardEdge);
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

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('userEditMustChangePassword')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认保存'));
    await tester.pumpAndSettle();

    expect(userService.updateCalls, 1);
    expect(userService.lastUpdateStageId, isNull);
    expect(
      userService.getUserDetail(userId: 6).then((value) => value.stageId),
      completion(11),
    );
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

  testWidgets('编辑用户详情加载失败时显示回退提示', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 12,
          username: 'detail_fallback',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..getUserDetailError = ApiException('详情读取失败', 500);
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

    expect(find.byKey(const ValueKey('userEditDetailWarning')), findsOneWidget);
    expect(find.textContaining('部分详情刷新失败'), findsOneWidget);
  });

  testWidgets('非系统管理员编辑用户时账号字段保持只读', (tester) async {
    final userService =
        _FakeUserService(
            initialUsers: [
              _buildUser(
                id: 13,
                username: 'readonly_account',
                roleCode: 'production_admin',
                roleName: '生产管理员',
              ),
            ],
          )
          ..profileRoleCode = 'production_admin'
          ..profileRoleName = '生产管理员';
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

    final editableField = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, '账号'),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableField.readOnly, isTrue);
    expect(find.text('仅系统管理员可修改账号'), findsOneWidget);
  });

  testWidgets('编辑用户更新返回 400 时维持错误提示', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 14,
          username: 'edit_400',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..updateUserError = ApiException('必须至少保留一个系统管理员', 400);
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
    await tester.tap(find.byKey(const ValueKey('userEditStatusDisabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('更新用户失败：必须至少保留一个系统管理员'), findsOneWidget);
  });

  testWidgets('编辑用户更新返回 401 时触发登出回调', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 15,
          username: 'edit_401',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..updateUserError = ApiException('登录失效', 401);
    final craftService = _FakeCraftService();
    var logoutCalls = 0;
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      onLogout: () {
        logoutCalls += 1;
      },
    );

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('userEditStatusDisabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认保存'));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
  });

  testWidgets('编辑用户更新返回 403 时维持错误提示', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 16,
          username: 'edit_403',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..updateUserError = ApiException('禁止访问', 403);
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
    await tester.tap(find.byKey(const ValueKey('userEditStatusDisabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('更新用户失败：禁止访问'), findsOneWidget);
  });

  testWidgets('逻辑删除弹窗展示影响摘要且删除原因必填', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 18,
          username: 'delete_target',
          roleCode: 'production_admin',
          roleName: '生产管理员',
          stageId: 10,
          isOnline: true,
        ),
      ],
    )..onlineStatusUserIds = {18};
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
    await tester.tap(find.text('逻辑删除'));
    await tester.pumpAndSettle();

    expect(find.text('逻辑删除用户'), findsOneWidget);
    expect(find.text('影响摘要'), findsOneWidget);
    expect(find.textContaining('提交后将强制下线当前会话'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '删除原因'), findsOneWidget);

    await tester.tap(find.text('确认删除'));
    await tester.pump();
    expect(find.text('请输入删除原因'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '删除原因'), '离职归档');
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(userService.deleteCalls, 1);
    expect(userService.lastDeleteRemark, '离职归档');
    expect(find.textContaining('已移入已删除视图'), findsOneWidget);
    expect(find.text('delete_target'), findsNothing);
  });

  testWidgets('切换到仅已删除后可看到已删除用户并执行恢复', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 19,
          username: 'archived_user',
          roleCode: 'production_admin',
          roleName: '生产管理员',
          isActive: false,
          isDeleted: true,
        ),
      ],
    );
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('archived_user'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('userToolbarDeletedScopeFilter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅已删除').last);
    await tester.pumpAndSettle();

    expect(find.text('archived_user'), findsOneWidget);
    expect(find.text('已删除'), findsWidgets);

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();

    expect(find.text('恢复用户'), findsOneWidget);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('停用'), findsNothing);
    expect(find.text('重置密码'), findsNothing);

    await tester.tap(find.text('恢复用户'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '恢复原因'), '误删恢复');
    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();

    expect(userService.restoreCalls, 1);
    expect(userService.lastRestoreRemark, '误删恢复');
    expect(find.text('archived_user'), findsNothing);
    expect(find.textContaining('当前保持停用状态'), findsOneWidget);
  });

  testWidgets('当前登录用户不显示逻辑删除入口', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 99,
          username: 'admin',
          roleCode: 'system_admin',
          roleName: '系统管理员',
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

    expect(find.text('逻辑删除'), findsNothing);
  });

  testWidgets('全部用户视图下恢复后行保留但状态改为停用', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 20,
          username: 'recover_all_scope',
          roleCode: 'production_admin',
          roleName: '生产管理员',
          isActive: false,
          isDeleted: true,
        ),
      ],
    );
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    await tester.tap(
      find.byKey(const ValueKey('userToolbarDeletedScopeFilter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部用户').last);
    await tester.pumpAndSettle();

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复用户'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '恢复原因'), '归档回滚');
    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();

    expect(find.text('recover_all_scope'), findsOneWidget);
    expect(find.text('已删除'), findsNothing);
    expect(find.text('停用'), findsWidgets);
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
    expect(find.text('逻辑删除'), findsNothing);

    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '停用原因'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '停用原因'), '排班冻结');
    await tester.tap(find.widgetWithText(FilledButton, '停用').last);
    await tester.pumpAndSettle();

    expect(userService.disableCalls, 1);
    expect(userService.lastDisableRemark, '排班冻结');
    expect(userService.resetPasswordCalls, 0);
  });

  testWidgets('停用后行立即变为停用且在线状态为离线', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 40,
          username: 'disable_status',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ).copyWith(isOnline: true),
      ],
    )..onlineStatusUserIds = {40};
    final craftService = _FakeCraftService();
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('在线'), findsWidgets);

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '停用原因'), '夜班切换');
    await tester.tap(find.widgetWithText(FilledButton, '停用').last);
    await tester.pumpAndSettle();

    expect(find.text('离线'), findsWidgets);
    expect(find.text('停用'), findsWidgets);
    expect(find.textContaining('强制下线 1 个会话'), findsOneWidget);
  });

  testWidgets('启用用户时备注可空并展示重新登录提示', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 41,
          username: 'enable_status',
          roleCode: 'production_admin',
          roleName: '生产管理员',
          isActive: false,
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
    await tester.tap(find.text('启用'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '启用').last);
    await tester.pumpAndSettle();

    expect(userService.enableCalls, 1);
    expect(userService.lastEnableRemark, isNull);
    expect(find.textContaining('需重新登录后才会恢复在线状态'), findsOneWidget);
  });

  testWidgets('停用当前登录用户后立即触发登出回调', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 99,
          username: 'admin',
          roleCode: 'system_admin',
          roleName: '系统管理员',
          isOnline: true,
        ),
      ],
    )..onlineStatusUserIds = {99};
    final craftService = _FakeCraftService();
    var logoutCalls = 0;
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      onLogout: () {
        logoutCalls += 1;
      },
    );

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '停用原因'), '账号收口');
    await tester.tap(find.widgetWithText(FilledButton, '停用').last);
    await tester.pumpAndSettle();

    expect(userService.disableCalls, 1);
    expect(logoutCalls, 1);
  });

  testWidgets('重置密码后行在线状态立即变为离线', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 41,
          username: 'reset_status',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ).copyWith(isOnline: true),
      ],
    )..onlineStatusUserIds = {41};
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
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Reset@123');
    await tester.enterText(find.widgetWithText(TextFormField, '重置原因'), '班次交接');
    await tester.tap(find.text('确认重置'));
    await tester.pumpAndSettle();

    expect(userService.lastResetRemark, '班次交接');
    expect(find.textContaining('强制下线 1 个会话'), findsOneWidget);
    expect(find.text('离线'), findsWidgets);
    expect(find.text('启用'), findsWidgets);
  });

  testWidgets('重置密码返回 400 时展示失败提示', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 42,
          username: 'reset_fail',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..resetPasswordError = ApiException('新密码不能与当前密码相同', 400);
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
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Reset@123');
    await tester.enterText(find.widgetWithText(TextFormField, '重置原因'), '异常修复');
    await tester.tap(find.text('确认重置'));
    await tester.pumpAndSettle();

    expect(find.textContaining('重置密码失败：新密码不能与当前密码相同'), findsOneWidget);
    expect(userService.resetPasswordCalls, 0);
  });

  testWidgets('重置密码返回 401 时触发登出回调', (tester) async {
    final userService = _FakeUserService(
      initialUsers: [
        _buildUser(
          id: 43,
          username: 'reset_401',
          roleCode: 'production_admin',
          roleName: '生产管理员',
        ),
      ],
    )..resetPasswordError = ApiException('登录失效', 401);
    final craftService = _FakeCraftService();
    var logoutCalls = 0;
    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      onLogout: () {
        logoutCalls += 1;
      },
    );

    final rowActionMenu = find.descendant(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(rowActionMenu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Reset@123');
    await tester.enterText(
      find.widgetWithText(TextFormField, '重置原因'),
      '会话失效校验',
    );
    await tester.tap(find.text('确认重置'));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
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

    expect(find.text('导出当前筛选结果'), findsNothing);
  });

  testWidgets('用户管理页 403 时展示无权限提示', (tester) async {
    final userService = _FakeUserService(initialUsers: const [])
      ..listAllRolesError = ApiException('禁止访问', 403);
    final craftService = _FakeCraftService();

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
    );

    expect(find.text('当前账号没有用户管理权限，请使用有权限账号登录。'), findsOneWidget);
  });

  testWidgets('用户管理页 401 时会触发登出回调', (tester) async {
    final userService = _FakeUserService(initialUsers: const [])
      ..listAllRolesError = ApiException('登录失效', 401);
    final craftService = _FakeCraftService();
    var logoutCalls = 0;

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
            onLogout: () {
              logoutCalls += 1;
            },
            canCreateUser: true,
            canEditUser: true,
            canToggleUser: true,
            canResetPassword: true,
            canDeleteUser: true,
            canExport: true,
            userService: userService,
            craftService: craftService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
  });

  testWidgets('创建导出任务后自动打开任务弹窗并可下载保存', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      saveExportFile:
          ({
            required filename,
            required bytes,
            required mimeType,
            required format,
          }) async {
            expect(format, 'csv');
            expect(mimeType, 'text/csv');
            return 'C:/exports/$filename';
          },
    );

    final exportMenuButton = find.ancestor(
      of: find.text('导出当前筛选结果'),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(exportMenuButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 CSV').last);
    await tester.pumpAndSettle();
    expect(find.text('创建导出任务'), findsWidgets);
    await tester.tap(find.text('创建导出任务').last);
    await tester.pumpAndSettle();

    expect(userService.createExportTaskCalls, 1);
    expect(userService.lastExportFormat, 'csv');
    expect(find.text('导出任务已创建，生成完成后可下载'), findsOneWidget);
    expect(find.text('导出任务'), findsWidgets);
    expect(find.text('可下载'), findsOneWidget);

    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();

    expect(userService.downloadExportTaskCalls, 1);
    expect(find.textContaining('已下载到 C:/exports/'), findsOneWidget);
  });

  testWidgets('下载导出任务取消保存后提示已取消', (tester) async {
    final userService = _FakeUserService(initialUsers: const []);
    final craftService = _FakeCraftService();

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      saveExportFile:
          ({
            required filename,
            required bytes,
            required mimeType,
            required format,
          }) async => null,
    );

    final exportMenuButton = find.ancestor(
      of: find.text('导出当前筛选结果'),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(exportMenuButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 Excel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建导出任务').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(userService.lastExportFormat, 'excel');
    expect(find.text('已取消下载保存'), findsOneWidget);
  });

  testWidgets('创建导出任务失败后提示错误信息', (tester) async {
    final userService = _FakeUserService(initialUsers: const [])
      ..createExportTaskError = ApiException('导出接口异常', 500);
    final craftService = _FakeCraftService();

    await _pumpPage(
      tester,
      userService: userService,
      craftService: craftService,
      saveExportFile:
          ({
            required filename,
            required bytes,
            required mimeType,
            required format,
          }) async => 'C:/exports/$filename',
    );

    final exportMenuButton = find.ancestor(
      of: find.text('导出当前筛选结果'),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    await tester.tap(exportMenuButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 CSV').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建导出任务').last);
    await tester.pumpAndSettle();

    expect(find.text('创建导出任务失败：导出接口异常'), findsOneWidget);
  });
}
