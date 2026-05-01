import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/account_settings_page.dart';
import 'package:mes_client/features/user/presentation/audit_log_page.dart';
import 'package:mes_client/features/user/presentation/function_permission_config_page.dart';
import 'package:mes_client/features/user/presentation/login_session_page.dart';
import 'package:mes_client/features/user/presentation/role_management_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';

Finder _findSemanticsLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: $label)',
  );
}

final AppSession _session = AppSession(baseUrl: '', accessToken: 'token');

final RoleItem _qualityRole = RoleItem(
  id: 2,
  code: 'quality_admin',
  name: '品质管理员',
  description: '品质角色',
  roleType: 'builtin',
  isBuiltin: true,
  isEnabled: true,
  userCount: 2,
  createdAt: null,
  updatedAt: null,
);

class _FakeSupportUserService extends UserService {
  _FakeSupportUserService() : super(_session);

  int listRolesCalls = 0;
  int listOnlineSessionsCalls = 0;
  int listAuditLogsCalls = 0;
  int? lastRolePage;
  int? lastRolePageSize;
  String? lastRoleKeyword;
  int? lastAuditLogPageSize;
  int? lastAuditLogPage;
  String? lastAuditOperatorUsername;
  String? lastAuditActionCode;
  String? lastAuditTargetType;
  DateTime? lastAuditStartTime;
  DateTime? lastAuditEndTime;
  String? lastOnlineSessionStatusFilter;
  int enableRoleCalls = 0;
  int disableRoleCalls = 0;
  int deleteRoleCalls = 0;
  int? lastDeletedRoleId;
  String? createdRoleCode;
  String? createdRoleName;
  int createRoleCalls = 0;
  Object? listRolesError;
  Object? listAuditLogsError;
  Object? deleteRoleError;
  Object? enableRoleError;
  Object? disableRoleError;
  List<RoleListResult> roleResponses = [
    RoleListResult(total: 1, items: [_maintenanceRole]),
  ];
  List<AuditLogListResult> auditLogResponses = [
    AuditLogListResult(
      total: 1,
      items: [
        AuditLogItem(
          id: 1,
          occurredAt: DateTime.parse('2026-03-20T08:00:00Z'),
          operatorUserId: 1,
          operatorUsername: 'admin',
          actionCode: 'user.create',
          actionName: '新建用户',
          targetType: 'user',
          targetId: '2',
          targetName: 'tester',
          result: 'success',
          beforeData: const {'username': 'old'},
          afterData: const {'username': 'tester'},
          ipAddress: '127.0.0.1',
          terminalInfo: 'widget-test',
          remark: '审计日志回归',
        ),
      ],
    ),
  ];

  @override
  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 200,
    String? keyword,
  }) async {
    final error = listRolesError;
    if (error != null) {
      throw error;
    }
    listRolesCalls += 1;
    lastRolePage = page;
    lastRolePageSize = pageSize;
    lastRoleKeyword = keyword;
    return roleResponses[(listRolesCalls - 1).clamp(
      0,
      roleResponses.length - 1,
    )];
  }

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) async {
    return RoleListResult(total: 2, items: [_maintenanceRole, _qualityRole]);
  }

  @override
  Future<RoleItem> createRole({
    required String code,
    required String name,
    String? description,
    String roleType = 'custom',
    bool isEnabled = true,
  }) async {
    createRoleCalls += 1;
    createdRoleCode = code;
    createdRoleName = name;
    return RoleItem(
      id: 99,
      code: code,
      name: name,
      description: description,
      roleType: roleType,
      isBuiltin: false,
      isEnabled: isEnabled,
      userCount: 0,
      createdAt: null,
      updatedAt: null,
    );
  }

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
    final error = listAuditLogsError;
    if (error != null) {
      throw error;
    }
    listAuditLogsCalls += 1;
    lastAuditLogPage = page;
    lastAuditLogPageSize = pageSize;
    lastAuditOperatorUsername = operatorUsername;
    lastAuditActionCode = actionCode;
    lastAuditTargetType = targetType;
    lastAuditStartTime = startTime;
    lastAuditEndTime = endTime;
    return auditLogResponses[(listAuditLogsCalls - 1).clamp(
      0,
      auditLogResponses.length - 1,
    )];
  }

  @override
  Future<OnlineSessionListResult> listOnlineSessions({
    required int page,
    required int pageSize,
    String? keyword,
    String? statusFilter,
  }) async {
    listOnlineSessionsCalls += 1;
    lastOnlineSessionStatusFilter = statusFilter;
    return OnlineSessionListResult(
      total: 1,
      items: [
        OnlineSessionItem(
          id: 1,
          sessionTokenId: 'session-1',
          userId: 2,
          username: 'tester',
          roleCode: 'quality_admin',
          roleName: '品质管理员',
          stageId: null,
          stageName: null,
          loginTime: DateTime.parse('2026-03-20T08:00:00Z'),
          lastActiveAt: DateTime.parse('2026-03-20T08:10:00Z'),
          expiresAt: DateTime.parse('2026-03-20T09:00:00Z'),
          ipAddress: '127.0.0.1',
          terminalInfo: 'widget-test',
          status: 'active',
        ),
      ],
    );
  }

  @override
  Future<RoleItem> enableRole({required int roleId}) async {
    final error = enableRoleError;
    if (error != null) {
      throw error;
    }
    enableRoleCalls += 1;
    return _maintenanceRole;
  }

  @override
  Future<RoleItem> disableRole({required int roleId}) async {
    final error = disableRoleError;
    if (error != null) {
      throw error;
    }
    disableRoleCalls += 1;
    return _maintenanceRole;
  }

  @override
  Future<void> deleteRole({required int roleId}) async {
    final error = deleteRoleError;
    if (error != null) {
      throw error;
    }
    deleteRoleCalls += 1;
    lastDeletedRoleId = roleId;
  }
}

class _FakeSupportAuthzService extends AuthzService {
  _FakeSupportAuthzService() : super(_session);

  int applyCapabilityPacksCalls = 0;
  final List<String> loadedCatalogModules = <String>[];
  String? lastAppliedModuleCode;
  int? lastExpectedRevision;
  List<CapabilityPackRoleDraftItem>? lastAppliedRoleItems;
  Object? applyCapabilityPacksError;
  Map<String, CapabilityPackRoleConfigResult> roleConfigByRole = {};

  @override
  Future<CapabilityPackCatalogResult> loadCapabilityPackCatalog({
    required String moduleCode,
  }) async {
    loadedCatalogModules.add(moduleCode);
    return CapabilityPackCatalogResult(
      moduleCode: moduleCode,
      moduleCodes: const ['user', 'system', 'product'],
      moduleName: moduleCode == 'product' ? '产品管理' : '用户管理',
      moduleRevision: 1,
      modulePermissionCode: moduleCode == 'product'
          ? 'module.product'
          : 'module.user',
      capabilityPacks: const [
        CapabilityPackItem(
          capabilityCode: 'feature.user.role_management.view',
          capabilityName: '查看角色管理',
          groupCode: 'user.roles',
          groupName: '角色管理',
          pageCode: 'role_management',
          pageName: '角色管理',
          description: '查看角色与权限说明',
          dependencyCapabilityCodes: [],
          linkedActionPermissionCodes: [],
        ),
      ],
      roleTemplates: const [],
    );
  }

  @override
  Future<CapabilityPackRoleConfigResult> loadCapabilityPackRoleConfig({
    required String roleCode,
    required String moduleCode,
  }) async {
    final overridden = roleConfigByRole[roleCode];
    if (overridden != null) {
      return overridden;
    }
    return CapabilityPackRoleConfigResult(
      roleCode: roleCode,
      roleName: roleCode == 'quality_admin' ? '品质管理员' : '维修员',
      readonly: false,
      moduleCode: moduleCode,
      moduleEnabled: true,
      grantedCapabilityCodes: const ['feature.user.role_management.view'],
      effectiveCapabilityCodes: const ['feature.user.role_management.view'],
      effectivePagePermissionCodes: const ['page.role_management.view'],
      autoLinkedDependencies: const [],
    );
  }

  @override
  Future<CapabilityPackPreviewResult> applyCapabilityPacks({
    required String moduleCode,
    required List<CapabilityPackRoleDraftItem> roleItems,
    required int expectedRevision,
    String? remark,
  }) async {
    final error = applyCapabilityPacksError;
    if (error != null) {
      throw error;
    }
    applyCapabilityPacksCalls += 1;
    lastAppliedModuleCode = moduleCode;
    lastExpectedRevision = expectedRevision;
    lastAppliedRoleItems = List<CapabilityPackRoleDraftItem>.from(roleItems);
    return const CapabilityPackPreviewResult(
      moduleCode: 'user',
      moduleRevision: 2,
      roleResults: [],
    );
  }
}

class _FakeSupportAccountUserService extends UserService {
  _FakeSupportAccountUserService() : super(_session);

  int getMyProfileCalls = 0;
  int getMySessionCalls = 0;

  @override
  Future<ProfileResult> getMyProfile() async {
    getMyProfileCalls += 1;
    return ProfileResult(
      id: 1,
      username: 'tester',
      fullName: '测试用户',
      roleCode: 'quality_admin',
      roleName: '品质管理员',
      stageId: null,
      stageName: null,
      isActive: true,
      createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
      lastLoginAt: DateTime.parse('2026-03-20T08:00:00Z'),
      lastLoginIp: '127.0.0.1',
      passwordChangedAt: DateTime.parse('2026-03-18T08:00:00Z'),
    );
  }

  @override
  Future<CurrentSessionResult> getMySession() async {
    getMySessionCalls += 1;
    return CurrentSessionResult(
      sessionTokenId: 'session-1',
      loginTime: DateTime.parse('2026-03-20T08:00:00Z'),
      lastActiveAt: DateTime.parse('2026-03-20T08:10:00Z'),
      expiresAt: DateTime.parse('2026-03-20T09:00:00Z'),
      remainingSeconds: 1200,
      status: 'active',
    );
  }
}

class _FakeSupportAuthService extends AuthService {
  int logoutCalls = 0;

  @override
  Future<void> logout({
    required String baseUrl,
    required String accessToken,
  }) async {
    logoutCalls += 1;
  }
}

final RoleItem _maintenanceRole = RoleItem(
  id: 1,
  code: 'maintenance_staff',
  name: '维修员',
  description: '维修角色',
  roleType: 'builtin',
  isBuiltin: true,
  isEnabled: true,
  userCount: 2,
  createdAt: null,
  updatedAt: null,
);

final RoleItem _customRole = RoleItem(
  id: 88,
  code: 'custom_quality_reviewer',
  name: '质检复核员',
  description: '可删除自定义角色',
  roleType: 'custom',
  isBuiltin: false,
  isEnabled: true,
  userCount: 0,
  createdAt: null,
  updatedAt: null,
);

Future<void> _pumpPage(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1920, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  final userService = _FakeSupportUserService();
  final authzService = _FakeSupportAuthzService();
  final accountUserService = _FakeSupportAccountUserService();
  final authService = _FakeSupportAuthService();

  testWidgets('role management page 接入统一页头和列表区锚点', (tester) async {
    await _pumpPage(
      tester,
      RoleManagementPage(
        session: _session,
        onLogout: () {},
        canCreateRole: true,
        canEditRole: true,
        canToggleRole: true,
        canDeleteRole: true,
        userService: userService,
      ),
    );

    expect(
      find.byKey(const ValueKey('role-management-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('role-management-table-section')),
      findsOneWidget,
    );
  });

  testWidgets('audit log page 接入统一页头和筛选区锚点', (tester) async {
    await _pumpPage(
      tester,
      AuditLogPage(
        session: _session,
        onLogout: () {},
        userService: userService,
      ),
    );

    expect(find.byKey(const ValueKey('audit-log-page-header')), findsOneWidget);
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('audit-log-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('audit-log-table-section')),
      findsOneWidget,
    );
  });

  testWidgets('role management page renders role list', (tester) async {
    await _pumpPage(
      tester,
      RoleManagementPage(
        session: _session,
        onLogout: () {},
        canCreateRole: true,
        canEditRole: true,
        canToggleRole: true,
        canDeleteRole: true,
        userService: userService,
      ),
    );

    expect(find.text('维修员'), findsOneWidget);
    expect(find.text('maintenance_staff'), findsNothing);
    expect(find.text('系统内置'), findsWidgets);
    expect(
      find.byKey(const ValueKey('role-management-page-header')),
      findsOneWidget,
    );
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.textContaining('总数'), findsNothing);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
  });

  testWidgets(
    'role management page shows maintenance role as builtin without delete',
    (tester) async {
      userService.disableRoleCalls = 0;
      await _pumpPage(
        tester,
        RoleManagementPage(
          session: _session,
          onLogout: () {},
          canCreateRole: false,
          canEditRole: true,
          canToggleRole: true,
          canDeleteRole: true,
          userService: userService,
        ),
      );

      expect(find.widgetWithText(OutlinedButton, '停用'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '编辑'), findsOneWidget);
      expect(find.text('删除'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, '停用'));
      await tester.pumpAndSettle();

      expect(find.text('停用角色确认'), findsOneWidget);
      expect(find.textContaining('角色“维修员”'), findsOneWidget);
      expect(userService.disableRoleCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, '停用').last);
      await tester.pumpAndSettle();

      expect(userService.disableRoleCalls, 1);
      expect(userService.enableRoleCalls, 0);
    },
  );

  testWidgets(
    'role management create dialog hides code and description fields',
    (tester) async {
      userService.createRoleCalls = 0;
      userService.createdRoleCode = null;

      await _pumpPage(
        tester,
        RoleManagementPage(
          session: _session,
          onLogout: () {},
          canCreateRole: true,
          canEditRole: true,
          canToggleRole: true,
          canDeleteRole: true,
          userService: userService,
        ),
      );

      await tester.tap(find.text('新增角色'));
      await tester.pumpAndSettle();

      expect(find.text('角色编码'), findsNothing);
      expect(find.widgetWithText(TextFormField, '角色说明'), findsNothing);
      expect(find.widgetWithText(TextFormField, '角色名称'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '中文自定义角色');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(userService.createRoleCalls, 1);
      expect(userService.createdRoleName, '中文自定义角色');
      expect(userService.createdRoleCode, isNotNull);
      expect(userService.createdRoleCode, isNotEmpty);
    },
  );

  testWidgets(
    'role management edit dialog also hides code and description fields',
    (tester) async {
      await _pumpPage(
        tester,
        RoleManagementPage(
          session: _session,
          onLogout: () {},
          canCreateRole: true,
          canEditRole: true,
          canToggleRole: true,
          canDeleteRole: true,
          userService: userService,
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, '编辑'));
      await tester.pumpAndSettle();

      expect(find.text('角色编码'), findsNothing);
      expect(find.widgetWithText(TextFormField, '角色说明'), findsNothing);
      expect(find.widgetWithText(TextFormField, '角色名称'), findsOneWidget);
    },
  );

  testWidgets('function permission config filters system module option', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        authzService: authzService,
        userService: userService,
      ),
    );

    expect(find.byType(FunctionPermissionConfigPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('function-permission-config-page-header')),
      findsOneWidget,
    );
    expect(find.text('功能权限配置'), findsOneWidget);
    expect(find.text('系统管理'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('function permission config refresh keeps unsaved protection', (
    tester,
  ) async {
    authzService.loadedCatalogModules.clear();
    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        authzService: authzService,
        userService: userService,
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('未保存'), findsWidgets);
    expect(
      find.byKey(const ValueKey('function-permission-config-page-header')),
      findsOneWidget,
    );
    expect(find.byTooltip('刷新'), findsOneWidget);

    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();

    expect(find.text('切换模块'), findsOneWidget);
    expect(find.text('当前有未保存改动，是否放弃并切换？'), findsOneWidget);
    expect(authzService.loadedCatalogModules, ['production', 'user']);
  });

  testWidgets('function permission config save success triggers callback', (
    tester,
  ) async {
    authzService.applyCapabilityPacksCalls = 0;
    authzService.applyCapabilityPacksError = null;
    authzService.lastAppliedRoleItems = null;
    var callbackCalls = 0;

    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        onPermissionsChanged: () async {
          callbackCalls += 1;
        },
        authzService: authzService,
        userService: userService,
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认保存'));
    await tester.pumpAndSettle();

    expect(authzService.applyCapabilityPacksCalls, 1);
    expect(authzService.lastAppliedModuleCode, 'user');
    expect(authzService.lastAppliedRoleItems, isNotNull);
    expect(authzService.lastAppliedRoleItems, isNotEmpty);
    expect(callbackCalls, 1);
    expect(find.text('保存成功。'), findsOneWidget);
  });

  testWidgets('function permission config save 409 shows conflict message', (
    tester,
  ) async {
    authzService.applyCapabilityPacksError = ApiException('版本冲突', 409);

    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        authzService: authzService,
        userService: userService,
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败：当前模块版本已变化，请刷新后重试。'), findsOneWidget);
    authzService.applyCapabilityPacksError = null;
  });

  testWidgets('function permission config save 401 triggers logout', (
    tester,
  ) async {
    authzService.applyCapabilityPacksError = ApiException('登录失效', 401);
    var logoutCalls = 0;

    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {
          logoutCalls += 1;
        },
        authzService: authzService,
        userService: userService,
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认保存'));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
    authzService.applyCapabilityPacksError = null;
  });

  testWidgets('function permission config readonly role disables editing', (
    tester,
  ) async {
    authzService.roleConfigByRole = {
      'maintenance_staff': const CapabilityPackRoleConfigResult(
        roleCode: 'maintenance_staff',
        roleName: '维修员',
        readonly: true,
        moduleCode: 'production',
        moduleEnabled: true,
        grantedCapabilityCodes: ['feature.user.role_management.view'],
        effectiveCapabilityCodes: ['feature.user.role_management.view'],
        effectivePagePermissionCodes: ['page.role_management.view'],
        autoLinkedDependencies: [],
      ),
    };

    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        authzService: authzService,
        userService: userService,
      ),
    );

    final switchWidget = tester.widget<Switch>(find.byType(Switch).first);
    expect(switchWidget.onChanged, isNull);
    expect(find.text('当前角色为只读，权限项不可编辑。'), findsOneWidget);
    authzService.roleConfigByRole = {};
  });

  testWidgets('function permission config exposes stable semantics labels', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        authzService: authzService,
        userService: userService,
      ),
    );

    expect(_findSemanticsLabel('功能权限配置主区域'), findsOneWidget);
    expect(_findSemanticsLabel('功能权限配置保存按钮'), findsOneWidget);
  });

  testWidgets('function permission config 脏数据切换模块时可确认放弃并重载', (tester) async {
    authzService.loadedCatalogModules.clear();

    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        authzService: authzService,
        userService: userService,
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('未保存'), findsWidgets);

    await tester.tap(find.text('用户管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('产品管理').last);
    await tester.pumpAndSettle();

    expect(find.text('切换模块'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '放弃并切换'));
    await tester.pumpAndSettle();

    expect(
      authzService.loadedCatalogModules,
      containsAll(<String>['user', 'product']),
    );
  });

  testWidgets('audit log page renders audit rows', (tester) async {
    userService.listAuditLogsCalls = 0;
    userService.lastAuditLogPageSize = null;

    await _pumpPage(
      tester,
      AuditLogPage(
        session: _session,
        onLogout: () {},
        userService: userService,
      ),
    );

    expect(find.text('新建用户'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
    expect(find.textContaining('user: tester'), findsOneWidget);
    expect(find.textContaining('username: old'), findsOneWidget);
    expect(find.textContaining('username: tester'), findsOneWidget);
    expect(find.text('IP地址'), findsNothing);
    expect(find.text('终端信息'), findsNothing);
    expect(find.text('127.0.0.1'), findsNothing);
    expect(find.text('widget-test'), findsNothing);
    expect(find.byKey(const ValueKey('audit-log-page-header')), findsOneWidget);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
    expect(userService.listAuditLogsCalls, 1);
    expect(userService.lastAuditLogPageSize, 10);
  });

  testWidgets('audit log page supports filter date range and pagination', (
    tester,
  ) async {
    userService.listAuditLogsCalls = 0;
    userService.auditLogResponses = [
      AuditLogListResult(
        total: 11,
        items: userService.auditLogResponses.first.items,
      ),
      AuditLogListResult(
        total: 11,
        items: [
          AuditLogItem(
            id: 2,
            occurredAt: DateTime.parse('2026-03-21T08:00:00Z'),
            operatorUserId: 2,
            operatorUsername: 'auditor',
            actionCode: 'user.disable',
            actionName: '停用用户',
            targetType: 'user',
            targetId: '3',
            targetName: 'target-user',
            result: 'success',
            beforeData: const {'enabled': true},
            afterData: const {'enabled': false},
            ipAddress: null,
            terminalInfo: null,
            remark: null,
          ),
        ],
      ),
    ];

    await _pumpPage(
      tester,
      AuditLogPage(
        session: _session,
        onLogout: () {},
        userService: userService,
        dateRangePicker: (context, start, end) async {
          return DateTimeRange(
            start: DateTime(2026, 3, 1),
            end: DateTime(2026, 3, 5),
          );
        },
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, '操作人账号'), 'admin');
    await tester.enterText(
      find.widgetWithText(TextField, '操作编码'),
      'user.create',
    );
    await tester.enterText(find.widgetWithText(TextField, '目标类型'), 'user');
    await tester.tap(find.widgetWithText(OutlinedButton, '选择时间范围'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();

    expect(userService.lastAuditLogPage, 1);
    expect(userService.lastAuditOperatorUsername, 'admin');
    expect(userService.lastAuditActionCode, 'user.create');
    expect(userService.lastAuditTargetType, 'user');
    expect(userService.lastAuditStartTime, DateTime(2026, 3, 1));
    expect(userService.lastAuditEndTime, DateTime(2026, 3, 5, 23, 59, 59));

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pumpAndSettle();

    expect(find.text('停用用户'), findsOneWidget);
    expect(find.text('第 2 / 2 页'), findsOneWidget);
  });

  testWidgets('audit log page handles 401', (tester) async {
    var logoutCalls = 0;
    userService.listAuditLogsError = ApiException('登录失效', 401);

    await _pumpPage(
      tester,
      AuditLogPage(
        session: _session,
        onLogout: () {
          logoutCalls += 1;
        },
        userService: userService,
      ),
    );

    expect(logoutCalls, 1);

    userService.listAuditLogsError = null;
  });

  testWidgets('audit log page shows failure message', (tester) async {
    userService.listAuditLogsError = ApiException('查询失败', 500);
    await _pumpPage(
      tester,
      AuditLogPage(
        session: _session,
        onLogout: () {},
        userService: userService,
      ),
    );

    expect(find.text('加载审计日志失败：查询失败'), findsOneWidget);
    userService.listAuditLogsError = null;
  });

  testWidgets('audit log page 清除时间范围后重新查询会移除时间筛选', (tester) async {
    userService.auditLogResponses = [
      AuditLogListResult(
        total: 1,
        items: userService.auditLogResponses.first.items,
      ),
    ];

    await _pumpPage(
      tester,
      AuditLogPage(
        session: _session,
        onLogout: () {},
        userService: userService,
        dateRangePicker: (context, start, end) async {
          return DateTimeRange(
            start: DateTime(2026, 3, 1),
            end: DateTime(2026, 3, 5),
          );
        },
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '选择时间范围'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('清除时间范围'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();

    expect(userService.lastAuditStartTime, isNull);
    expect(userService.lastAuditEndTime, isNull);
  });

  testWidgets('login session page renders', (tester) async {
    userService.listOnlineSessionsCalls = 0;
    userService.lastOnlineSessionStatusFilter = null;

    await _pumpPage(
      tester,
      LoginSessionPage(
        session: _session,
        onLogout: () {},
        canViewOnlineSessions: true,
        canForceOffline: true,
        userService: userService,
      ),
    );

    expect(find.text('登录会话'), findsOneWidget);
    expect(find.text('tester'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('login-session-page-header')),
      findsOneWidget,
    );
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.text('登录日志'), findsNothing);
    expect(find.text('全选当前页'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
    expect(userService.listOnlineSessionsCalls, 1);
    expect(userService.lastOnlineSessionStatusFilter, 'active');
  });

  testWidgets('login session page refresh button reuses current page query', (
    tester,
  ) async {
    userService.listOnlineSessionsCalls = 0;

    await _pumpPage(
      tester,
      LoginSessionPage(
        session: _session,
        onLogout: () {},
        canViewOnlineSessions: true,
        canForceOffline: true,
        userService: userService,
      ),
    );

    expect(userService.listOnlineSessionsCalls, 1);

    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();

    expect(userService.listOnlineSessionsCalls, 2);
    expect(userService.lastOnlineSessionStatusFilter, 'active');
  });

  testWidgets('role management supports pagination query delete and failure', (
    tester,
  ) async {
    userService.listRolesCalls = 0;
    userService.roleResponses = [
      RoleListResult(total: 11, items: [_customRole]),
      RoleListResult(total: 11, items: [_maintenanceRole]),
      RoleListResult(total: 1, items: [_customRole]),
      RoleListResult(total: 1, items: [_customRole]),
    ];
    userService.deleteRoleCalls = 0;
    userService.deleteRoleError = null;

    await _pumpPage(
      tester,
      RoleManagementPage(
        session: _session,
        onLogout: () {},
        canCreateRole: true,
        canEditRole: true,
        canToggleRole: true,
        canDeleteRole: true,
        userService: userService,
      ),
    );

    expect(find.text('质检复核员'), findsOneWidget);
    expect(userService.lastRolePage, 1);
    expect(userService.lastRolePageSize, 10);

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 2 页'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '关键词'), '复核');
    await tester.tap(find.widgetWithText(OutlinedButton, '查询'));
    await tester.pumpAndSettle();
    expect(userService.lastRolePage, 1);
    expect(userService.lastRoleKeyword, '复核');

    await tester.tap(find.widgetWithText(OutlinedButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-delete-dialog')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(userService.deleteRoleCalls, 1);
    expect(userService.lastDeletedRoleId, _customRole.id);

    userService.deleteRoleError = ApiException('角色已被绑定，无法删除', 409);
    await tester.tap(find.widgetWithText(OutlinedButton, '删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.text('角色已被绑定，无法删除'), findsOneWidget);
    userService.deleteRoleError = null;
  });

  testWidgets('role management toggle failure shows snackbar', (tester) async {
    userService.disableRoleError = ApiException('停用失败', 500);

    await _pumpPage(
      tester,
      RoleManagementPage(
        session: _session,
        onLogout: () {},
        canCreateRole: false,
        canEditRole: true,
        canToggleRole: true,
        canDeleteRole: false,
        userService: userService,
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '停用'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '停用').last);
    await tester.pumpAndSettle();

    expect(find.text('停用失败'), findsOneWidget);
    userService.disableRoleError = null;
  });

  testWidgets('role management page handles 401 on initial load', (
    tester,
  ) async {
    var logoutCalls = 0;
    userService.listRolesError = ApiException('登录失效', 401);

    await _pumpPage(
      tester,
      RoleManagementPage(
        session: _session,
        onLogout: () {
          logoutCalls += 1;
        },
        canCreateRole: false,
        canEditRole: false,
        canToggleRole: false,
        canDeleteRole: false,
        userService: userService,
      ),
    );

    expect(logoutCalls, 1);
    userService.listRolesError = null;
  });

  testWidgets('login session page无在线会话权限时不发起加载', (tester) async {
    userService.listOnlineSessionsCalls = 0;

    await _pumpPage(
      tester,
      LoginSessionPage(
        session: _session,
        onLogout: () {},
        canViewOnlineSessions: false,
        canForceOffline: false,
        userService: userService,
      ),
    );

    expect(find.text('在线会话'), findsNothing);
    expect(find.text('当前账号没有在线会话查看权限。'), findsOneWidget);
    expect(userService.listOnlineSessionsCalls, 0);
  });

  testWidgets('account settings page 接入统一页头锚点', (tester) async {
    await _pumpPage(
      tester,
      AccountSettingsPage(
        session: _session,
        onLogout: () {},
        canChangePassword: true,
        canViewSession: true,
        userService: accountUserService,
        authService: authService,
      ),
    );

    expect(
      find.byKey(const ValueKey('account-settings-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
  });

  testWidgets('login session page 接入统一页头锚点', (tester) async {
    await _pumpPage(
      tester,
      LoginSessionPage(
        session: _session,
        onLogout: () {},
        canViewOnlineSessions: true,
        canForceOffline: true,
        userService: userService,
      ),
    );

    expect(
      find.byKey(const ValueKey('login-session-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
  });

  testWidgets('function permission config page 接入统一页头锚点', (tester) async {
    await _pumpPage(
      tester,
      FunctionPermissionConfigPage(
        session: _session,
        onLogout: () {},
        authzService: authzService,
        userService: userService,
      ),
    );

    expect(
      find.byKey(const ValueKey('function-permission-config-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
  });
}
