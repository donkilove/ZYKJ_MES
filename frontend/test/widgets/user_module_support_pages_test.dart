import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/audit_log_page.dart';
import 'package:mes_client/pages/function_permission_config_page.dart';
import 'package:mes_client/pages/login_session_page.dart';
import 'package:mes_client/pages/role_management_page.dart';
import 'package:mes_client/services/authz_service.dart';
import 'package:mes_client/services/user_service.dart';
import 'package:mes_client/widgets/crud_page_header.dart';
import 'package:mes_client/widgets/crud_list_table_section.dart';

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

  int listOnlineSessionsCalls = 0;
  int listAuditLogsCalls = 0;
  int? lastAuditLogPageSize;
  String? lastOnlineSessionStatusFilter;
  int enableRoleCalls = 0;
  int disableRoleCalls = 0;
  String? createdRoleCode;
  String? createdRoleName;
  int createRoleCalls = 0;

  @override
  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 200,
    String? keyword,
  }) async {
    return RoleListResult(total: 1, items: [_maintenanceRole]);
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
    listAuditLogsCalls += 1;
    lastAuditLogPageSize = pageSize;
    return AuditLogListResult(
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
    );
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
    enableRoleCalls += 1;
    return _maintenanceRole;
  }

  @override
  Future<RoleItem> disableRole({required int roleId}) async {
    disableRoleCalls += 1;
    return _maintenanceRole;
  }
}

class _FakeSupportAuthzService extends AuthzService {
  _FakeSupportAuthzService() : super(_session);

  @override
  Future<CapabilityPackCatalogResult> loadCapabilityPackCatalog({
    required String moduleCode,
  }) async {
    return CapabilityPackCatalogResult(
      moduleCode: 'user',
      moduleCodes: const ['user', 'system', 'product'],
      moduleName: '用户管理',
      moduleRevision: 1,
      modulePermissionCode: 'module.user',
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
    expect(find.byType(CrudPageHeader), findsOneWidget);
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
    expect(find.byType(CrudPageHeader), findsOneWidget);
    expect(find.text('功能权限配置'), findsOneWidget);
    expect(find.text('系统管理'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('function permission config refresh keeps unsaved protection', (
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

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('未保存'), findsWidgets);

    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();

    expect(find.text('刷新页面'), findsOneWidget);
    expect(find.text('当前有未保存改动，是否放弃并刷新？'), findsOneWidget);
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
    expect(find.byType(CrudPageHeader), findsOneWidget);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
    expect(userService.listAuditLogsCalls, 1);
    expect(userService.lastAuditLogPageSize, 50);
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

    expect(find.text('在线会话'), findsOneWidget);
    expect(find.text('tester'), findsOneWidget);
    expect(find.byType(CrudPageHeader), findsOneWidget);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.text('登录日志'), findsNothing);
    expect(find.text('全选当前页'), findsOneWidget);
    expect(userService.listOnlineSessionsCalls, 1);
    expect(userService.lastOnlineSessionStatusFilter, 'active');
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
}
