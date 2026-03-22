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

final AppSession _session = AppSession(baseUrl: '', accessToken: 'token');

class _FakeSupportUserService extends UserService {
  _FakeSupportUserService() : super(_session);

  @override
  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 200,
    String? keyword,
  }) async {
    return RoleListResult(total: 1, items: [_role]);
  }

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) async {
    return RoleListResult(total: 1, items: [_role]);
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
  Future<LoginLogListResult> listLoginLogs({
    required int page,
    required int pageSize,
    String? username,
    bool? success,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    return LoginLogListResult(
      total: 1,
      items: [
        LoginLogItem(
          id: 1,
          loginTime: DateTime.parse('2026-03-20T08:00:00Z'),
          username: 'tester',
          success: true,
          ipAddress: '127.0.0.1',
          terminalInfo: 'widget-test',
          failureReason: null,
          sessionTokenId: 'session-1',
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
}

class _FakeSupportAuthzService extends AuthzService {
  _FakeSupportAuthzService() : super(_session);

  @override
  Future<CapabilityPackCatalogResult> loadCapabilityPackCatalog({
    required String moduleCode,
  }) async {
    return CapabilityPackCatalogResult(
      moduleCode: 'user',
      moduleCodes: const ['user'],
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
    return const CapabilityPackRoleConfigResult(
      roleCode: 'quality_admin',
      roleName: '品质管理员',
      readonly: false,
      moduleCode: 'user',
      moduleEnabled: true,
      grantedCapabilityCodes: ['feature.user.role_management.view'],
      effectiveCapabilityCodes: ['feature.user.role_management.view'],
      effectivePagePermissionCodes: ['page.role_management.view'],
      autoLinkedDependencies: [],
    );
  }
}

final RoleItem _role = RoleItem(
  id: 1,
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
        canManage: true,
        userService: userService,
      ),
    );

    expect(find.text('品质管理员'), findsOneWidget);
    expect(find.text('系统内置'), findsOneWidget);
  });

  testWidgets('function permission config renders capability pack', (
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

    expect(find.text('品质管理员'), findsOneWidget);
    expect(find.textContaining('能力包'), findsOneWidget);
    expect(find.text('查看角色管理'), findsOneWidget);
  });

  testWidgets('audit log page renders audit rows', (tester) async {
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
  });

  testWidgets('login session page renders login logs and online sessions', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      LoginSessionPage(
        session: _session,
        onLogout: () {},
        canManage: true,
        userService: userService,
      ),
    );

    expect(find.text('登录日志'), findsOneWidget);
    expect(find.text('在线会话'), findsOneWidget);
    expect(find.text('tester'), findsOneWidget);
  });
}
