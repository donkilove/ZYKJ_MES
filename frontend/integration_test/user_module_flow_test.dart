import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/registration_approval_page.dart';
import 'package:mes_client/features/user/presentation/user_management_page.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class _IntegrationUserService extends UserService {
  _IntegrationUserService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

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
    return UserListResult(
      total: 1,
      items: [
        UserItem(
          id: 1,
          username: 'integration_user',
          fullName: 'integration_user',
          remark: null,
          isOnline: true,
          isActive: true,
          isDeleted: false,
          mustChangePassword: false,
          lastSeenAt: null,
          stageId: null,
          stageName: null,
          roleCode: 'production_admin',
          roleName: '生产管理员',
          lastLoginAt: null,
          lastLoginIp: null,
          passwordChangedAt: null,
          createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
          updatedAt: DateTime.parse('2026-04-20T08:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) async {
    return RoleListResult(
      total: 1,
      items: [
        RoleItem(
          id: 1,
          code: 'production_admin',
          name: '生产管理员',
          description: null,
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 1,
          createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
          updatedAt: DateTime.parse('2026-04-20T08:00:00Z'),
        ),
      ],
    );
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
      createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
      lastLoginAt: null,
      lastLoginIp: null,
      passwordChangedAt: null,
    );
  }

  @override
  Future<Set<int>> listOnlineUserIds({required List<int> userIds}) async {
    return {1};
  }

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
          id: 572,
          account: 'pending_572',
          status: 'pending',
          rejectedReason: null,
          reviewedByUserId: null,
          reviewedAt: null,
          createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
        ),
      ],
    );
  }
}

class _IntegrationCraftService extends CraftService {
  _IntegrationCraftService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 10,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(total: 1, items: const []);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('用户模块通过总页壳层展示主业务页并可切到支持页签', (tester) async {
    final userService = _IntegrationUserService();
    final craftService = _IntegrationCraftService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            child: UserPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              visibleTabCodes: const [
                'user_management',
                'registration_approval',
                'account_settings',
              ],
              capabilityCodes: {
                UserFeaturePermissionCodes.userManagementCreate,
                UserFeaturePermissionCodes.userManagementUpdate,
                UserFeaturePermissionCodes.userManagementLifecycle,
                UserFeaturePermissionCodes.userManagementPasswordReset,
                UserFeaturePermissionCodes.userManagementDelete,
                UserFeaturePermissionCodes.userManagementExport,
                UserFeaturePermissionCodes.registrationApprovalApprove,
                UserFeaturePermissionCodes.registrationApprovalReject,
              },
              preferredTabCode: 'account_settings',
              tabPageBuilder: (tabCode, child) {
                if (child is UserManagementPage) {
                  return UserManagementPage(
                    session: child.session,
                    onLogout: child.onLogout,
                    canCreateUser: child.canCreateUser,
                    canEditUser: child.canEditUser,
                    canToggleUser: child.canToggleUser,
                    canResetPassword: child.canResetPassword,
                    canDeleteUser: child.canDeleteUser,
                    canRestoreUser: child.canRestoreUser,
                    canExport: child.canExport,
                    onNavigateToRoleManagement: child.onNavigateToRoleManagement,
                    userService: userService,
                    craftService: craftService,
                    saveExportFile: child.saveExportFile,
                    isCurrentTabVisible: child.isCurrentTabVisible,
                  );
                }
                if (child is RegistrationApprovalPage) {
                  return RegistrationApprovalPage(
                    session: child.session,
                    onLogout: child.onLogout,
                    canApprove: child.canApprove,
                    canReject: child.canReject,
                    routePayloadJson: child.routePayloadJson,
                    userService: userService,
                    craftService: craftService,
                  );
                }
                return child;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user-page-shell')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-settings-page-header')),
      findsOneWidget,
    );
  });
}
